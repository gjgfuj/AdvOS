local name = "MCI"
local version = 0.2

local function p(d) syscall.execute("stdout_write",d) end
local currentDir = ""
local envVars = {editor = "boot:/skex.lua"}
syscall.register("shell_get_current_dir", function() return currentDir end)
syscall.register("shell_set_current_dir", function(newDir) currentDir = newDir end)
syscall.register("shell_get_env_var", function(index) return envVars[index] end)
syscall.register("shell_set_env_var", function(index, value) envVars[index] = value end)

local cmds = {"Commands:",
"run [file] - runs a file",
"mkdir [directory] - creates a directory",
"rm [file] - removes a file/directory",
"pwd - prints the working directory",
"chdir/cd [directory] - changes the working directory",
"drives - lists avalible drives",
"setdrive [mountstr] - sets the drive",
"copy/cp [source] [destination] - copies a file from source to destination",
"move/mv [source] [destination] - moves a file from source to destination",
"edit - runs the editor defined by the envar",
"mount - drive mounting config",
"flushlog - flushes the system log to disk, only if logging is enabled",
"?/h - displays this help dialog"}
local run=true
while run do
 if syscall.execute("shell_get_current_dir") == "/" then syscall.execute("shell_set_current_dir","") end
 local input = syscall.execute("stdin_read",syscall.execute("network_get_user").."@"..syscall.execute("network_get_hostname").." "..syscall.execute("fs_get_drive")..":"..syscall.execute("shell_get_current_dir"))
 local args = {}
 for word in input:gmatch("([^%s]+)") do table.insert(args, word) end
 local input = table.remove(args,1)
 if input == "run" then
  syscall.execute("runfile",currentDir..args[1])
 elseif input == "dir" or input == "list" then
  local dirTable = syscall.execute("fs_list",currentDir)
  for k,v in pairs(dirTable) do
   if syscall.execute("fs_exists",currentDir..v) then p(tostring(v).." : "..syscall.execute("fs_size",currentDir..v))
   else count = v
   end
  end
  syscall.execute("stdout_write","Count: "..count)
 elseif input == "mkdir" then
  syscall.execute("fs_mkdir",currentDir..args[1])
 elseif input == "rm" then
  syscall.execute("fs_remove",currentDir..args[1])
 elseif input == "pwd" then
  p(syscall.execute("fs_get_drive")..":"..currentDir)
 elseif input == "chdir" or input == "cd" then
  if syscall.execute("fs_exists",currentDir..args[1]) and syscall.execute("fs_is_dir",currentDir..args[1]) then
   if args[1] == "/" then
    syscall.execute("shell_set_current_dir","")
   else
    syscall.execute("shell_set_current_dir",currentDir..args[1].."/")
   end
  else
   p("Not found or not a directory")
  end
 elseif input == "drives" then
  for k,v in pairs(syscall.execute("fs_get_drive_map")) do
   p(k..":"..v.address)
  end
 elseif input == "setdrive" then
  syscall.execute("fs_set_drive",args[1])
  currentDir = ""
 elseif input == "copy" or input == "cp" then
  syscall.execute("fs_copy",args[1],args[2])
 elseif input == "move" or input == "mv" then
  syscall.execute("fs_move",args[1],args[2])
 elseif input == "edit" then
  syscall.execute("runfile",syscall.execute("shell_get_env_var","editor"))
 elseif input == "mount" then
  local list = component.list("filesystem")
  local fslist = {}
  for k,v in pairs(list) do
   table.insert(fslist,k)
  end
  for k,v in pairs(fslist) do
   syscall.execute("stdout_write",k..": "..v)
  end
  syscall.execute("stdout_write","Drive to mount? (1 .. "..#fslist..")")
  repeat
   local dtm = tonumber(syscall.execute("stdin_read"))
   syscall.execute("stdout_write",dtm.." "..type(dtm))
  until dtm ~= nil
  local mountaddr = table.remove(fslist,dtm)
  local mountAs = syscall.execute("stdin_read","Mount as")
  syscall.execute("fs_mount",component.proxy(mountaddr),mountAs)
 elseif input == "unmount" or input == "umount" then
  syscall.execute("fs_unmount",args[1])
 elseif input == "flushlog" then
  syscall.execute("log_flush")
 elseif input == "?" or input == "h" then
  for k,v in pairs(cmds) do
   p(v)
  end
 elseif input == "exit" then
  run = false
 end
end
