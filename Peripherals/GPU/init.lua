local perpath = select(1,...) --The path to the gpu folder
local events = require("Engine.events")
local coreg = require("Engine.coreg")

return function(config) --A function that creates a new GPU peripheral.
  
  --Load the config--
  local _LIKO_W, _LIKO_H = config._LIKO_W or 192, config._LIKO_H or 128 --LIKO screen width.
  local _LIKO_X, _LIKO_Y = 0,0 --LIKO12 Screen padding in the HOST screen.
  
  local _HOST_W, _HOST_H = love.graphics.getDimensions() --The host window size.
  
  local _GIFScale = math.floor(config._GIFScale or 2) --The gif scale factor (must be int).
  local _GIFStartKey = config._GIFStartKey or "f8"
  local _GIFEndKey = config._GIFEndKey or "f9"
  local _GIFPauseKey = config._GIFPauseKey or "f12"
  local _GIFFrameTime = (config._GIFFrameTime or 1/60)*2
  local _GIFTimer, _GIFRec = 0
  
  local _LIKOScale = math.floor(config._LIKOScale or 3) --The LIKO12 screen scale to the host screen scale.
  
  local _FontChars = config._FontChars or 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"\'`-_/1234567890!?[](){}.,;:<>+=%#^*~\\|$@& ' --Font chars
  local _FontPath, _FontExtraSpacing = config._FontPath or "/Engine/font.png", config._FontExtraSpacing or 1 --Font image path, and how many extra spacing pixels between every character.
  
  local _ColorSet = config._ColorSet or {
    {0,0,0,255}, --Black 1
    {28,43,83,255}, --Dark Blue 2
    {127,36,84,255}, --Dark Red 3
    {0,135,81,255}, --Dark Green 4
    {171,82,54,255}, --Brown 5
    {96,88,79,255}, --Dark Gray 6
    {195,195,198,255}, --Gray 7
    {255,241,233,255}, --White 8
    {237,27,81,255}, --Red 9
    {250,162,27,255}, --Orange 10
    {247,236,47,255}, --Yellow 11
    {93,187,77,255}, --Green 12
    {81,166,220,255}, --Blue 13
    {131,118,156,255}, --Purple 14
    {241,118,166,255}, --Pink 15
    {252,204,171,255} --Human Skin 16
  } --The colorset of the gpu
  
  _ColorSet[0] = {0,0,0,0} --Color index 0 must be always transparent.
  
  local _ClearOnRender = config._ClearOnRender --Should clear the screen when render, some platforms have glitches when this is disabled.
  if type(_ClearOnRender) == "nil" then _ClearOnRender = true end --Defaults to be enabled.
  local cpukit
  if config.CPUKit then cpukit = config.CPUKit end
  --End of config loading--
  
  
  local _ShouldDraw = false --This flag means that the gpu has to update the screen for the user.
  
  --Hook the resize function--
  events:register("love:resize",function(w,h) --Do some calculations
    _HOST_W, _HOST_H = w, h
    local TSX, TSY = w/_LIKO_W, h/_LIKO_H --TestScaleX, TestScaleY
    if TSX < TSY then
      _LIKOScale = TSX
      _LIKO_X, _LIKO_Y = 0, (_HOST_H-_LIKO_H*_LIKOScale)/2
    else
      _LIKOScale = TSY
      _LIKO_X, _LIKO_Y = (_HOST_W-_LIKO_W*_LIKOScale)/2, 0
    end
    _ShouldDraw = true
  end)
  
  --Hook to some functions to redraw (when the window is moved, got focus, etc ...)
  events:register("love:focus",function(f) if f then _ShouldDraw = true end end) --Window got focus.
  events:register("love:visible",function(v) if v then _ShouldDraw = true end end) --Window got visible.
  
  --Initialize the gpu--
  love.graphics.setDefaultFilter("nearest","nearest") --Set the scaling filter to the nearest pixel.
  local _ScreenCanvas = love.graphics.newCanvas(_LIKO_W, _LIKO_H) --Create the screen canvas.
  local _GIFCanvas = love.graphics.newCanvas(_LIKO_W*_GIFScale,_LIKO_H*_GIFScale) --Create the gif canvas, used to apply the gif scale factor.
  local _Font = love.graphics.newImageFont(_FontPath, _FontChars, _FontExtraSpacing)
  
  love.graphics.clear(0,0,0,255) --Clear the host screen.
  
  love.graphics.setCanvas(_ScreenCanvas) --Activate LIKO12 canvas.
  love.graphics.clear(0,0,0,255) --Clear LIKO12 screen for the first time.
  
  events:trigger("love:resize", _HOST_W, _HOST_H) --Calculate LIKO12 scale to the host window for the first time.
  
  love.graphics.setFont(_Font) --Apply the default font.
  
  --Post initialization (Setup the in liko12 gpu settings)--
  
  local gpuName, gpuVersion, gpuVendor, gpuDevice = love.graphics.getRendererInfo()
  --love.filesystem.write("/GPUInfo.txt",gpuName..";"..gpuVersion..";"..gpuVendor..";"..gpuDevice)
  
  local ofs = {} --Offsets table.
  ofs.screen = {0,0} --The offset of all the drawing opereations.
  ofs.point = {0,0} --The offset of GPU.point/s.
  ofs.print = {-1,-1} --The offset of GPU.print.
  ofs.line = {0,0} --The offset of GPU.line/s.
  ofs.circle = {0,0,0} --The offset of GPU.circle with l as false (x,y,r).
  ofs.circle_line = {0,0,0} --The offset of GPU.circle with l as true (x,y,r).
  ofs.ellipse = {0,0,0,0} --The offset of GPU.circle with l as false (x,y,rx,ry).
  ofs.ellipse_line = {0,0,0,0} --The offset of GPU.circle with l as true (x,y,rx,ry).
  ofs.rect = {-1,-1} --The offset of GPU.rect with l as false.
  ofs.rectSize = {0,0} --The offset of w,h in GPU.rect with l as false.
  ofs.rect_line = {0,0} --The offset of GPU.rect with l as true.
  ofs.rectSize_line = {-1,-1} --The offset of w,h in GPU.rect with l as false.
  ofs.image = {-1,-1}
  ofs.quad = {-1,-1}
  
  if gpuVersion == "OpenGL ES 3.1 v1.r7p0-03rel0.b8759509ece0e6dda5325cb53763bcf0" then
    --GPU glitch fix for this driver, happens at my samsung j700h
    ofs.screen = {0,-1}
    --ofs.point = {0,0}
    ofs.print = {-1,0}
    ofs.rect = {-1,0}
    ofs.image = {-1,0}
    ofs.quad = {-1,0}
  end
  
  love.graphics.translate(unpack(ofs.screen)) --Offset all the drawing opereations.
  
  local _Mobile = love.system.getOS() == "Android" or love.system.getOS() == "iOS"
  
  --Internal Functions--
  local function _HostToLiko(x,y) --Convert a position from HOST screen to LIKO12 screen.
    --x, y = x-_ScreenX, y-_ScreenY
    return math.floor((x - _LIKO_X)/_LIKOScale )+1, math.floor((y - _LIKO_Y)/_LIKOScale)+1
  end
  
  local function _GetColor(c) return _ColorSet[c or 1] or _ColorSet[0] end --Get the (rgba) table of a color id.
  local function _GetColorID(r,g,b,a) --Get the color id by the (rgba) table.
    local a = type(a) == "nil" and 255 or a
    for id, col in pairs(_ColorSet) do
      if col[1] == r and col[2] == g and col[3] == b and col[4] == a then
        return id
      end
    end
    return 0
  end
  
  local function magiclines(s)
    if s:sub(-1)~="\n" then s=s.."\n" end
    return s:gmatch("(.-)\n")
  end
  
  local function exe(...) --Excute a LIKO12 api function (to handle errors)
    local args = {...}
    if args[1] then
      local nargs = {}
      for k,v in pairs(args) do --Clone the args, removing the first one
        if type(k) == "number" then
          nargs[k-1] = v
        else
          nargs[k] = v
        end
      end
      return unpack(nargs)
    else
      return error(args[2])
    end
  end
  
  --gifrecorder
  local _GIF = love.filesystem.load(perpath.."gif.lua")( _ColorSet, _GIFScale, _LIKO_W, _LIKO_H )
  events:register("love:keypressed", function(key,sc,isrepeat)
    if key == _GIFStartKey then
      if _GIFRec then return end --If there is an already in progress gif
      if love.filesystem.exists("/~gifrec.gif") then
        _GIFRec = _GIF.continue("/~gifrec.gif")
        return
      end
      _GIFRec = _GIF.new("/~gifrec.gif")
    elseif key == _GIFEndKey then
      if not _GIFRec then
        if love.filesystem.exists("/~gifrec.gif") then
          _GIFRec = _GIF.continue("/~gifrec.gif")
        else return end
      end
      _GIFRec:close()
      _GIFRec = nil
      love.filesystem.write("/LIKO12-"..os.time()..".gif",love.filesystem.read("/~gifrec.gif"))
      love.filesystem.remove("/~gifrec.gif")
    elseif key == _GIFPauseKey then
      if not _GIFRec then return end
      _GIFRec.file:flush()
      _GIFRec.file:close()
      _GIFRec = nil
    end
  end)
  events:register("love:reboot",function(args)
    if _GIFRec then
      _GIFRec.file:flush()
      _GIFRec.file:close()
      _GIFRec = nil
      
      love.filesystem.write("/~gifreboot.gif",love.filesystem.read("/~gifrec.gif"))
      love.filesystem.remove("/~gifrec.gif")
    end
  end)
  events:register("love:quit", function()
    if _GIFRec then
      _GIFRec.file:flush()
      _GIFRec.file:close()
      _GIFRec = nil
    end
    return false
  end)
  
  --Restoring the gif record if it was made by a reboot
  if love.filesystem.exists("/~gifreboot.gif") then
    if not _GIFRec then
      love.filesystem.write("/~gifrec.gif",love.filesystem.read("/~gifreboot.gif"))
      love.filesystem.remove("/~gifreboot.gif")
      _GIFRec = _GIF.continue("/~gifrec.gif")
    end
  end
  
  --Mouse Hooks (To translate them to LIKO12 screen)--
  events:register("love:mousepressed",function(x,y,b,istouch)
    local x,y = _HostToLiko(x,y)
    events:trigger("GPU:mousepressed",x,y,b,istouch)
    if cpukit then cpukit.triggerEvent("mousepressed",x,y,b,istouch) end
  end)
  events:register("love:mousemoved",function(x,y,dx,dy,istouch)
    local x,y = _HostToLiko(x,y)
    local dx, dy = _HostToLiko(dx,dy)
    events:trigger("GPU:mousemoved",x,y,dx,dy,istouch)
    if cpukit then cpukit.triggerEvent("mousemoved",x,y,dx,dy,istouch) end
  end)
  events:register("love:mousereleased",function(x,y,b,istouch)
    local x,y = _HostToLiko(x,y)
    events:trigger("GPU:mousereleased",x,y,b,istouch)
    if cpukit then cpukit.triggerEvent("mousereleased",x,y,b,istouch) end
  end)
  
  --Touch Hooks (To translate them to LIKO12 screen)--
  events:register("love:touchpressed",function(id,x,y,dx,dy,p)
    local x,y = _HostToLiko(x,y)
    local dx, dy = _HostToLiko(dx,dy)
    events:trigger("GPU:touchpressed",id,x,y,dx,dy,p)
    if cpukit then cpukit.triggerEvent("touchpressed",id,x,y,dx,dy,p) end
  end)
  events:register("love:touchmoved",function(id,x,y,dx,dy,p)
    local x,y = _HostToLiko(x,y)
    local dx, dy = _HostToLiko(dx,dy)
    events:trigger("GPU:touchmoved",id,x,y,dx,dy,p)
    if cpukit then cpukit.triggerEvent("touchmoved",id,x,y,dx,dy,p) end
  end)
  events:register("love:touchreleased",function(id,x,y,dx,dy,p)
    local x,y = _HostToLiko(x,y)
    local dx, dy = _HostToLiko(dx,dy)
    events:trigger("GPU:touchreleased",id,x,y,dx,dy,p)
    if cpukit then cpukit.triggerEvent("touchreleased",id,x,y,dx,dy,p) end
  end)
  
  --The api starts here--
  local GPU = {}
  
  local flip = false
  local ColorStack = {} --The colors stack (pushColor,popColor)
  local printCursor = {x=1,y=1,bgc=1}
  local TERM_W, TERM_H = math.floor(_LIKO_W/4), math.floor(_LIKO_H/7)-2
  
  function GPU.screenSize() return true, _LIKO_W, _LIKO_H end
  function GPU.screenWidth() return true, _LIKO_W end
  function GPU.screenHeight() return true, _LIKO_H end
  function GPU.termSize() return true, TERM_W, TERM_H end
  function GPU.termWidth() return true, TERM_W end
  function GPU.termHeight() return true, TERM_H end
  
  --Call with color id to set the active color.
  --Call with no args to get the current acive color id.
  function GPU.color(id)
    if id then
      if type(id) ~= "number" then return false, "The color id must be a number." end --Error
      if id > 16 or id < 0 then return false, "The color id is out of range." end --Error
      id = math.floor(id) --Remove the float digits.
      love.graphics.setColor(_GetColor(id)) --Set the active color.
      return true --It ran successfuly.
    else
      return true, _GetColorID(love.graphics.getColor()) --Return the current color.
    end
  end
  
  --Push the current active color to the ColorStack.
  function GPU.pushColor()
    table.insert(ColorStack,exe(GPU.color())) --Add the active color id to the stack.
    return true --It ran successfully.
  end
  
  --Pop the last color from the ColorStack and set it to the active color.
  function GPU.popColor()
    if #ColorStack == 0 then return false, "No more colors to pop." end --Error
    exe(GPU.color(ColorStack[#ColorStack])) --Set the last color in the stack to be the active color.
    table.remove(ColorStack,#ColorStack) --Remove the last color in the stack.
    return true --It ran successfully
  end
  
  --Suspend the coroutine till the screen is updated
  function GPU.flip()
    _ShouldDraw = true -- Incase if no changes are made so doesn't suspend forever
    flip = true
    return 2 --Do not resume automatically
  end
  
  --Draw a rectangle filled, or lines only.
  --X pos, Y pos, W width, H height, L linerect, C colorid.
  function GPU.rect(x,y,w,h,l,c)
    local x,y,w,h,l,c = x or 1, y or 1, w or 1, h or 1, l or false, c --In case if they are not provided.
    
    --It accepts all the args as a table.
    if x and type(x) == "table" then
      x,y,w,h,l,c = unpack(x)
    end
    
    --Args types verification
    if type(x) ~= "number" then return false, "X pos must be a number or nil." end --Error
    if type(y) ~= "number" then return false, "Y pos must be a number or nil." end --Error
    if type(w) ~= "number" then return false, "W width must be a number or nil." end --Error
    if type(h) ~= "number" then return false, "H height must be a number or nil." end --Error
    if type(l) ~= "boolean" then return false, "L linerect must be a number or nil." end --Error
    if c and type(c) ~= "number" then return false, "The color id must be a number or nil." end --Error
    
    --Remove float digits
    x,y,w,h,c = math.floor(x), math.floor(y), math.floor(w), math.floor(h), c and math.floor(c) or c
    
    if c then --If the colorid is provided, pushColor then set the color.
      exe(GPU.pushColor())
      exe(GPU.color(c))
    end
    
    --Apply the offset.
    if l then
      x,y = x+ofs.rect_line[1], y+ofs.rect_line[2] --Pos
      w,h = w+ofs.rectSize_line[1], h+ofs.rectSize_line[2] --Size
    else
      x,y = x+ofs.rect[1], y+ofs.rect[2] --Pos
      w,h = w+ofs.rectSize[1], h+ofs.rectSize[2] --Size
    end
    
    love.graphics.rectangle(l and "line" or "fill",x,y,w,h) _ShouldDraw = true --Draw and tell that changes has been made.
    
    if c then exe(GPU.popColor()) end --Restore the color from the stack.
    
    return true --It ran successfully
  end
  
  --Draws a circle filled, or lines only.
  function GPU.circle(x,y,r,l,c)
    local x,y,r,l,c = x or 1, y or 1, r or 1, l or false, c --In case if they are not provided.
    
    --It accepts all the args as a table.
    if x and type(x) == "table" then
      x,y,r,l,c = unpack(x)
    end
    
    if c then --If the colorid is provided, pushColor then set the color.
      exe(GPU.pushColor())
      exe(GPU.color(c))
    end
    
    --Apply the offset.
    if l then
      x,y,r = x+ofs.circle_line[1], y+ofs.circle_line[2], r+ofs.circle_line[3]
    else
      x,y,r = x+ofs.circle[1], y+ofs.circle[2], r+ofs.circle[3]
    end
    
    love.graphics.circle(l and "line" or "fill",x,y,r) _ShouldDraw = true --Draw and tell that changes has been made.
    
    if c then exe(GPU.popColor()) end --Restore the color from the stack.
    
    return true --It ran successfully
  end
  
  --Draws a ellipse filled, or lines only.
  function GPU.ellipse(x,y,rx,ry,l,c)
    local x,y,rx,ry,l,c = x or 1, y or 1, rx or 1, ry or 1, l or false, c --In case if they are not provided.
    
    --It accepts all the args as a table.
    if x and type(x) == "table" then
      x,y,rx,ry,l,c = unpack(x)
    end
    
    if c then --If the colorid is provided, pushColor then set the color.
      exe(GPU.pushColor())
      exe(GPU.color(c))
    end
    
    --Apply the offset.
    if l then
      x,y,rx,ry = x+ofs.ellipse_line[1], y+ofs.ellipse_line[2], rx+ofs.ellipse_line[3], ry+ofs.ellipse_line[4]
    else
      x,y,rx,ry = x+ofs.ellipse[1], y+ofs.ellipse[2], rx+ofs.ellipse[3], ry+ofs.ellipse[4]
    end
    
    love.graphics.ellipse(l and "line" or "fill",x,y,rx,ry) _ShouldDraw = true --Draw and tell that changes has been made.
    
    if c then exe(GPU.popColor()) end --Restore the color from the stack.
    
    return true --It ran successfully
  end
  
  --Sets the position of the printing corsor when x,y are supplied
  --Or returns the current position of the printing cursor when x,y are not supplied
  function GPU.printCursor(x,y,bgc)
    if x or y or bgc then
      local x, y = x or printCursor.x, y or printCursor.y
      local bgc = bgc or printCursor.bgc
      if type(x) ~= "number" then return false, "X pos must be a number or nil." end --Error
      if type(y) ~= "number" then return false, "Y pos must be a number or nil." end --Error
      if type(bgc) ~= "number" then return false, "Background Color must be a number or nil." end --Error
      printCursor.x, printCursor.y = x, y --Set the cursor pos
      printCursor.bgc = bgc
      return true --It ran successfully.
    else
      return true, printCursor.x, printCursor.y, printCursor.bgc --Return the current cursor pos
    end
  end
  
  --Prints text to the screen,
  --Requires more work
  --Acts as a terminal print if x, y are not provided,
  --Or prints at the specific pos x, y3
  function GPU.print(t,x,y)
    local t = tostring(t)
    if x and y then --If the x & y are provided
      love.graphics.print(t, math.floor((x or 1)+ofs.print[1]), math.floor((y or 1)+ofs.print[2])) _ShouldDraw = true --Print the text to the screen and tall that changes has been made.
    else --If they are not, print on the grid
      local anl = true --Auto new line
      if type(x) == "boolean" then anl = x end
      local function printgrid(tx,gx,gy)
        if printCursor.bgc > 0 then exe(GPU.rect(math.floor((gx or 1)*4-2)-1, math.floor((gy or 1)*8-6)-1, tx:len()*4 +1, 7, false, printCursor.bgc)) end
        love.graphics.print(tx, math.floor(((gx or 1)*4-2)+ofs.print[1]), math.floor(((gy or 1)*8-6)+ofs.print[2]))
      _ShouldDraw = true end
      if y then printgrid(t,printCursor.x,printCursor.y) printCursor.x = printCursor.x + t:len() return true end
      local function cr() local s = exe(GPU.screenshot()):image() GPU.clear() s:draw(1,-6) end
      local function printLine(txt,f,ff)
        if txt:len()+printCursor.x-1 > TERM_W then
          local tl = txt:len()+printCursor.x-1
          printLine(txt:sub(0,txt:len()-(tl-TERM_W)),f,false)
          printLine(txt:sub(txt:len()-(tl-TERM_W)+1,-1),f,ff)
        else
          if printCursor.y == TERM_H+1 then cr() printCursor.y = TERM_H end
          printgrid(txt,printCursor.x, printCursor.y)
          if printCursor.y < TERM_H+1 and not(ff and f) then printCursor.y = printCursor.y+1 end
          if ff and f then
            printCursor.x = printCursor.x + txt:len()
          else
            printCursor.x = 1
          end
        end
      end
      local lcount = 0
      local bkt = t --Make a backup
      for line in magiclines(t) do lcount = lcount+1 end
      for line in magiclines(bkt) do 
        lcount = lcount-1
        printLine(line,lcount==0,not anl)
      end
    end
    return true
  end
  
  function GPU.printBackspace(c,skpCr)
    local c = c or printCursor.bgc
    if type(c) ~= "number" then return false, "Color must be a number value, provided: "..type(c) end
    local function cr() local s = exe(GPU.screenshot()):image() GPU.clear() s:draw(1,6) end
    if printCursor.x > 1 then
      printCursor.x = printCursor.x-1
      exe(GPU.rect(math.floor((printCursor.x or 1)*4-2)-1, math.floor((printCursor.y or 1)*8-6)-1, 5, 7, false, c))
    elseif not skpCr then
      if printCursor.y > 1 then
        printCursor.y = printCursor.y - 1
        printCursor.x = TERM_W
      else
        printCursor.x = TERM_W
        cr()
      end
      exe(GPU.rect(math.floor((printCursor.x or 1)*4-2)-1, math.floor((printCursor.y or 1)*8-6)-1, 5, 7, false, c))
    end
    return true
  end
  
  --Clears the whole screen with black or the given color id.
  function GPU.clear(c)
    local c = c or 1
    if type(c) ~= "number" then return false, "The color id must be a number." end --Error
    if c > 16 or c < 0 then return false, "The color id is out of range." end --Error
    exe(GPU.rect(1,1,_LIKO_W,_LIKO_H,false,c)) --Draw a rectangle that covers the whole screen.
    return true --It ran successfully.
  end
  
  --Draws a point/s at specific location/s, accepts the colorid as the last args, x and y of points must be provided before the colorid.
  function GPU.points(...)
    local args = {...} --The table of args
    exe(GPU.pushColor()) --Push the current color.
    if not (#args % 2 == 0) then exe(GPU.color(args[#args])) table.remove(args,#args) end --Extract the colorid (if exists) from the args and apply it.
    for k,v in ipairs(args) do if type(v) ~= "number" then return false, "Arg #"..k.." must be a number." end end --Error
    for k,v in ipairs(args) do if (k % 2 == 0) then args[k] = v + ofs.point[2] else args[k] = v + ofs.point[1] end end --Apply the offset.
    love.graphics.points(unpack(args)) _ShouldDraw = true --Draw the points and tell that changes has been made.
    exe(GPU.popColor()) --Pop the last color in the stack.
    return true --It ran successfully.
  end
  GPU.point = GPU.points --Just an alt name :P.
  
  --Draws a line/s at specific location/s, accepts the colorid as the last args, x1,y1,x2 and y2 of points must be provided before the colorid.
  function GPU.lines(...)
    local args = {...} --The table of args
    exe(GPU.pushColor()) --Push the current color.
    if not (#args % 2 == 0) then exe(GPU.color(args[#args])) table.remove(args,#args) end --Extract the colorid (if exists) from the args and apply it.
    for k,v in ipairs(args) do if type(v) ~= "number" then return false, "Arg #"..k.." must be a number." end end --Error
    for k,v in ipairs(args) do if (k % 2 == 0) then args[k] = v + ofs.line[2] else args[k] = v + ofs.line[1] end end --Apply the offset.
    love.graphics.line(unpack(args)) _ShouldDraw = true --Draw the lines and tell that changes has been made.
    exe(GPU.popColor()) --Pop the last color in the stack.
    return true --It ran successfully.
  end
  GPU.line = GPU.lines --Just an alt name :P.
  --Image API--
  function GPU.quad(x,y,w,h,sw,sh)
    return true, love.graphics.newQuad(x,y,w,h,sw,sh)
  end
  
  function GPU.image(data)
    local Image
    if type(data) == "string" then --Load liko12 specialized image format
      local imageData = exe(GPU.imagedata(data))
      return true, imageData:image()
    elseif type(data) == "userdata" and data.typeOf and data:typeOf("ImageData") then
      Image = love.graphics.newImage(data)
      --imageData = exe(GPU.imagedata(Image))
    end
    
    local i = {}
    
    function i:draw(x,y,r,sx,sy,quad)
      local x, y, sx, sy = x or 1, y or 1, sx or 1, sy or 1
      GPU.pushColor()
      love.graphics.setColor(255,255,255,255)
      if quad then
        love.graphics.draw(Image,quad,math.floor(x+ofs.quad[1]),math.floor(y+ofs.quad[2]),r,math.floor(sx),math.floor(sy))
      else
        love.graphics.draw(Image,math.floor(x+ofs.image[1]),math.floor(y+ofs.image[2]),r,math.floor(sx),math.floor(sy))
      end
      GPU.popColor()
      _ShouldDraw = true
      return self
    end
    function i:size() return Image:getDimensions() end
    function i:width() return Image:getWidth() end
    function i:height() return Image:getHeight() end
    function i:data() return exe(GPU.imagedata(Image:getData())) end
    function i:quad(x,y,w,h) return love.graphics.newQuad(x-1,y-1,w or self:width(),h or self:height(),self:width(),self:height()) end
    
    return true, i
  end
  
  function GPU.imagedata(w,h)
    local imageData
    if h then
      imageData = love.image.newImageData(w,h)
    elseif type(w) == "string" then --Load specialized liko12 image format
      if w:sub(0,12) == "LK12;GPUIMG;" then
        local w,h,data = string.match(w,"LK12;GPUIMG;(%d+)x(%d+);(.+)")
        imageData = love.image.newImageData(w,h)
        local Colors = {["0"]=0,["1"]=1,["2"]=2,["3"]=3,["4"]=4,["5"]=5,["6"]=6,["7"]=7,["8"]=8,["9"]=9,a=10,b=11,c=12,d=13,e=14,f=15,g=16}
        imageData:mapPixel(function(x,y,r,g,b,a)
          local c = Colors[data:sub(0,1)]
          data = data:sub(2,-1)
          return unpack(_GetColor(c))
        end)
      else
        imageData = love.image.newImageData(love.filesystem.newFileData(w,"image.png"))
      end
    elseif type(w) == "userdata" and w.typeOf and w:typeOf("ImageData") then
      imageData = w
    end
    
    local id = {}
    
    function id:size() return imageData:getDimensions() end
    function id:getPixel(x,y) return _GetColorID(imageData:getPixel((x or 1)-1,(y or 1)-1)) end
    function id:setPixel(x,y,c) imageData:setPixel((x or 1)-1,(y or 1)-1,unpack(_GetColor(c))) return self end
    function id:map(mf)
      imageData:mapPixel(
      function(x,y,r,g,b,a)
        local newCol = mf(x+1,y+1,_GetColorID(r,g,b,a))
        newCol = newCol and _GetColor(newCol) or {r,g,b,a}
        return unpack(newCol)
      end)
      return self
    end
    function id:height() return imageData:getHeight() end
    function id:width() return imageData:getWidth() end
    function id:paste(expdata,dx,dy,sx,sy,sw,sh) local sprData = love.image.newImageData(love.filesystem.newFileData(expdata,"image.png")) imageData:paste(sprData,(dx or 1)-1,(dy or 1)-1,(sx or 1)-1,(sy or 1)-1,sw or sprData:getWidth(), sh or sprData:getHeight()) return self end
    function id:quad(x,y,w,h) return love.graphics.newQuad(x-1,y-1,w or self:width(),h or self:height(),self:width(),self:height()) end
    function id:image() return exe(GPU.image(imageData)) end
    function id:export() return imageData:encode("png"):getString() end
    function id:enlarge(scale)
      local scale = math.floor(scale or 1)
      if scale <= 0 then scale = 1 end --Protection
      if scale == 1 then return self end
      local newData = exe(GPU.imagedata(self:width()*scale,self:height()*scale))
      self:map(function(x,y,c)
        for iy=1, scale do for ix=1, scale do
          newData:setPixel((x-1)*scale + ix,(y-1)*scale + iy,c)
        end end
      end)
      return newData
    end
    function id:encode() --Export to liko12 format
      local data = "LK12;GPUIMG;"..self:width().."x"..self.height()..";"
      local colors = {"1","2","3","4","5","6","7","8","9","a","b","c","d","e","f","g";[0]="0"}
      self:map(function(x,y,c) data = data..colors[c] end)
      return data
    end
    
    return true, id
  end
  
  function GPU.screenshot(x,y,w,h)
    local x, y, w, h = x or 1, y or 1, w or _LIKO_W, h or _LIKO_H
    if x and type(x) ~= "number" then return false, "X must be a number, provided: "..type(x) end
    if y and type(y) ~= "number" then return false, "Y must be a number, provided: "..type(y) end
    if w and type(w) ~= "number" then return false, "W must be a number, provided: "..type(w) end
    if h and type(h) ~= "number" then return false, "H must be a number, provided: "..type(h) end
    return true, exe(GPU.imagedata(_ScreenCanvas:newImageData(x-1,y-1,w,h)))
  end
  
  --Mouse API--
  
  --Returns the current position of the mouse.
  function GPU.getMPos()
    local x,y = _HostToLiko(love.mouse.getPosition()) --Convert the mouse position
    return true, x, y --And return it
  end
  
  --Returns if the given mouse button is down
  function GPU.isMDown(b)
    if type(b) ~= "number" then return false, "Button must be a number, provided: "..type(b) end --Error
    local b = math.floor(b)
    return true, love.mouse.isDown(b)
  end
  
  --Cursor API--
  local _Cursor = "none"
  local _CursorsCache = {}
  
  function GPU.cursor(imgdata,name,hx,hy)
    if type(imgdata) == "string" then --Set the current cursor
      if _Cursor == imgdata then return true end
      if (not _CursorsCache[imgdata]) and (imgdata ~= "none") then return false, "Cursor doesn't exists: "..imgdata end
      if _Cursor == "none" then love.mouse.setVisible(true) end
      _Cursor = imgdata
      if _Cursor == "none" then
        love.mouse.setVisible(false)
      elseif not _Mobile then
        love.mouse.setCursor(_CursorsCache[_Cursor].cursor)
      end
      return true --It ran successfully
    elseif type(imgdata) == "table" then --Create a new cursor from an image.
      if not( imgdata.enlarge and imgdata.export ) then return false, "Invalied image" end
      
      local name = name or "default"
      if type(name) ~= "string" then return false, "Name must be a string, provided: "..type(name) end
      
      local hx, hy = hx or 1, hy or 1
      if type(hx) ~= "number" then return false, "Hot X must be a number or a nil, provided: "..type(hx) end
      if type(hy) ~= "number" then return false, "Hot Y must be a number or a nil, provided: "..type(hy) end
      hx, hy = math.floor(hx)-1, math.floor(hy)-1
      
      local enimg = imgdata:enlarge(_LIKOScale)
      local limg = love.image.newImageData(love.filesystem.newFileData(enimg:export(),"cursor.png")) --Take it out to love image object
      local gifimg = love.graphics.newImage(love.filesystem.newFileData(imgdata:export(),"cursor.png"))
      local hotx, hoty = hx*_LIKOScale, hy*_LIKOScale --Converted to host scale
      local cur = _Mobile and {} or love.mouse.newCursor(limg,hotx,hoty)
      
      _CursorsCache[name] = {cursor=cur,imgdata=imgdata,gifimg=gifimg,hx=hx,hy=hy}
      return true --It ran successfully
    elseif type(imgdata) == "nil" then
      return true, _Cursor, _CursorsCache[_Cursor].imgdata, _CursorsCache[_Cursor].hx+1, _CursorsCache[_Cursor].hy+1
    else --Invalied
      return false, "The first argument must be a string, image or nil"
    end
  end
  
  events:register("love:resize",function() --The new size will be calculated in the top, because events are called by the order they were registered with
    if _Mobile then return end
    for k, cursor in pairs(_CursorsCache) do
      local enimg = cursor.imgdata:enlarge(_LIKOScale)
      local limg = love.image.newImageData(love.filesystem.newFileData(enimg:export(),"cursor.png")) --Take it out to love image object
      local hotx, hoty = cursor.hx*_LIKOScale, cursor.hy*_LIKOScale --Converted to host scale
      local cur = love.mouse.newCursor(limg,hotx,hoty)
      _Cursor = "none"; _CursorsCache[k].cursor = cur
    end
    exe(GPU.cursor(_Cursor))
  end)
  
  exe(GPU.cursor(exe(GPU.imagedata(1,1)):setPixel(1,1,8),"default"))
  exe(GPU.cursor(_Cursor))
  
  --End of API--
  
  love.graphics.setLineStyle("rough") --Set the line style.
  love.graphics.setLineJoin("miter") --Set the line join style.
  love.graphics.setPointSize(1) --Set the point size to 1px.
  love.graphics.setLineWidth(1) --Set the line width to 1px.
  love.graphics.setColor(_GetColor(1)) --Set the active color to black.
  love.mouse.setVisible(false)
  
  exe(GPU.clear()) --Clear the canvas for the first time.
  
  --Host to love.run when graphics is active--
  events:register("love:graphics",function()
    if _ShouldDraw then --When it's required to draw (when changes has been made to the canvas)
      love.graphics.setCanvas() --Quit the canvas and return to the host screen.
      love.graphics.origin() --Reset all transformations.
      
      GPU.pushColor() --Push the current color to the stack.
      love.graphics.setColor(255,255,255,255) --I don't want to tint the canvas :P
      
      if _ClearOnRender then love.graphics.clear(0,0,0,255) end --Clear the screen (Some platforms are glitching without this).
      
      love.graphics.draw(_ScreenCanvas, _LIKO_X, _LIKO_Y, 0, _LIKOScale, _LIKOScale) --Draw the canvas.
      
      love.graphics.present() --Present the screen to the host & the user.
      love.graphics.setCanvas(_ScreenCanvas) --Reactivate the canvas.
      love.graphics.translate(unpack(ofs.screen)) --Reapply the offset.
      _ShouldDraw = false --Reset the flag.
      GPU.popColor() --Restore the active color.
      if flip then
        flip = false
        coreg:resumeCoroutine(true)
      end
    end
  end)
  
  events:register("love:update",function(dt)
    if not _GIFRec then return end
    _GIFTimer = _GIFTimer + dt
    if _GIFTimer >= _GIFFrameTime then
      _GIFTimer = _GIFTimer-_GIFFrameTime
      love.graphics.setCanvas() --Quit the canvas and return to the host screen.
      love.graphics.origin() --Reset all transformations.
      
      GPU.pushColor() --Push the current color to the stack.
      love.graphics.setColor(255,255,255,255) --I don't want to tint the canvas :P
      
      love.graphics.setCanvas(_GIFCanvas)
      
      love.graphics.clear(0,0,0,255) --Clear the screen (Some platforms are glitching without this).
      
      love.graphics.setColor(255,255,255,255)
      
      love.graphics.draw(_ScreenCanvas, 0, 0, 0, _GIFScale, _GIFScale) --Draw the canvas.
      
      if _Cursor ~= "none" then --Draw the cursor
        local cx, cy = exe(GPU.getMPos())
        love.graphics.draw(_CursorsCache[_Cursor].gifimg,(cx-_CursorsCache[_Cursor].hx)*_GIFScale-1,(cy-_CursorsCache[_Cursor].hy)*_GIFScale-1,0,_GIFScale,_GIFScale)
      end
      
      love.graphics.setCanvas()
      
      love.graphics.setCanvas(_ScreenCanvas) --Reactivate the canvas.
      love.graphics.translate(unpack(ofs.screen)) --Reapply the offset.
      GPU.popColor() --Restore the active color.
      
      _GIFRec:frame(_GIFCanvas:newImageData())
    end
  end)
  
  local devkit = {}
  devkit._LIKO_W = _LIKO_W
  devkit._LIKO_X = _LIKO_Y
  devkit._HOST_W = _HOST_H
  devkit._GIFScale = _GIFScale
  devkit._GIFStartKey = _GIFStartKey
  devkit._GIFEndKey = _GIFEndKey
  devkit._GIFPauseKey = _GIFPauseKey
  devkit._GIFFrameTime = _GIFFrameTime
  devkit._LIKOScale = _LIKOScale
  devkit._FontChars = _FontChars
  devkit._FontPath = _FontPath
  devkit._FontExtraSpacing = _FontExtraSpacing
  devkit._ColorSet = _ColorSet
  devkit._ClearOnRender = _ClearOnRender
  devkit._ScreenCanvas = _ScreenCanvas
  devkit._GIFCanvas = _GIFCanvas
  devkit._Font = _Font
  devkit.ofs = ofs
  devkit._HostToLiko = _HostToLiko
  devkit._GetColor = _GetColor
  devkit._GetColorID = _GetColorID
  devkit.exe = exe
  devkit._GIF = _GIF
  devkit.ColorStack = ColorStack
  devkit.TERM_W = TERM_W
  devkit.TERM_H = TERM_H
  devkit._CursorsCache = _CursorsCache
  
  return GPU, devkit --Return the table containing all of the api functions.
end
