local oh = require("oh")
local C = oh.Code

local tests = {C[[
    local a = 1
    type_assert(a, 1)
]],C[[
    local type a = number
    type_assert(a, _ as number)
]],C[[
    local a
    a = 1
    type_assert(a, 1)
]],C[[
    local a = {}
    a.foo = {}

    local c = 0

    function a:bar()
        type_assert(self, a)
        c = 1
    end

    a:bar()

    type_assert(c, 1)
]], C[[
    local function test()

    end

    type_assert(test, nil as function():)
]], C[[
    local a = 1
    repeat
        type_assert(a, 1)
    until false
]], C[[
    local c = 0
    for i = 1, 10, 2 do
        type_assert(i, nil as number)
        if i == 1 then
            c = 1
            break
        end
    end
    type_assert(c, 1)
]], C[[
    local a = 0
    while false do
        a = 1
    end
    type_assert(a, 0)
]], C[[
    local function lol(a,b,c)
        if true then
            return a+b+c
        elseif true then
            return true
        end
        a = 0
        return a
    end
    local a = lol(1,2,3)

    type_assert(a, 6)
]], C[[
    local a = 1+2+3+4
    local b = nil

    local function print(foo)
        return foo
    end

    if a then
        b = print(a+10)
    end

    type_assert(b, 20)
    type_assert(a, 10)
]], C[[
    local a
    a = 2

    if true then
        local function foo(lol)
            return foo(lol), nil
        end
        local complex = foo(a)
        type_assert(foo, nil as function(_:any, _:nil):number )
    end
]], C[[
    b = {}
    b.lol = 1

    local a = b

    local function foo(tbl)
        return tbl.lol + 1
    end

    local c = foo(a)

    type_assert(c, 2)
]], C[[
    local META = {}
    META.__index = META

    function META:Test(a,b,c)
        return 1+c,2+b,3+a
    end

    local a,b,c = META:Test(1,2,3)

    local ret

    if someunknownglobal as any then
        ret = a+b+c
    end

    type_assert(ret, 12)
]], C[[
    local function test(a)
        if a then
            return 1
        end

        return false
    end

    local res = test(true)

    if res then
        local a = 1 + res

        type_assert(a, 2)
    end
]], C[[
    local a = 1337
    for i = 1, 10 do
        type_assert(i, 1)
        if i == 15 then
            a = 7777
            break
        end
    end
    type_assert(a, 1337)
]], C[[
    local function lol(a, ...)
        local lol,foo,bar = ...

        if a == 1 then return 1 end
        if a == 2 then return {} end
        if a == 3 then return "", foo+2,3 end
    end

    local a,b,c = lol(3,1,2,3)

    type_assert(a, "")
    type_assert(b, 4)
    type_assert(c, 3)
]], C[[
    function foo(a, b) return a+b end

    local a = foo(1,2)

    type_assert(a, 3)
]],C[[
local   a,b,c = 1,2,3
        d,e,f = 4,5,6

type_assert(a, 1)
type_assert(b, 2)
type_assert(c, 3)

type_assert(d, 4)
type_assert(e, 5)
type_assert(f, 6)

local   vararg_1 = ... as any
        vararg_2 = ... as any

type_assert(vararg_1, _ as any)
type_assert(vararg_2, _ as any)

local function test(...)
    return a,b,c, ...
end

A, B, C, D = test(), 4

type_assert(A, 1)
type_assert(B, 2)
type_assert(C, 3)
type_assert(D, nil as ...) -- THIS IS WRONG, tuple of any?

local z,x,y,æ,ø,å = test(4,5,6)
local novalue

type_assert(z, 1)
type_assert(x, 2)
type_assert(y, 3)
type_assert(æ, 4)
type_assert(ø, 5)
type_assert(å, 6)

]], C[[
local a = {b = {c = {}}}
a.b.c = 1
]],C[[
    local a = function(b)
        if b then
            return true
        end
        return 1,2,3
    end

    a()
    a(true)

]],C[[
    function string(ok)
        if ok then
            return 2
        else
            return "hello"
        end
    end

    string(true)
    local ag = string()

    type_assert(ag, "hello")

]],C[[
    local foo = {lol = 3}
    function foo:bar(a)
        return a+self.lol
    end

    type_assert(foo:bar(2), 5)

]],C[[
    function prefix (w1, w2)
        return w1 .. ' ' .. w2
    end

    type_assert(prefix("hello", "world"), "hello world")
]],C[[
    local function test(max)
        for i = 1, max do
            if i == 20 then
                return false
            end

            if i == 5 then
                return true
            end
        end
        return "lol"
    end

    local a = test(20)
    local b = test(5)
    local c = test(1)

    local LOL = a

    type_assert(a, false)
    type_assert(b, true)
    type_assert(c, "lol")
]], C[[
    local func = function()
        local a = 1

        return function()
            return a
        end
    end

    local f = func()

    type_assert(f(), 1)
]],C[[
    function prefix (w1, w2)
        return w1 .. ' ' .. w2
    end

    local w1,w2 = "foo", "bar"
    local statetab = {["foo bar"] = 1337}

    local test = statetab[prefix(w1, w2)]
    type_assert(test, 1337)
]],C[[
    local function test(a)
        --if a > 10 then return a end
        return test(a+1)
    end

    type_assert(test(1), nil as any)
]],C[[
    local function test(a)
        if a > 10 then return a end
        return test(a+1)
    end

    type_assert(test(1), nil as number)
]],C[[
    local a: string | number = 1

    local function test(a: number, b: string): boolean, number

    end

    local foo,bar = test(1, "")

    type_assert(foo, nil as boolean)
    type_assert(bar, nil as number)
]],C[[
    do
        type x = boolean | number
    end

    type c = x
    local a: c
    type b = {foo = a as any}
    local c: function(a: number, b:number): b, b

    type_assert(c, nil as function(_:table, _:table): number, number)

]], C[[
    local function test(a:number,b: number)
        return a + b
    end

    type_assert(test, nil as function(_:number, _:number): number)
]],C[[
    type lol = number

    interface math {
        sin = function(a: lol, b: string): lol
        cos = function(a: string): lol
        cos = function(a: number): lol
    }

    interface math {
        lol = function(): lol
    }


    local a = math.sin(1, "")
    local b = math.lol()

    type_assert(a, nil as number)
    type_assert(b, nil as number)
]], C[[
    interface foo {
        a = number
        b = {
            str = string,
        }
    }

    local b: foo = {}
    local c = b.a
    local d = b.b.str

    type_assert(b, nil as foo)
]], C[[
  --  local a: (string|number)[] = {"", ""}
  --  a[1] = ""
  --  a[2] = 1
]], C[[
    interface foo {
        bar = function(a: boolean, b: number): true
        bar = function(a: number): false
    }

    local a = foo.bar(true, 1)
    local b = foo.bar(1)

    type_assert(a, true)
    type_assert(b, false)
]],C[[
    local a: string = "1"
    type a = string | number | (boolean | string)

    type type_func = function(a,b,c) return types.Type("string"), types.Type("number") end
    local a, b = type_func(a,2,3)
    type_assert(a, _ as string)
    type_assert(b, _ as number)
]],C[[
    type Array = function(T, L)
        return types.Type("list", T.name, L.value)
    end

    type Exclude = function(T, U)
        if T.types then
            for i,v in ipairs(T.types) do
                if v:IsType(U) and v.value == U.value then
                    table.remove(T.types, i)
                end
            end
        end
        return T
    end

    local list: Array<number, 3> = {1, 2, 3}
    local a: Exclude<1|2|3, 2> = 1

    type_assert(a, _ as 1|3)
    type_assert(a, _ as number[3])
]],C[[
    type next = function(t, k)
        -- behavior of the external next function
        -- we can literally just pass what the next function returns
        local a,b

        if k then
            a,b = next(t.value, k.value)
        else
            a,b = next(t.value)
        end

        if type(a) == "table" and a.name then
            a = a.value
        end

        if type(b) == "table" and b.name then
            b = b.value
        end

        return types.Type(type(a), a), types.Type(type(b), b)
    end

    function pairs(t)
        return next, t, nil
    end

    do
        local function iter(a, i)
            i = i + 1
            local v = a[i]
            if v then
                return i, v
            end
        end

        function ipairs(a)
            return iter, a, 0
        end
    end

    for k,v in pairs({foo = true}) do
        type_assert(k, _ as "foo")
        type_assert(v, _ as true)
    end

    for i,v in ipairs({"LOL",2,3}) do
        type_assert(i, _ as 1)
        type_assert(v, _ as "LOL")
    end
]],C[[
    type next = function(tbl, _key)
        local key, val

        for k, v in pairs(tbl.value) do
            if not key then
                key = types.Type(type(k))
            elseif not key:IsType(k) then
                if type(k) == "string" then
                    key = types.Fuse(key, types.Type("string"))
                else
                    key = types.Fuse(key, types.Type(k.name))
                end
            end

            if not val then
                val = types.Type(type(v))
            else
                if not val:IsType(v) then
                    val = types.Fuse(val, types.Type(v.name))
                end
            end
        end
    end

    local a = {
        foo = true,
        bar = false,
        a = 1,
        lol = {},
    }

    local k, v = next(a)
]],C[[
    local a: _G.string

    type_assert(a, _G.string)
]],C[[
    local a = ""

    if a is string then
        type_assert(a, _ as string)
    end

]],C[[
    local a = math.cos(1)
    type_assert(a, nil as number)

    if a is number then
        type_assert(a, _ as number)
    end
]],C[[
    interface math {
        sin = function(number): number
    }

    interface math {
        cos = function(number): number
    }

    local a = math.sin(1)

    type_assert(a, _ as number)
]],C[=[
    local a = 1
    function b(lol)
        if lol == 1 then return "foo" end
        return lol + 4, true
    end
    local d = b(2)
    local d = b(a)

    local lol: {a = boolean} = {}
    lol.a = true

    function lol:Foo(foo, bar)
        local a = self.a
    end

    --local lol: string[] = {}

    --local a = table.concat(lol)
]=],C[[
    type a = function()
        _G.LOL = true
    end

    type b = function()
        _G.LOL = nil
        analyzer:GetValue("a", "typesystem").func()
        if not _G.LOL then
            error("test fail")
        end
    end

    local a = b()
]],C[[
    a: number = (lol as any)()

    type_assert(a, _ as number)
]], C[[
    local a = {}
    a.b: boolean, a.c: number = LOL as any, LOL2 as any
]],C[[
    type test = {
        sin = (function(number): number),
        cos = (function(number): number),
    }

    local a = test.sin(1)
]],C[[
    type lol = function(a) return a end
    local a: lol<string>
    type_assert(a, _ as string)
]],C[[
    local a = {}
    function a:lol(a,b,c)
        return a+b+c
    end
    type_assert(a:lol(1,2,3), 6)
]],C[[
    local a = {}
    function a.lol(_, a,b,c)
        return a+b+c
    end
    type_assert(a:lol(1,2,3), 6)
]],C[[
    local a = {}
    function a.lol(a,b,c)
        return a+b+c
    end
    type_assert(a.lol(1,2,3), 6)
]],C[[
    local a = {}
    function a.lol(...)
        local a,b,c = ...
        return a+b+c
    end
    type_assert(a.lol(1,2,3), 6)
]],C[[
    local a = {}
    function a.lol(foo, ...)
        local a,b,c = ...
        return a+b+c+foo
    end
    type_assert(a.lol(10,1,2,3), 16)
]],C[[
    local a = (function(...) return ...+... end)(10)
]],C[[
    local k,v = next({k = 1})
]],C[[
    -- this will error with not defined
    --type_assert(TOTAL_STRANGER_COUNT, _ as number)
    --type_assert(TOTAL_STRANGER_STRING, _ as string)
]],C[[
    local a = b as any
    local b = 2
    type_assert(a, _ as any)
]],C[[
    type test = (function(boolean, boolean): number) | (function(boolean): string)

    local a = test(true, true)
    local b = test(true)

    type_assert(a, _ as number)
    type_assert(b, _ as string)
]]}

for _, code_data in ipairs(tests) do
    if code_data == false then return end

    --function code_data:OnError(obj, msg, start, stop, ...) print(require("oh.print_util").FormatError(self.code, self.name, msg, start, stop)) end

    assert(code_data:Analyze())
end