VERSION = "1.0.0"

local micro = import("micro")
local config = import("micro/config")
local shell = import("micro/shell")
local buffer = import("micro/buffer")
local os = import("os")
local filepath = import("path/filepath")

local fileName = ""
local filePostfix = ""
local gdbJobHandle = nil

function error()
end

function onGdbStdout(outStr, args)
		micro.TermMessage("[gdb] stdout: " .. outStr)
end

function onGdbStdError(errorStr, args)
		micro.TermMessage("[gdb] error: " .. errorStr)
end

function onGdbExit(exitStr, args)
		micro.TermMessage("[gdb] exited: " .. exitStr)
end

function gdbRun()
	shell.JobSend(gdbJobHandle, "run\n")
end

function strsplit (inputstr, sep)
   if sep == nil then
      sep = "%s"
   end
   local t={}
   for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
      table.insert(t, str)
   end
   return t
end


function compile(bp)

	ret = shell.ExecCommand("gcc", "-g", fileName .. "." .. filePostfix, "-o", fileName)
	if (ret == '') then
		micro.InfoBar():Message("compile success")
	else
		micro.InfoBar():Message("compile error: " .. ret)
	end
end

function run(bp)

	ret = shell.RunTermEmulator(bp, "./" .. fileName, true, false, nil, nil)

	if(ret) then 
		micro.InfoBar():Message(ret)	
	end

end

function debug(bp)

	--ret = shell.RunTermEmulator(newBuffer, "gdb " .. "./" .. fileName, true, false, nil, nil)

	local jobArgs = {"./" .. fileName, "-ex", "break main"}
	gdbJobHandle = shell.JobSpawn("gdb", jobArgs, onGdbStdout, onGdbStdout, onGdbStdout, nil)
	micro.InfoBar():Message(gdbJobHandle)
	if(ret) then 
		micro.InfoBar():Message(ret)	
	end
	
end

function init()

	--t = strsplit(micro.CurPane().Buf.Path, ".")
	--micro.InfoBar():Message(t)
	
	fileName = strsplit(micro.CurPane().Buf.Path, ".")[1]
	filePostfix = strsplit(micro.CurPane().Buf.Path, ".")[2]

	config.MakeCommand("compile", compile, config.NoComplete)
	config.MakeCommand("run", run, config.NoComplete)
	config.MakeCommand("debug", debug, config.NoComplete)
	config.MakeCommand("gdbRun", gdbRun, config.NoComplete)
	config.TryBindKey("F3", "command-edit:compile ", true)	
	config.TryBindKey("F4", "command-edit:run ", true)	
	config.TryBindKey("F5", "command-edit:debug ", true)	
	config.TryBindKey("F6", "command-edit:gdbRun ", true)	
end
