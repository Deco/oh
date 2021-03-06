return function(META)
    local ipairs = ipairs
    local assert = assert
    local type = type

    function META:Whitespace(str, force)

        if self.config.preserve_whitespace == nil and not force then return end

        if str == "?" then
            if self.syntax.IsLetter(self:GetPrevChar()) or self.syntax.IsNumber(self:GetPrevChar()) then
                self:Emit(" ")
            end
        elseif str == "\t" then
            self:EmitIndent()
        elseif str == "\t+" then
            self:Indent()
        elseif str == "\t-" then
            self:Outdent()
        else
            if self.config.no_newlines and str == "\n" then
                self:Emit(" ")
            else
                self:Emit(str)
            end
        end
    end

    function META:Emit(str) assert(type(str) == "string")
        self.out[self.i] = str or ""
        self.i = self.i + 1
    end

    function META:Indent()
        self.level = self.level + 1
    end

    function META:Outdent()
        self.level = self.level - 1
    end

    function META:EmitIndent()
        if self.config.no_newlines then
            --self:Emit("")
        else
            self:Emit(("\t"):rep(self.level))
        end
    end

    function META:GetPrevChar()
        local prev = self.out[self.i - 1]
        local char = prev and prev:sub(-1)
        return char and char:byte() or 0
    end

    function META:EmitWhitespace(token)
        if token.type ~= "space" or self.config.preserve_whitespace == nil then
            self:EmitToken(token)
            if token.type ~= "space" then
                self:Whitespace("\n")
                self:Whitespace("\t")
            end
        end
    end

    function META:EmitToken(node, translate)
        if node.whitespace then
            for _, data in ipairs(node.whitespace) do
                if self.config.no_comments ~= true or (data.type ~= "multiline_comment" and data.type ~= "line_comment") then
                    self:EmitWhitespace(data)
                end
            end
        end

        if self.TranslateToken then
            translate = self:TranslateToken(node) or translate
        end

        if translate then
            if type(translate) == "table" then
                self:Emit(translate[node.value] or node.value)
            elseif type(translate) == "function" then
                self:Emit(translate(node.value))
            elseif translate ~= "" then
                self:Emit(translate)
            end
        else
            self:Emit(node.value)
        end
    end

    function META:Initialize()
        self.level = 0
        self.out = {}
        self.i = 1
    end

    function META:Concat()
        return table.concat(self.out)
    end

    function META:BuildCode(block)
        if block.imports then
            self.done = {}
            self:Emit("IMPORTS = IMPORTS or {}\n")
            for i, node in ipairs(block.imports) do
                if not self.done[node.path] then
                    self:Emit("IMPORTS['" .. node.path .. "'] = function(...) " .. node.root:Render({}) .. " end\n")
                    self.done[node.path] = true
                end
            end
        end

        self:EmitStatements(block.statements)

        return self:Concat()
    end
end