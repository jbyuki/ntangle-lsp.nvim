@../lua/ntangle-lsp/util.lua=

@functions

return {
	@export_symbols
}

@functions+=
local function make_position_params(pos, sel)
	@get_corresponding_line_and_col
	@get_corresponding_uri
	return { 
		textDocument = {uri = section_uri},
		position = {line = lnum, character = col},
	}
end

@export_symbols+=
make_position_params = make_position_params,

@get_corresponding_line_and_col+=
local row, col = unpack(pos)
local buffer_lookup = require("ntangle-lsp").get_buffer_lookup()
local prefix_len, refs, lnum = unpack(buffer_lookup[row][sel])
lnum = lnum-1
local line = vim.api.nvim_buf_get_lines(0, row-1, row, true)[1]
col = vim.str_utfindex(line, col) + prefix_len

@get_corresponding_uri+=
local section_uri
for uri, doc in pairs(require("ntangle-lsp").document_lookup) do
	local _, document_refs = unpack(doc)
	if refs == document_refs then
		section_uri = uri
	end
end

@functions+=
local function search_symbol(query)
	@do_lsp_search_query
	if results_lsp then
		@convert_symbols_to_qflist_and_unntangle
		@put_results_in_quickfix
	end
	@open_quickfix
end

@export_symbols+=
search_symbol = search_symbol,

@do_lsp_search_query+=
local params = {query = query}
local results_lsp = require("ntangle-lsp").buf_request_sync(vim.fn.bufnr("%"), "workspace/symbol", params)

@convert_symbols_to_qflist_and_unntangle+=
local qflist = {}
for _, symbol in ipairs(results_lsp) do
	local range = symbol.location.range
	local uri = string.lower(symbol.location.uri)
	local document_lookup = require"ntangle-lsp".document_lookup
	local kind = vim.lsp.util._get_symbol_kind_name(symbol.kind)

	if document_lookup[uri] then
		@get_line_and_document_from_tangle
		@make_qflist_entry
	else
		local filename = vim.uri_to_fname(uri)
		local lnum = range.start.line + 1
		local col = range.start.character + 1
		@make_qflist_entry
	end
end

@get_line_and_document_from_tangle+=
local buf, refs = unpack(document_lookup[symbol.location.uri])
local offset_start, new_lnum_start = unpack(refs[range.start.line+1])
local lnum = new_lnum_start+1
local col = range.start.character + 1 - offset_start
local filename = vim.api.nvim_buf_get_name(buf)

@make_qflist_entry+=
table.insert(qflist, {
	filename = filename,
	lnum = lnum,
	col = col,
	kind = kind,
	text = '['..kind..'] '..symbol.name
})

@put_results_in_quickfix+=
vim.fn.setqflist(qflist)

@open_quickfix+=
vim.api.nvim_command("copen")

@functions+=
local function get_candidates_position()
	@get_cursor_position
	@get_candidates_positions
	return {row, col}, candidates
end

@export_symbols+=
get_candidates_position = get_candidates_position,

@get_cursor_position+=
local row, col = unpack(vim.api.nvim_win_get_cursor(0))

@get_candidates_positions+=
local buffer_lookup = require("ntangle-lsp").get_buffer_lookup()
local candidates = {}
for _, c in ipairs(buffer_lookup[row]) do
	local _, _, lnum = unpack(c)
	table.insert(candidates, "L" .. lnum)
end

@export_symbols+=
get_candidates_position = get_candidates_position,
