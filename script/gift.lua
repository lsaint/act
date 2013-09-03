

local GiftPower = {
    [1] = 10,
    [2] = 10,
    [3] = 10,
    [4] = 10,
    [5] = 80,
    [6] = 80,
    [7] = 80,
    [8] = 2500,
}


GiftMgr = {}
GiftMgr.orderid2req = {}

function GiftMgr:new(sid, presenters)
    self.__index = self
    local ins = setmetatable({}, self)
    ins.sid = sid
    ins.presenters = presenters
    ins.powers = {} -- {uid=power}
    ins.camps = {{}, {}} -- {camp_a, camp_b}
    ins.options = {}
    ins.polls = {0, 0, 0, 0}
    ins.polled_players = {}
    return ins
end

-- req -- [to_uid, gift.id, gift.count, csn]
function GiftMgr:regGiftOrder(from_uid, req)
    local t = os.date("%Y%m%d%H%M%S")
    local to_md5_args = { APPID, from_uid, req.to_uid, req.gift.id,
                          req.gift.count, req.csn, self.sid, SRVID, 
                          t, AUTH_KEY }
    local to_md5 = string.format("%s%s%s%s%s%s%s%s%s%s", unpack(to_md5_args))
    local post_string = string.format(
       "appid=%s&fromuid=%s&touid=%s&giftid=%s&giftcount=%s&sn=%s&ch=%s&srvid=%s&time=%s&verify=%s", 
        unpack(to_md5_args), GoMd5(to_md5))
    local ss = GoPost(post_string)
    local op, orderid, token = self:checkPostRet(ss)
    if orderid ~= "" then
        self.orderid2req[orderid] = req
    end
    return token
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

function GiftMgr:givecb(uid, touid, gift)
    local p = GiftPower[gift.id] * gift.count
    local cur_p  = self.powers[uid] or 0
    self.powers[uid] = p + cur_p

    local o = self:whichPresenter(touid)
    if o == nil then return end
    cur_p = self.camps[o].uid or 0
    self.camps[o][uid] = cur_p + p
end

function GiftMgr:poll(player, idx)
    if self.polled_players[player.uid] ~= nil or 
            idx > 4 or idx < 1 then
        return false
    end
    self.polled_players[player] = idx
    local p = self.powers[uid] or 1
    self.polls[idx] = self.polls[idx] + p
end

function GiftMgr:sortPower(to_sort, top_n)
    local sorted = {}
    for k, v in pairs(to_sort) do
        table.insert(sorted, {k, v})
    end
    table.sort(sorted, function(a, b) return a[2] > b[2] end)
    local ret = {}
    for i, v in ipairs(sorted) do
        table.insert(ret, unpack(v))
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

