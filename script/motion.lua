

local Motion = {
    {id = 1, desc = "11"},
    {id = 2, desc = "22"},
    {id = 3, desc = "33"},
}


function RandomMotion()
    n = math.random(3)
    return Motion[n]
end

