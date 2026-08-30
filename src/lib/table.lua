local function shallowcopy(orig)
    local orig_type = type(orig)
    local copy

    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end

    return copy
end

local function deepcopy(orig)
    local orig_type = type(orig)
    local copy

    if orig_type == 'table' then
        copy = {}

        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end

        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end

    return copy
end

local function serialize(tbl, indent)
    indent = indent or 0
    local toPrint = string.rep("  ", indent) .. "{\n"
    for k, v in pairs(tbl) do
        local key = type(k) == "string" and '"' .. k .. '"' or k
        local value = type(v) == "table" and serialize(v, indent + 1) or tostring(v)
        toPrint = toPrint .. string.rep("  ", indent + 1) .. key .. " = " .. value .. ",\n"
    end
    return toPrint .. string.rep("  ", indent) .. "}"
end

local function dump(tbl, indent)
    print(serialize(tbl, indent))
end

_G.table.deepcopy = deepcopy
_G.table.shallowcopy = shallowcopy
_G.table.dump = dump

return _G.table

