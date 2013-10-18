
local time_table = {}

Timer = {}

function Timer:new(sid)
    self.__index = self
    local ins = setmetatable({}, self)
    ins.timers = {}
    ins.sid = sid
    ins.tid = 0
    time_table[sid] = ins
    return ins
end

function Timer:settimer(interval, count, func, ...)
    self.tid = self.tid + 1
    local mark = os.time()
    local t = {mark, interval, count, func, ...}
    self.timers[self.tid] = t
    return self.tid
end

function Timer:update()
    for k, v in pairs(self.timers) do 
        local t = os.time()
        local count = v[3]
        if t - v[2] >= v[1] then
            v[1] = t
            if count ~= nil then
                v[3] = count - 1
            end
            v[4](unpack(v, 5))

            if count ~= nil and count <= 1 then
                self:rmtimer(k)
            end
        end
    end
end

function Timer:rmtimer(tid)
    self.timers[tid] = nil
end

function TimerUpdate() 
    for k, v in pairs(time_table) do
        v:update()
    end
end

