
local types = require("oh.types")

local META = {}
META.__index = META

local table_insert = table.insert

do
    function META:Hash(t)
        if type(t) == "string" then
            return t
        end

        assert(type(t.value.value) == "string")

        return t.value.value
    end

    local function table_to_types(self, node, out)
        for _,v in ipairs(node.children) do
            if v.kind == "table_key_value" then
                --out[types.Type("string", v.key.value)] = self:TypeFromNode(v.value) -- HMMM
                out[v.key.value] = self:TypeFromNode(v.value)
            elseif v.kind == "table_expression_value" then
                local t = self:TypeFromNode(v.key)
                if t:IsType("string") then
                    out[t.value] = self:TypeFromNode(v.value)
                else
                    out[t] = self:TypeFromNode(v.value)
                end
            elseif v.kind == "table_index_value" then
                out[v.i] = self:TypeFromNode(v.value)
            end
        end
    end

    local function new_type(self, node, ...)
        if type(node) == "string" then
            return types.Type(type)
        end

        assert(node.type == "expression")

        if node.kind == "value" then
            local t = node.value.type
            local v = node.value.value
            if t == "number" then
                return types.Type("number", tonumber(v))
            elseif t == "string" then
                return types.Type("string", v:sub(2, -2))
            elseif t == "letter" then
                return types.Type("string", v)
            elseif v == "..." then
                local t = types.Type("...")
                t.values = ... -- HACK
                return t
            elseif v == "true" then
                return types.Type("boolean", true)
            elseif v == "false" then
                return types.Type("boolean", false)
            elseif v == "nil" then
                return types.Type("nil")
            else
                error("unhanlded value type " .. t .. " ( " .. v .. " ) ")
            end
            --local t = types.Type()
        elseif node.kind == "table" then
            local t = types.Type("table")

            table_to_types(self, node, t.value)

            return t
        elseif node.kind == "function" then
            local t = types.Type("function")
            node.scope = self.scope
            return t
        else
            error("unhanlded expresison kind " .. node.kind)
        end
    end

    function META:TypeFromNode(node, ...)
        return new_type(self, node, ...):AttachNode(node)
    end

    function META:TypeFromImplicitNode(node, ...)
        return types.Type(...):AttachNode(node)
    end

    --[[
        local a = b -- this works and shouldn't work
        local b = 2
        print(a)
        >> 2

        ability to create a temporary scope based on some other scope

        maybe don't try and declare and collect functions if they aren't called
        collect function behavior only when called, and mark dead paths in function

        when a function is defined, it returns any and and takes any until it's actaully called, then it becomes refined
    ]]

    function META:PushScope(node, extra_node)
        assert(type(node) == "table" and node.kind, "expected an associated ast node")

        self:FireEvent("enter_scope", node, extra_node)

        local parent = self.scope

        local scope = {
            children = {},
            parent = parent,
            upvalues = {},
            upvalue_map = {},

            node = node,
            extra_node = extra_node,
        }

        if parent then
            table_insert(parent.children, scope)
        end

        self.scope = scope

        return scope
    end

    function META:PopScope()
        self:FireEvent("leave_scope", self.scope.node, self.scope.extra_node)

        local scope = self.scope.parent
        if scope then
            self.scope = scope
        end
    end

    function META:GetScope()
        return self.scope
    end

    function META:DeclareUpvalue(key, data)
        local upvalue = {
            key = key,
            data = data,
            scope = self.scope,
            events = {},
            shadow = self:GetUpvalue(key),
        }

        table_insert(self.scope.upvalues, upvalue)
        self.scope.upvalue_map[self:Hash(key)] = upvalue

        self:FireEvent("upvalue", key, data)

        return upvalue
    end

    function META:DeclareGlobal(key, data)
        self.env[self:Hash(key)] = data
    end

    function META:GetUpvalue(key)
        if not self.scope then return end

        local key_hash = self:Hash(key)

        if self.scope.upvalue_map[key_hash] then
            return self.scope.upvalue_map[key_hash]
        end

        local scope = self.scope.parent
        while scope do
            if scope.upvalue_map[key_hash] then
                return scope.upvalue_map[key_hash]
            end
            scope = scope.parent
        end
    end

    function META:MutateUpvalue(key, val)
        local upvalue = self:GetUpvalue(key)
        if upvalue then
            upvalue.data = val
            self:FireEvent("mutate_upvalue", key, val)
            return true
        end
        return false
    end

    function META:GetValue(key)
        local upvalue = self:GetUpvalue(key)

        if upvalue then
            return upvalue.data
        end

        return self.env[self:Hash(key)]
    end

    function META:SetGlobal(key, val)
        self:FireEvent("set_global", key, val)

        self.env[self:Hash(key)] = val
    end

    function META:NewIndex(obj, key, val)
        local node = obj

        local key = self:CrawlExpression(key)
        local obj = self:CrawlExpression(obj) or self:TypeFromImplicitNode(node, "nil")

        obj:set(key, val)

        self:FireEvent("newindex", obj, key, val)
    end

    function META:Assign(node, val)
        if node.kind == "value" then
            if not self:MutateUpvalue(node, val) then
                self:SetGlobal(node, val)
            end
        elseif node.kind == "postfix_expression_index" then
            self:NewIndex(node.left, node.expression, val)
        else
            self:NewIndex(node.left, node.right, val)
        end
    end

    function META:UnpackExpressions(expressions)
        local ret = {}

        if not expressions then return ret end

        for _, exp in ipairs(expressions) do
            for _, t in ipairs({self:CrawlExpression(exp)}) do
                if t:IsType("...") then
                    if t.values then
                        for _, t in ipairs(t.values) do
                            table.insert(ret, t)
                        end
                    end
                end
                table.insert(ret, t)
            end
        end

        return ret
    end
