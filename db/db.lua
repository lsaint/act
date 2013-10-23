
local json = require("cjson")

local _x = {desc = "出事了"}

function RandomMotion()
    local req = {params = {{count = 10}}, method = "randomMotion", id = 1}
    local ret = json.decode(GoPost(DB_URL, json.encode(req)))
    if ret.error == json.null then
        return ret.result
    end
    return nil
end


function RandomPunish()
    local req = {params = {{count = 4}}, method="randomPunish", id = 2}
    local ret = json.decode(GoPost(DB_URL, json.encode(req)))
    if ret.error == json.null then
        return ret.result
    end
    return {_x, _x, _x, _x}
end


-- uid, sid, to_uid, finish_time, create_time, step, gid, gcount, op_ret, orderid, sn
function SaveGift(dt)
    local req = {params = {dt}, method="saveGift", id = 3}
    local ret = json.decode(GoPost(DB_URL, json.encode(req)))
    return ret.error == json.null
end


function SaveRoundSidInfo(dt)
    local req = {params = {dt}, method="saveRoundSidInfo", id = 4}
    local ret = json.decode(GoPost(DB_URL, json.encode(req)))
    return ret.error == json.null
end


function SaveRoundUidInfo(dt)
    local req = {params = {dt}, method="saveRoundUidInfo", id = 5}
    local ret = json.decode(GoPost(DB_URL, json.encode(req)))
    return ret.error == json.null
end

