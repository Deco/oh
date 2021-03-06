local syntax = require("oh.lua.syntax")
local helpers = require("oh.helpers")

local META = {}
META.__index = META

--[[# type META.i = number ]]

META.syntax = syntax
require("oh.base_lexer")(META)

local function ReadLiteralString(self, multiline_comment)
    local start = self.i

    self:Advance(1)

    if self:IsValue("=") then
        for _ = self.i, self:GetLength() do
            self:Advance(1)
            if not self:IsValue("=") then
                break
            end
        end
    end

    if not self:IsValue("[") then
        if multiline_comment then return false end
        return nil, "expected " .. helpers.QuoteToken(self:GetChars(start, self.i - 1) .. "[") .. " got " .. helpers.QuoteToken(self:GetChars(start, self.i))
    end

    self:Advance(1)

    local closing = "]" .. string.rep("=", (self.i - start) - 2) .. "]"
    local pos = self:FindNearest(closing)
    if pos then
        self:Advance(pos)
        return true
    end

    return nil, "expected "..helpers.QuoteToken(closing).." reached end of code"
end

do
    function META:ReadCommentEscape()
        if
            self:IsValue("-") and
            self:IsValue("-", 1) and
            self:IsValue("[", 2) and
            self:IsValue("[", 3) and
            self:IsValue("#", 4)
        then
            self:Advance(5)
            self.comment_escape = string.char(self:GetChar())
            return true
        end
    end

    function META:ReadRemainingCommentEscape()
        if self.comment_escape and self:IsValue("]") and self:IsValue("]", 1) then
            self:Advance(2)

            return true
        end
    end
end

function META:ReadMultilineComment()
    if  self:IsValue("-") and self:IsValue("-", 1) and self:IsValue("[", 2) and (
        self:IsValue("[", 3) or self:IsValue("=", 3)
    ) then
        local start = self.i
        self:Advance(2)

        local ok, err = ReadLiteralString(self, true)

        if not ok then

            if err then
                self:Error("expected multiline comment to end: " .. err, start, start + 1)
                self:SetPosition(start + 2)
            else
                self:SetPosition(start)
            end

            return false
        end
        return true
    end
end

function META:ReadLineComment()
    if self:IsValue("-") and self:IsValue("-", 1)then
        self:Advance(#"--")

        for _ = self.i, self:GetLength() do
            if self:IsValue("\n") then
                break
            end
            self:Advance(1)
        end

        return true
    end

    return false
end


function META:ReadCMultilineComment()
    if self:IsValue("/") and self:IsValue("*", 1) then
        self:Advance(2)
        for _ = self.i, self:GetLength() do
            if self:IsValue("*") and self:IsValue("/", 1) then
                self:Advance(2)
                break
            end
            self:Advance(1)
        end

        return true
    end

    return false
end

function META:ReadCLineComment()
    if self:IsValue("/") and self:IsValue("/", 1)then

        self.potential_lua54_division_operator = true
        self:Advance(2)

        for _ = self.i, self:GetLength() do
            if self:IsValue("\n") then
                break
            end
            self:Advance(1)
        end

        return true
    end

    return false
end

function META:ReadMultilineString()
    if self:IsValue("[") and (self:IsValue("[", 1) or self:IsValue("=", 1)) then
        local start = self.i
        local ok, err = ReadLiteralString(self, false)

        if not ok then
            self:Error("expected multiline string to end: " .. err, start, start + 1)
            return true
        end

        return true
    end

    return false
end

do
    function META.GenerateMap(str)
        local out = {}
        for i = 1, #str do
            out[str:byte(i)] = true
        end
        return out
    end

    function META.BuildReadFunction(tbl, lower)
        local copy = {}
        local done = {}

        for _, str in ipairs(tbl) do
            if not done[str] then
                table.insert(copy, str)
                done[str] = true
            end
        end

        table.sort(copy, function(a, b) return #a > #b end)

        local kernel = "return function(self)\n"

            for _, str in ipairs(copy) do
            local lua = "if "

            for i = 1, #str do
                if lower then
                    lua = lua .. "(self:IsByte(" .. str:byte(i) .. "," .. i-1 .. ")" .. " or " .. "self:IsByte(" .. str:byte(i) .. "-32," .. i-1 .. ")) "
                else
                    lua = lua .. "self:IsByte(" .. str:byte(i) .. "," .. i-1 .. ") "
                end

                if i ~= #str then
                    lua = lua .. "and "
                end
            end

            lua = lua .. "then"
            lua = lua .. " self:Advance("..#str..") return true end"
            kernel = kernel .. lua .. "\n"
        end

        kernel = kernel .. "\nend"

        return assert(load(kernel))()
    end

    local allowed_hex = META.GenerateMap("1234567890abcdefABCDEF")

    META.IsInNumberAnnotation = META.BuildReadFunction(syntax.NumberAnnotations, true)

    function META:ReadNumberAnnotations(what)
        if what == "hex" then
            if self:IsValue("p") or self:IsValue("P") then
                return self:ReadNumberPowExponent("pow")
            end
        elseif what == "decimal" then
            if self:IsValue("e") or self:IsValue("E") then
                return self:ReadNumberPowExponent("exponent")
            end
        end

        return self:IsInNumberAnnotation()
    end

    function META:ReadNumberPowExponent(what)
        self:Advance(1)
        if self:IsValue("+") or self:IsValue("-") then
            self:Advance(1)
            if not syntax.IsNumber(self:GetChar()) then
                self:Error("malformed " .. what .. " expected number, got " .. string.char(self:GetChar()), self.i - 2)
                return false
            end
        end
        for _ = self.i, self:GetLength() do
            if not syntax.IsNumber(self:GetChar()) then
                break
            end
            self:Advance(1)
        end

        return true
    end

    function META:ReadHexNumber()
        self:Advance(2)

        local dot = false

        for _ = self.i, self:GetLength() do
            if self:IsValue("_") then self:Advance(1) end

            if self:IsValue(".") then
                if dot then
                    --self:Error("dot can only be placed once")
                    return
                end
                dot = true
                self:Advance(1)
            end

            if self:ReadNumberAnnotations("hex") then
                break
            end

            if allowed_hex[self:GetChar()] then
                self:Advance(1)
            elseif syntax.IsSpace(self:GetChar()) or syntax.IsSymbol(self:GetChar()) then
                break
            elseif self:GetChar() ~= 0 then
                self:Error("malformed number "..string.char(self:GetChar()).." in hex notation")
                return
            end
        end
    end

    function META:ReadBinaryNumber()
        self:Advance(2)

        for _ = self.i, self:GetLength() do
            if self:IsValue("_") then self:Advance(1) end

            if self:IsValue("1") or self:IsValue("0") then
                self:Advance(1)
            elseif syntax.IsSpace(self:GetChar()) or syntax.IsSymbol(self:GetChar()) then
                break
            elseif self:GetChar() ~= 0 then
                self:Error("malformed number "..string.char(self:GetChar()).." in binary notation")
                return
            end

            if self:ReadNumberAnnotations("binary") then
                break
            end
        end
    end

    function META:ReadDecimalNumber()
        local dot = false

        for _ = self.i, self:GetLength() do
            if self:IsValue("_") then self:Advance(1) end

            if self:IsValue(".") then
                if dot then
                    --self:Error("dot can only be placed once")
                    return
                end
                dot = true
                self:Advance(1)
            end

            if self:ReadNumberAnnotations("decimal") then
                break
            end

            if syntax.IsNumber(self:GetChar()) then
                self:Advance(1)
            --elseif self:IsSymbol() or self:IsSpace() then
                --break
            else--if self:GetChar() ~= 0 then
                --self:Error("malformed number "..self:GetChar().." in hex notation")
                break
            end
        end
    end

    function META:ReadNumber()
        if syntax.IsNumber(self:GetChar()) or (self:IsValue(".") and syntax.IsNumber(self:GetChar(1))) then

            if self:IsValue("x", 1) or self:IsValue("X", 1) then
                self:ReadHexNumber()
            elseif self:IsValue("b", 1) or self:IsValue("B", 1) then
                self:ReadBinaryNumber()
            else
                self:ReadDecimalNumber()
            end

            return true
        end

        return false
    end
end

function META:ReadInlineTypeCode()
    if self:IsValue("§") then
        self:Advance(1)
        for _ = self.i, self:GetLength() do
            if self:IsValue("\n") then
                break
            end
            self:Advance(1)
        end

        return true
    end
end

do
    local B = string.byte

    local escape_character = B[[\]]
    local quotes = {
        Double = [["]],
        Single = [[']],
    }

    for name, quote in pairs(quotes) do
        local key = "string_escape_" .. name
        local function escape(self, c)
            if self[key] then

                if c == B"z" and not self:IsValue(quote) then
                    self:ReadSpace(self)
                end

                self[key] = false
                return "string"
            end

            if c == escape_character then
                self[key] = true
            end

            return false
        end

        META["Read" .. name .. "String"] = function(self)
            if not self:IsValue(quote) then
                return false
            end

            local start = self.i
            self:Advance(1)

            for _ = self.i, self:GetLength() do
                local char = self:ReadChar()

                if not escape(self, char) then

                    if char == B"\n" then
                        self:Advance(-1)
                        self:Error("expected " .. name:lower() .. " quote to end", start, self.i - 1)
                        return true
                    end

                    if char == B(quote) then
                        return true
                    end
                end
            end

            self:Error("expected " .. name:lower() .. " quote to end: reached end of file", start, self.i - 1)

            return true
        end
    end
end

function META:OnInitialize()
    self.comment_escape = false
end

function META:Read()
    if self:ReadRemainingCommentEscape() then return "discard" end

    if
        self:ReadSpace() then               return "space", true elseif
        self:ReadCommentEscape() then       return "comment_escape", true elseif

        self:ReadCMultilineComment() then   return "multiline_comment", true elseif
        self:ReadCLineComment() then        return "line_comment", true elseif

        self:ReadMultilineComment() then    return "multiline_comment", true elseif
        self:ReadLineComment() then         return "line_comment", true elseif
        
        self:ReadInlineTypeCode() then      return "type_code", false elseif

        self:ReadNumber() then              return "number", false elseif

        self:ReadMultilineString() then     return "string", false elseif
        self:ReadSingleString() then        return "string", false elseif
        self:ReadDoubleString() then        return "string", false elseif

        self:ReadLetter() then              return "letter", false elseif
        self:ReadSymbol() then              return "symbol", false elseif
        self:ReadEndOfFile() then           return "end_of_file", false elseif
    false then end

    return self:ReadUnknown()
end

return function(code)
    local self = setmetatable({}, META)
    self:Initialize(code)
    return self
end