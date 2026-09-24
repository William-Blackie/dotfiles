local keyguide = require("keyguide")
require("hs.ipc")

hs.autoLaunch(true)
hs.dockIcon(false)

hs.urlevent.bind("keyguide", function(_, params)
  keyguide.show(params.scope or "all")
end)

local menu = hs.menubar.new()
if menu then
  menu:setTitle("⌨")
  menu:setTooltip("Key guide")
  menu:setClickCallback(function()
    keyguide.show("all")
  end)
end
