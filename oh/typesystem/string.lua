local types = require("oh.typesystem.types")
local syntax = require("oh.lua.syntax")
local bit = not _G.bit and require("bit32") or _G.bit

local META = {}
META.Type = "string"
META.__index = META

function META:GetSignature()
    if self.literal then
        return "string" .. "-" .. types.GetSignature(self.data)
    end

    return "string"
end

function META:Get(key)
    local val = type(self.data) == "table" and self.data:Get(key)

    if not val and self.meta then
        local index = self.meta:Get("__index")
        if index.Type == "table" then
            return index:Get(key)
        end
    end

    return val
end

function META:Set(key, val)
    return false, "cannot " .. tostring(self) .. "[" .. tostring(key) .. "] = " .. tostring(val)
end

function META:GetData()
    return self.data
end

function META:Copy()
    local data = self.data

    local copy = types.String(data):MakeLiteral(self.literal)
    copy.volatile = self.volatile
    return copy
end

function META.SubsetOf(A, B)
    if B.Type == "tuple" and B:GetLength() == 1 then B = B:Get(1) end

    if B.Type == "set" then
        local errors = {}
        for _, b in ipairs(B:GetElements()) do
            local ok, reason = A:SubsetOf(b)
            if ok then
                return true
            end
            table.insert(errors, reason)
        end
        return false, table.concat(errors, "\n")
    end

    if A.Type == "any" or A.volatile then return true end
    if B.Type == "any" or B.volatile then return true end

    if B.Type == "string" then

        if A.literal == true and B.literal == true then
            -- compare against literals
            if A.data == B.data then
                return true
            end

            return types.errors.subset(A, B)
        elseif A.data == nil and B.data == nil then
            -- number contains number
            return true
        elseif A.literal and not B.literal then
            -- 42 subset of number?
            return true
        elseif not A.literal and B.literal then
            -- number subset of 42 ?
            return types.errors.subset(A, B)
        end

        -- number == number
        return true
    else
        return false, tostring(A) .. " is not the same type as " .. tostring(B)
    end
    error("this shouldn't be reached ")

    return false
end

function META:__tostring()
    --return "「"..self.uid .. " 〉" .. self:GetSignature() .. "」"

    if self.volatile then
        local str = "string"

        if self.data ~= nil then
            str = str .. "(" .. tostring(self.data) .. ")"
        end

        str = str .. "💥"

        return str
    end

    if self.literal then
        if self.data then
            return ("%q"):format(self.data)
        end

        if self.data == nil then
            return "string"
        end

        return tostring(self.data) .. (self.max and (".." .. tostring(self.max.data)) or "")
    end

    if self.data == nil then
        return "string"
    end

    return "string" .. "(".. tostring(self.data) .. (self.max and (".." .. self.max.data) or "") .. ")"
end

function META:Serialize()
    return self:__tostring()
end

function META:IsVolatile()
    return self.volatile == true
end

function META:IsFalsy()
    return false
end

function META:IsTruthy()
    return true
end

return types.RegisterType(META)