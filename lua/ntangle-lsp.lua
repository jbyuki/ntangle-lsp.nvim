-- Generated from border_window.lua.tl, buf_attach.lua.tl, contextmenu.lua.tl, debug.lua.tl, declaration.lua.tl, definition.lua.tl, hover.lua.tl, implementation.lua.tl, init_client.lua.tl, ntangle-lsp.lua.tl, parse.lua.tl, publish_diagnostics.lua.tl, send_changes.lua.tl, type_definition.lua.tl using ntangle.nvim
require("linkedlist")

local active_clients = {}

local contextmenu_contextmenu

local contextmenu_win

-- this is all for experimentation purposes...
local client_clangd

local bufaddress = {}
local bufcontent = {}

local genmeta = {}

local attached = {}

local sections = {}
local curSection = nil

local LineType = {
	SECTION = 3,
	
	REFERENCE = 1,
	
	TEXT = 2,
	
}

local fill_border

local register_client

local contextmenu_open

local debug_array

local buf_request

local make_position_params

local get_candidates_position

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

local function buf_attach()
	local client_id = client_clangd
	assert(client_id, "No active clangd client!")
	local bufnr = vim.fn.bufnr()
	
	vim.api.nvim_buf_set_keymap(bufnr, 'n', '<leader>j', '<cmd>lua require("ntangle-lsp").definition()<CR>', {noremap = true})
	vim.api.nvim_buf_set_keymap(bufnr, 'n', 'K', '<cmd>lua require("ntangle-lsp").hover()<CR>', {noremap = true})
	
	attach_to_buf(bufnr, client_id, "cpp")
	
	register_client(bufnr, client_id)
	
end

