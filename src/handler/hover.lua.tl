##../ntangle_lsp
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
	local pos, candidates = get_candidates_position()

	local function action(sel)
		local params = make_position_params(pos, sel)
		local buf = vim.api.nvim_get_current_buf()
		buf_request(buf, 'textDocument/hover', params)
	end

	@do_action_and_open_context_menu_if_multiple_choices
end

@export_symbols+=
hover = hover,

@declare_functions+=
local make_position_params

@functions+=
function make_position_params(pos, sel)
	@get_corresponding_line_and_col
	@get_corresponding_uri
	return { 
		textDocument = {uri = section_uri},
		position = {line = lnum, character = col},
	}
end

@get_corresponding_line_and_col+=
local row, col = unpack(pos)
local prefix_len, refs, lnum = unpack(buffer_lookup[row][sel])
lnum = lnum-1
local line = vim.api.nvim_buf_get_lines(0, row-1, row, true)[1]
col = vim.str_utfindex(line, col) + prefix_len

@get_corresponding_uri+=
local section_uri
for uri, doc in pairs(document_lookup) do
	local _, document_refs = unpack(doc)
	if refs == document_refs then
		section_uri = uri
	end
end

@declare_functions+=
local get_candidates_position

@functions+=
function get_candidates_position()
	@get_cursor_position
	@get_candidates_positions
	return {row, col}, candidates
end

@get_cursor_position+=
local row, col = unpack(vim.api.nvim_win_get_cursor(0))

@get_candidates_positions+=
local candidates = {}
for _, c in ipairs(buffer_lookup[row]) do
	local _, _, lnum = unpack(c)
	print("candidate " .. lnum)
	table.insert(candidates, "L" .. lnum)
end

@do_action_and_open_context_menu_if_multiple_choices+=
if #candidates > 1 then
	contextmenu_open(candidates,
		function(sel) 
			action(sel)
		end
	)
else
	action(1)
end

@script_variables+=
local buffer_lookup = {} -- reverse lookup of document_lookup

@clear_sections+=
buffer_lookup = {}

@save_also_reverse_lookup+=
local rel = line.lnum - buffer_offset
buffer_lookup[rel] = buffer_lookup[rel] or {}
table.insert(buffer_lookup[rel], { string.len(prefix), refs, #refs }) -- only saves refs table reference
