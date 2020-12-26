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

local function search_symbol(query)
	local params = {query = query}
	local results_lsp = require("ntangle-lsp").buf_request_sync(vim.fn.bufnr("%"), "workspace/symbol", params)
	
	if results_lsp then
		local qflist = {}
		for _, symbol in ipairs(results_lsp) do
			local range = symbol.location.range
			local uri = string.lower(symbol.location.uri)
			local document_lookup = require"ntangle-lsp".document_lookup
			local kind = vim.lsp.util._get_symbol_kind_name(symbol.kind)
		
			if document_lookup[uri] then
				local buf, refs = unpack(document_lookup[symbol.location.uri])
				local offset_start, new_lnum_start = unpack(refs[range.start.line+1])
				local lnum = new_lnum_start+1
				local col = range.start.character + 1 - offset_start
				local filename = vim.api.nvim_buf_get_name(buf)
				
				table.insert(qflist, {
					filename = filename,
					lnum = lnum,
					col = col,
					kind = kind,
					text = '['..kind..'] '..symbol.name
				})
				
			else
				local filename = vim.uri_to_fname(uri)
				local lnum = range.start.line + 1
				local col = range.start.character + 1
				table.insert(qflist, {
					filename = filename,
					lnum = lnum,
					col = col,
					kind = kind,
					text = '['..kind..'] '..symbol.name
				})
				
			end
		end
		
		vim.fn.setqflist(qflist)
		
	end
	vim.api.nvim_command("copen")
end


return {
	make_position_params = make_position_params,
	
	search_symbol = search_symbol,
	
}

