--local os_config = {hostname="advOS",netname="default",user="user",logbuffer="10",log="false"}
function error(errordata)
 syscall.execute("stdout_write","error: "..errordata)
end
--syscall init
syscall = {}
local syscalls = {}
function syscall.register(name, callback)
 syscalls[name] = callback
end
function syscall.execute(name, ...)
 local call = syscalls[name]
 if call then
  return call(...)
 else
  error("syscall failed: "..tostring(name))
 end
 coroutine.yield()
end
--event syscalls, very important
local eventStack = {}
local listeners = {}
syscall.register("event_listen", function(evtype,callback)
 if listeners[evtype] ~= nil then
  table.insert(listeners[evtype],callback)
  return #listeners
 else
  listeners[evtype] = {callback}
  return 1
 end
end)
syscall.register("event_ignore", function(evtype,id)
 table.remove(listeners[evtype],id)
end)
syscall.register("event_pull", function(filter)
 if not filter then return table.remove(eventStack,1)
 else
  for _,v in pairs(eventStack) do
   if v == filter then
    return v
   end
  end
  repeat
   t=table.pack(computer.pullSignal())
   evtype = table.remove(t,1)
   if listeners[evtype] ~= nil then
    for k,v in pairs(listeners[evtype]) do
     local evt,rasin = pcall(v,evtype,table.unpack(t))
     if not evt then
      syscall.execute("stdout_write","Event listener failed: "..tostring(evtype)..":"..tostring(k)..":"..rasin)
     end
    end
   end
  until evtype == filter
  return evtype, table.unpack(t)
 end
end)
--screen init
local gpu, screen = component.list("gpu")(), component.list("screen")()
local w, h
if gpu and screen then
 component.invoke(gpu, "bind", screen)
 w, h = component.invoke(gpu, "getResolution")
 component.invoke(gpu, "setResolution", w, h)
 component.invoke(gpu, "setBackground", 0x000000)
 component.invoke(gpu, "setForeground", 0xFFFFFF)
 component.invoke(gpu, "fill", 1, 1, w, h, " ")
end
y = h
x = 1
--syscall term stuff
syscall.register("stdio_clear",function() local y = 1 component.invoke(gpu, "fill", 1, 1, w, h, " ") end)
syscall.register("stdout_write",function(msg) --register syscall for output
 local mx, my = component.invoke(gpu, "getResolution")
 msg = tostring(msg)
 if msg:len() < mx then
  if gpu and screen then
   component.invoke(gpu, "set", x, y, msg)
    if y == h then
     component.invoke(gpu, "copy", 1, 2, w, h - 1, 0, -1)
     component.invoke(gpu, "fill", 1, h, w, 1, " ")
    else
     y = y + 1
    end
   end
--  syscall.execute("log","[stdout] ["..syscall.execute("network_get_user").."] "..msg)
 else
  repeat
   syscall.execute("stdout_write",msg:sub(1,mx-1))
   msg = msg:sub(mx-1)
  until msg == "" or msg == nil
 end
end)
syscall.register('stdin_read', function(prefix,rc)
 if prefix == nil then prefix = "" end
 local sx, sy = x, y
 local s = ""
 local gpu = component.proxy(component.list("gpu")())
 local mx, my = gpu.getResolution()
 local function rerender()
  local blanks = ""
  for i = sx+1,mx do
   blanks = blanks.." "
  end
  gpu.set(sx,sy,blanks)
  if rc == nil then
   gpu.set(sx,sy,prefix.."> "..s.."_")
  else
   local rs = ""
   if s:len() > 0 then
    for i = 1,s:len() do
     rs = rs..rc
    end
   end
   gpu.set(sx,sy,prefix.."> "..rs.."_")
  end
 end
 rerender()
 repeat
  evtype, _, keya, keyb = syscall.execute("event_pull","key_down")
   if evtype == "key_down" then
    if keya > 31 then
     s=s..string.char(keya)
    elseif keya == 8 and keyb == 14 then
     s=s:sub(1,s:len()-1)
    end
   rerender()
  end
 until evtype == "key_down" and keya == 13 and keyb == 28
 if rc == nil then
  gpu.set(sx,sy,prefix.."> "..s.." ")
 else
  gpu.set(sx,sy,prefix.."> "..rc:rep(s:len()).." ")
 end
 if y == my then
  gpu.copy(1, 2, mx, my - 1, 0, -1)
  gpu.fill(1, my, mx, 1, " ")
 else
  y = y + 1
 end
 if rc == nil then
--  syscall.execute("log","[stdin] ["..syscall.execute("network_get_user").."] "..prefix.."> "..s)
 else
--  syscall.execute("log","[stdin] ["..syscall.execute("network_get_user").."] "..prefix.."> "..rc:rep(s:len()))
 end
 return s
end)
syscall.register("term_set_x", function (ix)
 x = ix
end)
syscall.register("term_set_y", function (iy)
 y = iy
end)
--system syscalls
syscall.register("loadfile",function(filename)
 f = syscall.execute("fs_open",filename)
 if not f then error("file not found: "..filename) end
 c = ""
 l = ""
 repeat
  l=f.read() or ""
  c=c..l
 until l == "" or l == nil
 f.close()
 return(load(c))
end)
syscall.register("runfile",function(filename,...)
 local success, reason = pcall(syscall.execute("loadfile",filename),...)
 if not success then syscall.execute("stdout_write",reason) end
end)
function io_executeOnDrive(index,method, ...) --executes a method on a drive
 local origDrive = syscall.execute("fs_get_drive")
 syscall.execute("fs_set_drive",index)
 local derp = table.pack(syscall.execute("fs_invoke", method, ...))
 syscall.execute("fs_set_drive",origDrive)
 return table.unpack(derp)
