-- Generated from border_window.lua.tl, contextmenu.lua.tl, debug.lua.tl, declaration.lua.tl, definition.lua.tl, hover.lua.tl, implementation.lua.tl, init_client.lua.tl, ntangle-lsp.lua.tl, parse.lua.tl, publish_diagnostics.lua.tl, send_changes.lua.tl, type_definition.lua.tl using ntangle.nvim
require("linkedlist")

local contextmenu_contextmenu

local contextmenu_win

local buffer_lookup = {} -- reverse lookup of document_lookup

local active_clients = {}

local document_lookup = {}

local buffer_offset

local sections = {}
local curSection = nil

local LineType = {
	SECTION = 3,
	
	REFERENCE = 1,
	
	TEXT = 2,
	
}

local refs = {}

local fill_border

local contextmenu_open

local debug_array

local buf_request

local make_position_params

local get_candidates_position

local register_client

local parse

local make_on_publish_diagnostics

local attach_to_buf 

local outputSections

function fill_border(borderbuf, border_opts, center_title, border_title)
	local border_text = {}
	
	local border_chars = {
		topleft  = '╭',
		topright = '╮',
		top      = '─',
		left     = '│',
		right    = '│',
		botleft  = '╰',
		botright = '╯',
		bot      = '─',
	}
	
	-- local border_chars = {
		-- topleft  = '╔',
		-- topright = '╗',
		-- top      = '═',
		-- left     = '║',
		-- right    = '║',
		-- botleft  = '╚',
		-- botright = '╝',
		-- bot      = '═',
	-- }
	
	for y=1,border_opts.height do
		local line = ""
		if y == 1 then
			if not center_title then
				line = border_chars.topleft .. border_chars.top
				local title_len = 0
				if border_title then
					line = line .. border_title
					title_len = vim.api.nvim_strwidth(border_title)
				end
				
				for x=2+title_len+1,border_opts.width-1 do
					line = line .. border_chars.top
				end
				line = line .. border_chars.topright
				
			else
				line = border_chars.topleft
				
				local title_len = 0
				if border_title then
					title_len = vim.api.nvim_strwidth(border_title)
				end
				
				local pad_left = math.floor((border_opts.width-title_len)/2)
				
				for x=2,pad_left do
					line = line .. border_chars.top
				end
				
				if border_title then
					line = line .. border_title
				end
				
				for x=pad_left+title_len+1,border_opts.width-1 do
					line = line .. border_chars.top
				end
				
				line = line .. border_chars.topright
				
			end
		elseif y == border_opts.height then
			line = border_chars.botleft
			for x=2,border_opts.width-1 do
				line = line .. border_chars.bot
			end
			line = line .. border_chars.botright
			
		else
			line = border_chars.left
			for x=2,border_opts.width-1 do
				line = line .. " "
			end
			line = line .. border_chars.right
		end
		table.insert(border_text, line)
	end
	
	vim.api.nvim_buf_set_lines(borderbuf, 0, -1, true, border_text)
	
end

function contextmenu_open(candidates, callback)
	local max_width = 0
	for _, el in ipairs(candidates) do
		max_width = math.max(max_width, vim.api.nvim_strwidth(el))
	end
	
	local buf = vim.api.nvim_create_buf(false, true)
	local w, h = vim.api.nvim_win_get_width(0), vim.api.nvim_win_get_height(0)
	
	local opts = {
		relative = "cursor",
		width = max_width,
		height = #candidates,
		col = 2,
		row =  2,
		style = 'minimal'
	}
	
	contextmenu_win = vim.api.nvim_open_win(buf, false, opts)
	
	local borderbuf = vim.api.nvim_create_buf(false, true)
	
	local border_opts = {
		relative = "cursor",
		width = opts.width+2,
		height = opts.height+2,
		col = 1,
		row =  1,
		style = 'minimal'
	}
	
	fill_border(borderbuf, border_opts, false, "")
	
	local borderwin = vim.api.nvim_open_win(borderbuf, false, border_opts)
	
	vim.api.nvim_buf_set_lines(buf, 0, -1, true, candidates)
	
	vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>', '<cmd>lua require"ntangle-lsp".select_contextmenu()<CR>', {noremap = true})
	
	vim.api.nvim_win_set_option(borderwin, "winblend", 30)
	vim.api.nvim_win_set_option(contextmenu_win, "winblend", 30)
	vim.api.nvim_win_set_option(contextmenu_win, "cursorline", true)
	vim.api.nvim_set_current_win(contextmenu_win)
	contextmenu_contextmenu = callback
	
end

local function select_contextmenu()
	local row = vim.fn.line(".")
	if contextmenu_contextmenu then
		vim.api.nvim_win_close(contextmenu_win, true)
		
		contextmenu_contextmenu(row)
		contextmenu_contextmenu = nil
	end
end

function debug_array(l)
	if #l == 0 then
		print("{}")
	end
	for i, li in ipairs(l) do
		print(i .. ": " .. vim.inspect(li))
	end
end
local function declaration()
	local pos, candidates = get_candidates_position()

	local function action(sel)
		local params = make_position_params(pos, sel)
		local buf = vim.api.nvim_get_current_buf()
		buf_request(buf, 'textDocument/declaration', params)
	end

	if #candidates > 1 then
		contextmenu_open(candidates,
			function(sel) 
				action(sel)
			end
		)
	else
		action(1)
	end
	
