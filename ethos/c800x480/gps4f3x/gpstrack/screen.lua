--[[#############################################################################
SCREEN Library: GPS F3X Tracker for Ethos v1.2

Copyright (c) 2024 Axel Barnitzke - original code for OpenTx          MIT License
Copyright (c) 2024 Milan Repik - porting to FrSky Ethos               MIT License

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Change log:
- v1.1: - only FONT_L is used for widget height > 290 (for full frame widget on 800x480 screen it is >= 294) and FONT_S otherwise
- v1.2: - improved management of fonts and FONT_STD included for full height / half wide widget layout
################################################################################]]

local screen = {initialized=false, has_stack=false, cleaned=false, text_h=18, font=0}

screen.stack_values = {}

function screen.title(text, stack)                          -- draw a title
  local color=lcd.RGB (0xEA, 0x5E, 0x00)
  lcd.color (color)
  if stack then
    lcd.drawFilledRectangle(screen.stack_xmin, screen.ymin, screen.stack_xmax, screen.text_h)
  else
    lcd.drawFilledRectangle(screen.xmin, screen.ymin, screen.xmax, screen.text_h)
  end  
  color=lcd.RGB (0xFF, 0xFF, 0xFF)
  lcd.color (color)
  if stack then
    lcd.drawText(screen.stack_xmin,screen.ymin,string.format("%-50.50s", text))    
  else  
    lcd.drawText(screen.xmin,screen.ymin,string.format("%-50.50s", text))
  end
end

function screen.text(row,text)                              -- draw a line of text
  if row > 0 and row <= screen.rows then
    local y0 = screen.ymin + row * screen.text_h
    local x0 = screen.xmin + 1
    local s
    if screen.has_stack then 
      s = string.format("%-35.35s", text)
    else
      s = string.format("%-50.50s", text)
    end
    lcd.drawText(x0,y0,s)
    end
end

function screen.addTime(number,timestamp_ms)                -- add a new lap number with its time to the stack
  local seconds = math.floor(timestamp_ms / 1000)
  local rest_ms = timestamp_ms % 1000
  screen.addStack(string.format("%2d: %3d:%02ds",number,seconds,math.floor(rest_ms/10)))
end

function screen.addLaps(number,laps)                        -- add a new lap number to the stack
  screen.addStack(string.format("%2d: %2d laps",number,laps))
end

function screen.addStack(text)                              -- add text to the 1-st line of the stack and move rest down
  for i=screen.rows-1,1,-1 do
    screen.stack_values[i+1] = screen.stack_values[i]
  end
  screen.stack_values[1] = text
end

function screen.showStack()                                 -- print the contents of the whole stack
  for i=1,screen.rows,1 do
    if screen.stack_values[i] ~= "" then
      local y0 = screen.ymin + i * screen.text_h + 4
      local x0 = screen.stack_xmin + 1
      local s = string.format("%11.11s", screen.stack_values[i])
      lcd.drawText(x0,y0,s)
    end  
  end
end

function screen.resetStack()                                -- empty the stack
  if screen.has_stack then
    for i=1,screen.rows,1 do
      screen.stack_values[i] = ""
    end
  end
end

function screen.init(with_stack)                            -- setup widget screen
  if not screen.initialized then
    LCD_W, LCD_H = lcd.getWindowSize()
    if LCD_H > 290 then                                     -- Height is 294+ for 800x480 screen resolution and full frame
      if LCD_W > 390 then                                   -- Width is 388 for 800x480 screen resolution and half frame
        lcd.font(FONT_L); screen.font = FONT_L
      else
        lcd.font(FONT_STD); screen.font = FONT_STD
      end
    else
      lcd.font(FONT_S); screen.font = FONT_S
    end
--    print ("Screen Init LCD_H: ", LCD_H, ", LCD_W: ", LCD_W, ", lcd.font: ", lcd.font())    
    
    text_w, screen.text_h = lcd.getTextSize("")
    screen.rows = math.floor(LCD_H / screen.text_h) - 1     -- exclude title row
    screen.has_stack = with_stack or false                  -- "with_stack" = with area for F3x runs information

    screen.ymax = LCD_H
    screen.ymin = 0                   
    screen.xmin = 0
    if screen.has_stack then   
      screen.xmax = math.floor(3 * LCD_W / 4)
      screen.resetStack()
    else
      screen.xmax = LCD_W
    end
    screen.stack_xmin = screen.xmax
    screen.stack_xmax = LCD_W
    screen.initialized = true
    screen.cleaned = false
  end
end

return screen