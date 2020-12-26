@../lua/ntangle-lsp.lua=
@requires
@script_variables
@declare_functions
@functions
return {
@export_symbols
}

@functions+=
local function tangle(filename)
	@clear_sections
	if filename then
		@read_file_line_by_line
	else
		@read_file_line_by_line_from_buffer
		@parse_tangle_lines
	end
	@output_sections
end

@export_symbols+=
tangle = tangle,

@read_file_line_by_line+=
lnum = 1
for line in io.lines(filename) do
	@check_if_line_escape_double_at
	@check_if_line_is_section
	@check_if_line_is_reference
	@otherwise_add_to_section
	lnum = lnum+1;
end

@read_file_line_by_line_from_buffer+=
local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)

@parse_tangle_lines+=
lnum = 1
for _,line in ipairs(lines) do
	@check_if_line_escape_double_at
	@check_if_line_is_section
	@check_if_line_is_reference
	@otherwise_add_to_section
	@save_line_reference
	lnum = lnum+1;
end

@check_if_line_is_section+=
elseif string.match(line, "^@[^@]%S*[+-]?=%s*$") then
	@parse_section_name
	@create_new_section
	@link_to_previous_section_if_needed
	@otherwise_just_save_section
	@set_section_as_current_section

@parse_section_name+=
local _, _, name, op = string.find(line, "^@(%S-)([+-]?=)%s*$")

@line_types+=
SECTION = 3,

@create_new_section+=
local section = { linetype = LineType.SECTION, str = name, lines = {}}

@requires+=
require("ntangle-lsp.linkedlist")

@script_variables+=
local sections = {}
local curSection = nil

@clear_sections+=
sections = {}
curSection = nil

@link_to_previous_section_if_needed+=
if op == '+=' or op == '-=' then
	if sections[name] then
		if op == '+=' then
			@add_back_to_section
		elseif op == '-=' then
			@add_front_to_section
		end
	else
		@create_section_linked_list_non_root
		@add_back_to_section
	end

@add_back_to_section+=
linkedlist.push_back(sections[name].list, section)

@add_front_to_section+=
linkedlist.push_front(sections[name].list, section)

@create_section_linked_list_non_root+=
sections[name] = { root = false, list = {} }

@otherwise_just_save_section+=
else 
	@create_section_linked_list_root
	@add_back_to_section
end

@create_section_linked_list_root+=
sections[name] = { root = true, list = {} }

@set_section_as_current_section+=
curSection = section

@check_if_line_is_reference+=
elseif string.match(line, "^%s*@[^@]%S*%s*$") then
	@get_reference_name
	-- @check_that_sections_is_not_empty
	@create_line_reference
	@add_line_to_section

@get_reference_name+=
local _, _, prefix, name = string.find(line, "^(%s*)@(%S+)%s*$")
if name == nil then
	print(line)
end

@check_that_sections_is_not_empty+=
if sections[name] then
	hasSection = true
end

@script_variables+=
local LineType = {
	@line_types
}

@line_types+=
REFERENCE = 1,

@create_line_reference+=
local l = { 
	linetype = LineType.REFERENCE, 
	str = name,
	prefix = prefix
}

@otherwise_add_to_section+=
else
	@check_that_sections_is_not_empty
	@create_text_line
	@add_line_to_section
end

@line_types+=
TEXT = 2,

@create_text_line+=
local l = { 
	linetype = LineType.TEXT, 
	str = line 
}

@check_if_line_escape_double_at+=
if string.match(line, "^%s*@@") then
	local hasSection = false
	@check_that_sections_is_not_empty
	if hasSection then
		@create_text_line_without_at
		@add_line_to_section
	end

@create_text_line_without_at+=
local _,_,pre,post = string.find(line, '^(.*)@@(.*)$')
local text = pre .. "@" .. post
local l = { 
	linetype = LineType.TEXT, 
	str = text 
}

@add_line_to_section+=
linkedlist.push_back(curSection.lines, l)

