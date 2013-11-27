
local json = require("cjson")


function randomGet(kwargs, method)
    local req = {params = {kwargs}, method = method, id = 12}
    local ret = json.decode(GoPost(DB_URL, json.encode(req)))
    if ret and ret.error == json.null then
        return ret.result
    end
    return nil
end

function RandomMotion(kwargs)
     return randomGet(kwargs, "randomMotion")
end

function RandomPunish(kwargs)
     return randomGet(kwargs, "randomPunish")
end


-- uid, sid, to_uid, finish_time, create_time, step, gid, gcount, op_ret, orderid, sn
function SaveGift(dt)
    local req = {params = {dt}, method="saveGift", id = 3}
    local ret = json.decode(GoPost(DB_URL, json.encode(req)))
    return ret.error == json.null
end


function GetBillBoard(sid)
    local req = {params = {{count=BILLBOARD_COUNT, sid=sid}}, method="getBillboard", id = 4}
    local ret = json.decode(GoPost(DB_URL, json.encode(req)))
    local billboard = {}
    if ret.error == json.null then
        for _, item in ipairs(ret.result) do
            for k, v in pairs(item) do
                table.insert(billboard, {user={name=k}, s=v})
            end
        end
    end
    return billboard
end

function SaveName(uid, name)
    local req = {params = {{uid=uid, name=name}}, method="setName", id = 5}
    GoPost(DB_URL, json.encode(req))
end