end
--filesystem code
local fs={}
fs.drive_map={}
fs.activeDrive="boot"
syscall.register("fs_drives",function() return fs.drive_map,fs.activeDrive end)
syscall.register("fs_mount",function(proxy,index) fs.drive_map[index]=proxy end)
syscall.register("fs_unmount",function(index) fs.drive_map[index]=nil end)
syscall.register("fs_proxy",function(index) return fs.drive_map.index end)
syscall.register("fs_invoke",function(method,...) return fs.drive_map[fs.activeDrive][method](...) end) --wtf?
syscall.register("fs_get_drive",function() return fs.activeDrive end)
syscall.register("fs_set_drive",function(index) fs.activeDrive=index end)
syscall.register("fs_get_drive_map", function() return fs.drive_map end)
syscall.register("fs_exists", function(path) drive,path = syscall.execute("fs_resolve",path) return io_executeOnDrive(drive,"exists",path) end)
syscall.register("fs_is_dir", function(path) drive,path = syscall.execute("fs_resolve",path) return io_executeOnDrive(drive,"isDirectory",path) end)
syscall.register("fs_mkdir", function(path) drive,path = syscall.execute("fs_resolve",path) return io_executeOnDrive(drive,"makeDirectory",path) end)
syscall.register("fs_list", function(path) drive,path = syscall.execute("fs_resolve",path) return io_executeOnDrive(drive,"list",path or "/") end)
syscall.register("fs_remove", function(path) drive,path = syscall.execute("fs_resolve",path) return io_executeOnDrive(drive,"remove",path) end)
syscall.register("fs_move", function(path1, path2) syscall.execute("fs_copy",path1,path2) return syscall.execute("fs_remove",path1) end)
syscall.register("fs_size", function(path) drive,path = syscall.execute("fs_resolve",path) return io_executeOnDrive(drive,"size",path) end)
syscall.register("fs_resolve",function(path)
 local path=path:gsub("\\","/")
 local sC,_ = path:find(":") or path:len()
 local sS,_ = path:find("/") or 0
 if sC < sS then
  return path:sub(1,sC-1), path:sub(sC+1,path:len())
 else
  return syscall.execute("fs_get_drive"), path
 end
end)
syscall.register("fs_open",function(path,mode)
 if not mode then mode = "r" end
 local proxyFile = {}
 local handle = 0
 local drive, path = syscall.execute("fs_resolve",path)
 local fsInUse = syscall.execute("fs_get_drive_map")[drive]
 if fsInUse == nil then return false, "drive not found" end
 if not fsInUse.exists(path) and mode:sub(1,1) == "r" then return false, "file not found" end
 handle = fsInUse.open(path,mode)
 if mode:sub(1,1) == "r" then
  function proxyFile.read(len)
   if not len then len = math.huge end
   return fsInUse.read(handle,len)
  end
 else
  function proxyFile.write(data)
   fsInUse.write(handle,data)
  end
 end
 function proxyFile.close()
  fsInUse.close(handle)
  proxyFile = nil
  fsInUse = nil
 end
 return proxyFile
end)
syscall.register("fs_copy", function(origPath, destPath)
 local sF = syscall.execute("fs_open",origPath,"r")
 local dF = syscall.execute("fs_open",destPath,"w")
 if not sF or not dF then return false, "file not found" end
 c = ""
 l = ""
 repeat
  l=sF.read() or ""
  dF.write(l)
 until l == ""
 sF.close()
 dF.close()
end)
--component code -- list, type, proxy, doc, methods
syscall.register("component_list", function(filter) return component.list(filter) end)
syscall.register("component_type", function(addr) return component.type(addr) end)
syscall.register("component_proxy", function(addr) return component.proxy(addr) end)
syscall.register("component_methods", function(addr) return component.methods(addr) end)
--computer?
syscall.register("beep",function(freq) computer.beep(freq) end) -- most important part.
syscall.register("computer_shutdown", function() computer.shutdown() end)
syscall.register("computer_reboot", function() computer.shutdown(true) end)
--derp loop
syscall.execute("fs_mount",component.proxy(computer.getBootAddress()),"boot")
syscall.execute("fs_mount",component.proxy(computer.tmpAddress()),"temp")
--log, temp stuff
--local log_buffer = {}
--syscall.register("log",function(msg)
-- if os_config.log == "true" then
--  if #log_buffer < tonumber(os_config.logbuffer) then
--   table.insert(log_buffer,"["..tostring(computer.uptime()).."] "..msg.."\n")
--  else
--   syscall.execute("log_flush")
--  end
-- end
--end)
--syscall.register("log_flush", function()
-- if os_config.log == "true" then
--  local f = syscall.execute("fs_open","boot:/micrOS.log","a")
--  local log_s = ""
--  for k,v in ipairs(log_buffer) do
--  end
--  f.write(log_s)
--  f.close()
--  log_buffer = {}
-- end
--end)
--syscall.register("config_reload", function()
-- if syscall.execute("fs_exists","boot:/micrOS.cfg") then
--  local f=syscall.execute("fs_open","boot:/micrOS.cfg")
--  local c = ""
--  local l = ""
--  repeat
--   l=f.read() or ""
--   c=c..l
--  until l == "" or l == nil
--  f.close()
--  for word in c:gmatch("[^\r\n]+") do
--   local st,ed = word:find("=")
--   os_config[word:sub(1,st-1)]=word:sub(ed+1)
--  end
-- else
--  local default_config = "hostname=micrOS\r\nnetname=default\r\nuser=user\r\nlogbuffer=10\r\nlog=false"
--  local f=syscall.execute("fs_open","boot:/micrOS.cfg","w")
--  f.write(default_config)
--  f.close()
-- end
--end)
--syscall.register("network_get_hostname",function()
-- return os_config.hostname
--end)
--syscall.register("network_get_user", function()
-- return os_config.user
--end)
function computer.shutdown(reboot)
-- syscall.execute("flushlog")
 computer.shutdown(reboot)
end
--syscall.execute("config_reload")
--syscall.execute("stdout_write",(math.floor(computer.totalMemory()/1024)).."k total, "..tostring(math.floor(computer.freeMemory()/1024)).."k free, "..tostring(math.floor((computer.totalMemory()-computer.freeMemory())/1024)).."k used")
if syscall.execute("fs_exists","postinit.lua") then
 while true do
  --os_config.user=syscall.execute("stdin_read","Username")
  syscall.execute("runfile","postinit.lua")
 end
end
syscall.execute("stdout_write","OS crashed, press enter to shut down.")
syscall.execute("stdin_read")
computer.shutdown()
