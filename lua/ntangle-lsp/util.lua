-- Generated from util.lua.tl using ntangle.nvim

local function make_position_params()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	
	local buffer_lookup = require("ntangle-lsp").get_buffer_lookup()
	local prefix_len, refs, lnum = unpack(buffer_lookup[row][1])
	lnum = lnum-1
	local line = vim.api.nvim_buf_get_lines(0, row-1, row, true)[1]
	col = vim.str_utfindex(line, col) + prefix_len
	
	local section_uri
	for uri, doc in pairs(require("ntangle-lsp").document_lookup) do
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


return {
	make_position_params = make_position_params,
	
}

