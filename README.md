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


Usage
-----

Now only works for C++ (for testing purposes).
When opening a `.cpp.tl` file, execute `:LspCPP`.

Custom Handlers
---------------

* [ ] callHierarchy/incomingCalls
* [ ] callHierarchy/outgoingCalls
* [ ] textDocument/codeAction
* [ ] textDocument/completion
* [x] textDocument/declaration
* [x] textDocument/definition
* [ ] textDocument/documentHighlight
* [ ] textDocument/documentSymbol
* [ ] textDocument/formatting
* [x] textDocument/hover
* [x] textDocument/implementation
* [x] textDocument/publishDiagnostics
* [ ] textDocument/rangeFormatting
* [ ] textDocument/references
* [ ] textDocument/rename
* [x] textDocument/signatureHelp
* [x] textDocument/typeDefinition
* [ ] window/logMessage
* [ ] window/showMessage
* [ ] workspace/applyEdit
* [ ] workspace/symbol
