local types = require("oh.typesystem.types")

local META = {}
META.Type = "table"
META.__index = META

local function sort(a, b) return a < b end

function META:GetSignature()
    if self.supress then
        return "*self*"
    end

    local s = {}

    self.supress = true
    for i, keyval in ipairs(self.data) do
        s[i] = keyval.key:GetSignature() .. "=" .. keyval.val:GetSignature()
    end
    self.supress = nil

    table.sort(s, sort)

    return table.concat(s, "\n")
end

local level = 0
function META:__tostring()
    if self.supress then
        return "*self*"
    end
    self.supress = true

    local s = {}

    level = level + 1
    local indent = ("\t"):rep(level)

    if self.contract then
        for i, keyval in ipairs(self.contract.data) do
            local key, val = tostring(self.data[i] and self.data[i].key or "undefined"), tostring(self.data[i] and self.data[i].val or "undefined")
            local tkey, tval = tostring(keyval.key), tostring(keyval.val)
            s[i] = indent .. tkey .. " ⊃ ".. key .. " = " .. tval .. " ⊃ " .. val
        end
    else
        for i, keyval in ipairs(self.data) do
            local key, val = tostring(keyval.key), tostring(keyval.val)
            s[i] = indent .. key .. " = " .. val
        end
    end
    level = level - 1

    self.supress = nil

    table.sort(s, sort)

    return "{\n" .. table.concat(s, ",\n") .. "\n" .. ("\t"):rep(level) .. "}"
end

function META:GetLength()
    return #self.data
end

-- TODO
local done

function META.SubsetOf(A, B)
    if A == B then
        return true
    end

    if B.Type == "any" then
        return true
    end

    if B.Type == "tuple" then
        if B:GetLength() > 0 then
            for i, a in ipairs(A.data) do
                if a.key.Type == "number" then
                    if not B:Get(i) then
                        return types.errors.missing(B, i)
                    end

                    if not a.val:SubsetOf(B:Get(i)) then
                        return types.errors.subset(a.val, B:Get(i))
                    end
                end
            end
        else
            local count = 0
            for i, a in ipairs(A.data) do
                if a.key.data ~= i then
                    return types.errors.other("index " .. tostring(a.key) .. " is not the same as " .. tostring(i))
                end

                count = count + 1
            end
            if count ~= B:GetMaxLength() then
                return types.errors.other(" count " .. tostring(count) .. " is not the same as max length " .. tostring(B:GetMaxLength()))
            end
        end

        return true
    elseif B.Type == "table" then

        if B.meta and B.meta == A then
            return true
        end

        done = done or {}
        for _, a in ipairs(A.data) do
            local b
            do
                local reasons = {}

                if not B.data[1] then
                    return types.errors.other("table is empty")
                end

                for _, keyval in ipairs(B.data) do
                    local ok, reason = a.key:SubsetOf(keyval.key)
                    if ok then
                        b = keyval
                        break
                    end
                    table.insert(reasons, reason)
                end

                if not b then
                    return types.errors.other(table.concat(reasons, "\n"))
                end
            end

            local key = a.val:GetSignature() .. b.val:GetSignature()
            if not done or not done[key] then
                if done then
                    done[key] = true
                end

                local ok, reason = a.val:SubsetOf(b.val)
                if not ok then
                    return types.errors.subset(a.val, b.val, reason)
                end
            end
        end
        done = nil

        return true
    elseif B.Type == "set" then
        return types.Set({A}):SubsetOf(B)
    end

    return types.errors.subset(A, B)
end

function META:IsDynamic()
    return true
end

function META:Union(tbk)
    local copy = types.Table({})

    for _, keyval in ipairs(self.data) do
        copy:Set(keyval.key, keyval.val)
    end

    for _, keyval in ipairs(tbk.data) do
        copy:Set(keyval.key, keyval.val)
    end

    return copy
end

function META:Delete(key)
    for i, keyval in ipairs(self.data) do
        if key:SubsetOf(keyval.key) then
            table.remove(self.data, i)
            return true
        end
    end
    return types.errors.other("cannot remove " .. tostring(key) .. " from table because it was not found in " .. tostring(self))
end

function META:GetKeySet()
    local set = types.Set()

    for _, keyval in ipairs(self.data) do
        set:AddElement(keyval.key:Copy())
    end

    return set
end

function META:Contains(key)
    return self:GetKeyVal(key, true)
end

