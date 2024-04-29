
local tools = {indent = ''}
-- unused
 function tools.str2float(str)
    -- simple string to float converter
    -- can convert real numbers only:
    -- NN.NNNNN yes, .NNNN yes, NNNNNN yes, NN.NNNNeN no
    local val = 0.0
    local pos = string.find(str,'.',1,true)
    if pos then
        -- split into intergral and fractional part
        local len = string.len(str)
        local ipart = '0' .. string.sub(str,1,pos-1)
        local fpart = string.sub(str,pos+1,len)
        -- develope divisor to make fpart < 1
        local flen = string.len(fpart)
        local divisor = math.pow(10,flen)
        -- make numbers from strings
        local inum = tonumber(ipart) 
        local fnum = tonumber(fpart)/divisor

        val = inum + fnum
    else
        -- no dot -> make a number
        val = tonumber(str) + 0.0
    end
    return val
end

function tools.serializeTable (tbl)
    if type(tbl) ~= "table" then
      return tbl
    end
    tools.indent=tools.indent .. "   "
    local result= "\n" .. tools.indent .. "{\n"
    for k, v in pairs(tbl) do
      if type(k) == "number" then
        k="[" .. k .. "]"
      end
      if type(v) == "table" then
        result=result .. tools.indent .. k .. " = " .. tools.serializeTable(v) .. ",\n"
      elseif type(v) == "function" then
      elseif type(v) == "string" then
        result=result .. tools.indent .. k .. " = '" .. v .. "',\n"
      elseif type(v) == "boolean" then
        if v then result=result .. tools.indent .. k .. " = true,\n"
        else result=result .. tools.indent .. k .. " = false,\n"
        end
      else
        result=result .. tools.indent .. k .. " = " .. v .. ",\n"
      end
    end
    result = result ..   tools.indent .. "}"
    tools.indent=string.sub(tools.indent,4)
    return result
  end

  return tools