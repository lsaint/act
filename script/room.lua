
require "utility"
require "round"
require "gift"
require "db"

GameRoom = {}
GameRoom.__index = GameRoom

function GameRoom.new(tsid, sid)
    local self = setmetatable({}, GameRoom)
    self.tsid = tsid
    self.sid = sid
    self.uid2player = {}
    self.presenters = {}
    self.status = "Ready"
    self.mode = "MODE_ACT"
    self:init()
    return self
end

function GameRoom.init(self)
    print("init")
    self.over = {}
    self.scores = {0, 0}
    self.timer = Timer:new(self.sid)
    self.guess = nil
    self.giftmgr = GiftMgr:new(self.tsid, self.sid, self.presenters)
    self.roundmgr = RoundMgr:new(self)
    self.billboard = {topn = GetBillBoard(self.tsid)}
    self.timer:settimer(SAMPLER_INTERVAL, nil, self.postSamele, self)
end

--self:SendMsg("S2CLoginRep", rep, {player.uid}) -- multi
function GameRoom.SendMsg(self, pname, msg, uids)
    SendMsg(pname, msg, uids, self.tsid, self.sid)
end

--self:Broadcast("S2CLoginRep", rep) -- all
function GameRoom.Broadcast(self, pname, msg)
    SendMsg(pname, msg, {}, self.tsid, self.sid)
end

function GameRoom.settimer(self, interval, count, func, ...)
    return self.timer:settimer(interval, count, func, ...)
end

function GameRoom.notifyStatus(self, st)
    self.status = st
    self:Broadcast("S2CNotifyStatus", {status = st})
end

function GameRoom.A(self)
    return self.presenters[1]
end

function GameRoom.B(self)
    return self.presenters[2]
end

function GameRoom.updateBillboard(self)
    self.billboard = {topn = GetBillBoard(self.tsid)}
end

function GameRoom.addPlayer(self, player)
    local n = self.uid2player.n or 0
    self.uid2player[player.uid] = player
    self.uid2player.n = n + 1
end

function GameRoom.delPlayer(self, player)
    local n = self.uid2player.n or 0
    self.uid2player[player.uid] = nil
    self.uid2player.n = n - 1
end

function GameRoom.OnLogin(self, player, req)
    local rep = { ret = "UNMATCH_VERSION"}
    local v = req.version:split(".")
    if #v < 2 or tonumber(v[1]) ~= V1 or tonumber(v[2]) ~= V2 then
        player:SendMsg("S2CLoginRep", rep)
        return
    end

    self:addPlayer(player)
    rep = {
        ret = "OK",
        mode = self.mode,
        status = self.status,
        user = { },
    }
    rep.user.power = self.giftmgr:getPower(player.uid)
    player:SendMsg("S2CLoginRep", rep)

    player:SendMsg("S2CNotifyPrelude", self:getPrelude())
    player:SendMsg("S2CNotifyBillboard", self.billboard)

    if self.status == "Poll" then
        player:SendMsg("S2CNotfiyPunishOptions", 
            {options = self.giftmgr.options, loser = self:getLoser().user})
    elseif self.status == "Punish" then
        player:SendMsg("S2CNotfiyPunishOptions", 
            {options = self.giftmgr.options, loser = self:getLoser().user})
        player:SendMsg("S2CNotifyPunish", {punish = self.giftmgr:getPollResult()})
        player:SendMsg("S2CNotifyScores", {scores = self.scores})
    elseif self.status == "Round" and self.roundmgr then
        local remain_time = self.roundmgr:GetRemainTime()
        if remain_time < 0 then return end
        player:SendMsg("S2CNotifyRoundStart", {
                presenter = {uid = self.roundmgr:GetCurPresenter().uid},
                round = self.roundmgr.roundNum,
                mot = self.roundmgr:GetCurMotion(),
                time = remain_time,
            })
    end
    SaveName(player.uid, player.name)
end

function GameRoom.OnChangeMode(self, player, req)
    print("changemode", dump(req))
    local rep = {ret = "FL"}
    if player.role ~= "Attendee" and req.mode ~= self.mode and self.status == "Ready" then
        self.mode = req.mode
        rep.ret = "OK"
        self:Broadcast("S2CNotifyChangeMode", 
                       {mode = self.mode, user = {uid = player.uid, name = player.name}})
       self:init()
    end
    player:SendMsg("S2CChangeModeRep", rep)
end

function GameRoom.OnPrelude(self, player, req)
    local a, b = self:A(), self:B()
    local r1 = self:updateRole(player, a, req.user.role, "CandidateA", "PresenterA", 1, b)
    local r2 = self:updateRole(player, b, req.user.role, "CandidateB", "PresenterB", 2, a)
    if r1 or r2 then
        self:Broadcast("S2CNotifyPrelude", self:getPrelude())
    else
        print("update role FL")
        return 
    end

    if a and b then    
        if a.role == "PresenterA" and b.role == "PresenterB" then
            tprint("START", self.tsid, self.sid)
            self:notifyStatus("Round")
            self.timer:settimer(5, 1, self.roundmgr.RoundStart, self.roundmgr)
            self.timer:settimer(BC_TOPN_INTERVAL, nil, self.notifyTopn, self)
            self.timer:settimer(BC_BILLBOARD_INTERVAL, nil, self.notifyBillboard, self)
            self.giftmgr.presenters = self.presenters
        end
    end
