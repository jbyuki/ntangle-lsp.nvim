##../ntangle_lsp
@functions+=
local function definition()
	local pos, candidates = get_candidates_position()

	local function action(sel)
		local params = make_position_params(pos, candidates, sel)
		buf_request('textDocument/definition', params)
	end

	@do_action_and_open_context_menu_if_multiple_choices
end

@client_handlers+=
["textDocument/definition"] = make_location_handler(),

@export_symbols+=
definition = definition,
make_location_handler = make_location_handler,

@functions+=
local function make_location_handler()
	return function(_, method, result)
		if not vim.tbl_islist(result) then result = { result } end

		for _, r in ipairs(result) do
			if genmeta[r.uri] then
				-- @convert_uri_and_location
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
