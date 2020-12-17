-- Generated from ntangle-lsp.lua.tl using ntangle.nvim
require("ntangle-lsp.linkedlist")

local sections = {}
local curSection = nil

local LineType = {
	SECTION = 3,
	
	REFERENCE = 1,
	
	TEXT = 2,
	
}

local lineRefs = {}

local nagivationLines = {}

events = {}

local document_lookup = {}

local buffer_lookup = {} -- reverse lookup of document_lookup

local active_clients = {}

local outputSections

local getlinenum

local toluapat

local collectLines

local buf_request

local function tangle(filename)
	sections = {}
	curSection = nil
	
	lineRefs = {}
	
	buffer_lookup = {}
	
	if filename then
		lnum = 1
		for line in io.lines(filename) do
			if string.match(line, "^%s*@@") then
				local hasSection = false
				if sections[name] then
					hasSection = true
				end
				
				if hasSection then
					local _,_,pre,post = string.find(line, '^(.*)@@(.*)$')
					local text = pre .. "@" .. post
					local l = { 
						linetype = LineType.TEXT, 
						str = text 
					}
					
					l.lnum = lnum
					
					linkedlist.push_back(curSection.lines, l)
					
				end
			
			elseif string.match(line, "^@[^@]%S*[+-]?=%s*$") then
				local _, _, name, op = string.find(line, "^@(%S-)([+-]?=)%s*$")
				
				local section = { linetype = LineType.SECTION, str = name, lines = {}}
				
				if op == '+=' or op == '-=' then
					if sections[name] then
						if op == '+=' then
							linkedlist.push_back(sections[name].list, section)
							
						elseif op == '-=' then
							linkedlist.push_front(sections[name].list, section)
							
						end
					else
						sections[name] = { root = false, list = {} }
						
						linkedlist.push_back(sections[name].list, section)
						
					end
				
				else 
					sections[name] = { root = true, list = {} }
					
					linkedlist.push_back(sections[name].list, section)
					
				end
				
				curSection = section
				
			
			elseif string.match(line, "^%s*@[^@]%S*%s*$") then
				local _, _, prefix, name = string.find(line, "^(%s*)@(%S+)%s*$")
				if name == nil then
					print(line)
				end
				
				-- @check_that_sections_is_not_empty
				local l = { 
					linetype = LineType.REFERENCE, 
					str = name,
					prefix = prefix
				}
				
				l.lnum = lnum
				
				linkedlist.push_back(curSection.lines, l)
				
			
			else
				if sections[name] then
					hasSection = true
				end
				
				local l = { 
					linetype = LineType.TEXT, 
					str = line 
				}
				
				l.lnum = lnum
				
				linkedlist.push_back(curSection.lines, l)
				
			end
			
			lnum = lnum+1;
		end
		
	else
		local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
		
		lnum = 1
		for _,line in ipairs(lines) do
			if string.match(line, "^%s*@@") then
				local hasSection = false
				if sections[name] then
					hasSection = true
				end
				
				if hasSection then
					local _,_,pre,post = string.find(line, '^(.*)@@(.*)$')
					local text = pre .. "@" .. post
					local l = { 
						linetype = LineType.TEXT, 
						str = text 
					}
					
					l.lnum = lnum
					
					linkedlist.push_back(curSection.lines, l)
					
				end
			
			elseif string.match(line, "^@[^@]%S*[+-]?=%s*$") then
				local _, _, name, op = string.find(line, "^@(%S-)([+-]?=)%s*$")
				
				local section = { linetype = LineType.SECTION, str = name, lines = {}}
				
				if op == '+=' or op == '-=' then
					if sections[name] then
						if op == '+=' then
							linkedlist.push_back(sections[name].list, section)
							
						elseif op == '-=' then
							linkedlist.push_front(sections[name].list, section)
							
						end
					else
						sections[name] = { root = false, list = {} }
						
						linkedlist.push_back(sections[name].list, section)
						
					end
				
				else 
					sections[name] = { root = true, list = {} }
					
					linkedlist.push_back(sections[name].list, section)
					
				end
				
				curSection = section
				
			
			elseif string.match(line, "^%s*@[^@]%S*%s*$") then
				local _, _, prefix, name = string.find(line, "^(%s*)@(%S+)%s*$")
				if name == nil then
					print(line)
				end
				
				-- @check_that_sections_is_not_empty
				local l = { 
					linetype = LineType.REFERENCE, 
					str = name,
					prefix = prefix
				}
				
				l.lnum = lnum
				
				linkedlist.push_back(curSection.lines, l)
				
			
			else
				if sections[name] then
					hasSection = true
				end
				
				local l = { 
					linetype = LineType.TEXT, 
					str = line 
				}
				
				l.lnum = lnum
				
				linkedlist.push_back(curSection.lines, l)
				
			end
			
			lineRefs[lnum] = curSection.str
			
			lnum = lnum+1;
		end
		
	end
	if not filename then
		filename = vim.api.nvim_call_function("expand", { "%:p"})
	end
	local parendir = vim.api.nvim_call_function("fnamemodify", { filename, ":p:h" })
	for name, section in pairs(sections) do
		if section.root then
			local fn
			if name == "*" then
				local tail = vim.api.nvim_call_function("fnamemodify", { filename, ":t:r" })
				fn = parendir .. "/tangle/" .. tail
			
			else
				if string.find(name, "/") then
					fn = parendir .. "/" .. name
				
				else 
					fn = parendir .. "/tangle/" .. name
				end
				
			end
			
			lines = {}
			if string.match(fn, "lua$") then
				local relname
				if filename then
					relname = filename
				else
					relname = vim.api.nvim_buf_get_name(0)
				end
				relname = vim.api.nvim_call_function("fnamemodify", { relname, ":t" })
				table.insert(lines, "-- Generated from " .. relname .. " using ntangle.nvim")
			end
			
			if string.match(fn, "vim$") then
				local relname
				if filename then
					relname = filename
				else
					relname = vim.api.nvim_buf_get_name(0)
				end
				relname = vim.api.nvim_call_function("fnamemodify", { relname, ":t" })
				table.insert(lines, "\" Generated from " .. relname .. " using ntangle.nvim")
			end
			
			outputSections(lines, file, name, "")
			local modified = false
			do
				local f = io.open(fn, "r")
				if f then 
					modified = false
					local lnum = 1
					for line in f:lines() do
						if lnum > #lines then
							modified = true
							break
						end
						if line ~= lines[lnum] then
							modified = true
							break
						end
						lnum = lnum + 1
					end
					
					if lnum-1 ~= #lines then
						modified = true
					end
					
					f:close()
				else
					modified = true
				end
			end
			
			if modified then
				local f = io.open(fn, "w")
				if f then
					for _,line in ipairs(lines) do
						f:write(line .. "\n")
					end
					f:close()
				else
					print("Could not write to " .. fn)
				end
			end
			
		end
	end
	
