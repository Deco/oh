local map --= {}

if map then
    debug.sethook(function(evt)
        if evt ~= "line" then return end
        local info = debug.getinfo(2)
        local src = info.source:sub(2)
        map[src] = map[src] or {}    
        map[src][info.currentline] = (map[src][info.currentline] or 0) + 1
    end, "l")
end

function _G.test(name, cb)
    local ok, err = pcall(cb)
    if ok then
        io.write(".")
        io.output():flush()
    else
        io.write("\n")
        io.write("FAIL: ",  name, ": ", err, "\n")
    end
end

function pending()

end

function _G.equal(a, b, level)
    level = level or 1
    if a ~= b then
        if type(a) == "string" then
            a = string.format("%q", a)
        end
        if type(b) == "string" then
            b = string.format("%q", b)
        end
        error(tostring(a) .. " ~= " .. tostring(b), level + 1)
    end
end


local path = ...

if path and path:sub(-4) == ".lua" then
    assert(loadfile(path))()
else
    local what = path
    local path = "test/" .. ((what and what .. "/") or "lua/")
    for path in io.popen("find " .. path):lines() do
        if path:sub(-4) == ".lua" and not path:find("/file_importing/", nil, true) then
            assert(loadfile(path))()
        end
    end
end

io.write("\n")

if map then
    for k,v in pairs(map) do
        if k:find("oh/", 1, true) then
            local f = io.open(k .. ".coverage", "w")

            local i = 1
            for line in io.open(k):lines() do
                if map[k][i] then
                    f:write("\n")
                else
                    f:write(line, "\n")
                end
                i = i + 1
            end

            f:close()
        end
    end
end