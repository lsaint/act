

local GiftPower = {
    [1009] = 69,
    [1001] = 1,
    [1010] = 199,
    [1012] = 89,
    [1013] = 1,
    [1016] = 5,
    [1017] = 5,
    [1018] = 10,
}

local GiftCost = {
    [1009] = 690,
    [1001] = 10,
    [1010] = 1990,
    [1012] = 890,
    [1013] = 10,
    [1016] = 50,
    [1017] = 50,
    [1018] = 100,
}


GiftMgr = {}
GiftMgr.orderid2req = {}

function GiftMgr:new(tsid, sid, presenters)
    self.__index = self
    local ins = setmetatable({}, self)
    ins.tsid = tsid
    ins.sid = sid
    ins.presenters = presenters
    ins.powers = {} -- {uid=power}
    ins.uid2givername = {}
    ins.camps = {{}, {}} -- {camp_a_powers, camp_b_powers}
    ins.options = {}
    ins.polls = {0, 0, 0, 0}
    ins.polled_players = {}
    return ins
end

-- req -- [to_uid, gift.id, gift.count]
function GiftMgr:regGiftOrder(player, req)
    if req.to_uid == 0 then return "", 0, "" end
    local t, sn, from_uid = os.date("%Y%m%d%H%M%S"), GoGetSn(), player.uid
    local to_md5_args = { APPID, from_uid, req.to_uid, req.gift.id,
                          req.gift.count, sn, self.tsid, SRVID, 
                          t, AUTH_KEY }
    local to_md5 = string.format("%s%s%s%s%s%s%s%s%s%s", unpack(to_md5_args))
    to_md5_args[10] = GoMd5(to_md5)
    local post_string = string.format(
       "appid=%s&fromuid=%s&touid=%s&giftid=%s&giftcount=%s&sn=%s&ch=%s&srvid=%s&time=%s&verify=%s", 
        unpack(to_md5_args))
    --local ss = GoPost(GIFT_URL, post_string)
    GoPostAsync(GIFT_URL, post_string, function(ss)
        local op, orderid, token = self:checkPostRet(ss)
        player:SendMsg("S2CRegGiftRep", {token = token, sn=sn, orderid=orderid})
        tprint("RegGiftRep", orderid, sn, token)
        if orderid ~= "" then
            req["sid"] = self.sid -- for gift's callback 
            self.orderid2req[orderid] = req
            SaveGift({uid=from_uid, to_uid=req.to_uid, gid=req.gift.id, gcount=req.gift.count,
                      sid=self.tsid, step=STEP_GIFT_REG, orderid=orderid, sn=sn, op_ret=op, 
                      create_time=TIME_NOW, finish_time=TIME_INGORE})
        end
    end)
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
    local cur_p  = self.powers[uid] or 1
    self.powers[uid] = p + cur_p

    local o = self:whichPresenter(touid)
    if not o then return end
    cur_p = self.camps[o].uid or 1
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
        return "FL", 0, idx
    end
    self.polled_players[player.uid] = idx
    local p = self.powers[player.uid] or 1
    self.polls[idx] = self.polls[idx] + p
    self.powers[player.uid] = 0
    return "OK", p, idx
end

function GiftMgr:sortPower(to_sort, top_n)
    local sorted = {}
    for k, v in pairs(to_sort) do
        table.insert(sorted, {k, v})
    end
    table.sort(sorted, function(a, b) return a[2] > b[2] end)
    local ret = {}
    for i, v in ipairs(sorted) do
        if v[2] ~= 0 then 
            local u = v[1]
            local n = self.uid2givername[u] or ""
            table.insert(ret, {user={uid=u, name=n}, s=v[2]})
            if i >= top_n then break end
        end
    end
    return ret
end

function GiftMgr:topn()
    return self:sortPower(self.powers, 5)
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

function GiftMgr:sign(uid, name)
    self.uid2givername[uid] = name
end

-- cls methond
function GiftMgr.finishGift(uid, orderid, gid, gcount)
    local t = os.date("%Y%m%d%H%M%S")
    local to_md5_args = { APPID, uid, orderid, SRVID, t, AUTH_KEY }
    local to_md5 = string.format("%s%s%s%s%s%s", unpack(to_md5_args))
    to_md5_args[#to_md5_args] = GoMd5(to_md5)
    local post_string = string.format(
       "appid=%s&uid=%s&orderid=%s&srvid=%s&time=%s&verify=%s", 
        unpack(to_md5_args))
    --local ss = GoPost(FINISH_GIFT_URL, post_string)
    GoPostAsync(FINISH_GIFT_URL, post_string, function(ss)
        tprint("finishGift", uid, orderid, ss)
        local ret = parseUrlArg(ss)
        local money = gcount * GiftCost[gid]
        SaveGift({orderid=orderid, step=STEP_GIFT_FINISH, finish_time=TIME_NOW, 
                  money=money, op_ret=(ret["op_ret"] or "")})
    end)
end

