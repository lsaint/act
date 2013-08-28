

local timer = {}

local time_table = {}
local tid = 0

-- count == nil  -- loop forever
function timer.settimer(interval, count, func, ...)
    tid = tid + 1
    mark = os.time()
    local t = {mark, interval, count, func, ...}
    time_table[tid] = t
    return tid
end

function timer.rmtimer(tid)
    table.remove(time_table, tid)
end

function timer.update()
    for k, v in ipairs(time_table) do 
        t = os.time()
        count = v[3]
        if t - v[2] >= v[1] then
            v[1] = t
            if count ~= nil then
                v[3] = count - 1
            end
            v[4](unpack(v, 5))
        end
        if count ~= nil and count - 1 < 0 then
            table.remove(time_table, k)
        end
    end
end

return timer
