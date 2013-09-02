
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



function split(str, pat)
   local t = {}  -- NOTE: use {n = 0} in Lua-5.0
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
     table.insert(t,cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t
end
