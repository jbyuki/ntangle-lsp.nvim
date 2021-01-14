##../ntangle_lsp
@declare_functions+=
local make_on_publish_diagnostics

@functions+=
function make_on_publish_diagnostics()
	return function(_, method, params, client_id)
		@get_tangled_meta_info
		local new_params = {}
		@uri_of_current_buffer
		for _, diag in ipairs(params.diagnostics) do
			@convert_line_number_tangled_line_numbers
			@build_params_structure_to_pass_to_publish_diagnostics_if_current_buffer
		end
		@call_builtin_on_publish_diagnostics_with_modified_params
	end
end

@client_handlers+=
["textDocument/publishDiagnostics"] = make_on_publish_diagnostics(),

@get_tangled_meta_info+=
local meta = genmeta[params.uri]

@convert_line_number_tangled_line_numbers+=
local line_start_gen = diag.range["start"].line+1
local line_end_gen = diag.range["end"].line+1

local offset_start = meta[line_start_gen].offset
local offset_end = meta[line_end_gen].offset

diag.range["start"].character = diag.range["start"].character - offset_start
diag.range["end"].character = diag.range["end"].character - offset_end

diag.range["start"].line = meta[line_start_gen].lnum-1
diag.range["end"].line = meta[line_end_gen].lnum-1

@uri_of_current_buffer+=
new_params.uri = vim.uri_from_bufnr(0)

@build_params_structure_to_pass_to_publish_diagnostics_if_current_buffer+=
new_params.diagnostics = new_params.diagnostics or {}
local part = meta[line_start_gen].part
if part == vim.api.nvim_buf_get_name(0) then
	table.insert(new_params.diagnostics, diag)
end

@call_builtin_on_publish_diagnostics_with_modified_params+=
vim.lsp.diagnostic.on_publish_diagnostics(_, method, new_params, client_id)