end

local function definition()
	local pos, candidates = get_candidates_position()

	local function action(sel)
		local params = make_position_params(pos, sel)
		local buf = vim.api.nvim_get_current_buf()
		buf_request(buf, 'textDocument/definition', params)
	end

	if #candidates > 1 then
		contextmenu_open(candidates,
			function(sel) 
				action(sel)
			end
		)
	else
		action(1)
	end
	
end

local function make_location_handler(buf)
	local uri = string.lower(vim.uri_from_bufnr(buf))
	
	return function(_, method, result)
		local converted = {}
		if not vim.tbl_islist(result) then result = { result } end

		for _, r in ipairs(result) do
			if document_lookup[string.lower(r.uri)] then
				local remote_uri = string.lower(r.uri)
				local buf, refs = unpack(document_lookup[remote_uri])
				
				local offset_start, new_lnum_start = unpack(refs[r.range["start"].line+1])
				local offset_end, new_lnum_end = unpack(refs[r.range["end"].line+1])
				
				r.range["start"].character = r.range["start"].character - offset_start
				r.range["end"].character = r.range["end"].character - offset_end
				
				r.range["start"].line = new_lnum_start-1
				r.range["end"].line = new_lnum_end-1
				
				r.uri = vim.uri_from_bufnr(buf)
				
			end
		end

		vim.lsp.util.jump_to_location(result[1])
		
		if #result > 1 then
			vim.lsp.util.set_qflist(vim.lsp.util.locations_to_items(result))
			vim.api.nvim_command("copen")
			vim.api.nvim_command("wincmd p")
		end
	end
end

function buf_request(buf, method, params, handler)
	local client_id = active_clients[buf]
	local client = vim.lsp.get_client_by_id(client_id)
	
	if client.supports_method(method) then
		client.request(method, params, handler, buf)
	end
	
end

local function hover()
	local pos, candidates = get_candidates_position()

	local function action(sel)
		local params = make_position_params(pos, sel)
		local buf = vim.api.nvim_get_current_buf()
		buf_request(buf, 'textDocument/hover', params)
	end

	if #candidates > 1 then
		contextmenu_open(candidates,
			function(sel) 
				action(sel)
			end
		)
	else
		action(1)
	end
	
end

function make_position_params(pos, sel)
	local row, col = unpack(pos)
	local prefix_len, refs, lnum = unpack(buffer_lookup[row][sel])
	lnum = lnum-1
	local line = vim.api.nvim_buf_get_lines(0, row-1, row, true)[1]
	col = vim.str_utfindex(line, col) + prefix_len
	
	local section_uri
	for uri, doc in pairs(document_lookup) do
		local _, document_refs = unpack(doc)
		if refs == document_refs then
			section_uri = uri
		end
	end
	
	return { 
		textDocument = {uri = section_uri},
		position = {line = lnum, character = col},
	}
end

function get_candidates_position()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	
	local candidates = {}
	for _, c in ipairs(buffer_lookup[row]) do
		local _, _, lnum = unpack(c)
		print("candidate " .. lnum)
		table.insert(candidates, "L" .. lnum)
	end
	
	return {row, col}, candidates
end

local function implementation()
	local pos, candidates = get_candidates_position()

	local function action(sel)
		local params = make_position_params(pos, sel)
		local buf = vim.api.nvim_get_current_buf()
		buf_request(buf, 'textDocument/implementation', params)
	end

	if #candidates > 1 then
		contextmenu_open(candidates,
			function(sel) 
				action(sel)
			end
		)
	else
		action(1)
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
				["textDocument/declaration"] = make_location_handler(bufnr),
				["textDocument/definition"] = make_location_handler(bufnr),
				
				["textDocument/implementation"] = make_location_handler(bufnr),
				["textDocument/publishDiagnostics"] = make_on_publish_diagnostics(bufnr),
				
				["textDocument/typeDefinition"] = make_location_handler(bufnr),
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
				
				buffer_offset = offset[fn] - 1
				
			else
				buffer_offset = 0
			end

			buffer_lookup = {}
			
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
			
			buffer_offset = offset[fn] - 1
			
		else
			buffer_offset = 0
		end

		buffer_lookup = {}
		
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
				refs[#refs+1] = { string.len(prefix), line.lnum - buffer_offset }
				
				local rel = line.lnum - buffer_offset
				buffer_lookup[rel] = buffer_lookup[rel] or {}
				table.insert(buffer_lookup[rel], { string.len(prefix), refs, #refs }) -- only saves refs table reference
			end
			
			if line.linetype == LineType.REFERENCE then
				outputSections(lines, file, line.str, prefix .. line.prefix, refs)
			end
			
		end
	end
end

local function type_definition()
	local pos, candidates = get_candidates_position()

	local function action(sel)
		local params = make_position_params(pos, sel)
		local buf = vim.api.nvim_get_current_buf()
		buf_request(buf, 'textDocument/typeDefinition', params)
	end

	if #candidates > 1 then
		contextmenu_open(candidates,
			function(sel) 
				action(sel)
			end
		)
	else
		action(1)
	end
	
end

return {
declaration = declaration,

definition = definition,
make_location_handler = make_location_handler,

hover = hover,

implementation = implementation,

start = start,

type_definition = type_definition,

}