end

function GameRoom.updateRole(self, player, cur, role, ca, pr, idx, oth)
    local r, uid = nil, player.uid

    if cur then
        if cur.role == ca and role == pr and uid == cur.uid then
            r = "OK"; cur.role = role
        end
        if cur.role == ca and role == "Attendee" and uid == cur.uid then
            r = "OK"; cur.role = role
            self.presenters[idx] = nil
        end
        if cur.role == pr and role == "Attendee" and uid == cur.uid 
                                                and self.status == "Ready" then
            r = "OK"; cur.role = role
            self.presenters[idx] = nil
        end
        if cur.role == role and role == ca then
            r = "OCCUPY"
        end
    else
        if role == ca and oth ~= player then
            r = "OK"
            player.role = role
            self.presenters[idx] = player
        end
    end

    if r then 
        player:SendMsg("S2CPreludeRep", {ret = r})
    end
    return r
end

function GameRoom.getPrelude(self)
    local a, b = self:A(), self:B()
    local rep = {}
    if not a and not b then
        return rep
    elseif a and b then
        rep = {a = {uid = a.uid, role = a.role}, b = {uid = b.uid, role = b.role}}
    elseif not b then
        rep = {a = {uid = a.uid, role = a.role}}
    else
        rep = {b = {uid = b.uid, role = b.role}}
    end
    return rep
end

function GameRoom.notifyScore(self)
    local bc = {scores = self.scores}
    self:Broadcast("S2CNotifyScores", bc)
end

function GameRoom.pollStart(self)
    print("pollStart")
    self:notifyStatus("Poll")
    local bc = {options = RandomPunish({public=3, private=1, sid=self.tsid}), 
                loser = self:getLoser().user}
    self.giftmgr.options = bc.options
    self:Broadcast("S2CNotfiyPunishOptions", bc)
    self.timer:settimer(POLL_TIME, 1, self.punishStart, self)
    self.timer:settimer(BC_POLLS_INTERVAL, POLL_TIME/BC_POLLS_INTERVAL+1, self.notifyPolls, self)
end

function GameRoom.OnPoll(self, player, req)
    local r, p, idx = self.giftmgr:poll(player, req.punish_id)
    player:SendMsg("S2CPollRep", {ret = r})
    if p > 1 then
        self:Broadcast("S2CNotifyPowerPoll", {
                user = {
                    name = player.name,
                    power = p,
                },
                id = idx,
        })
    end
end

function GameRoom.notifyPolls(self)
    self:Broadcast("S2CNotifyPolls", {polls = self.giftmgr.polls})
end

function GameRoom.punishStart(self)
    print("punishStart")
    self:notifyStatus("Punish")
    self:Broadcast("S2CNotifyPunish", {punish = self.giftmgr:getPollResult()})
end

function GameRoom.OnPunishOver(self, player, req)
    print("PunishOver")
    if #self.over >= 2 then return end
    table.insert(self.over, player)    
    local rep = {ret = "WAIT_OTHER"}
    if #self.over == 2 then
        self:stopGame()
        rep.ret = "OK"
    else 
        print("waiting other over")
        self:Broadcast("S2CNotifyPunishOver",
                {presenter = {uid = self.over[1].uid}})
    end
    player:SendMsg("S2CPunishOverRep", rep)
end

function GameRoom.OnStopGame(self, player, req)
    print("OnStopGame")
    if player:isAorB() then
        self:stopGame(STOP_LEFT, player.name)
    end
end

function GameRoom.OnAdminClear(self, player, req)
    if player.privilege >= 200 and #self.presenters > 0 then
        self:setPresenter2Attendee(self:A())
        self:setPresenter2Attendee(self:B())
        self:stopGame(STOP_ADMIN, player.name)
    end
end

function GameRoom.stopGame(self, t, n)
    print("stopGame", t, n)
    self:notifyStatus("Ready")
    self:init()
    self:setPresenter2Candidate()
    self:Broadcast("S2CNotifyPrelude", self:getPrelude())
    self:Broadcast("S2CNotifyChat", { msg = "", user = { name = n }, type = t })
end

function GameRoom.OnRegGift(self, player, req)
    self.giftmgr:regGiftOrder(player, req)
end

