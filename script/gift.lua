

local GiftPower = {
    [1001] = 10,
    [1003] = 80,
    [1009] = 800,
    [1010] = 2500,
    [1012] = 1100,
    [1013] = 10,
    [1014] = 80,
    [1015] = 80,
}
local SN = 0


GiftMgr = {}
GiftMgr.orderid2req = {}

function GiftMgr:new(sid, presenters)
    self.__index = self
    local ins = setmetatable({}, self)
    ins.sid = sid
    ins.presenters = presenters
    ins.powers = {} -- {uid=power}
    ins.camps = {{}, {}} -- {camp_a_powers, camp_b_powers}
    ins.options = {}
    ins.polls = {0, 0, 0, 0}
    ins.polled_players = {}
    return ins
end

-- req -- [to_uid, gift.id, gift.count]
function GiftMgr:regGiftOrder(from_uid, req)
    if req.to_uid == 0 then return "", 0, "" end
    local t, sn = os.date("%Y%m%d%H%M%S"), GoGetSn()
    local to_md5_args = { APPID, from_uid, req.to_uid, req.gift.id,
                          req.gift.count, sn, self.sid, SRVID, 
                          t, AUTH_KEY }
    local to_md5 = string.format("%s%s%s%s%s%s%s%s%s%s", unpack(to_md5_args))
    to_md5_args[10] = GoMd5(to_md5)
    local post_string = string.format(
       "appid=%s&fromuid=%s&touid=%s&giftid=%s&giftcount=%s&sn=%s&ch=%s&srvid=%s&time=%s&verify=%s", 
        unpack(to_md5_args))
    local ss = GoPost(GIFT_URL, post_string)
    local op, orderid, token = self:checkPostRet(ss)
    if orderid ~= "" then
        self.orderid2req[orderid] = req
    end
    return token, sn, orderid
end

function GiftMgr:checkPostRet(ss)
    local ret = parseUrlArg(ss)
    return ret["op_ret"] or "", ret["orderid"] or "", ret["token"] or ""
end

function GiftMgr:whichPresenter(uid)
    if self.presenters[1].uid == uid then
        return 1
    elseif self.presenters[2].uid == uid then
        return 2
    end
    return nil
end

function GiftMgr:increasePower(uid, touid, gid, gcount)
    print("increasePower")
    if self.polled_players[uid] then return end
    local p = GiftPower[gid] * gcount
    local cur_p  = self.powers[uid] or 0
    self.powers[uid] = p + cur_p

    local o = self:whichPresenter(touid)
    if not o then return end
    cur_p = self.camps[o].uid or 0
    self.camps[o][uid] = cur_p + p
end

function GiftMgr:getPower(uid)
    if self.polled_players[uid] then
        return 0 
    end
    return self.powers[uid] or 1
end

function GiftMgr:poll(player, idx)
    if self.polled_players[player.uid] or idx > 4 or idx < 1 then
        return "FL", 0
    end
    self.polled_players[player.uid] = idx
    local p = self.powers[player.uid] or 1
    self.polls[idx] = self.polls[idx] + p
    self.powers[player.uid] = 0
    return "OK", p
end

function GiftMgr:sortPower(to_sort, top_n)
    local sorted = {}
    for k, v in pairs(to_sort) do
        table.insert(sorted, {k, v})
    end
    table.sort(sorted, function(a, b) return a[2] > b[2] end)
    local ret = {}
    for i, v in ipairs(sorted) do
        table.insert(ret, {user={uid=v[1]}, s=v[2]})
        if i >= top_n then break end
    end
    return ret
end

function GiftMgr:top3()
    return self:sortPower(self.powers, 3)
end

function GiftMgr:vips()
    return self:sortPower(self.camps[1], 2),  
           self:sortPower(self.camps[2], 2)
end

function GiftMgr:getPollResult()
    if self.polls[1] == self.polls[2] and
            self.polls[2] == self.polls[3] and
            self.polls[3] == self.polls[4] then
        return self.options[4]
    end

    local idx, poll = 1, self.polls[1]
    for i=2, 4 do
        if self.polls[i] > poll then
            idx, poll = i, self.polls[i]
        end
    end
    return self.options[idx]
end

-- cls methond
function GiftMgr.finishGift(uid, orderid)
    print("finishGift", uid, orderid)
    local t = os.date("%Y%m%d%H%M%S")
    local to_md5_args = { APPID, uid, orderid, SRVID, t, AUTH_KEY }
    local to_md5 = string.format("%s%s%s%s%s%s", unpack(to_md5_args))
    to_md5_args[#to_md5_args] = GoMd5(to_md5)
    local post_string = string.format(
       "appid=%s&uid=%s&orderid=%s&srvid=%s&time=%s&verify=%s", 
        unpack(to_md5_args))
    local ss = GoPost(FINISH_GIFT_URL, post_string)
    print("finish order ret", ss)
end