function register_client(buf, client_id)
	-- atm only one client per buffer possible
	active_clients[buf] = client_id
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
		buf_request('textDocument/declaration', params)
	end

	if #candidates > 1 then
		local candidates_str = {}
		for _, c in ipairs(candidates) do
			table.insert(candidates_str, c.root_uri .. " " .. c.lnum)
		end
		contextmenu_open(candidates_str,
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
		buf_request('textDocument/definition', params)
	end

	if #candidates > 1 then
		local candidates_str = {}
		for _, c in ipairs(candidates) do
			table.insert(candidates_str, c.root_uri .. " " .. c.lnum)
		end
		contextmenu_open(candidates_str,
			function(sel) 
				action(sel)
			end
		)
	else
		action(1)
	end
	
end

local function make_location_handler(buf)
	-- @get_uri_of_buffer
	-- return function(_, method, result)
		-- local converted = {}
		-- if not vim.tbl_islist(result) then result = { result } end
-- 
		-- for _, r in ipairs(result) do
			-- if document_lookup[string.lower(r.uri)] then
				-- @convert_uri_and_location
			-- end
		-- end
-- 
		-- @call_builtin_on_location_handler_with_modified_params
	-- end
end

function buf_request(method, params, handler)
	local client_id = client_clangd
	local client = vim.lsp.get_client_by_id(client_id)
	
	if client.supports_method(method) then
		local buf = vim.api.nvim_get_current_buf()
		client.request(method, params, handler, buf)
	end
	
end

local function hover()
	local pos, candidates = get_candidates_position()

	local function action(sel)
		local params = make_position_params(pos, candidates, sel)
		local buf = vim.api.nvim_get_current_buf()
		buf_request('textDocument/hover', params)
	end

	if #candidates > 1 then
		local candidates_str = {}
		for _, c in ipairs(candidates) do
			table.insert(candidates_str, c.root_uri .. " " .. c.lnum)
		end
		contextmenu_open(candidates_str,
			function(sel) 
				action(sel)
			end
		)
	else
		action(1)
	end
	
end

function make_position_params(pos, candidates, sel)
	local row, col = unpack(pos)
	local c = candidates[sel]
	local lnum = c.lnum-1
	local line = vim.api.nvim_get_current_line()
	col = vim.str_utfindex(line, col) + c.offset
	
	local root_uri = c.root_uri
	
	return { 
		textDocument = {uri = root_uri},
		position = {line = lnum, character = col},
	}
end

function get_candidates_position()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	
	local uri = vim.uri_from_bufnr(0)
	local candidates = {}
	for root_uri, meta in pairs(genmeta) do
		for lnum, info in ipairs(meta) do
			if info.part == uri and info.lnum == row then
				table.insert(candidates, {
					root_uri = root_uri,
					lnum = lnum,
					offset = info.offset,
				})
				
			end
		end
	end
	
	return {row, col}, candidates
end

local function implementation()
	local pos, candidates = get_candidates_position()

	local function action(sel)
		local params = make_position_params(pos, sel)
		local buf = vim.api.nvim_get_current_buf()
		buf_request('textDocument/implementation', params)
	end

	if #candidates > 1 then
		local candidates_str = {}
		for _, c in ipairs(candidates) do
			table.insert(candidates_str, c.root_uri .. " " .. c.lnum)
		end
		contextmenu_open(candidates_str,
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
		vim.lsp.set_log_level("debug")
		local client_id = vim.lsp.start_client {
			cmd = { "clangd" },
			root_dir = ".",
			handlers = {
				["textDocument/declaration"] = make_location_handler(bufnr),
				["textDocument/definition"] = make_location_handler(bufnr),
				
				["textDocument/implementation"] = make_location_handler(bufnr),
				["textDocument/publishDiagnostics"] = make_on_publish_diagnostics(),
				
				["textDocument/typeDefinition"] = make_location_handler(bufnr),
				-- ["textDocument/definition"] = make_location_handler(bufnr),
				-- ["textDocument/declaration"] = make_location_handler(bufnr),
				-- ["textDocument/typeDefinition"] = make_location_handler(bufnr),
				-- ["textDocument/implementation"] = make_location_handler(bufnr),
			},
		}
		
		client_clangd = client_id
	end
end

function parse(assembly_lines)
	local parts = vim.tbl_keys(assembly_lines)
	table.sort(parts)
	

	for _, part in ipairs(parts) do
		local lines = assembly_lines[part]
		local lnum = 1
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
					l.part = part
					
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
				
				-- @check_that_sections_is_not_empty
				local l = { 
					linetype = LineType.REFERENCE, 
					str = name,
					prefix = prefix
				}
				
				l.lnum = lnum
				l.part = part
				
				linkedlist.push_back(curSection.lines, l)
				
			
			elseif string.match(line, "^##%S*%s*$") then
			else
				if sections[name] then
					hasSection = true
				end
				
				local l = { 
					linetype = LineType.TEXT, 
					str = line 
				}
				
				l.lnum = lnum
				l.part = part
				
				linkedlist.push_back(curSection.lines, l)
				
			end
			
			lnum = lnum+1;
		end
	end
end

function make_on_publish_diagnostics()
	return function(_, method, params, client_id)
		local meta = genmeta[params.uri]
		
		local new_params = {}
		new_params.uri = vim.uri_from_bufnr(0)
		new_params.diagnostics = {}
		
		for _, diag in ipairs(params.diagnostics) do
			local line_start_gen = diag.range["start"].line+1
			local line_end_gen = diag.range["end"].line+1
			
			local offset_start = meta[line_start_gen].offset
			local offset_end = meta[line_end_gen].offset
			
			diag.range["start"].character = diag.range["start"].character - offset_start
			diag.range["end"].character = diag.range["end"].character - offset_end
			
			diag.range["start"].line = meta[line_start_gen].lnum-1
			diag.range["end"].line = meta[line_end_gen].lnum-1
			
			local part = meta[line_start_gen].part
			if part == vim.uri_from_bufnr(0) then
				table.insert(new_params.diagnostics, diag)
			end
			
		end
		vim.lsp.diagnostic.on_publish_diagnostics(_, method, new_params, client_id)
	end
end

function attach_to_buf(buf, client_id, language_id)
	local client = vim.lsp.get_client_by_id(client_id)
	assert(client, "Could not find client_id")
	

	if attached[buf] then
		return
	end
	
	attached[buf] = true

	vim.api.nvim_buf_attach(buf, true, {
		on_lines = function(_, buf, changedtick, firstline, lastline, new_lastline, old_byte_size)
			local assembly_filename, uri = unpack(bufaddress[buf])
			local lines = bufcontent[assembly_filename][uri]
			
			for _=firstline+1,lastline do
				table.remove(lines, firstline+1)
			end
			
			local changed = vim.api.nvim_buf_get_lines(buf, firstline, new_lastline, true)
			for _, line in ipairs(changed) do
				table.insert(lines, firstline+1, line)
			end
			

			local curassembly
			local assembly_filename
			local top = lines[1] or ""
			if string.match(top, "^##%S*%s*$") then
				local name = string.match(top, "^##(%S*)%s*$")
				
				curassembly = name
				
				local bufname = vim.api.nvim_buf_get_name(buf)
				local extname = vim.fn.fnamemodify(bufname, ":e:e")
				local relname = vim.fn.fnamemodify(curassembly, ":h")
				local assname = vim.fn.fnamemodify(curassembly, ":t")
				local parent = vim.fn.fnamemodify(bufname, ":h")
				assembly_filename = parent .. "/" .. relname .. "/" .. assname .. "." .. extname
				
			end
			
			if not curassembly then
				assembly_filename = vim.api.nvim_buf_get_name(buf)
			end
			

			if curassembly ~= assembly_filename then
				local uri = vim.uri_from_bufnr(buf)
				bufcontent[assembly_filename][uri] = nil
			
				if not bufcontent[assembly_filename] then
					local extname = vim.fn.fnamemodify(assembly_filename, ":e:e")
					local assembly_dir = vim.fn.fnamemodify(assembly_filename, ":h")
					local assembly_name = vim.fn.fnamemodify(assembly_filename, ":t:r:r")
					
					local parts = vim.split(vim.fn.glob(assembly_dir .. "/tangle/" .. assembly_name .. ".*." .. extname), "\n")
					
					bufcontent[assembly_filename] = {}
					
					for _, part in ipairs(parts) do
						if part ~= "" then
							local origin_path
							local f = io.open(part, "r")
							local origin_path = f:read("*line")
							f:close()
							
							local uri = vim.uri_from_fname(origin_path)
							if origin_path ~= bufname and not bufcontent[assembly_filename][uri] then
								local partlines = {}
								local f = io.open(origin_path, "r")
								if f then
									local lnum = 1
									while true do
										local line = f:read("*line")
										if not line then break end
										if lnum > 1 then
											table.insert(partlines, line)
										end
										lnum = lnum + 1
									end
									f:close()
								end
								bufcontent[assembly_filename][uri] = partlines
								
							end
						end
					end
					
				end
			
				local uri = vim.uri_from_bufnr(buf)
				bufcontent[assembly_filename][uri] = lines
				
				local uri = vim.uri_from_bufnr(buf)
				bufaddress[buf] = { assembly_filename, uri }
				
			end
			

			sections = {}
			curSection = nil
			
			parse(bufcontent[assembly_filename])
			

			local parendir = vim.fn.fnamemodify(assembly_filename, ":p:h")
			for name, section in pairs(sections) do
				if section.root then
					local fn
					if name == "*" then
						local tail = vim.fn.fnamemodify( assembly_filename, ":t:r" )
						fn = parendir .. "/tangle/" .. tail
					
					else
						if string.find(name, "/") then
							fn = parendir .. "/" .. name
						else
							fn = parendir .. "/tangle/" .. name
						end
					end
					
					local lines = {}
					local uri = string.lower(vim.uri_from_fname(fn))
					
					genmeta[uri] = {}
					
					if string.match(fn, "lua$") then
						local relname
						if filename then
							relname = filename
						else
							relname = vim.api.nvim_buf_get_name(0)
						end
						relname = vim.api.nvim_call_function("fnamemodify", { relname, ":t" })
						table.insert(lines, "-- Generated from " .. relname .. " using ntangle.nvim")
						table.insert(genmeta[name], {})
						
					elseif string.match(fn, "vim$") then
						local relname
						if filename then
							relname = filename
						else
							relname = vim.api.nvim_buf_get_name(0)
						end
						relname = vim.api.nvim_call_function("fnamemodify", { relname, ":t" })
						table.insert(lines, "\" Generated from " .. relname .. " using ntangle.nvim")
						table.insert(genmeta[name], {})
						
					end
					
					outputSections(assembly_filename, lines, uri, name, "")
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
		

		local curassembly
		local assembly_filename
		local top = lines[1] or ""
		if string.match(top, "^##%S*%s*$") then
			local name = string.match(top, "^##(%S*)%s*$")
			
			curassembly = name
			
			local bufname = vim.api.nvim_buf_get_name(buf)
			local extname = vim.fn.fnamemodify(bufname, ":e:e")
			local relname = vim.fn.fnamemodify(curassembly, ":h")
			local assname = vim.fn.fnamemodify(curassembly, ":t")
			local parent = vim.fn.fnamemodify(bufname, ":h")
			assembly_filename = parent .. "/" .. relname .. "/" .. assname .. "." .. extname
			
		end
		
		if not curassembly then
			assembly_filename = vim.api.nvim_buf_get_name(buf)
		end
		

		if not bufcontent[assembly_filename] then
			local extname = vim.fn.fnamemodify(assembly_filename, ":e:e")
			local assembly_dir = vim.fn.fnamemodify(assembly_filename, ":h")
			local assembly_name = vim.fn.fnamemodify(assembly_filename, ":t:r:r")
			
			local parts = vim.split(vim.fn.glob(assembly_dir .. "/tangle/" .. assembly_name .. ".*." .. extname), "\n")
			
			bufcontent[assembly_filename] = {}
			
			for _, part in ipairs(parts) do
				if part ~= "" then
					local origin_path
					local f = io.open(part, "r")
					local origin_path = f:read("*line")
					f:close()
					
					local uri = vim.uri_from_fname(origin_path)
					if origin_path ~= bufname and not bufcontent[assembly_filename][uri] then
						local partlines = {}
						local f = io.open(origin_path, "r")
						if f then
							local lnum = 1
							while true do
								local line = f:read("*line")
								if not line then break end
								if lnum > 1 then
									table.insert(partlines, line)
								end
								lnum = lnum + 1
							end
							f:close()
						end
						bufcontent[assembly_filename][uri] = partlines
						
					end
				end
			end
			
		end

		local uri = vim.uri_from_bufnr(buf)
		bufcontent[assembly_filename][uri] = lines
		
		local uri = vim.uri_from_bufnr(buf)
		bufaddress[buf] = { assembly_filename, uri }
		

		sections = {}
		curSection = nil
		
		parse(bufcontent[assembly_filename])
		
		local parendir = vim.fn.fnamemodify(assembly_filename, ":p:h")
		for name, section in pairs(sections) do
			if section.root then
				local fn
				if name == "*" then
					local tail = vim.fn.fnamemodify( assembly_filename, ":t:r" )
					fn = parendir .. "/tangle/" .. tail
				
				else
					if string.find(name, "/") then
						fn = parendir .. "/" .. name
					else
						fn = parendir .. "/tangle/" .. name
					end
				end
				
				local lines = {}
				local uri = string.lower(vim.uri_from_fname(fn))
				
				genmeta[uri] = {}
				
				if string.match(fn, "lua$") then
					local relname
					if filename then
						relname = filename
					else
						relname = vim.api.nvim_buf_get_name(0)
					end
					relname = vim.api.nvim_call_function("fnamemodify", { relname, ":t" })
					table.insert(lines, "-- Generated from " .. relname .. " using ntangle.nvim")
					table.insert(genmeta[name], {})
					
				elseif string.match(fn, "vim$") then
					local relname
					if filename then
						relname = filename
					else
						relname = vim.api.nvim_buf_get_name(0)
					end
					relname = vim.api.nvim_call_function("fnamemodify", { relname, ":t" })
					table.insert(lines, "\" Generated from " .. relname .. " using ntangle.nvim")
					table.insert(genmeta[name], {})
					
				end
				
				outputSections(assembly_filename, lines, uri, name, "")
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

function outputSections(assembly_filename, lines, uri, name, prefix)
	if not sections[name] then
		return
	end
	
	for section in linkedlist.iter(sections[name].list) do
		for line in linkedlist.iter(section.lines) do
			if line.linetype == LineType.TEXT then
				lines[#lines+1] = prefix .. line.str
				table.insert(genmeta[uri], {
					part = line.part,
					lnum = line.lnum,
					text = line.str,
					offset = string.len(prefix),
				})
				
			end
			
			if line.linetype == LineType.REFERENCE then
				outputSections(assembly_filename, lines, uri, line.str, prefix .. line.prefix)
			end
			
		end
	end
end

local function type_definition()
	local pos, candidates = get_candidates_position()

	local function action(sel)
		local params = make_position_params(pos, sel)
		local buf = vim.api.nvim_get_current_buf()
		buf_request('textDocument/typeDefinition', params)
	end

	if #candidates > 1 then
		local candidates_str = {}
		for _, c in ipairs(candidates) do
			table.insert(candidates_str, c.root_uri .. " " .. c.lnum)
		end
		contextmenu_open(candidates_str,
			function(sel) 
				action(sel)
			end
		)
	else
		action(1)
	end
	
end

return {
buf_attach = buf_attach,

declaration = declaration,

definition = definition,
make_location_handler = make_location_handler,

hover = hover,

implementation = implementation,

start = start,

type_definition = type_definition,

}