@output_sections+=
if not filename then
	filename = vim.api.nvim_call_function("expand", { "%:p"})
end
local parendir = vim.api.nvim_call_function("fnamemodify", { filename, ":p:h" })
for name, section in pairs(sections) do
	if section.root then
		local fn
		@if_star_replace_with_current_filename
		@otherwise_put_node_name
		lines = {}
		@output_generated_header
		outputSections(lines, file, name, "")
		@check_file_is_modified
		@if_modified_write_file
	end
end

@if_star_replace_with_current_filename+=
if name == "*" then
	local tail = vim.api.nvim_call_function("fnamemodify", { filename, ":t:r" })
	fn = parendir .. "/tangle/" .. tail

@otherwise_put_node_name+=
else
	@if_has_slash_put_in_indicated_directory
	@otherwise_put_in_tangle_directory
end

@if_has_slash_put_in_indicated_directory+=
if string.find(name, "/") then
	fn = parendir .. "/" .. name

@otherwise_put_in_tangle_directory+=
else 
	fn = parendir .. "/tangle/" .. name
end

@declare_functions+=
local outputSections

@functions+=
function outputSections(lines, file, name, prefix, refs)
	@check_if_section_exists_otherwise_return_nil
	for section in linkedlist.iter(sections[name].list) do
		for line in linkedlist.iter(section.lines) do
			@if_line_is_text_output_it
			@if_reference_recursively_call_output
		end
	end
end

@check_if_section_exists_otherwise_return_nil+=
if not sections[name] then
	return
end

