##../ntangle_lsp
@declare_functions+=
local make_on_publish_diagnostics

@functions+=
function make_on_publish_diagnostics(buf)
	@get_uri_of_buffer
	return function(_, method, params, client_id)
		@convert_uri_to_tangle_buffer_uri
		@convert_line_numbers_to_tangle_line_numbers
		@call_builtin_on_publish_diagnostics_with_modified_params
	end
end

@client_handlers+=
["textDocument/publishDiagnostics"] = make_on_publish_diagnostics(bufnr),

@get_uri_of_buffer+=
local uri = string.lower(vim.uri_from_bufnr(buf))

@convert_uri_to_tangle_buffer_uri+=
local remote_uri = params.uri
params.uri = uri

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
