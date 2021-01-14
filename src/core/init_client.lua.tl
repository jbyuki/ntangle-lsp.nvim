##../ntangle_lsp
@functions+=
local function start(lang)
	if not lang or lang == "cpp" then
		vim.schedule(function()
		vim.lsp.set_log_level("debug")
		@get_current_buffer_number
		@get_current_buffer_root_dir
		@create_lsp_client_with_clangd
		@wait_some_time
		@register_client
		@define_some_general_keybindings
		@attach_ntangle_lsp_to_buf
		end)
	end
end

@export_symbols+=
start = start,

@get_current_buffer_root_dir+=
local root_dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p:h")

@get_current_buffer_number+=
local bufnr = vim.fn.bufnr(0)

@create_lsp_client_with_clangd+=
local client_id = vim.lsp.start_client {
	cmd = { "clangd" },
	root_dir = root_dir,
	handlers = {
		@client_handlers
		-- ["textDocument/definition"] = make_location_handler(bufnr),
		-- ["textDocument/declaration"] = make_location_handler(bufnr),
		-- ["textDocument/typeDefinition"] = make_location_handler(bufnr),
		-- ["textDocument/implementation"] = make_location_handler(bufnr),
	},
}

@wait_some_time+=
vim.wait(500)
print("LSP starting...")

@define_some_general_keybindings+=
vim.api.nvim_buf_set_keymap(bufnr, 'n', '<leader>j', '<cmd>lua require("ntangle-lsp").definition()<CR>', {noremap = true})
vim.api.nvim_buf_set_keymap(bufnr, 'n', 'K', '<cmd>lua require("ntangle-lsp").hover()<CR>', {noremap = true})

@attach_ntangle_lsp_to_buf+=
attach_to_buf(bufnr, client_id, "cpp")

@register_client+=
register_client(bufnr, client_id)

@script_variables+=
local active_clients = {}

@declare_functions+=
local register_client

@functions+=
function register_client(buf, client_id)
	active_clients[buf] = client_id
end