function GameRoom.OnGiftCb(self, op, from_uid, to_uid, gid, gcount, orderid)
    tprint("OnGiftCb", op, from_uid, to_uid, gid, gcount, orderid)
    if op == 1 then 
        GiftMgr.finishGift(from_uid, orderid, gid, gcount)
    end

    local req, giver = GiftMgr.orderid2req[orderid], self.uid2player[from_uid]
    if giver then
        giver:SendMsg("S2CGiftRep", {op = op, orderid = orderid})
    end

    if not req or op ~= 1 then 
        -- not register or pay unsucess,  nothing to do with power
        SaveGift({orderid=orderid, step=STEP_GIFT_UNSUCESS, op_ret=op})
        return 
    end
    if self.status ~= "Ready" then
        self.giftmgr:increasePower(from_uid, to_uid, gid, gcount)
    end
    GiftMgr.orderid2req[orderid] = nil

    local receiver =  self.uid2player[to_uid]
    local gname, rname, guid, ruid = "", "", 0, 0
    if receiver then 
        rname = receiver.name 
        ruid = receiver.uid
    end
    if giver then 
        gname = giver.name 
        guid = giver.uid
        self.giftmgr:sign(guid, gname)
    end
    local bc = {
        giver = {name = gname, uid = guid},
        receiver = {name = rname, uid = ruid},
        gift = {id = gid, count = gcount},
    }
    self:Broadcast("S2CNotifyGift", bc)
end

function GameRoom.OnChat(self, player, req)
    local bc = {
        msg = req.msg, 
        user = {
            uid = player.uid,
            name = player.name,
        }
    }
    if self.status == "Round" and self.guess then
        local ret, isfirst, answer = self.guess:guess(player, req.msg)
        bc.msg = answer
        bc.correct = ret
        if ret then
            if isfirst then
                self:addScore()
            else
                return
            end
        end
    end
    self:Broadcast("S2CNotifyChat", bc)
end

function  GameRoom.addScore(self)
    if self.roundmgr:GetCurPresenter() == self.presenters[1] then
        self.scores[1] = self.scores[1] + BINGO_SCORE
    elseif self.roundmgr:GetCurPresenter() == self.presenters[2] then
        self.scores[2] = self.scores[2] + BINGO_SCORE
    end
end

function GameRoom.getLoser(self)
    local idx = 1
    if self.scores[2] < self.scores[1] then
        idx = 2
    elseif self.scores[2] == self.scores[1] then
        idx = math.random(2)
    end
    return self.presenters[idx]
end

function GameRoom.notifyVips(self)
    local a, b = self.giftmgr:vips()
    self:Broadcast("S2CNotifyVips", {a_vip = a,  b_vip = b})
end

function GameRoom.notifyTopn(self)
    self:Broadcast("S2CNotifyTopnGiver", {topn = self.giftmgr:topn()})
end

function GameRoom.notifyBillboard(self)
    self:updateBillboard()
    self:Broadcast("S2CNotifyBillboard", self.billboard)
end

function GameRoom.setPresenter2Attendee(self, player)
    if not player then return end
    if self:A() and player.uid == self:A().uid then
        player.role = "Attendee"
        self.presenters[1] = nil
    end
    if self:B() and player.uid == self:B().uid then
        player.role = "Attendee"
        self.presenters[2] = nil
    end
end

function GameRoom.setPresenter2Candidate(self)
    if self:A() then self:A().role = "CandidateA" end
    if self:B() then self:B().role = "CandidateB" end
end

function GameRoom.OnLogout(self, player, req)
    if not player then return end
    print("OnLogout", player.uid, player.role)
    if player:isAorB() then 
        self:setPresenter2Attendee(player)
        if self.status ~= "Ready" then
            self:stopGame(STOP_LOGOUT, player.name)
        else
            self:Broadcast("S2CNotifyPrelude", self:getPrelude())
        end
    end
    self:delPlayer(player)
end

function GameRoom.OnAbortRound(self, player, req)
    if self.roundmgr:AbortRound(player, req.round_num) then
        self:Broadcast("S2CNotifyAbortRound", {user = {uid = player.uid}})
    end
end

function GameRoom.OnNetCtrl(self, dt)
    if dt.op == "restart" then
        tprint("[CTRL]RESTART")
        local defer = dt.defer or "60"
        self:Broadcast("S2CNotifyChat", {msg = defer, type = STOP_RESTART})
    end
end

function GameRoom.postSamele(self)
    local p = {"report", self.tsid, self.sid, self.uid2player.n, self.mode, self.status, SAMPLER_PWD}
    local d = string.format("?action=%s&tsid=%s&ssid=%s&ccu=%s&mode=%s&status=%s&pwd=%s", unpack(p))
    --local ret = GoPost(string.format("%s%s", SAMPLER_URL, d), "L")
    GoPostAsync(string.format("%s%s", SAMPLER_URL, d), "L")
end

function GameRoom.OnPing(self, player, req)
end

function GameRoom.checkPing(self)
    print("checkping")
    local now = os.time()
    for uid, player in pairs(self.uid2player) do
        if now - player.lastping > PING_LOST then
            print("ping lost", uid)
            self:OnLogout(player)
        end
    end
end

function GameRoom.OnInvildProto(self, uid, pname)
    self:SendMsg("S2CReLogin", {}, {uid})
end

