VERSION = "1.0.0"

local micro = import("micro")
local config = import("micro/config")
local shell = import("micro/shell")
local buffer = import("micro/buffer")
local info = import("micro/info")
local os = import("os")
local filepath = import("path/filepath")

local fileName = ""
local filePostfix = ""
local gdbJobHandle = nil
local gdbBreakpoints = {}

local gdbDebugBp = nil
local gdbStoppedOnBreakpoint = false
local gdbAskedForInfoLocals = false
local gdbInfoBuffer = {}

function error()
end

function arrayRemove(t, val)
    local j, n = 1, #t;
    for i=1,n do
        if (t[i] ~= val) then

            -- Move i's kept value to j's position, if it's not already there.
            if (i ~= j) then
                t[j] = t[i];
                t[i] = nil;
            end
            j = j + 1; -- Increment position of where we'll place the next kept value.
        else
            t[i] = nil;
        end
    end
    return t;
end

function arrayContains(table, val)
	for i = 1, #table, 1 do
		if (table[i] == val) then
			return true
		end
	end
	return false
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

function strsplitLines(str)
   local t = {}
   local function helper(line)
      table.insert(t, line)
      return ""
   end
   helper((str:gsub("(.-)\r?\n", helper)))
   return t
end

function gdbHitBreakpoint(line)
		gdbDebugBp.Buf:AddMessage(buffer.NewMessageAtLine("[gdb]", "test", line, buffer.MTError))
end

function toogleBreakpoint(bp)
	gdbDebugBp = bp
	line = gdbDebugBp.Buf:GetActiveCursor().Loc.Y + 1

	if(arrayContains(gdbBreakpoints, line )) then
		arrayRemove(gdbBreakpoints, line)
	else
		table.insert(gdbBreakpoints, line)
	end

	gdbDebugBp.Buf:ClearMessages("[gdb]")
	for i = 1, #gdbBreakpoints, 1 do
			gdbDebugBp.Buf:AddMessage(buffer.NewMessageAtLine("[gdb]", "", gdbBreakpoints[i], buffer.MTInfo))
	end
end

function onGdbStdout(outStr, args)
		local lines = strsplitLines(outStr)

		if(gdbStoppedOnBreakpoint == false) then
			for i = 1, #lines, 1 do
				--check if gdb message is a breakpoint hit
				--micro.TermMessage(lines[i])
				if(string.sub(lines[i], 1, 10) == "Breakpoint") then
					--stopped on breakpoint
					gdbStoppedOnBreakpoint = true

					--get breakpoint position
					local line = lines[i]
					local lenOfLine = string.len(line)
					local posOfSeperator = string.find(line, ":")
					local lineOfBreakpoint = tonumber(string.sub(line, posOfSeperator + 1, lenOfLine))

					local tmp = ""
					shell.JobSend(gdbJobHandle, "info locals\n")
					gdbAskedForInfoLocals = true
					for i = 1, #gdbInfoBuffer, 1 do
						tmp = tmp .. gdbInfoBuffer[i] .. "|"
					end

					--show breakpoints gutter
					gdbDebugBp.Buf:ClearMessages("[gdb]")
					for j = 1, #gdbBreakpoints, 1 do
						if(tonumber(gdbBreakpoints[j]) ~= lineOfBreakpoint) then
							gdbDebugBp.Buf:AddMessage(buffer.NewMessageAtLine("[gdb]", "", gdbBreakpoints[j], buffer.MTInfo))
						end
					end
					gdbDebugBp.Buf:AddMessage(buffer.NewMessageAtLine("[gdb]", tmp, lineOfBreakpoint, buffer.MTError))			
				end
			end
		else
			if(gdbAskedForInfoLocals == true) then
				gdbInfoBuffer = lines
				--micro.InfoBar():Message(gdbInfoBuffer)
				gdbAskedForInfoLocals = false
			end		
		end
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
	gdbDebugBp = bp

	local jobArgs = {"./" .. fileName}

	--add breakpoints to job args
	if(gdbBreakpoints) then
		for i = 1, #gdbBreakpoints, 1 do
			table.insert(jobArgs, "-ex")
			table.insert(jobArgs, "break " .. fileName .. "." .. filePostfix .. ":" .. gdbBreakpoints[i])
		end
	end
	
	gdbJobHandle = shell.JobSpawn("gdb", jobArgs, onGdbStdout, onGdbStdout, onGdbStdout, nil)
	--micro.InfoBar():Message(gdbJobHandle)
	--micro.TermMessage(gdbJobHandle)
	
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
	config.MakeCommand("toogleBreakpoint", toogleBreakpoint, config.NoComplete)
	config.TryBindKey("F3", "command-edit:compile ", true)	
	config.TryBindKey("F4", "command-edit:run ", true)	
	config.TryBindKey("F5", "command-edit:debug ", true)	
	config.TryBindKey("F6", "command-edit:gdbRun ", true)
	config.TryBindKey("F7", "command-edit:toogleBreakpoint ", true)		
end