end

function META:FireEvent(what, ...)
    if self.suppress_events then return end

    self:OnEvent(what, ...)
end

function META:CrawlStatements(statements, ...)
    for _, val in ipairs(statements) do
        if self:CrawlStatement(val, ...) == true then
            return true
        end
    end
end

local evaluate_expression

function META:CrawlStatement(statement, ...)
    if statement.kind == "root" then
        self:PushScope(statement)
        if self:CrawlStatements(statement.statements, ...) == true then
            return true
        end
        self:PopScope()
    elseif statement.kind == "local_assignment" then
        local ret = self:UnpackExpressions(statement.right)

        for i, node in ipairs(statement.left) do
            local key = node
            local val = ret[i]
            self:DeclareUpvalue(key, val)
        end
    elseif statement.kind == "assignment" then
        local ret = self:UnpackExpressions(statement.right)

        for i, node in ipairs(statement.left) do
            self:Assign(node, ret[i])
        end
    elseif statement.kind == "function" then
        self:Assign(
            statement.expression,
            self:CrawlExpression(statement:ToExpression("function"))
        )
    elseif statement.kind == "local_function" then
        self:DeclareUpvalue(
            statement.identifier,
            self:CrawlExpression(statement:ToExpression("function"))
        )
    elseif statement.kind == "if" then
        for i, statements in ipairs(statement.statements) do
            local b = not statement.expressions[i] or self:CrawlExpression(statement.expressions[i])
            if b == true or b:IsTruthy() then
                self:PushScope(statement, statement.tokens["if/else/elseif"][i])
                if self:CrawlStatements(statements, ...) == true then
                    self:PopScope()
                    if type(b) == "table" and b.value == true then
                        return true
                    end
                end
                self:PopScope()
            end
        end
    elseif statement.kind == "while" then
        if self:CrawlExpression(statement.expression):IsTruthy() then
            self:PushScope(statement)
            if self:CrawlStatements(statement.statements, ...) == true then
                return true
            end
            self:PopScope()
        end
    elseif statement.kind == "do" then
        self:PushScope(statement)
        if self:CrawlStatements(statement.statements, ...) == true then
            return true
        end
        self:PopScope()
    elseif statement.kind == "repeat" then
        self:PushScope(statement)
        if self:CrawlStatements(statement.statements, ...) == true then
            return true
        end
        if self:CrawlExpression(statement.expression):Truthy() then
            self:FireEvent("break")
        end
        self:PopScope()
    elseif statement.kind == "return" then
        local return_values = ...

        local evaluated = {}
        for i,v in ipairs(statement.expressions) do
            evaluated[i] = self:CrawlExpression(v)

            if return_values then
                table.insert(return_values, evaluated[i])
            end
        end

        self:FireEvent("return", evaluated)

        return true
    elseif statement.kind == "break" then
        self:FireEvent("break")

        return true
    elseif statement.kind == "expression" then
        self:FireEvent("call", statement.value, {self:CrawlExpression(statement.value)})
    elseif statement.kind == "for" then
        self:PushScope(statement)
        if statement.fori then
            local range = self:CrawlExpression(statement.expressions[1]):Max(self:CrawlExpression(statement.expressions[2]))
            self:DeclareUpvalue(statement.identifiers[1], range)
            if statement.expressions[3] then
                self:CrawlExpression(statement.expressions[3])
            end
        else
            --for i,v in ipairs(statement.identifiers) do
                --self:DeclareUpvalue(v, statement.expressions[i] and self:CrawlExpression(statement.expressions[i] or nil))
            --end
            local func = self:CrawlExpression(statement.expressions[1])
            local args
            if type(func) == "function" then
                args = func()
                print(args, debug.getinfo(func).source)
            else
                args = func:IsType("function") and self:CallFunction(func, {statement.expressions[2] and self:CrawlExpression(statement.expressions[2])})
            end

            for i,v in ipairs(statement.identifiers) do
                self:DeclareUpvalue(v, args and args[i])
            end
        end
        if self:CrawlStatements(statement.statements, ...) == true then
            return true
        end
        self:PopScope()
    elseif statement.kind ~= "end_of_file" and statement.kind ~= "semicolon" then
        error("unhandled statement " .. tostring(statement))
    end
end

