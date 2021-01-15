##../ntangle_lsp
@functions+=
local function buf_attach()
	local client_id = client_clangd
	assert(client_id, "No active clangd client!")
	@get_current_buffer_number
	@define_some_general_keybindings
	@attach_ntangle_lsp_to_buf
	@register_client
end

@export_symbols+=
buf_attach = buf_attach,

@get_current_buffer_number+=
local bufnr = vim.fn.bufnr()

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
	-- atm only one client per buffer possible
	active_clients[buf] = client_id
end
