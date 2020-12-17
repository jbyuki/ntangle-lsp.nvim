@../lua/ntangle-lsp/util.lua=
@requires
@script_variables

@declare_functions
@functions

return {
	@export_symbols
}

@functions+=
local function make_position_params()
	@get_cursor_position
	@get_corresponding_line_and_col
	@get_corresponding_uri
	return { 
		textDocument = {uri = section_uri},
		position = {line = lnum, character = col},
	}
end

@export_symbols+=
make_position_params = make_position_params,

@get_cursor_position+=
local row, col = unpack(vim.api.nvim_win_get_cursor(0))

@get_corresponding_line_and_col+=
local buffer_lookup = require("ntangle-lsp").get_buffer_lookup()
local prefix_len, refs, lnum = unpack(buffer_lookup[row][1])
lnum = lnum-1
local line = vim.api.nvim_buf_get_lines(0, row-1, row, true)[1]
col = vim.str_utfindex(line, col) + prefix_len

@get_corresponding_uri+=
local section_uri
for uri, document_refs in pairs(require("ntangle-lsp").document_lookup) do
	if refs == document_refs then
		section_uri = uri
	end
end
