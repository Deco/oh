local syntax = require("oh.lua.syntax")
local print_util = require("oh.print_util")

local META = {}

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
        return nil, "expected " .. print_util.QuoteToken(self:GetChars(start, self.i - 1) .. "[") .. " got " .. print_util.QuoteToken(self:GetChars(start, self.i))
    end

    self:Advance(1)

    local closing = "]" .. string.rep("=", (self.i - start) - 2) .. "]"
    local pos = self:FindNearest(closing)
    if pos then
        self:Advance(pos)
        return true
    end

    return nil, "expected "..print_util.QuoteToken(closing).." reached end of code"
end

do
    function META:IsMultilineComment()
        return
            self:IsValue("-") and self:IsValue("-", 1) and self:IsValue("[", 2) and (
                self:IsValue("[", 3) or self:IsValue("=", 3)
            )
    end

    function META:ReadMultilineComment()
        local start = self.i
        self:Advance(2)

        if self:IsValue("#", 2) then
            self:Advance(3)
            self.comment_escape = true
            return "comment_escape_start"
        end

        local ok, err = ReadLiteralString(self, true)

        if not ok then
            if err then
                self.i = start + 2
                self:Error("unterminated multiline comment: " .. err, start, start + 1)
            else
                self.i = start
                return self:ReadLineComment()
            end
        end

        return "multiline_comment"
    end
end

do
    function META:IsLineComment() 
        return self:IsValue("-") and self:IsValue("-", 1)
        -- we have to add this check here becuse line comments / whitespace is read before non whitespace
        and not self:IsValue(":", 2) -- type comment
    end 

    function META:ReadLineComment()
        self:Advance(#"--")

        for _ = self.i, self:GetLength() do
            if self:IsValue("\n") then
                break
            end
            self:Advance(1)
        end

        return "line_comment"
    end
end

do
    function META:IsTypeComment()
        return self:IsValue("-") and self:IsValue("-", 1) and self:IsValue(":", 2)
    end

    function META:ReadTypeComment()
        self:Advance(#"--:")

        for _ = self.i, self:GetLength() do
            if self:IsValue("\n") then
                break
            end
            self:Advance(1)
        end

        return "type_comment"
    end
end

do
    function META:IsMultilineString()
        return self:IsValue("[") and (
            self:IsValue("[", 1) or self:IsValue("=", 1)
        )
    end

    function META:ReadMultilineString()
        local start = self.i
        local ok, err = ReadLiteralString(self, false)

        if not ok then
            self:Error("unterminated multiline string: " .. err, start, start + 1)
            return
        end

        return "string"
    end
end
    
do
    function META.GenerateMap(str)
        local out = {}
        for i = 1, #str do
            out[str:byte(i)] = true
        end
        return out
    end

    function META.GenerateLookupFunction(tbl, lower)
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

        return assert(loadstring(kernel))()
    end

    local allowed_hex = META.GenerateMap("1234567890abcdefABCDEF")

    META.IsInNumberAnnotation = META.GenerateLookupFunction(syntax.NumberAnnotations, true)

    function META:ReadNumberAnnotations(what)
        if what == "hex" then
            if self:IsNumberPow() then
                return self:ReadNumberPowExponent("pow")
            end
        elseif what == "decimal" then
            if self:IsNumberExponent() then
                return self:ReadNumberPowExponent("exponent")
            end
        end

        return self:IsInNumberAnnotation()
    end

    function META:IsNumberExponent()
        return self:IsValue("e") or self:IsValue("E")
    end

    function META:IsNumberPow()
        return self:IsValue("p") or self:IsValue("P")
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
            elseif self:IsSymbol() or self:IsSpace() then
                break
            elseif self:GetChar() ~= 0 then
                self:Error("malformed number "..string.char(self:GetChar()).." in hex notation")
                return
            end
        end

        return "number"
    end

    function META:ReadBinaryNumber()
        self:Advance(2)

        for _ = self.i, self:GetLength() do
            if self:IsValue("_") then self:Advance(1) end

            if self:IsValue("1") or self:IsValue("0") then
                self:Advance(1)
            elseif self:IsSymbol() or self:IsSpace() then
                break
            elseif self:GetChar() ~= 0 then
                self:Error("malformed number "..string.char(self:GetChar()).." in binary notation")
                return
            end

            if self:ReadNumberAnnotations("binary") then
                break
            end
        end

        return "number"
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

        return "number"
    end

    function META:IsNumber()
        return syntax.IsNumber(self:GetChar()) or (self:IsValue(".") and syntax.IsNumber(self:GetChar(1)))
    end

    function META:ReadNumber()
        if self:IsValue("x", 1) or self:IsValue("X", 1) then
            return self:ReadHexNumber()
        elseif self:IsValue("b", 1) or self:IsValue("B", 1) then
            return self:ReadBinaryNumber()
        end

        return self:ReadDecimalNumber()
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
        META["Is" .. name .. "String"] = function(self)
            return self:IsValue(quote)
        end

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
            local start = self.i
            self:Advance(1)

            for _ = self.i, self:GetLength() do
                local char = self:ReadChar()

                if not escape(self, char) then

                    if char == B"\n" then
                        self:Advance(-1)
                        self:Error("unterminated " .. name:lower() .. " quote", start, self.i - 1)
                        return false
                    end

                    if char == B(quote) then
                        return "string"
                    end
                end
            end

            self:Error("unterminated " .. name:lower() .. " quote: reached end of file", start, self.i - 1)

            return false
        end
    end
end

function META:ReadWhiteSpace()
    if
    self:IsSpace() then                 return self:ReadSpace() elseif

    self:IsMultilineComment() then      return self:ReadMultilineComment() elseif
    self:IsLineComment() then           return self:ReadLineComment() elseif
        
    false then end
end

function META:ReadNonWhiteSpace()
    if
    self:IsTypeComment() then           return self:ReadTypeComment() elseif
    self:IsMultilineString() then       return self:ReadMultilineString() elseif
    self:IsNumber() then                return self:ReadNumber() elseif
    self:IsSingleString() then          return self:ReadSingleString() elseif
    self:IsDoubleString() then          return self:ReadDoubleString() elseif
                        
    self:IsEndOfFile() then             return self:ReadEndOfFile() elseif
    self:IsLetter() then                return self:ReadLetter() elseif
    self:IsSymbol() then                return self:ReadSymbol() elseif
    false then end
end

return require("oh.lexer")(META, require("oh.lua.syntax"))