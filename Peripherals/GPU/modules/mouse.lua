--GPU: Mouse/Touch Input.

--luacheck: push ignore 211
local Config, GPU, yGPU, GPUVars, DevKit = ...
--luacheck: pop

local events = require("Engine.events")

local WindowVars = GPUVars.Window
local SharedVars = GPUVars.Shared

--==Varss Constants==--
local _HostToZyx = WindowVars.HostToZyx
local Verify = SharedVars.Verify

--==Local Variables==--
local CPUKit = Config.CPUKit

--==GPU Mouse API==--

--Returns the current position of the mouse.
function GPU.getMPos()
  return _HostToZyx(love.mouse.getPosition()) --Convert the mouse position
end

--Returns if the given mouse button is down
function GPU.isMDown(b)
  b = Verify(b,"Button","number")
  return love.mouse.isDown(b)
end

--==Hooks==--

--Mouse Hooks (To translate them to ZYX13 screen)--
events.register("love:mousepressed",function(x,y,b,istouch)
  x,y = _HostToZyx(x,y)
  events.trigger("GPU:mousepressed",x,y,b,istouch)
  if CPUKit then CPUKit.triggerEvent("mousepressed",x,y,b,istouch) end
end)
events.register("love:mousemoved",function(x,y,dx,dy,istouch)
  x,y = _HostToZyx(x,y)
  dx, dy = dx/WindowVars.ZYXScale, dy/WindowVars.ZYXScale
  events.trigger("GPU:mousemoved",x,y,dx,dy,istouch)
  if CPUKit then CPUKit.triggerEvent("mousemoved",x,y,dx,dy,istouch) end
end)
events.register("love:mousereleased",function(x,y,b,istouch)
  x,y = _HostToZyx(x,y)
  events.trigger("GPU:mousereleased",x,y,b,istouch)
  if CPUKit then CPUKit.triggerEvent("mousereleased",x,y,b,istouch) end
end)
events.register("love:wheelmoved",function(x,y)
  events.trigger("GPU:wheelmoved",x,y)
  if CPUKit then CPUKit.triggerEvent("wheelmoved",x,y) end
end)

--Touch Hooks (To translate them to ZYX13 screen)--
events.register("love:touchpressed",function(id,x,y,dx,dy,p)
  x,y = _HostToZyx(x,y)
  dx, dy = dx/WindowVars.ZYXScale, dy/WindowVars.ZYXScale
  events.trigger("GPU:touchpressed",id,x,y,dx,dy,p)
  if CPUKit then CPUKit.triggerEvent("touchpressed",id,x,y,dx,dy,p) end
end)
events.register("love:touchmoved",function(id,x,y,dx,dy,p)
  x,y = _HostToZyx(x,y)
  dx, dy = dx/WindowVars.ZYXScale, dy/WindowVars.ZYXScale
  events.trigger("GPU:touchmoved",id,x,y,dx,dy,p)
  if CPUKit then CPUKit.triggerEvent("touchmoved",id,x,y,dx,dy,p) end
end)
events.register("love:touchreleased",function(id,x,y,dx,dy,p)
  x,y = _HostToZyx(x,y)
  dx, dy = dx/WindowVars.ZYXScale, dy/WindowVars.ZYXScale
  events.trigger("GPU:touchreleased",id,x,y,dx,dy,p)
  if CPUKit then CPUKit.triggerEvent("touchreleased",id,x,y,dx,dy,p) end
end)