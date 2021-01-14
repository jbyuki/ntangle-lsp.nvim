-- Generated from debug.lua.tl, init_client.lua.tl, ntangle-lsp.lua.tl, parse.lua.tl, publish_diagnostics.lua.tl, send_changes.lua.tl using ntangle.nvim
require("linkedlist")

local active_clients = {}

local document_lookup = {}

local sections = {}
local curSection = nil

local LineType = {
	SECTION = 3,
	
	REFERENCE = 1,
	
	TEXT = 2,
	
}

local refs = {}

local debug_array

local register_client

local parse

local make_on_publish_diagnostics

local attach_to_buf 

local outputSections

function debug_array(l)
	if #l == 0 then
		print("{}")
	end
	for i, li in ipairs(l) do
		print(i .. ": " .. vim.inspect(li))
	end
end
local function start(lang)
	if not lang or lang == "cpp" then
		vim.schedule(function()
		vim.lsp.set_log_level("debug")
		local bufnr = vim.fn.bufnr(0)
		
		local root_dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p:h")
		
		local client_id = vim.lsp.start_client {
			cmd = { "clangd" },
			root_dir = root_dir,
			handlers = {
				["textDocument/publishDiagnostics"] = make_on_publish_diagnostics(bufnr),
				
				-- ["textDocument/definition"] = make_location_handler(bufnr),
				-- ["textDocument/declaration"] = make_location_handler(bufnr),
				-- ["textDocument/typeDefinition"] = make_location_handler(bufnr),
				-- ["textDocument/implementation"] = make_location_handler(bufnr),
			},
		}
		
		vim.wait(500)
		print("LSP starting...")
		
		register_client(bufnr, client_id)
		
		vim.api.nvim_buf_set_keymap(bufnr, 'n', '<leader>j', '<cmd>lua require("ntangle-lsp").definition()<CR>', {noremap = true})
		vim.api.nvim_buf_set_keymap(bufnr, 'n', 'K', '<cmd>lua require("ntangle-lsp").hover()<CR>', {noremap = true})
		
		attach_to_buf(bufnr, client_id, "cpp")
		
		end)
	end
end

function register_client(buf, client_id)
	active_clients[buf] = client_id
end
function parse(lines)
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
			
			refs[name] = refs[name] or {}
			table.insert(refs[name], curSection.str)
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
end

function make_on_publish_diagnostics(buf)
	local uri = string.lower(vim.uri_from_bufnr(buf))
	
	return function(_, method, params, client_id)
		print(vim.inspect(params))
		local remote_uri = params.uri
		params.uri = uri
		
		local _, refs = unpack(document_lookup[remote_uri])
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

