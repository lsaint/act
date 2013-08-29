

local Motion = {
    {id = 1, desc = "1号动作"},
    {id = 2, desc = "2号动作"},
    {id = 3, desc = "3号动作"},
}


function RandomMotion()
    n = math.random(3)
    return Motion[n]
end

