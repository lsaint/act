
function pt(t) 
    local dt = "{"
    for k, v in pairs(t) do
        if type(v) == "table" then
            if #v ~= 0 then
                v = string.format("%s%s%s", "[", table.concat(v, ":"), "]")
            else
                v = string.format("%s%d", "t", #v)
            end     
        end
        dt = string.format("%s%s: %s, ", dt, k, v)
    end
    dt = string.format("%s%s", dt, "}")
    print(dt)
end

