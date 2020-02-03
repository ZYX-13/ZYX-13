--GPU: Window and canvas creation.

--luacheck: push ignore 211
local Config, GPU, yGPU, GPUVars, DevKit = ...
--luacheck: pop

local events = require("Engine.events")

local RenderVars = GPUVars.Render
local WindowVars = GPUVars.Window

--==Localized Lua Library==--

local mathFloor = math.floor

--==Local Variables==--

local CPUKit = Config.CPUKit

local _Mobile = love.system.getOS() == "Android" or love.system.getOS() == "iOS" or Config._Mobile

local _ZYX_W, _ZYX_H = Config._ZYX_W or 192, Config._ZYX_H or 128 --ZYX-13 screen dimensions.
WindowVars.ZYX_X, WindowVars.ZYX_Y = 0,0 --ZYX-13 screen padding in the HOST screen.

local _PixelPerfect = Config._PixelPerfect --If the ZYX-13 screen must be scaled pixel perfect.
WindowVars.ZYXScale = mathFloor(Config._ZYXScale or 3) --The ZYX13 screen scale to the host screen scale.

WindowVars.Width, WindowVars.Height = _ZYX_W*WindowVars.ZYXScale, _ZYX_H*WindowVars.ZYXScale --The host window size.
if _Mobile then WindowVars.Width, WindowVars.Height = 0,0 end

--==Window creation==--

if not love.window.isOpen() then
  love.window.setMode(WindowVars.Width,WindowVars.Height,{
    vsync = 1,
    resizable = true,
    minwidth = _ZYX_W,
    minheight = _ZYX_H
  })
  
  if Config.title then
    love.window.setTitle(Config.title)
  else
    love.window.setTitle("ZYX-13 ".._ZVERSION)
  end
  love.window.setIcon(love.image.newImageData("icon.png"))
end

--Incase if the host operating system decided to give us different window dimensions.
WindowVars.Width, WindowVars.Height = love.graphics.getDimensions()

--==Window termination==--

events.register("love:quit", function()
  if love.window.isOpen() then
    love.graphics.setCanvas()
    love.window.close()
  end
  return false
end)

--==Window Events==--

--Hook the resize function
events.register("love:resize",function(w,h) --Do some calculations
  WindowVars.Width, WindowVars.Height = w, h
  local TSX, TSY = w/_ZYX_W, h/_ZYX_H --TestScaleX, TestScaleY
  
  WindowVars.ZYXScale = (TSX < TSY) and TSX or TSY
  if _PixelPerfect then WindowVars.ZYXScale = mathFloor(WindowVars.ZYXScale) end
  
  WindowVars.ZYX_X, WindowVars.ZYX_Y = (WindowVars.Width-_ZYX_W*WindowVars.ZYXScale)/2, (WindowVars.Height-_ZYX_H*WindowVars.ZYXScale)/2
  if _Mobile then WindowVars.ZYX_Y, RenderVars.AlwaysDrawTimer = 0, 1 end
  
  RenderVars.ShouldDraw = true
end)

--Hook to some functions to redraw (when the window is moved, got focus, etc ...)
events.register("love:focus",function(f) if f then RenderVars.ShouldDraw = true end end) --Window got focus.
events.register("love:visible",function(v) if v then RenderVars.ShouldDraw = true end end) --Window got visible.

--File drop hook
events.register("love:filedropped", function(file)
  file:open("r")
  local data = file:read()
  file:close()
  if CPUKit then CPUKit.triggerEvent("filedropped",file:getFilename(),data) end
end)

--Alt-Return (Fullscreen toggle) hook
local raltDown, lastWidth, lastHeight = false, 0, 0

events.register("love:keypressed", function(key, scancode,isrepeat)
  if key == "ralt" then
    raltDown = true --Had to use a workaround, for some reason isDown("ralt") is not working at Rami's laptop
  elseif key == "return" and raltDown and not isrepeat then
    local screenshot = GPU.screenshot():image()

    local canvas = love.graphics.getCanvas() --Backup the canvas.
    love.graphics.setCanvas() --Deactivate the canvas.

    if love.window.getFullscreen() then --Go windowed
      love.window.setMode(lastWidth,lastHeight,{
        fullscreen = false,
        vsync = 1,
        resizable = true,
        minwidth = _ZYX_W,
        minheight = _ZYX_H
      })
    else --Go fullscreen
      lastWidth, lastHeight = love.window.getMode()
      love.window.setMode(0,0,{fullscreen=true})
    end

    events.trigger("love:resize", love.graphics.getDimensions()) --Make sure the canvas is scaled correctly
    love.graphics.setCanvas{canvas,stencil=true} --Reactivate the canvas.

    screenshot:draw() --Restore the backed up screenshot
  end
end)

events.register("love:keyreleased", function(key, scancode)
  if key == "ralt" then raltDown = false end
end)

--==Graphics Initializations==--
love.graphics.clear(0,0,0,1) --Clear the host screen.

events.trigger("love:resize", WindowVars.Width, WindowVars.Height) --Calculate ZYX13 scale to the host window for the first time.

--==GPU Window API==--
function GPU.screenSize() return _ZYX_W, _ZYX_H end
function GPU.screenWidth() return _ZYX_W end
function GPU.screenHeight() return _ZYX_H end

--==Helper functions for WindowVars==--
function WindowVars.HostToZyx(x,y) --Convert a position from HOST screen to ZYX13 screen.
  return mathFloor((x - WindowVars.ZYX_X)/WindowVars.ZYXScale), mathFloor((y - WindowVars.ZYX_Y)/WindowVars.ZYXScale)
end

function WindowVars.ZyxToHost(x,y) --Convert a position from ZYX13 screen to HOST
  return mathFloor(x*WindowVars.ZYXScale + WindowVars.ZYX_X), mathFloor(y*WindowVars.ZYXScale + WindowVars.ZYX_Y)
end

--==GPUVars Exports==--
WindowVars.ZYX_W, WindowVars.ZYX_H = _ZYX_W, _ZYX_H

--==DevKit Exports==--
DevKit._ZYX_W = _ZYX_W
DevKit._ZYX_H = _ZYX_H
function DevKit.DevKitDraw(bool)
  RenderVars.DevKitDraw = bool
end