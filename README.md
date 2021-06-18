ntangle-lsp
===========

LSP + Literate Programming([ntangle](https://github.com/jbyuki/ntangle.nvim)) Possible?

**Note:** This is still in experimental stage. It's meant to test the feasability of such plugin.

<img src="https://i.postimg.cc/Kz3JJCMW/Capture.png" width="300">

Install
-------

Install using a plugin manager such as [vim-plug](https://github.com/junegunn/vim-plug).

```lua
Plug 'jbyuki/ntangle-ts.nvim' -- provides incremental tangling
Plug 'neovim/nvim-lspconfig' -- provides lsp server configs

Plug 'jbyuki/ntangle-lsp.nvim'
```

Config
------

```lua
lua << EOF
require"ntangle-lsp".setup {
  mappings = {
    ["K"] = require"ntangle-lsp".hover,
    ["gd"] = require"ntangle-lsp".definition,
  },
}
EOF
```
