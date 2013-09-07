

local Punishment = {
    {_id = "1", desc = "1号惩罚"},
    {_id = "2", desc = "2号惩罚"},
    {_id = "3", desc = "3号惩罚"},
    {_id = "4", desc = "4号惩罚"},
    {_id = "5", desc = "5号惩罚"},
    {_id = "6", desc = "6号惩罚"},
}

function RandomPunish1()
    ret = {}
    for i = 1, #Punishment do
        table.insert(ret, Punishment[math.random(#Punishment)])
    end
    return ret
end
