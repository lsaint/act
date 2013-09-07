

local Motion = {
    {_id = "1", desc = "11"},
    {_id = "2", desc = "22"},
    {_id = "3", desc = "33"},
}


function RandomMotion1()
    n = math.random(3)
    return Motion[n]
end

