local name = "AdvOS"
local version = "0.1"

local function p(d) syscall.execute("stdout_write",d) end
p("Initializing AdvOS.")
p("Reading config file.")
config = syscall.execute("loadfile", "boot:/advconfig.lua")()
syscall.register("advos_get_config", function() return config end)
syscall.register("network_get_user", function() return config.user end)
if config.systype == "simple" then
  syscall.execute("runfile", "boot:/simple.lua")
else
  syscall.execute("runfile", "boot:/shell.lua")
end
