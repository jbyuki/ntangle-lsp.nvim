##../ntangle_lsp
@declare_functions+=
local buf_request

@functions+=
function buf_request(method, params, handler)
	@get_client_from_buf
	@send_client_method
end

@get_client_from_buf+=
local client_id = client_clangd
local client = vim.lsp.get_client_by_id(client_id)

@send_client_method+=
if client.supports_method(method) then
	local buf = vim.api.nvim_get_current_buf()
	client.request(method, params, handler, buf)
end

@functions+=
local function hover()
	local pos, candidates = get_candidates_position()

	local function action(sel)
		local params = make_position_params(pos, candidates, sel)
		buf_request('textDocument/hover', params)
	end

	@do_action_and_open_context_menu_if_multiple_choices
end

@export_symbols+=
hover = hover,

@declare_functions+=
local make_position_params

@functions+=
function make_position_params(pos, candidates, sel)
	@get_corresponding_line_and_col
	@get_corresponding_uri
	return { 
		textDocument = {uri = root_uri},
		position = {line = lnum, character = col},
	}
end

@get_corresponding_line_and_col+=
local row, col = unpack(pos)
local c = candidates[sel]
local lnum = c.lnum-1
local line = vim.api.nvim_get_current_line()
col = vim.str_utfindex(line, col) + c.offset

@get_corresponding_uri+=
local root_uri = c.root_uri

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
local uri = get_uri(0)
local candidates = {}
for root_uri, meta in pairs(genmeta) do
	for lnum, info in ipairs(meta) do
		if info.part == uri and info.lnum == row then
			@add_candidate_position
		end
	end
end

@add_candidate_position+=
table.insert(candidates, {
	root_uri = root_uri,
	lnum = lnum,
	offset = info.offset,
})

@do_action_and_open_context_menu_if_multiple_choices+=
if #candidates > 1 then
	@make_candidates_text
	contextmenu_open(candidates_str,
		function(sel) 
			action(sel)
		end
	)
else
	action(1)
end

@make_candidates_text+=
local candidates_str = {}
for _, c in ipairs(candidates) do
	table.insert(candidates_str, c.root_uri .. " " .. c.lnum)
end
