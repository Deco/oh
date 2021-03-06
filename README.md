# What
"oh" is a Lua based language with a typesystem that transpiles to Lua. It started as a toy project and place for me to explore how programming languages are built, but my eventual goal is to use this language in (goluwa)[https://github.com/CapsAdmin/goluwa].

I see this project as 5 parts at the moment. The lexer, parser, analyzer and emitter and the algebraic types.

# Parsing and transpiling
I wrote the lexer and parser trying not to look at existing Lua parsers (as a learning experience), but this makes it a little bit different in some ways. The syntax errors it can report are not standard and a bit more detailed. It's written in a way to be easily extendable for new syntax.

* Handles Luajit, lua 5.1-5.4 and Garry's mod Lua (which just adds optional C syntax).
* Errors are reported with character ranges
* Can continue when there's an error (useful for editors)
* Whitespace is preserved
* Can differantiate between single-line C comments and lua 5.4 divison operators.
* Transpiles bitwise operators, integer division, _ENV, etc down to luajit.

I have not fully decided the syntax for the language and runtime semantics for lua 5.3/4 features. But I feel this is more of a detail that can easily be changed later.

# Code analysis and typesystem
The analyzer works by evaluating the syntax tree. It runs similar to how Lua runs, but on a more general level and can take take multiple branches if its not sure. If everything is known about a program you may get its actual output at evaluation time. The typesystem is optional can be used similar to how you'd use it in Typescript.

The typesystem is designed to be non-opinionated and low level, kind of like the spirit of Lua. 

I try to achieve maximum type inference (for no real reason other than it's fun and challenging to make), but this can lead to some cryptic errors so in practice it's best to type your code, especially in functions.

For example:

```lua
local obj: nil | (function(): number)
local x = obj()
local y = x + 1
```

This code will log an error about potentially calling a nil value, but it will continue while removing nil from the set onwards. It does this by copying the current scope where.

# Current status and goals
At the moment I focus strongly on type inferrence and adding tests while trying to keep the code sane.

The parsing part of the project is mostly done except I have some ideas to make it cleaner and more extendable.

# Types

Fundementally the typesystem consists of number, string, table, function, symbol, set, tuple and any. 
As an example, types can be described by the language like this:

```lua
local type Boolean = true | false
local type Number = -inf .. inf | nan
local type String = $".*"
local type Any = Number | Boolean | String | nil

local type Table = { [exclude<|Any, nil|> | self] = Any | self }
type Any = Any | Table

local type Function = ( function(...Any): ...Any )

-- note that Function's Any does not include itself. This can be done but it's too complicated as an example
```

It's not entirely accurate but those types should behave the same way as number, string, boolean, etc.

# Numbers 
From literal to loose

```lua
type N = 1

local foo: N = 1
local foo: N = 2
      ^^^: 2 is not a subset of 1
```

```lua
type N = 1 .. 10

local foo: N = 1
local foo: N = 4
local foo: N = 11
      ^^^: 11 is not a subset of 1 .. 10
```

```lua
type N = 1 .. inf

local foo: N = 1
local bar: N = 2
local faz: N = -1
      ^^^: -1 is not a subset of 1 .. inf
```

```lua
type N = -inf .. inf

local foo: N = 0
local bar: N = 200
local faz: N = -10
local qux: N = 0/0
      ^^^: nan is not a subset of -inf .. inf
```

The logical progression here is to define N as `-inf .. inf | nan` but that has semantically the same meaning as `number`

# Strings
Strings can be defined as lua string patterns to constrain them:

```lua
local type mystring = $"FOO_.-"

local a: mystring = "FOO_BAR"
local b: mystring = "lol"
                    ^^^^^ : the pattern failed to match
```
A literal value:
```lua
type foo = "foo"
```

Or loose:
```lua
type one = string
```

`$".-"` is semantically the same as `string` but internally using `string` would be faster as it avoids string matching all the time

# Tables 
are similar to lua tables, where its key and value can be any type. 

the only special syntax is `self` which is used for self referencing types

here are some natural ways to define a table:

```lua
local type mytable = {
    foo = boolean,
    bar = string,
}

local type mytable = {
    ["foo"] = boolean,
    [number] = string,
}

local type mytable = {
    ["foo"] = boolean,
    [number] = string,
    faz = {
        [any] = any
    }
}
```

# Sets
A Set is a type separated by the bor operator `|` these are often used in uncertain conditions.

For example this case:

```lua
local x = 0
-- x is 0 here

if math.random() > 0.5 then
    x = 1
    -- x is 1 here
end

-- x is 1 | 0 here
```

This happens because `math.random()` returns `number` and `number > 0.5` is `true | false`.

```lua
local x = 0
-- x is 0 here
if true then
    x = 1
    -- x is 1 here
end
-- x is still 1 here
```
This happens because there's no doubt that `true` is true and so there's no uncertainty of what x is inside the if block or after it.

# Type functions
Type functions are lua functions. We can for example define math.ceil and a print function like this:

```lua
type function print(...)
    print(...)
end

type function math.floor(T: number)
    if T:IsLiteral() then
        return types.Number(math.floor(T:GetData())):MakeLiteral(true)
    end

    return types.Number()
end

local x = math.floor(5.5)
print(x)
```

When this code is analyzed, it will print 5 in its output. 
When transpiled to lua, the result is:
```lua
local x = math.floor(5.5)
print(x)
```

We can also define an assertion like this:

```lua
type function assert_whole_number(T: number)
    assert(math.ceil(T:GetData()) == T:GetData())
end

local x = assert_whole_number<|5.5|>
          ^^^^^^^^^^^^^^^^^^^: assertion failed!
```

But when this code is transpiled to lua, the result is:
```lua
local x = 5.5
```

`<|a,b,c|>` is the way to call type functions. In other languages it tends to be `<a,b,c>` but I chose this syntax to avoid conflicts with the `<` and `>` comparison operators


Here's an Exclude function, similar to how you would find in typescript.

```lua
type function Exclude(T, U)
    T:RemoveType(U)
    return T
end

local a: Exclude<|1|2|3, 2|>

type_assert(a, _ as 1|3)
```

It's also possible to use a more familiar "generics" syntax

```lua
local function Array<|T: any, L: number|>
    return {[1 .. L] = T}
end

local list: Array<|number, 3|> = {1, 2, 3, 4}
                                 ^^^^^^^^^^^^: 4 is not a subset of 1..3
```

Note that even though T type annotated with any, it does not mean that T becomes any inside the function. The type annotation here acts more of a constraint. In Typescript it would be something like

```ts
type Array<T extends any, length extends number> = {[key: 1 .. length]: T}
```
(assuming typescript supports number ranges)

Type function arguments needs to be explicitly typed.

# Examples

## List type

```lua
type StringList = { [1 .. inf] = string}

local names: StringList = {}
names[1] = "foo"
names[2] = "bar"
names[-1] = "faz"
^^^^^^^^^: -1 is not a subset of 1 .. inf
```

## ffi.cdef errors in the compiler
```lua
type function ffi.cdef(c_declaration: string)
    if c_declaration:IsLiteral() then
        local ffi = require("ffi")
        ffi.cdef(c_declaration:GetData())
    end
end

ffi.cdef("bad c declaration")
```

```lua
4 | d
5 | end
6 | 
8 | ffi.cdef("bad c declaration")
    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
-> | test.lua:8:0 : declaration specifier expected near 'bad'
```

## `load` evaluation

```lua
local function build_summary_function(tbl)
    local lua = {}
    table.insert(lua, "local sum = 0")
    table.insert(lua, "for i = " .. tbl.init .. ", " .. tbl.max .. " do")
    table.insert(lua, tbl.body)
    table.insert(lua, "end")
    table.insert(lua, "return sum")
    return load(table.concat(lua, "\n"), tbl.name)
end

local func = build_summary_function({
    name = "myfunc",
    init = 1,
    max = 10,
    body = "sum = sum + i !!ManuallyInsertedSyntaxError!!"
})
```

```lua
----------------------------------------------------------------------------------------------------
    4 | )
    5 |  table.insert(lua, "end")
    6 |  table.insert(lua, "return sum")
    8 |  return load(table.concat(lua, "\n"))
                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    9 | end
10 | 
----------------------------------------------------------------------------------------------------
-> | test.lua:8:8
    ----------------------------------------------------------------------------------------------------
    1 | local sum = 0
    2 | for i = 1, 10 do
    3 | sum = sum + i !!ManuallyInsertedSyntaxError!!
                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    4 | end
    5 | return sum
    ----------------------------------------------------------------------------------------------------
    -> | myfunc:3:14 : expected assignment or call expression got ❲symbol❳ (❲!❳)
```
This works because there is no uncertainty about the code generated passed to the load function. If there was, lets say we did `body = "sum = sum + 1" .. (unknown_global as string)`, this would make the table itself become uncertain so that table.concat would return `string` and not the actual results of the concatenation.

# Dictionary

I'm not an academic person and so I struggle a bit with naming things properly in the typesystem, but I think I'm getting the hang of it. Here are some definitions, some public and some private.

## Type hiearchy
The way I see types is that they are like parent / children. This can be visualized in "mind maps" neatly.

## Subset
If something is "sub" of /lower/inside/contains something larger. For example `1` is a subset of `number` because `number` contains all the numbers.
`1` is also a subset of `1 | 2` since the set contains `1`. But `number` is not a subset of `1` since `1` does not contain numbers like 2, 4, 100, 1337, 90377, etc.

```lua
    -- pseduo code

    local one = {1}
    local number = {1,2,3,4,5,6,7,...} -- all possible numbers
    
    local function is_subset(a, b)
        for _, val in ipairs(a) do
            if not table.contains(val, b) then
                return false, "a is not a subset of b: type b does not contain " .. tostring(val)
            end
        end
        return true
    end

    assert(is_subset(one, number))
    assert(not is_subset(number, one))
```

## Superset
The logical opposite of subset
```lua
local is_superset = function(a, b) return is_subset(b, a) end
```

## Literal
Something of which nothing can be a subset of, except itself. It is similar to an atom or unit in other languages.

## runtime / typesystem
The analyzer will analyze code in these two different contexts. Locals and environment variables are stored in separate scopes and code behaves a little bit different in each environment. They are 2 different worlds where the typesystem watches and tells you about how the runtime beahves.
```lua
local a: *type expression analyzed in "typesystem"* = *runtime expression anlyzed in "runtime"*
```

## Contract
If a runtime object is given a contract, it cannot be anything that breaks this contract.


```lua
local a: 1 .. 5 = 3 -- 3 is within 1 .. 5 so the contract is not broken
a = 1 -- 1 is still within the contract
a = 6 -- the contract was broken, so log an error.
```

# Development

To run tests run `luajit test/run`

I've setup vscode to run the task `onsave` when a file is saved with the plugin `gruntfuggly.triggertaskonsave`. This runs `on_editor_save.lua` which run tests when modifying the core of the language.

I also have a file called `test_focus.lua` in root which will override the test suite when the file is not empty. This makes it easier for me to debug specific cases.

# Similar projects

Teal (https://github.com/teal-language/tl) is a language similar to this, with a much higher likelyhood of succeeding as it does not intend to be as verbose as this project. I'm thinking a nice goal is that I can contribute what I've learned here, be it through tests or other things.


