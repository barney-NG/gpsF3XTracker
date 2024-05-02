--[[#############################################################################
Copyright (c) 2024 Axel Barnitzke                                     MIT License

SCREEN Library:

functions: ---------------------------------------------------------------------

################################################################################]]

-- Widget Definition
local screen = {initialized=false, has_stack=false, cleaned=false, taranis=false, title_height=8}

screen.stack_values = {}

-- clean and redraw the complete area
function screen.clean()
    if not screen.cleaned then
        lcd.clear()
        lcd.drawRectangle(screen.xmin, screen.ymin, screen.xmax-screen.xmin, screen.ymax-screen.ymin, SOLID)
        if screen.has_stack then
            lcd.drawRectangle(screen.stack_xmin, screen.ymin, screen.stack_xmax-screen.stack_xmin, screen.ymax-screen.ymin, SOLID)
        end
        local step = screen.rh
        local y0 = screen.ymin + screen.rh
        local y1 = screen.ymax - screen.rh
        for y = y0, y1, step do
            -- lcd.drawLine(screen.xmin+1,y,screen.xmax-1,y,SOLID,FORCE)
            lcd.drawLine(screen.xmin+1,y,screen.xmax-1,y,SOLID,0)
        end
        screen.cleaned = true
    end
end
-- draw the topline of a list
function screen.listBox(row,list,idx,flags)
    screen.text(row, list[idx+1], flags or 0)
end
-- draw title (Taranis) or something like a title (others)
function screen.title(text, first, last)
    -- Only on Taranis available
    if screen.taranis then
        lcd.drawScreenTitle(text, first or 0, last or 0)
    else
        local s = string.format("%-50.50s", text)
        lcd.drawFilledRectangle(screen.xmin, screen.ymin-screen.title_height, screen.xmax-screen.xmin, screen.title_height, SOLID)
        lcd.drawText(screen.xmin+1,4,s,SMLSIZE+INVERS)
    end
end
-- draw a formatted number
function screen.number(row,number,precision, digits)
    if row > 0 and row <= screen.rows then
        local p = precision or 0
        local d = digits or 6
        local format = string.format("%%%d.%df",d,p)
        local s = string.format(format, number)
        screen.text(row,s)
    end
end
-- draw a line of text
function screen.text(row,text,extra)
    local flags = extra or 0
    if row > 0 and row <= screen.rows then
        local y0 = screen.ymin + (row-1) * screen.rh + 4
        local x0 = screen.xmin + 1
        local s
        if screen.has_stack then 
            s = string.format("%-35.35s", text)
        else
            s = string.format("%-50.50s", text)
        end
        lcd.drawText(x0,y0,s,SMLSIZE+flags)
    end
end
-- add a new time to the stack
function screen.addTime(number,timestamp_ms)
    local seconds = math.floor(timestamp_ms / 1000)
    local rest_ms = timestamp_ms % 1000
    screen.addStack(string.format("%2d: %3d:%02ds",number,seconds,math.floor(rest_ms/10)))
end
-- add a new lp number to the stack
function screen.addLaps(number,laps)
        screen.addStack(string.format("%2d: %2d laps",number,laps))
end
-- add some text to the stack area
function screen.stack_text(row,text,extra)
    local flags = extra or 0
    if row > 0 and row <= screen.rows then
        local y0 = screen.ymin + (row-1) * screen.rh + 4
        local x0 = screen.stack_xmin + 1
        local s = string.format("%11.11s", text)
        lcd.drawText(x0,y0,s,SMLSIZE+flags)
    end
end
-- add text to the stack
function screen.addStack(text)
    for i=screen.rows-1,1,-1 do
        screen.stack_values[i+1] = screen.stack_values[i]
    end
    screen.stack_values[1] = text
end
-- print the contents of the whole stack
function screen.showStack()
    for i=1,screen.rows,1 do
        screen.stack_text(i, screen.stack_values[i])
    end
end
-- empty the stack
function screen.resetStack()
    if screen.has_stack then
        for i=1,screen.rows,1 do
            screen.stack_values[i] = "--: ---:--"
        end
    end
end
-- resize is needed if printed on a part of the display
function screen.resize(x,y,w,h)
    screen.title_height = math.floor((h-y)/(screen.rows+1))
    screen.ymax = h
    screen.ymin = y + screen.title_height
    screen.xmin = x
    if screen.has_stack then
        screen.xmax = math.floor(3 * w / 4)
        screen.resetStack()
    else
        screen.xmax = w
    end
    screen.stack_xmin = screen.xmax
    screen.stack_xmax = w
    screen.rh = math.floor((screen.ymax-screen.ymin)/screen.rows)
end
-- setup one screen occupying the whole display
function screen.init( rows_in, with_stack )
    if not screen.initialized then
        local ver, radio, maj, minor, rev = getVersion()
        if string.find(radio, 'x9d') then
            screen.taranis = true
        end
        screen.rows = rows_in or 4
        screen.has_stack = with_stack or false
        -- Taranis title is 8 pixel
        screen.ymax = LCD_H
        screen.ymin = 8
        screen.xmin = 0
        if screen.has_stack then
            screen.xmax = math.floor(3 * LCD_W / 4)
            screen.resetStack()
        else
            screen.xmax = LCD_W
        end
        screen.stack_xmin = screen.xmax
        screen.stack_xmax = LCD_W
        screen.rh = math.floor((screen.ymax-screen.ymin)/screen.rows)
        screen.initialized = true
        screen.cleaned = false
    end
end


return screen