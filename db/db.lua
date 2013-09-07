
require "json"

local _x = {desc = "出事了"}

function RandomMotion()
    local req = {params = {{count = 1}}, method = "randomMotion", id = 1}
    local ret = json.decode(GoPost(DB_URL, json.encode(req)))
    if ret.error == nil then
        return ret.result[1]
    end
    return _x
end


function RandomPunish()
    local req = {params = {{count = 4}}, method="randomPunish", id = 2}
    local ret = json.decode(GoPost(DB_URL, json.encode(req)))
    if ret.error == nil then
        return ret.result
    end
    return {_x, _x, _x, _x}
end

