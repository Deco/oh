local types = require("oh.typesystem.types")

local META = {}
META.Type = "tuple"
META.__index = META

function META:GetSignature()
    local s = {}

    for i,v in ipairs(self.data) do
        s[i] = v:GetSignature()
    end

    if self.Remainder then
        table.insert(s, self.Remainder:GetSignature())
    end

    if self.Repeat then
        table.insert(s, "x")
        table.insert(s, tostring(self.Repeat))
    end

    return table.concat(s, " ")
end

function META:__tostring()
    local s = {}

    for i,v in ipairs(self.data) do
        s[i] = tostring(v)
    end

    if self.Remainder then
        table.insert(s, tostring(self.Remainder))
    end

    local s = "⦅" .. table.concat(s, ", ") .. "⦆"

    if self.Repeat then
        s = s .. "×" .. tostring(self.Repeat)
    end

    return s
end

function META:Merge(tup)
    local src = self.data

    for i = 1, tup:GetMinimumLength() do
        local a = self:Get(i)
        local b = tup:Get(i)
        if a then
            src[i] = types.Set({a, b})
        else
            src[i] = b:Copy()
        end
    end

    self.Remainder = tup.Remainder or self.Remainder
    self.Repeat = tup.Repeat or self.Repeat

    return self
end

function META:GetTypes()
    return self.data
end

function META:SetReferenceId(id)

    for i = 1, #self:GetTypes() do
        self:Get(i):SetReferenceId(id)
    end

    return self
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
    copy.Remainder = self.Remainder
    copy.Repeat = self.Repeat

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

    for i = 1, A:GetLength() do
        local a = A:Get(i)
        local b = B:Get(i)

        if not b then
            return types.errors.missing(B, "index " .. i .. ": " ..tostring(a))
        end

        local ok, reason = a:SubsetOf(b)

        if not ok then
            return types.errors.subset(a, b, reason)
        end
    end

    return true
end

function META:Get(key)
    local real_key = key
    assert(type(key) == "number", "key must be a number")
    
    local val = self.data[key]

    if not val and self.Repeat and key <= (#self.data * self.Repeat) then
        return self.data[((key-1) % #self.data) + 1]
    end

    if not val and self.Remainder then
        return self.Remainder:Get(key - #self.data)
    end

    return val
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
    return self:Get(1):IsTruthy()
end

function META:IsFalsy()
    return self:Get(1):IsFalsy()
end

function META:GetLength()
    if self.Remainder then
        return #self.data + self.Remainder:GetLength()
    end
    
    if self.Repeat then
        return #self.data * self.Repeat
    end

    return #self.data
end

function META:GetMinimumLength()
    return #self.data
end

function META:AddRemainder(obj)
    self.Remainder = obj
    return self
end

function META:SetRepeat(amt)
    self.Repeat = amt
    return self
end

function META:Unpack(length)
    length = length or self:GetLength()
    length = math.min(length, self:GetLength())

    assert(length ~= math.huge, "length must be finite")

    local out = {}

    local i = 1
    for _ = 1, length do
        out[i] = self:Get(i)
        if out[i] and out[i].Type == "tuple" then
            if i == length then
                for _, v in ipairs({out[i]:Unpack(out[i]:GetMinimumLength())}) do
                    out[i] = v
                    i = i + 1
                end
            else
                out[i] = out[i]:Get(1)
            end
        end
        i = i + 1
    end

    return table.unpack(out)
end

function META:Slice(start, stop)
    -- NOT ACCURATE YET

    start = start or 1
    stop = stop or #self.data

    local copy = self:Copy()
    copy.data = {}
    for i = start, stop do
        table.insert(copy.data, self.data[i])
    end
    return copy
end

function META:Initialize(data)
    self.data = {}
    data = data or {}
    
    for i, v in ipairs(data) do
        if not types.IsTypeObject(v) then
            for k,v in pairs(v) do print(k,v) end
            error(tostring(v) .. " is not a type object")
        end

        if i == #data and v.Type == "tuple" and not v.Remainder then
            self:AddRemainder(v)
        else
            --if v.Type == "tuple" then print(debug.traceback("uh oh: " .. tostring(v) .. " " .. i))end
            self:Set(i, v)
        end
    end


    return true
end


return types.RegisterType(META)