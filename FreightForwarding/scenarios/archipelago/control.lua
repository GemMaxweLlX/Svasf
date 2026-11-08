-- Archipelago: freeplay on a map of small islands, with a chain of goals that walks through Freight Forwarding.
local handler = require("event_handler")
handler.add_lib(require("archipelago"))
handler.add_lib(require("__base__/script/freeplay/freeplay"))
if script.active_mods["space-age"] then
  handler.add_lib(require("space-finish-script"))
else
  handler.add_lib(require("silo-script"))
end
