##../ntangle_lsp
@functions+=
local function start(lang)
	if not lang or lang == "cpp" then
		vim.lsp.set_log_level("debug")
		@create_lsp_client_with_clangd
		@register_client_for_language
	end
end

@export_symbols+=
start = start,

@create_lsp_client_with_clangd+=
local client_id = vim.lsp.start_client {
	cmd = { "clangd" },
	root_dir = ".",
	handlers = {
		@client_handlers
		-- ["textDocument/definition"] = make_location_handler(bufnr),
		-- ["textDocument/declaration"] = make_location_handler(bufnr),
		-- ["textDocument/typeDefinition"] = make_location_handler(bufnr),
		-- ["textDocument/implementation"] = make_location_handler(bufnr),
	},
}

@script_variables+=
-- this is all for experimentation purposes...
local client_clangd

@register_client_for_language+=
client_clangd = client_id
