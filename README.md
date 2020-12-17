ntangle-lsp
===========

LSP + Literate Programming([ntangle](https://github.com/jbyuki/ntangle.nvim)) Possible?

**Note:** This is still in experimental stage. It's meant to test the feasability of such plugin.

Install
-------

Install using a plugin manager such as [vim-plug](https://github.com/junegunn/vim-plug).

```
Plug 'jbyuki/ntangle-lsp.nvim'
```


Test Script
-----------

This script can be used to attach an LSP client to a buffer for a `clangd` language server.
Insert the correct buffer number in the `bufnr` local variable.

Note: This is just a test script. Please don't judge its quality.

```lua
local bufnr = 1
vim.schedule(function()
local client_id = vim.lsp.start_client {
	cmd = { "clangd" },
	root_dir = ".",
	handlers = {
		["textDocument/publishDiagnostics"] = require("ntangle-lsp").make_on_publish_diagnostics(bufnr),
	},
}

require("ntangle-lsp").register_client(bufnr, client_id)

vim.api.nvim_buf_set_keymap(bufnr, 'n', 'K', '<cmd>lua require("ntangle-lsp").hover()<CR>', {noremap = true})
vim.wait(500)
vim.lsp.set_log_level("debug")
require("ntangle-lsp").attach_to_buf(bufnr, client_id, "cpp")
end)
```

Custom Handlers
---------------

* [ ] callHierarchy/incomingCalls
* [ ] callHierarchy/outgoingCalls
* [ ] textDocument/codeAction
* [ ] textDocument/completion
* [ ] textDocument/declaration
* [ ] textDocument/definition
* [ ] textDocument/documentHighlight
* [ ] textDocument/documentSymbol
* [ ] textDocument/formatting
* [x] textDocument/hover
* [ ] textDocument/implementation
* [x] textDocument/publishDiagnostics
* [ ] textDocument/rangeFormatting
* [ ] textDocument/references
* [ ] textDocument/rename
* [ ] textDocument/signatureHelp
* [ ] textDocument/typeDefinition
* [ ] window/logMessage
* [ ] window/showMessage
* [ ] workspace/applyEdit
* [ ] workspace/symbol
