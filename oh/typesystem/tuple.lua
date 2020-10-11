local types = require("oh.typesystem.types")

local META = {}
META.Type = "tuple"
META.__index = META

function META:GetSignature()
    local s = {}

    for i,v in ipairs(self.data) do
        s[i] = v:GetSignature()
    end

    return table.concat(s, " ")
end

function META:__tostring()
    local s = {}

    for i,v in ipairs(self.data) do
        s[i] = tostring(v)
    end

    return (self.ElementType and tostring(self.ElementType) or "") .. "⦅" .. table.concat(s, ", ") .. (self.max == math.huge and "..." or (self.max and ("#" .. self.max)) or "") .. "⦆"
end

function META:Merge(tup)
    local src = self:GetTypes()
    local dst = tup:GetTypes()

    for i,v in ipairs(dst) do
        if src[i] then

            if src[i].Type == "tuple" and src[i].max == math.huge then
                break
            else
                src[i] = types.Set({src[i], v})
            end
        else
            src[i] = dst[i]:Copy()
        end
    end

    return self
end

function META:SetElementType(typ)
    self.ElementType = typ
    return self
end

function META:GetElementType()
    return self.ElementType
end

function META:GetMaxLength()
    return self.max or 0
end

function META:Max(len)
    self.max = len
    return self
end

function META:GetTypes()
    return self.data
end

function META:GetMinimumLength()
    for i, v in ipairs(self:GetTypes()) do
        if v.Type == "symbol" and v:GetData() == nil then
            return i - 1
        end

        if v.Type == "set" and v:Get(types.Nil) then
            return i - 1
        end
    end

    return #self.data
end

function META:SetReferenceId(id)

    for i = 1, #self:GetTypes() do
        self:Get(i):SetReferenceId(id)
    end

    return self
end

function META:GetLength()
    return #self.data
end

function META:GetData()
    return self.data
end

function META:Copy(map)
    map = map or {}

    local copy = types.Tuple({})
    map[self] = map[self] or copy
    
    for i, v in ipairs(self.data) do
        v = map[v] or v:Copy(map)
        map[v] = map[v] or v
        copy:Set(i, v)
    end

    copy.node = self.node
    copy.ElementType = self.ElementType
    copy.max = self.max

    return copy
end

function META.SubsetOf(A, B)
    if A:GetLength() == 1 then
        return A:Get(1):SubsetOf(B)
    end

    if B.Type == "any" then
        return true
    end

    if B.Type == "table" then
        if not B:IsNumericallyIndexed() then
            return types.errors.other(tostring(B) .. " cannot be treated as a tuple because it contains non a numeric index " .. tostring(A))
        end
    end

    if A.ElementType and A.ElementType.Type == "any" then
        return true
    end
    
    if A:GetLength() > B:GetLength() and A:GetLength() > B:GetMaxLength() then
        return types.errors.other(tostring(A) .. " is larger than " .. tostring(B))
    end

    if B:GetLength() > A:GetLength() and B:GetLength() > A:GetMaxLength() then
        return types.errors.other(tostring(A) .. " is smaller than " .. tostring(B))
    end

    -- vararg
    if B.max == math.huge then
        local ok, reason = B:Get(1):SubsetOf(A)
        if not ok then
            return types.errors.subset(B:Get(1), A, reason)
        end
        return true
    end

    for i = 1, A:GetLength() do
        local a = A:Get(i)
        local b = B:Get(i)

        if not b then
            return types.errors.missing(B, i)
        end

        local ok, reason = a:SubsetOf(b)

        if not ok then
            return types.errors.subset(a, b, reason)
        end
    end

    return true
end

function META:Get(key)
    if self.max and self.ElementType then
        if key <= self.max then
            return self.ElementType:Copy()
        end
    end

    if type(key) == "number" then
        return self.data[key]
    end

    if key.Type == "number" or key.Type == "string" and key:IsLiteral() then
        key = key.data
    end

    return self.data[key]
end

function META:Set(key, val)
    self.data[key] =  val
    return true
end


function META:IsConst()
    for _, obj in ipairs(self.data) do
        if not obj:IsConst() then
            return false
        end
    end
    return true
end

function META:IsEmpty()
    return self:GetLength() == 0
end

function META:SetLength()

end

function META:IsTruthy()
    return true
end

function META:IsFalsy()
    return false
end

function META:Unpack(length)
    if self.max and self.ElementType then
        if length then
            local t = {}
            for i = 1, length do
                t[i] = self.ElementType:Copy()
            end
            return table.unpack(t)
        end

        return self
    end

    return table.unpack(self:GetData(), 1, length)
end

function META:Initialize(data)
    self.data = data or {}

    for _,v in ipairs(self.data) do
        if not types.IsTypeObject(v) then
            for k,v in pairs(v) do print(k,v) end
            error(tostring(v) .. " is not a type object")
        end
    end

    return true
end


return types.RegisterType(META)