@if_line_is_text_output_it+=
if line.linetype == LineType.TEXT then
	lines[#lines+1] = prefix .. line.str
	@if_has_refs_save_lnum
end

@if_reference_recursively_call_output+=
if line.linetype == LineType.REFERENCE then
	outputSections(lines, file, line.str, prefix .. line.prefix, refs)
end

@functions+=
local function goto(filename, linenum, root_pattern)
	@clear_sections
	@read_file_line_by_line
	@select_based_on_pattern
	@fake_output_until_linenum_readched
	@go_to_line
end

@export_symbols+=
goto = goto,

@create_text_line+=
l.lnum = lnum

@create_line_reference+=
l.lnum = lnum

@create_text_line_without_at+=
l.lnum = lnum

@declare_functions+=
local getlinenum

@fake_output_until_linenum_readched+=
local startline = 1
@get_expanded_root_name
@skip_some_lines_if_generated_header
local _,lnum = getlinenum(root, startline, linenum)
assert(lnum, "Could not go to line " .. linenum .. " in " .. root)

@functions+=
function getlinenum(name, cur, goal)
	@check_if_section_exists_otherwise_return_with_cur
	for section in linkedlist.iter(sections[name].list) do
		for line in linkedlist.iter(section.lines) do
			@if_line_is_text_increment_and_verify_goal
			@if_reference_recursively_call_getlinenum
		end
	end
	return cur, nil
end

@check_if_section_exists_otherwise_return_with_cur+=
if not sections[name] then
	return cur, nil
end

@if_line_is_text_increment_and_verify_goal+=
if line.linetype == LineType.TEXT then
	if cur == goal then 
		return cur, line.lnum 
	end
	cur = cur + 1
end

@if_reference_recursively_call_getlinenum+=
if line.linetype == LineType.REFERENCE then
	local found
	cur, found = getlinenum(line.str, cur, goal)
	if found then 
		return cur, found 
	end
end

@go_to_line+=
vim.api.nvim_command("normal " .. lnum .. "gg")

@check_file_is_modified+=
local modified = false
do
	local f = io.open(fn, "r")
	if f then 
		modified = false
		@check_if_every_line_match
		f:close()
	else
		modified = true
	end
end

@check_if_every_line_match+=
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

@if_modified_write_file+=
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

@declare_functions+=
local toluapat

@functions+=
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

@select_based_on_pattern+=
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

@functions+=
local function collectSection()
	@clear_sections
	@read_file_line_by_line_from_buffer
	@get_section_name_of_current_line
	@collect_recursively_lines
	@save_current_buffer

	@create_buffer_if_not_existent
	@keymap_transpose_buffer
	@switch_to_buffer
	@clear_buffer
	@put_lines_in_buffer
	@remove_last_line_in_buffer
	@save_lines_for_navigation
	@jump_to_lines_in_transpose_buffer
end

@export_symbols+=
collectSection = collectSection,

@check_if_section_is_present+=
local s
for n, section in pairs(sections) do
	if n == name then
		s = section
		break
	end
end
if not s then return end

@declare_functions+=
local collectLines

@functions+=
function collectLines(name, lines, prefix, curnum)
	local jumpline
	@check_if_section_is_present
	@collect_every_line_in_section
	return jumpline
end

@collect_every_line_in_section+=
for section in linkedlist.iter(s.list) do
	for line in linkedlist.iter(section.lines) do
		if line.lnum == curnum then jumpline = #lines+1 end

		if line.linetype == LineType.TEXT then table.insert(lines, { line.lnum, prefix .. line.str })
		elseif line.linetype == LineType.REFERENCE then 
			jumpline = collectLines(line.str, lines, prefix .. line.prefix, curnum) or jumpline
		end
	end
end

@collect_recursively_lines+=
local lines = {}
@get_expanded_name_from_current_buffer
@output_generated_header_fake
local jumpline = collectLines(name, lines, "", curnum)

@script_variables+=
local lineRefs = {}

@save_line_reference+=
lineRefs[lnum] = curSection.str

@clear_sections+=
lineRefs = {}

@get_section_name_of_current_line+=
local curnum = vim.api.nvim_call_function("line", {"."})
local name = lineRefs[curnum]

@create_buffer_if_not_existent+=
local transpose_buf = vim.api.nvim_create_buf(false, true)
local old_ft = vim.api.nvim_buf_get_option(0, "ft")
if old_ft then
	vim.api.nvim_buf_set_option(transpose_buf, "ft", old_ft)
end
-- vim.api.nvim_buf_set_name(transpose_buf, "transpose")

@switch_to_buffer+=
vim.api.nvim_set_current_buf(transpose_buf)

@clear_buffer+=
vim.api.nvim_command("normal ggdG")

@put_lines_in_buffer+=
local lnumtr = 0
for _,line in ipairs(lines) do
	local lnum, text = unpack(line)
	vim.api.nvim_buf_set_lines(transpose_buf, lnumtr, lnumtr, false, { text })
	lnumtr = lnumtr + 1
end

@keymap_transpose_buffer+=
vim.api.nvim_buf_set_keymap(transpose_buf, 'n', '<leader>i', '<cmd>lua navigateTo()<CR>', {noremap = true})

@script_variables+=
local nagivationLines = {}

@save_current_buffer+=
local originbuf = vim.api.nvim_call_function("bufnr", {})
local curcol = vim.api.nvim_call_function("col", {"."})

@save_lines_for_navigation+=
navigationLines = {}
for _,line in ipairs(lines) do 
	local lnum, _ = unpack(line)
	navigationLines[#navigationLines+1] = { buf = originbuf, lnum = lnum }
end

@jump_to_lines_in_transpose_buffer+=
if jumpline then
	vim.api.nvim_call_function("cursor", { jumpline, curcol-1 })
end

@remove_last_line_in_buffer+=
vim.api.nvim_command("normal Gddgg")

@functions+=
local function getRootFilename()
	local filename = vim.api.nvim_call_function("expand", { "%:p"})
	local parendir = vim.api.nvim_call_function("fnamemodify", { filename, ":p:h" })

	@get_first_line_section_name
	@parse_section_name

	local fn
	@if_star_replace_with_current_filename
	@otherwise_put_node_name
	return fn
end

@get_first_line_section_name+=
local line = vim.api.nvim_buf_get_lines(0, 0, 1, true)[1]

@export_symbols+=
getRootFilename = getRootFilename,

@output_generated_header+=
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

@skip_some_lines_if_generated_header+=
if string.match(fn, "lua$") then
	startline = startline + 1
end

if string.match(fn, "vim$") then
	startline = startline + 1
end

@output_generated_header_fake+=
if string.match(fn, "lua$") then
	table.insert(lines, {1, "-- Generated from {relname} using ntangle.nvim"})
end

if string.match(fn, "vim$") then
	table.insert(lines, {1, "\" Generated from {relname} using ntangle.nvim"})
end

@get_expanded_root_name+=
local fn = root
if root == "*" then
	fn = vim.api.nvim_call_function("fnamemodify", { filename, ":t:r" })
end

@get_expanded_name_from_current_buffer+=
local fn = name
if name == "*" then
	local filename = vim.api.nvim_buf_get_name(0)
	fn = vim.api.nvim_call_function("fnamemodify", { filename, ":t:r" })
end

@export_symbols+=
attach_to_buf = attach_to_buf,

@functions+=
local function attach_to_buf(buf, client_id, language_id)
	@get_client_from_id
	vim.api.nvim_buf_attach(buf, true, {
		on_lines = function(_, buf, changedtick, firstline, lastline, new_lastline, old_byte_size)
			@get_lines_from_buffer
			@clear_sections
			@parse_tangle_lines
			@for_every_root_node_send_content_to_lsp_server
			@if_paren_send_signature_help
		end
	})
	vim.schedule(function()
		@get_lines_from_buffer
		@clear_sections
		@parse_tangle_lines
		@for_every_root_node_send_did_open_to_lsp_server
	end)
end

@get_lines_from_buffer+=
local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)

@for_every_root_node_send_content_to_lsp_server+=
if not filename then
	filename = vim.api.nvim_buf_get_name(buf)
end
local parendir = vim.api.nvim_call_function("fnamemodify", { filename, ":p:h" })
for name, section in pairs(sections) do
	if section.root then
		local fn
		@if_star_replace_with_current_filename
		@otherwise_put_node_name
		local lines = {}
		local refs = {}
		@output_generated_header
		@get_text_document_uri
		outputSections(lines, file, name, "", refs)
		@save_document_refs
		@send_new_content_to_lsp_server
	end
end

@get_text_document_uri+=
local uri = string.lower(vim.uri_from_fname(fn))

@get_client_from_id+=
local client = vim.lsp.get_client_by_id(client_id)
assert(client, "Could not find client_id")

@script_variables+=
events = {}

@send_new_content_to_lsp_server+=
client.notify("textDocument/didChange", {
	textDocument = {
	  uri = uri;
	  version = changedtick;
	};
	contentChanges = { {
		text = table.concat(lines, "\n")
	} }
})

@for_every_root_node_send_did_open_to_lsp_server+=
if not filename then
	filename = vim.api.nvim_buf_get_name(buf)
end
local parendir = vim.api.nvim_call_function("fnamemodify", { filename, ":p:h" })
for name, section in pairs(sections) do
	if section.root then
		local fn
		@if_star_replace_with_current_filename
		@otherwise_put_node_name
		local lines = {}
		local refs = {}
		@output_generated_header
		outputSections(lines, file, name, "", refs)
		@get_text_document_uri
		@save_document_refs
		@send_did_open_to_lsp_server
	end
end

@send_did_open_to_lsp_server+=
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

@functions+=
local function make_on_publish_diagnostics(buf)
	@get_uri_of_buffer
	return function(_, method, params, client_id)
		@convert_uri_to_tangle_buffer_uri
		@convert_line_numbers_to_tangle_line_numbers
		@call_builtin_on_publish_diagnostics_with_modified_params
	end
end

@export_symbols+=
make_on_publish_diagnostics = make_on_publish_diagnostics,

@get_uri_of_buffer+=
local uri = string.lower(vim.uri_from_bufnr(buf))

@convert_uri_to_tangle_buffer_uri+=
local remote_uri = params.uri
params.uri = uri

@if_has_refs_save_lnum+=
refs[#refs+1] = { string.len(prefix), line.lnum }

@script_variables+=
local document_lookup = {}

@save_document_refs+=
document_lookup[uri] = {buf, refs}

@convert_line_numbers_to_tangle_line_numbers+=
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

@call_builtin_on_publish_diagnostics_with_modified_params+=
vim.lsp.diagnostic.on_publish_diagnostics(_, method, params, client_id)

@export_symbols+=
document_lookup = document_lookup,

@script_variables+=
local buffer_lookup = {} -- reverse lookup of document_lookup

@clear_sections+=
buffer_lookup = {}

@if_has_refs_save_lnum+=
-- Note: actually there can be multiple source location 
-- which map to target different location. In the future
-- there would need
buffer_lookup[line.lnum] = buffer_lookup[line.lnum] or {}
table.insert(buffer_lookup[line.lnum], { string.len(prefix), refs, #refs }) -- only saves refs table reference

@functions+=
local function get_buffer_lookup() 
	return buffer_lookup
end

@export_symbols+=
get_buffer_lookup = get_buffer_lookup,

@script_variables+=
local active_clients = {}

@functions+=
local function register_client(buf, client_id)
	active_clients[buf] = client_id
end

@export_symbols+=
register_client = register_client,

@declare_functions+=
local buf_request

@functions+=
function buf_request(buf, method, params, handler)
	@get_client_from_buf
	@send_client_method
end

@get_client_from_buf+=
local client_id = active_clients[buf]
local client = vim.lsp.get_client_by_id(client_id)

@send_client_method+=
if client.supports_method(method) then
	client.request(method, params, handler, buf)
end

@functions+=
local function hover()
	local params = require("ntangle-lsp.util").make_position_params()
	local buf = vim.api.nvim_get_current_buf()
	buf_request(buf, 'textDocument/hover', params)
end

@export_symbols+=
hover = hover,

-- @functions+=
-- local function make_on_definition(buf)
-- 	@get_uri_of_buffer
-- 	return function(...)
-- 		table.insert(events, {...})
-- 		-- @convert_uri_to_tangle_buffer_uri
-- 		-- @convert_line_numbers_to_tangle_line_numbers
-- 		-- @call_builtin_on_publish_diagnostics_with_modified_params
-- 	end
-- end
-- 
-- @export_symbols+=
-- make_on_definition = make_on_definition,

@functions+=
local function definition()
	local params = require("ntangle-lsp.util").make_position_params()
	local buf = vim.api.nvim_get_current_buf()
	buf_request(buf, 'textDocument/definition', params)
end

@export_symbols+=
definition = definition,
make_location_handler = make_location_handler,

@functions+=
local function make_location_handler(buf)
	@get_uri_of_buffer
	return function(_, method, result)
		local converted = {}
		if not vim.tbl_islist(result) then result = { result } end

		for _, r in ipairs(result) do
			if document_lookup[string.lower(r.uri)] then
				@convert_uri_and_location
			end
		end

		@call_builtin_on_location_handler_with_modified_params
	end
end

@convert_uri_and_location+=
local remote_uri = string.lower(r.uri)
local buf, refs = unpack(document_lookup[remote_uri])

local offset_start, new_lnum_start = unpack(refs[r.range["start"].line+1])
local offset_end, new_lnum_end = unpack(refs[r.range["end"].line+1])

r.range["start"].character = r.range["start"].character - offset_start
r.range["end"].character = r.range["end"].character - offset_end

r.range["start"].line = new_lnum_start-1
r.range["end"].line = new_lnum_end-1

r.uri = vim.uri_from_bufnr(buf)

@call_builtin_on_location_handler_with_modified_params+=
vim.lsp.util.jump_to_location(result[1])

if #result > 1 then
	vim.lsp.util.set_qflist(vim.lsp.util.locations_to_items(result))
	vim.api.nvim_command("copen")
	vim.api.nvim_command("wincmd p")
end

@functions+=
local function declaration()
	local params = require("ntangle-lsp.util").make_position_params()
	local buf = vim.api.nvim_get_current_buf()
	buf_request(buf, 'textDocument/declaration', params)
end

@export_symbols+=
declaration = declaration,

@functions+=
local function type_definition()
	local params = require("ntangle-lsp.util").make_position_params()
	local buf = vim.api.nvim_get_current_buf()
	buf_request(buf, 'textDocument/typeDefinition', params)
end

@export_symbols+=
type_definition = type_definition,

@functions+=
local function implementation()
	local params = require("ntangle-lsp.util").make_position_params()
	local buf = vim.api.nvim_get_current_buf()
	buf_request(buf, 'textDocument/implementation', params)
end

@export_symbols+=
implementation = implementation,


@functions+=
local function start(lang)
	if not lang or lang == "cpp" then
		vim.schedule(function()
		vim.lsp.set_log_level("debug")
		@get_current_buffer_number
		@get_current_buffer_root_dir
		@create_lsp_client_with_clangd
		@wait_some_time
		@register_client
		@define_some_general_keybindings
		@attach_ntangle_lsp_to_buf
		end)
	end
end

@export_symbols+=
start = start,

@get_current_buffer_root_dir+=
local root_dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p:h")

@get_current_buffer_number+=
local bufnr = vim.fn.bufnr(0)

@create_lsp_client_with_clangd+=
local client_id = vim.lsp.start_client {
	cmd = { "clangd" },
	root_dir = root_dir,
	handlers = {
		["textDocument/publishDiagnostics"] = make_on_publish_diagnostics(bufnr),
		["textDocument/definition"] = make_location_handler(bufnr),
		["textDocument/declaration"] = make_location_handler(bufnr),
		["textDocument/typeDefinition"] = make_location_handler(bufnr),
		["textDocument/implementation"] = make_location_handler(bufnr),
	},
}

@wait_some_time+=
vim.wait(500)
print("LSP starting...")

@define_some_general_keybindings+=
vim.api.nvim_buf_set_keymap(bufnr, 'n', '<leader>j', '<cmd>lua require("ntangle-lsp").definition()<CR>', {noremap = true})
vim.api.nvim_buf_set_keymap(bufnr, 'n', 'K', '<cmd>lua require("ntangle-lsp").hover()<CR>', {noremap = true})

@attach_ntangle_lsp_to_buf+=
attach_to_buf(bufnr, client_id, "cpp")

@register_client+=
register_client(bufnr, client_id)

@if_paren_send_signature_help+=
-- Very! important to put in vim.schedule.
-- The cursor moves after on_lines event
-- thus we defer the signature help function
vim.schedule(function()
	if new_lastline - firstline == 1 then
		local curline = lines[firstline+1]
		local linelen = string.len(curline)
		local lastchar = string.sub(curline, linelen, linelen)
		if lastchar == "(" or lastchar == "," then
			local params = require("ntangle-lsp.util").make_position_params()
			local buf = vim.api.nvim_get_current_buf()
			buf_request(buf, 'textDocument/signatureHelp', params)
		end
	end
end)

-- @define_some_general_keybindings+=
-- vim.api.nvim_buf_set_keymap(bufnr, 'i', '<tab>', '<cmd>lua require("ntangle-lsp").completion()<CR>', {noremap = true})

@functions+=
local function completion()
	local params = require("ntangle-lsp.util").make_position_params()
	local buf = vim.api.nvim_get_current_buf()
	buf_request(buf, 'textDocument/completion', params)
end

@export_symbols+=
completion = completion,

@functions+=
local function buf_request_sync(buf, method, params)
	@get_client_from_buf
	@make_response_handler
	@send_client_method
	@wait_for_response_to_return
	@return_response_from_handler
end

@export_symbols+=
buf_request_sync = buf_request_sync,

@make_response_handler+=
local returned_result
local function handler(err, _, result, client_id)
	returned_result = result
end

@wait_for_response_to_return+=
local it = 0
local it_max = 100

while not returned_result and it < it_max do
	vim.wait(100)
	it = it + 1
end

@return_response_from_handler+=
return returned_result