end

function outputSections(lines, file, name, prefix, refs)
	if not sections[name] then
		return
	end
	
	for section in linkedlist.iter(sections[name].list) do
		for line in linkedlist.iter(section.lines) do
			if line.linetype == LineType.TEXT then
				lines[#lines+1] = prefix .. line.str
				refs[#refs+1] = { string.len(prefix), line.lnum }
				
				-- Note: actually there can be multiple source location 
				-- which map to target different location. In the future
				-- there would need
				buffer_lookup[line.lnum] = buffer_lookup[line.lnum] or {}
				table.insert(buffer_lookup[line.lnum], { string.len(prefix), refs, #refs }) -- only saves refs table reference
				
			end
			
			if line.linetype == LineType.REFERENCE then
				outputSections(lines, file, line.str, prefix .. line.prefix, refs)
			end
			
		end
	end
end

local function goto(filename, linenum, root_pattern)
	sections = {}
	curSection = nil
	
	lineRefs = {}
	
	buffer_lookup = {}
	
	lnum = 1
	for line in io.lines(filename) do
		if string.match(line, "^%s*@@") then
			local hasSection = false
			if sections[name] then
				hasSection = true
			end
			
			if hasSection then
				local _,_,pre,post = string.find(line, '^(.*)@@(.*)$')
				local text = pre .. "@" .. post
				local l = { 
					linetype = LineType.TEXT, 
					str = text 
				}
				
				l.lnum = lnum
				
				linkedlist.push_back(curSection.lines, l)
				
			end
		
		elseif string.match(line, "^@[^@]%S*[+-]?=%s*$") then
			local _, _, name, op = string.find(line, "^@(%S-)([+-]?=)%s*$")
			
			local section = { linetype = LineType.SECTION, str = name, lines = {}}
			
			if op == '+=' or op == '-=' then
				if sections[name] then
					if op == '+=' then
						linkedlist.push_back(sections[name].list, section)
						
					elseif op == '-=' then
						linkedlist.push_front(sections[name].list, section)
						
					end
				else
					sections[name] = { root = false, list = {} }
					
					linkedlist.push_back(sections[name].list, section)
					
				end
			
			else 
				sections[name] = { root = true, list = {} }
				
				linkedlist.push_back(sections[name].list, section)
				
			end
			
			curSection = section
			
		
		elseif string.match(line, "^%s*@[^@]%S*%s*$") then
			local _, _, prefix, name = string.find(line, "^(%s*)@(%S+)%s*$")
			if name == nil then
				print(line)
			end
			
			-- @check_that_sections_is_not_empty
			local l = { 
				linetype = LineType.REFERENCE, 
				str = name,
				prefix = prefix
			}
			
			l.lnum = lnum
			
			linkedlist.push_back(curSection.lines, l)
			
		
		else
			if sections[name] then
				hasSection = true
			end
			
			local l = { 
				linetype = LineType.TEXT, 
				str = line 
			}
			
			l.lnum = lnum
			
			linkedlist.push_back(curSection.lines, l)
			
		end
		
		lnum = lnum+1;
	end
	
	local root
	if root_pattern ~= "*" then
		for name,section in pairs(sections) do
			if section.root and string.find(name, toluapat(root_pattern)) then
				root = name
				break
			end
		end
	
		if not root then
			print("Could not root section " .. root_pattern .. " " .. toluapat(root_pattern))
		end
	else
		root = root_pattern
	end
	
	local startline = 1
	local fn = root
	if root == "*" then
		fn = vim.api.nvim_call_function("fnamemodify", { filename, ":t:r" })
	end
	
	if string.match(fn, "lua$") then
		startline = startline + 1
	end
	
	if string.match(fn, "vim$") then
		startline = startline + 1
	end
	
	local _,lnum = getlinenum(root, startline, linenum)
	assert(lnum, "Could not go to line " .. linenum .. " in " .. root)
	
	vim.api.nvim_command("normal " .. lnum .. "gg")
	
end

function getlinenum(name, cur, goal)
	if not sections[name] then
		return cur, nil
	end
	
	for section in linkedlist.iter(sections[name].list) do
		for line in linkedlist.iter(section.lines) do
			if line.linetype == LineType.TEXT then
				if cur == goal then 
					return cur, line.lnum 
				end
				cur = cur + 1
			end
			
			if line.linetype == LineType.REFERENCE then
				local found
				cur, found = getlinenum(line.str, cur, goal)
				if found then 
					return cur, found 
				end
			end
			
		end
	end
	return cur, nil
end

function toluapat(pat)
	local luapat = ""
	for i=1,#pat do
		local c = string.sub(pat, i, i)

		if c == '*' then luapat = luapat .. "."
		elseif c == '.' then luapat = luapat .. "%."
		else luapat = luapat .. c end
	end
	return luapat
end

local function collectSection()
	sections = {}
	curSection = nil
	
	lineRefs = {}
	
	buffer_lookup = {}
	
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
	
	local curnum = vim.api.nvim_call_function("line", {"."})
	local name = lineRefs[curnum]
	
	local lines = {}
	local fn = name
	if name == "*" then
		local filename = vim.api.nvim_buf_get_name(0)
		fn = vim.api.nvim_call_function("fnamemodify", { filename, ":t:r" })
	end
	
	if string.match(fn, "lua$") then
		table.insert(lines, {1, "-- Generated from {relname} using ntangle.nvim"})
	end
	
	if string.match(fn, "vim$") then
		table.insert(lines, {1, "\" Generated from {relname} using ntangle.nvim"})
	end
	
	local jumpline = collectLines(name, lines, "", curnum)
	
	local originbuf = vim.api.nvim_call_function("bufnr", {})
	local curcol = vim.api.nvim_call_function("col", {"."})
	

	local transpose_buf = vim.api.nvim_create_buf(false, true)
	local old_ft = vim.api.nvim_buf_get_option(0, "ft")
	if old_ft then
		vim.api.nvim_buf_set_option(transpose_buf, "ft", old_ft)
	end
	-- vim.api.nvim_buf_set_name(transpose_buf, "transpose")
	
	vim.api.nvim_buf_set_keymap(transpose_buf, 'n', '<leader>i', '<cmd>lua navigateTo()<CR>', {noremap = true})
	
	vim.api.nvim_set_current_buf(transpose_buf)
	
	vim.api.nvim_command("normal ggdG")
	
	local lnumtr = 0
	for _,line in ipairs(lines) do
		local lnum, text = unpack(line)
		vim.api.nvim_buf_set_lines(transpose_buf, lnumtr, lnumtr, false, { text })
		lnumtr = lnumtr + 1
	end
	
	vim.api.nvim_command("normal Gddgg")
	
	navigationLines = {}
	for _,line in ipairs(lines) do 
		local lnum, _ = unpack(line)
		navigationLines[#navigationLines+1] = { buf = originbuf, lnum = lnum }
	end
	
	if jumpline then
		vim.api.nvim_call_function("cursor", { jumpline, curcol-1 })
	end
	
end

function collectLines(name, lines, prefix, curnum)
	local jumpline
	local s
	for n, section in pairs(sections) do
		if n == name then
			s = section
			break
		end
	end
	if not s then return end
	
	for section in linkedlist.iter(s.list) do
		for line in linkedlist.iter(section.lines) do
			if line.lnum == curnum then jumpline = #lines+1 end
	
			if line.linetype == LineType.TEXT then table.insert(lines, { line.lnum, prefix .. line.str })
			elseif line.linetype == LineType.REFERENCE then 
				jumpline = collectLines(line.str, lines, prefix .. line.prefix, curnum) or jumpline
			end
		end
	end
	
	return jumpline
end

local function getRootFilename()
	local filename = vim.api.nvim_call_function("expand", { "%:p"})
	local parendir = vim.api.nvim_call_function("fnamemodify", { filename, ":p:h" })

	local line = vim.api.nvim_buf_get_lines(0, 0, 1, true)[1]
	
	local _, _, name, op = string.find(line, "^@(%S-)([+-]?=)%s*$")
	

	local fn
	if name == "*" then
		local tail = vim.api.nvim_call_function("fnamemodify", { filename, ":t:r" })
		fn = parendir .. "/tangle/" .. tail
	
	else
		if string.find(name, "/") then
			fn = parendir .. "/" .. name
		
		else 
			fn = parendir .. "/tangle/" .. name
		end
		
	end
	
	return fn
end

local function attach_to_buf(buf, client_id, language_id)
	local client = vim.lsp.get_client_by_id(client_id)
	assert(client, "Could not find client_id")
	
	vim.api.nvim_buf_attach(buf, true, {
		on_lines = function(_, buf, changedtick, firstline, lastline, new_lastline, old_byte_size)
			local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)
			
			sections = {}
			curSection = nil
			
			lineRefs = {}
			
			buffer_lookup = {}
			
			lnum = 1
			for _,line in ipairs(lines) do
				if string.match(line, "^%s*@@") then
					local hasSection = false
					if sections[name] then
						hasSection = true
					end
					
					if hasSection then
						local _,_,pre,post = string.find(line, '^(.*)@@(.*)$')
						local text = pre .. "@" .. post
						local l = { 
							linetype = LineType.TEXT, 
							str = text 
						}
						
						l.lnum = lnum
						
						linkedlist.push_back(curSection.lines, l)
						
					end
				
				elseif string.match(line, "^@[^@]%S*[+-]?=%s*$") then
					local _, _, name, op = string.find(line, "^@(%S-)([+-]?=)%s*$")
					
					local section = { linetype = LineType.SECTION, str = name, lines = {}}
					
					if op == '+=' or op == '-=' then
						if sections[name] then
							if op == '+=' then
								linkedlist.push_back(sections[name].list, section)
								
							elseif op == '-=' then
								linkedlist.push_front(sections[name].list, section)
								
							end
						else
							sections[name] = { root = false, list = {} }
							
							linkedlist.push_back(sections[name].list, section)
							
						end
					
					else 
						sections[name] = { root = true, list = {} }
						
						linkedlist.push_back(sections[name].list, section)
						
					end
					
					curSection = section
					
				
				elseif string.match(line, "^%s*@[^@]%S*%s*$") then
					local _, _, prefix, name = string.find(line, "^(%s*)@(%S+)%s*$")
					if name == nil then
						print(line)
					end
					
					-- @check_that_sections_is_not_empty
					local l = { 
						linetype = LineType.REFERENCE, 
						str = name,
						prefix = prefix
					}
					
					l.lnum = lnum
					
					linkedlist.push_back(curSection.lines, l)
					
				
				else
					if sections[name] then
						hasSection = true
					end
					
					local l = { 
						linetype = LineType.TEXT, 
						str = line 
					}
					
					l.lnum = lnum
					
					linkedlist.push_back(curSection.lines, l)
					
				end
				
				lineRefs[lnum] = curSection.str
				
				lnum = lnum+1;
			end
			
			if not filename then
				filename = vim.api.nvim_buf_get_name(buf)
			end
			local parendir = vim.api.nvim_call_function("fnamemodify", { filename, ":p:h" })
			for name, section in pairs(sections) do
				if section.root then
					local fn
					if name == "*" then
						local tail = vim.api.nvim_call_function("fnamemodify", { filename, ":t:r" })
						fn = parendir .. "/tangle/" .. tail
					
					else
						if string.find(name, "/") then
							fn = parendir .. "/" .. name
						
						else 
							fn = parendir .. "/tangle/" .. name
						end
						
					end
					
					local lines = {}
					local refs = {}
					if string.match(fn, "lua$") then
						local relname
						if filename then
							relname = filename
						else
							relname = vim.api.nvim_buf_get_name(0)
						end
						relname = vim.api.nvim_call_function("fnamemodify", { relname, ":t" })
						table.insert(lines, "-- Generated from " .. relname .. " using ntangle.nvim")
					end
					
					if string.match(fn, "vim$") then
						local relname
						if filename then
							relname = filename
						else
							relname = vim.api.nvim_buf_get_name(0)
						end
						relname = vim.api.nvim_call_function("fnamemodify", { relname, ":t" })
						table.insert(lines, "\" Generated from " .. relname .. " using ntangle.nvim")
					end
					
					local uri = string.lower(vim.uri_from_fname(fn))
					
					outputSections(lines, file, name, "", refs)
					document_lookup[uri] = refs
					
					client.notify("textDocument/didChange", {
						textDocument = {
						  uri = uri;
						  version = changedtick;
						};
						contentChanges = { {
							text = table.concat(lines, "\n")
						} }
					})
					
				end
			end
			
		end
	})
	vim.schedule(function()
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)
		
		sections = {}
		curSection = nil
		
		lineRefs = {}
		
		buffer_lookup = {}
		
		lnum = 1
		for _,line in ipairs(lines) do
			if string.match(line, "^%s*@@") then
				local hasSection = false
				if sections[name] then
					hasSection = true
				end
				
				if hasSection then
					local _,_,pre,post = string.find(line, '^(.*)@@(.*)$')
					local text = pre .. "@" .. post
					local l = { 
						linetype = LineType.TEXT, 
						str = text 
					}
					
					l.lnum = lnum
					
					linkedlist.push_back(curSection.lines, l)
					
				end
			
			elseif string.match(line, "^@[^@]%S*[+-]?=%s*$") then
				local _, _, name, op = string.find(line, "^@(%S-)([+-]?=)%s*$")
				
				local section = { linetype = LineType.SECTION, str = name, lines = {}}
				
				if op == '+=' or op == '-=' then
					if sections[name] then
						if op == '+=' then
							linkedlist.push_back(sections[name].list, section)
							
						elseif op == '-=' then
							linkedlist.push_front(sections[name].list, section)
							
						end
					else
						sections[name] = { root = false, list = {} }
						
						linkedlist.push_back(sections[name].list, section)
						
					end
				
				else 
					sections[name] = { root = true, list = {} }
					
					linkedlist.push_back(sections[name].list, section)
					
				end
				
				curSection = section
				
			
			elseif string.match(line, "^%s*@[^@]%S*%s*$") then
				local _, _, prefix, name = string.find(line, "^(%s*)@(%S+)%s*$")
				if name == nil then
					print(line)
				end
				
				-- @check_that_sections_is_not_empty
				local l = { 
					linetype = LineType.REFERENCE, 
					str = name,
					prefix = prefix
				}
				
				l.lnum = lnum
				
				linkedlist.push_back(curSection.lines, l)
				
			
			else
				if sections[name] then
					hasSection = true
				end
				
				local l = { 
					linetype = LineType.TEXT, 
					str = line 
				}
				
				l.lnum = lnum
				
				linkedlist.push_back(curSection.lines, l)
				
			end
			
			lineRefs[lnum] = curSection.str
			
			lnum = lnum+1;
		end
		
		if not filename then
			filename = vim.api.nvim_buf_get_name(buf)
		end
		local parendir = vim.api.nvim_call_function("fnamemodify", { filename, ":p:h" })
		for name, section in pairs(sections) do
			if section.root then
				local fn
				if name == "*" then
					local tail = vim.api.nvim_call_function("fnamemodify", { filename, ":t:r" })
					fn = parendir .. "/tangle/" .. tail
				
				else
					if string.find(name, "/") then
						fn = parendir .. "/" .. name
					
					else 
						fn = parendir .. "/tangle/" .. name
					end
					
				end
				
				local lines = {}
				local refs = {}
				if string.match(fn, "lua$") then
					local relname
					if filename then
						relname = filename
					else
						relname = vim.api.nvim_buf_get_name(0)
					end
					relname = vim.api.nvim_call_function("fnamemodify", { relname, ":t" })
					table.insert(lines, "-- Generated from " .. relname .. " using ntangle.nvim")
				end
				
				if string.match(fn, "vim$") then
					local relname
					if filename then
						relname = filename
					else
						relname = vim.api.nvim_buf_get_name(0)
					end
					relname = vim.api.nvim_call_function("fnamemodify", { relname, ":t" })
					table.insert(lines, "\" Generated from " .. relname .. " using ntangle.nvim")
				end
				
				outputSections(lines, file, name, "", refs)
				local uri = string.lower(vim.uri_from_fname(fn))
				
				document_lookup[uri] = refs
				
				local params = {
					textDocument = {
						version = 0,
						uri = uri,
						-- TODO make sure our filetypes are compatible with languageId names.
						languageId = language_id,
						text = table.concat(lines, "\n"),
					}
				}
				client.notify('textDocument/didOpen', params)
				
			end
		end
		
	end)
end

local function make_on_publish_diagnostics(buf)
	local uri = string.lower(vim.uri_from_bufnr(buf))
	
	return function(_, method, params, client_id)
		local remote_uri = params.uri
		params.uri = uri
		
		local refs = document_lookup[remote_uri]
		for _, diag in ipairs(params.diagnostics) do
			local lnum_start = diag.range["start"].line
			local lnum_end = diag.range["end"].line
		
			local offset_start, new_lnum_start = unpack(refs[lnum_start+1])
			local offset_end, new_lnum_end = unpack(refs[lnum_end+1])
		
			diag.range["start"].character = diag.range["start"].character - offset_start
			diag.range["end"].character = diag.range["end"].character - offset_end
		
			diag.range["start"].line = new_lnum_start-1
			diag.range["end"].line = new_lnum_end-1
		end
		
		vim.lsp.diagnostic.on_publish_diagnostics(_, method, params, client_id)
		
	end
end

local function get_buffer_lookup() 
	return buffer_lookup
end

local function register_client(buf, client_id)
	active_clients[buf] = client_id
end

function buf_request(buf, method, params, handler)
	local client_id = active_clients[buf]
	local client = vim.lsp.get_client_by_id(client_id)
	
	if client.supports_method(method) then
		client.request(method, params, nil, buf)
	end
	
end

local function hover()
	local params = require("ntangle-lsp.util").make_position_params()
	local buf = vim.api.nvim_get_current_buf()
	buf_request(buf, 'textDocument/hover', params)
end

local function make_on_definition(buf)
	local uri = string.lower(vim.uri_from_bufnr(buf))
	
	return function(...)
		table.insert(events, {...})
		-- @convert_uri_to_tangle_buffer_uri
		-- @convert_line_numbers_to_tangle_line_numbers
		-- @call_builtin_on_publish_diagnostics_with_modified_params
	end
end

local function definition()
	local params = require("ntangle-lsp.util").make_position_params()
	local buf = vim.api.nvim_get_current_buf()
	buf_request(buf, 'textDocument/definition', params)
end

local function make_location_handler(buf)
	local uri = string.lower(vim.uri_from_bufnr(buf))
	
	return function(_, method, result)
		local converted = {}
		if not vim.tbl_islist(result) then result = { result } end

		for _, r in ipairs(result) do
			local remote_uri = string.lower(r.uri)
			local refs = document_lookup[remote_uri]
			table.insert(events, remote_uri)
			table.insert(events, document_lookup)
			
			local offset_start, new_lnum_start = unpack(refs[r.range["start"].line+1])
			local offset_end, new_lnum_end = unpack(refs[r.range["end"].line+1])
			
			r.range["start"].character = r.range["start"].character - offset_start
			r.range["end"].character = r.range["end"].character - offset_end
			
			r.range["start"].line = new_lnum_start-1
			r.range["end"].line = new_lnum_end-1
			
			r.uri = uri
			
		end

		table.insert(events, vim.inspect(result))
		vim.lsp.util.jump_to_location(result[1])
		
		if #result > 1 then
			vim.lsp.util.set_qflist(vim.lsp.util.locations_to_items(result))
			vim.api.nvim_command("copen")
			vim.api.nvim_command("wincmd p")
		end
	end
end

return {
tangle = tangle,

goto = goto,

collectSection = collectSection,

getRootFilename = getRootFilename,

attach_to_buf = attach_to_buf,

make_on_publish_diagnostics = make_on_publish_diagnostics,

document_lookup = document_lookup,

get_buffer_lookup = get_buffer_lookup,

register_client = register_client,

hover = hover,

make_on_definition = make_on_definition,

definition = definition,
make_location_handler = make_location_handler,

}