function META:GetKeyVal(key, reverse_subset)
    if not self.data[1] then
        return types.errors.other("table has no definitions")
    end

    local reasons = {}

    for _, keyval in ipairs(self.data) do
        local ok, reason

        if reverse_subset then
            ok, reason = key:SubsetOf(keyval.key)
        else
            ok, reason = keyval.key:SubsetOf(key)
        end

        if ok then
            if keyval.val.self then
                keyval.val = self
            end

            return keyval
        end
        table.insert(reasons, reason)
    end

    return types.errors.other(table.concat(reasons, "\n"))
end

function META:Set(key, val)
    key = types.Cast(key)
    val = types.Cast(val)

    if key.Type == "symbol" and key:GetData() == nil then
        return types.errors.other("key is nil")
    end

    if key.Type == "set" then
        local set = key
        for _, key in ipairs(set:GetElements()) do
            if key.Type == "symbol" and key:GetData() == nil then
                return types.errors.other(set:GetLength() == 1 and "key is nil" or "can be nil")
            end
        end
    end

    -- delete entry
    if val == nil or (val.Type == "symbol" and val:GetData() == nil) then
        return self:Delete(key)
    end

    if self.contract then
        local keyval, reason = self.contract:GetKeyVal(key, true)

        if not keyval then
            return keyval, reason
        end

        local keyval, reason = val:SubsetOf(keyval.val)

        if not keyval then
            return keyval, reason
        end
    end

    -- if the key exists, check if we can replace it and maybe the value
    local keyval, reason = self:GetKeyVal(key, true)

    if not keyval then
        table.insert(self.data, {key = key, val = val})
    else
        if keyval.val and keyval.key:GetSignature() ~= key:GetSignature() then
            keyval.val = types.Set({keyval.val, val})
        else
            keyval.val = val
        end
    end

    return true
end

function META:Get(key, raw)
    key = types.Cast(key)

    local keyval, reason = self:GetKeyVal(key, true)

    if keyval then
        return keyval.val
    end

    return types.errors.other(reason)
end

function META:IsNumericallyIndexed()

    for _, keyval in ipairs(self:GetElements()) do
        if keyval.key.Type ~= "number" then
            return false
        end
    end

    return true
end

function META:CopyLiteralness(from)
    for _, keyval_from in ipairs(from.data) do
        local keyval, reason = self:GetKeyVal(keyval_from.key)

        if not keyval then
            return types.errors.other(reason)
        end

        if keyval_from.key.Type == "table" then
            keyval.key:CopyLiteralness(keyval_from.key)
        else
            keyval.key:MakeLiteral(keyval_from.key:IsLiteral())
        end

        if keyval_from.val.Type == "table" then
            keyval.val:CopyLiteralness(keyval_from.val)
        else
            keyval.val:MakeLiteral(keyval_from.val:IsLiteral())
        end
    end
    return true
end

function META:Copy()
    local copy = types.Table({})

    for _, keyval in ipairs(self.data) do
        local k,v = keyval.key, keyval.val

        if k == self then
            k = copy
        else
            k = k:Copy()
        end

        if v == self then
            v = copy
        else
            k = k:Copy()
        end

        copy:Set(k,v)
    end

    copy.meta = self.meta

    return copy
end

function META:GetData()
    return self.data
end

function META:pairs()
    local i = 1
    return function()
        local keyval = self.data and self.data[i]

        if not keyval then
            return nil
        end

        i = i + 1

        return keyval.key, keyval.val
    end
end

function META:Extend(t)
    local copy = self:Copy()

    for _, keyval in ipairs(t.data) do
        if not copy:Get(keyval.key) then
            if keyval.val.self then
                keyval.val = copy
            end
            copy:Set(keyval.key, keyval.val)
        end
    end

    return copy
end

function META:IsLiteral()
    for _, v in ipairs(self.data) do
        if v.val ~= self then

            if v.key.Type == "set" then
                return types.errors.other("the key " .. tostring(v.key) .. " is a set")
            end

            if v.val.Type == "set" then
                return types.errors.other("the value " .. tostring(v.val) .. " is a set")
            end

            local ok, reason = v.key:IsLiteral()
            if not ok then
                return types.errors.other("the key " .. tostring(v.key) .. " is not a literal because " .. tostring(reason))
            end

            local ok, reason = v.val:IsLiteral()
            if not ok then
                return types.errors.other("the value " .. tostring(v.val) .. " is not a literal because " .. tostring(reason))
            end
        end
    end

    return true
end

function META:IsFalsy()
    return false
end

function META:IsTruthy()
    return true
end

function META:Initialize(data)
    self.data = {}

    if data then
        for _, v in ipairs(data) do
            self:Set(v.key, v.val)
        end
    end
end

return types.RegisterType(META)