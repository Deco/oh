-- i think this file shouldn't exist, but i'm not sure how else to deal with this right now

local analyzer_env = {}

do
    analyzer_env.current_analyzer = {}

    function analyzer_env.PushAnalyzer(a)
        table.insert(analyzer_env.current_analyzer, 1, a)
    end

    function analyzer_env.PopAnalyzer()
        table.remove(analyzer_env.current_analyzer, 1)
    end

    function analyzer_env.GetCurrentAnalyzer()
        return analyzer_env.current_analyzer[1]
    end
end

function analyzer_env.GetBaseAnalyzer()

    if not analyzer_env.base_analyzer then
        local base = require("oh.lua.analyzer")()
		base.IndexNotFound = nil

		local ret, root, code_data = base:AnalyzeFile("oh/lua/base_typesystem.oh")

		local g = base:TypeFromImplicitNode(root, "table")

		for k, v in pairs(base.env.typesystem) do
			g:Set(k, v)
		end

		-- TODO: string library isn't in base.env.typesystem
		g:Set("string", base:GetValue("string", "typesystem"))
		base:SetValue("_G", g, "typesystem")
		base:GetValue("_G", "typesystem"):Set("_G", g)

        analyzer_env.base_analyzer = base
    end

    return analyzer_env.base_analyzer
end

return analyzer_env