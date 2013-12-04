
require "guess"

RoundMgr = {}

function RoundMgr:new(room)
    self.__index = self
    local ins = setmetatable({}, self)
    ins.room = room
    ins.mode2start = {MODE_ACT = ins.startRoundAct, MODE_FREE = ins.startRoundFree}
    return ins
end

function RoundMgr:roundStart()
    print("RoundStart")
    local round_end_time = self.mode2start[self.room.mode](self)
    local notify_score_count = round_end_time / BC_SCORE_INTERVAL + 1
    self.room:settimer(BC_SCORE_INTERVAL, notify_score_count, self.room.notifyScore, self.room)
end

function RoundMgr:startRoundAct()
    print("startRoundAct")
    local motions = RandomMotion({public=ROUND_COUNT*2-1, private=1, sid=self.room.tsid})
    if motions == nil then return end
    self:doRoundAct(self.room:A(), 1, motions[1])
    for ar = 2, ROUND_COUNT do
        self.room:settimer(ROUND_TIME * (ar-1), 1, self.doRoundAct, self, self.room:A(), ar, motions[ar])
    end

    self.room:settimer(ROUND_COUNT * ROUND_TIME, 1, self.notifyA2B, self)
    local a_total_time = ROUND_COUNT * ROUND_TIME + A2B_ROUND_INTERVAL
    for br = 1, ROUND_COUNT do
        local t = a_total_time + ROUND_TIME * (br - 1)
        self.room:settimer(t, 1, self.doRoundAct, self, self.room:B(), br, motions[br+ROUND_COUNT])
    end

    local round_end_time = a_total_time + ROUND_TIME * ROUND_COUNT + 1
    self.room:settimer(round_end_time, 1, self.room.pollStart, self.room)
    return round_end_time
end

function RoundMgr:startRoundFree()
    print("startRoundFree")
    self:doRoundFree(self.room:A(), 1)
    self.room:settimer(ROUND_TIME_FREE, 1, self.notifyA2B, self)
    self.room:settimer(ROUND_TIME_FREE + A2B_ROUND_INTERVAL, 1, self.doRoundFree, self, self.room:B(), 2)
    local round_end_time = ROUND_TIME_FREE * 2 + A2B_ROUND_INTERVAL
    self.room:settimer(round_end_time, 1, self.room.pollStart, self.room)
    return round_end_time
end

function RoundMgr:doRoundAct(presenter, r, m)
    self:doRound(presenter, r, m, ROUND_TIME)
end

function RoundMgr:doRoundFree(presenter, r)
    self:doRound(presenter, r, nil, ROUND_TIME_FREE)
end

function RoundMgr:doRound(presenter, r, m, t)
    print("DoRound", r)
    self.room.round_info = {presenter, r, m, os.time(), t}
    self.room.guess = Guess:new(m)
    local bc = {
        presenter = {uid = presenter.uid},
        round = r,
        mot = m,
        time = t,
    }   
    self.room:Broadcast("S2CNotifyRoundStart", bc)
end

function RoundMgr:notifyA2B()
    print("notifyA2B")
    self.room:Broadcast("S2CNotifyA2B", {defer = A2B_ROUND_INTERVAL, b = {uid = self.room:B().uid}})
end