do
    local function merge_types(src, dst)
        if src then
            for i,v in ipairs(dst) do
                if src[i] then
                    src[i] = v + src[i]
                else
                    src[i] = dst[i]
                end
            end

            return src
        end

        return dst
    end

    evaluate_expression = function(node, stack, self)
        if node.kind == "value" then
            if
                (node.value.type == "letter" and node.upvalue_or_global) or
                node.value.value == "..."
            then
                stack:Push(self:GetValue(node) or self:TypeFromImplicitNode(node, "nil"))
            elseif
                node.value.type == "number" or
                node.value.type == "string" or
                node.value.type == "letter" or
                node.value.value == "nil" or
                node.value.value == "true" or
                node.value.value == "false"
            then
                stack:Push(self:TypeFromNode(node))
            else
                error("unhandled value type " .. node.value.type .. " " .. node:Render())
            end
        elseif node.kind == "function" or node.kind == "table" then
            stack:Push(self:TypeFromNode(node))
        elseif node.kind == "binary_operator" then
            local r, l = stack:Pop(), stack:Pop()
            local op = node.value.value

            if (op == "." or op == ":") and l:IsType("table") then
                if op == ":" then
                    stack:Push(l)
                end
                stack:Push(l:get(r))
                return
            end

            -- HACK
            if op == ".." or op == "^" then
                l,r = r,l
            end

            stack:Push(r:BinaryOperator(op, l, node))
        elseif node.kind == "prefix_operator" then
            local r = stack:Pop()
            local op = node.value.value

            stack:Push(r:PrefixOperator(op, node))
        elseif node.kind == "postfix_operator" then
            local r = stack:Pop()
            local op = node.value.value

            stack:Push(r:PostfixOperator(op, node))
        elseif node.kind == "postfix_expression_index" then
            local r = stack:Pop()
            local index = self:CrawlExpression(node.expression)

            stack:Push(r:get(index))
        elseif node.kind == "postfix_call" then
            local r = stack:Pop()

            if type(r) == "function" then
                local values = {}

                if node.expressions then
                    self.suppress_events = true
                    for _, exp in ipairs(node.expressions) do
                        local val = self:CrawlExpression(exp)
                        table.insert(values, val)
                    end
                    self.suppress_events = false
                end

                r(unpack(values))

                stack:Push(self:TypeFromImplicitNode(node, "nil"))
                return
            end

            if r.type == "any" then
                stack:Push(self:TypeFromImplicitNode(node, "any"))
            else
                local func_expr = r.node

                if func_expr and type(func_expr) == "table" and func_expr.kind == "function" then
                    if self.calling_function == r then
                        local args = {}
                        for i,v in ipairs(node.expressions) do
                            args[i] = self:CrawlExpression(v)
                        end
                        stack:Push(self:TypeFromImplicitNode(node, "any"))
                        return
                    end

                    self.calling_function = r
                    local ret = self:CallFunction(r, node.expressions, stack)
                    self.calling_function = nil

                    for _, v in ipairs(ret) do
                        stack:Push(v)
                    end
                elseif r:IsType("function") and r.ret then
                    if r.func then
                        local args = {}
                        for i,v in ipairs(node.expressions) do
                            args[i] = self:CrawlExpression(v)
                        end
                        local ret = {r.func(unpack(args))}
                        for _,v in ipairs(ret) do
                            stack:Push(v)
                        end
                    else
                        self:FireEvent("external_call", node, r)
                        for _,v in ipairs(r.ret) do
                            stack:Push(v)
                        end
                    end
                else
                    local args = {}
                    for i,v in ipairs(node.expressions) do
                        args[i] = self:CrawlExpression(v)
                    end
                    stack:Push(self:TypeFromImplicitNode(node, "any"))
                end
            end
        else
            error("unhandled expression " .. node.kind)
        end
    end

    function META:CallFunction(r, expressions, stack)
        local old_scope = self.scope
        self.scope = r.node.scope or self.scope
        self:PushScope(r.node)

        local arguments = {}

        if r.node.self_call and stack then
            local val = stack:Pop()
            table.insert(arguments, val)
            self:DeclareUpvalue("self", val)
        end

        for i, v in ipairs(r.node.identifiers) do
            if v.value.value == "..." then
                if expressions then
                    local values = {}
                    for i = i, #expressions do
                        table.insert(values, self:CrawlExpression(expressions[i]))
                    end
                    self:DeclareUpvalue(v, self:TypeFromNode(v, values))
                end
            else
                local arg = expressions[i] and self:CrawlExpression(expressions[i]) or nil
                self:DeclareUpvalue(v, arg)
                table.insert(arguments, arg)
            end
        end

        local ret = {}
        self:CrawlStatements(r.node.statements, ret)
        self:PopScope()
        self.scope = old_scope

        r.ret = merge_types(r.ret, ret)
        r.arguments = merge_types(r.arguments, arguments)

        self:FireEvent("function_spec", r)

        return ret
    end

    function META:CrawlExpression(exp)
        return exp:Evaluate(evaluate_expression, self)
    end
end

return function()
    return setmetatable({env = {}}, META)
end
