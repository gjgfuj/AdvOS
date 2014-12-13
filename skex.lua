local function print(...)
 syscall.execute("stdout_write",...)
end
local function read(pref,repchar)
 return syscall.execute("stdin_read",pref,repchar)
end
local function splitonspace(str)
 local t = {}
 for w in str:gmatch("%S+") do
  table.insert(t,w)
 end
 return t
end

local cmds = {"q - quit skex",
"o [filename] - loads a file into the buffer",
"l <start> <end> - writes the lines from <start> (default 1) to <end> (default #b) to stdout",
"lc - writes the current line to stdout",
"s [line] - seeks to a line",
"so - writes the number of the current line to stdout",
"i - inserts/appends lines, a line with only . to exit this mode",
"w [filename] - writes the buffer to [filename]",
"e - executes the code in the buffer",
"d - deletes the current line",
"r - replaces the current line",
"? / h - prints this help message"}

local run = true
local b = {}
local l = 1

while run do
 local cmdt = splitonspace(read("skex"))
 if cmdt[1] == "q" then
  run = false
 elseif cmdt[1] == "o" then
  local f = syscall.execute("fs_open",cmdt[2],"r")
  a="" repeat c=f.read() if c==nil then c="" end a=a..c until c=="" f.close() for L in a:gmatch("[^\r\n]+") do table.insert(b,l,L) l=l+1 end
 elseif cmdt[1] == "l" then
  startn,endn = cmdt[2],cmdt[3]
  if cmdt[2] == nil then
   startn=1
  end
  if cmdt[3] == nil then
   endn=#b
  end
  print("Line "..startn.." to "..endn..":")
  for i = tonumber(startn),tonumber(endn) do
   print(b[i])
  end
 elseif cmdt[1] == "lc" then
  print(b[l])
 elseif cmdt[1] == "so" then
  print("Current line: "..l)
 elseif cmdt[1] == "s" then
  l = tonumber(cmdt[2])
 elseif cmdt[1] == "i" then
  c=read("insert")
  repeat
   table.insert(b,l,c)
   l=l+1
   c=read("insert")
  until c=="."
 elseif cmdt[1] == "w" then
  f=syscall.execute("fs_open",cmdt[2],"w")
  print(f)
  for k,v in pairs(b) do
   f.write(v.."\n")
  end
  f.close()
 elseif cmdt[1] == "e" then
  cd=""
  for k,v in pairs(b) do
   cd=cd..v.."\n"
  end
  pcall(load(cd))
 elseif cmdt[1] == "d" then
  print(table.remove(b,l))
 elseif cmdt[1] == "r" then
  b[l] = read("replace")
 elseif cmdt[1] == "?" or cmdt[1]:sub(1,1) == "h" then
  print("Commands:")
  print("Arguments surrounded by []s are mandatory, arguments surrounded by <> are optional.")
  for k,v in ipairs(cmds) do
   print(v)
  end
 end
end
