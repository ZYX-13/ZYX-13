if (...) == "-?" then
  printUsage("version","Print the current version number.")
  return
end

color(11) print("ZYX-13 V".._ZYX_Version)
if old then
  color(6) print("Updated from: V".._ZYX_Old)
end
