local name = "AdvOS"
local version = "0.1"

local function p(d) syscall.execute("stdout_write",d) end
p("Initializing AdvOS.")
p("Reading config file.")
config = syscall.execute("loadfile", "boot:/advconfig.lua")()
if config.systype == "simple":
  syscall.execute("runfile", "boot:/simple.lua")
else:
  syscall.execute("runfile", "boot:/shell.lua")
