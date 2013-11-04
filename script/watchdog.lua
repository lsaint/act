
require "room"
require "player"

local function WatchDog()
    local self = {
        sid2room = {}
    }

    function self.gainRoom(tsid, sid)
        local room = self.sid2room[sid]
        if room == nil then
            room = GameRoom.new(tsid, sid)
            self.sid2room[sid] = room
        end
        return room
    end

    function self.dispatch(tsid, sid, uid, pname, data)
        local room = self.gainRoom(tsid, sid)
        local proto_name = string.format("%s%s", "proto.C2S", pname)
        local req = protobuf.decode(proto_name, data)
        local player = room.uid2player[uid]
        if not player then 
            if pname == "Login" then
                player = Player:new(req.user)
                room.uid2player[uid] = player
            elseif pname ~= "Logout" then
                room:OnInvildProto(uid, pname)
                return
            end
        elseif pname == "Login" then
            print("relogin", uid)
            return
        end
        local method = string.format("On%s", pname)
        --print(string.format("%s%s%s", "---------", pname, "---------"))
        player.lastping = os.time()
        room[method](room, player, req)
    end

    function self.giftCb(op, tsid, uid, touid, gid, gcount, orderid)
        local req = GiftMgr.orderid2req[orderid]
        if not req or not req["sid"] then 
            tprint("giftcb error", orderid)
            return 
        end
        local room = self.gainRoom(tonumber(tsid), req["sid"])
        room:OnGiftCb(tonumber(op), tonumber(uid), tonumber(touid), tonumber(gid), tonumber(gcount), orderid)
    end

    return self
end 

local watchdog = WatchDog()
return watchdog