function attach_to_buf(buf, client_id, language_id)
	local client = vim.lsp.get_client_by_id(client_id)
	assert(client, "Could not find client_id")
	

	vim.api.nvim_buf_attach(buf, true, {
		on_lines = function(_, buf, changedtick, firstline, lastline, new_lastline, old_byte_size)
			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
			
			local curassembly
			local line = lines[1] or ""
			if string.match(lines[1], "^##%S*%s*$") then
				local name = string.match(line, "^##(%S*)%s*$")
				
				curassembly = name
				
			end
			
			local filename
			if curassembly then
				local fn = vim.api.nvim_buf_get_name(0)
				local parendir = vim.fn.fnamemodify(fn, ":p:h")
				local assembly_parendir = vim.fn.fnamemodify(curassembly, ":h")
				local assembly_tail = vim.fn.fnamemodify(curassembly, ":t")
				local part_tail = vim.fn.fnamemodify(fn, ":t")
				local link_name = parendir .. "/" .. assembly_parendir .. "/tangle/" .. assembly_tail .. "." .. part_tail
				local path = vim.fn.fnamemodify(link_name, ":h")
				

				local assembled = {}
				local valid_parts = {}
				
				local offset = {}
				
				local origin = {}
				
				path = vim.fn.fnamemodify(path, ":p")
				local parts = vim.split(vim.fn.glob(path .. assembly_tail .. ".*.tl"), "\n")
				link_name = vim.fn.fnamemodify(link_name, ":p")
				for _, part in ipairs(parts) do
					if link_name ~= part then
						local f = io.open(part, "r")
						local origin_path = f:read("*line")
						f:close()
						
						local f = io.open(origin_path, "r")
						if f then
							table.insert(valid_parts, vim.fn.fnamemodify(part, ":t:e:e:e"))
							
							offset[origin_path] = #assembled
							
							local lnum = 1
							while true do
								local line = f:read("*line")
								if not line then break end
								if lnum > 1 then
									table.insert(assembled, line)
									table.insert(origin, origin_path)
									
								end
								lnum = lnum + 1
							end
							f:close()
						else
							os.remove(part)
							
						end
						
					else
						table.insert(valid_parts, vim.fn.fnamemodify(part, ":t:e:e:e"))
						
						offset[fn] = #assembled
						
						for lnum, line in ipairs(lines) do
							if lnum > 1 then
								table.insert(assembled, line)
								table.insert(origin, fn)
								
							end
						end
						
					end
				end
				
				lines = assembled

				local ext = vim.fn.fnamemodify(fn, ":e:e")
				filename = parendir .. "/" .. assembly_parendir .. "/" .. assembly_tail .. "." .. ext
				
			end

			sections = {}
			curSection = nil
			
			parse(lines)
			

			if not filename then
				filename = vim.api.nvim_buf_get_name(0)
			end
			local parendir = vim.fn.fnamemodify(filename, ":p:h")
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
					elseif string.match(fn, "vim$") then
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
					document_lookup[uri] = {buf, refs}
					
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
		local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
		
		local curassembly
		local line = lines[1] or ""
		if string.match(lines[1], "^##%S*%s*$") then
			local name = string.match(line, "^##(%S*)%s*$")
			
			curassembly = name
			
		end
		
		local filename
		if curassembly then
			local fn = vim.api.nvim_buf_get_name(0)
			local parendir = vim.fn.fnamemodify(fn, ":p:h")
			local assembly_parendir = vim.fn.fnamemodify(curassembly, ":h")
			local assembly_tail = vim.fn.fnamemodify(curassembly, ":t")
			local part_tail = vim.fn.fnamemodify(fn, ":t")
			local link_name = parendir .. "/" .. assembly_parendir .. "/tangle/" .. assembly_tail .. "." .. part_tail
			local path = vim.fn.fnamemodify(link_name, ":h")
			

			local assembled = {}
			local valid_parts = {}
			
			local offset = {}
			
			local origin = {}
			
			path = vim.fn.fnamemodify(path, ":p")
			local parts = vim.split(vim.fn.glob(path .. assembly_tail .. ".*.tl"), "\n")
			link_name = vim.fn.fnamemodify(link_name, ":p")
			for _, part in ipairs(parts) do
				if link_name ~= part then
					local f = io.open(part, "r")
					local origin_path = f:read("*line")
					f:close()
					
					local f = io.open(origin_path, "r")
					if f then
						table.insert(valid_parts, vim.fn.fnamemodify(part, ":t:e:e:e"))
						
						offset[origin_path] = #assembled
						
						local lnum = 1
						while true do
							local line = f:read("*line")
							if not line then break end
							if lnum > 1 then
								table.insert(assembled, line)
								table.insert(origin, origin_path)
								
							end
							lnum = lnum + 1
						end
						f:close()
					else
						os.remove(part)
						
					end
					
				else
					table.insert(valid_parts, vim.fn.fnamemodify(part, ":t:e:e:e"))
					
					offset[fn] = #assembled
					
					for lnum, line in ipairs(lines) do
						if lnum > 1 then
							table.insert(assembled, line)
							table.insert(origin, fn)
							
						end
					end
					
				end
			end
			
			lines = assembled

			local ext = vim.fn.fnamemodify(fn, ":e:e")
			filename = parendir .. "/" .. assembly_parendir .. "/" .. assembly_tail .. "." .. ext
			
		end

		sections = {}
		curSection = nil
		
		parse(lines)
		
		if not filename then
			filename = vim.api.nvim_buf_get_name(0)
		end
		local parendir = vim.fn.fnamemodify(filename, ":p:h")
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
				elseif string.match(fn, "vim$") then
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
				
				document_lookup[uri] = {buf, refs}
				
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

function outputSections(lines, file, name, prefix, refs)
	if not sections[name] then
		return
	end
	
	for section in linkedlist.iter(sections[name].list) do
		for line in linkedlist.iter(section.lines) do
			if line.linetype == LineType.TEXT then
				lines[#lines+1] = prefix .. line.str
				refs[#refs+1] = { string.len(prefix), line.lnum }
				
			end
			
			if line.linetype == LineType.REFERENCE then
				outputSections(lines, file, line.str, prefix .. line.prefix, refs)
			end
			
		end
	end
end

return {
start = start,

}
