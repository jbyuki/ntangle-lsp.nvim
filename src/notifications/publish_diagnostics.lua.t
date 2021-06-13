##../ntangle-lsp
@lsp_handlers+=
handlers["textDocument/publishDiagnostics"] = function(params)
  if attached[params.uri] then
    @clear_diagnostics
    @convert_uri_publish_diagnostics
    @convert_tangled_lnums
    @display_virtual_text_diagnostics
  end
end

@script_variables+=
local diag_ns = vim.api.nvim_create_namespace("")

@clear_diagnostics+=
vim.api.nvim_buf_clear_namespace(0, diag_ns, 0, -1)

@convert_uri_publish_diagnostics+=
local fname = vim.uri_to_fname(params.uri)
fname = fname:gsub("\\", "/")

@convert_tangled_lnums+=
local messages = {}
all_messages[fname] = messages
for _, diag in ipairs(params.diagnostics) do
  local lnum_start = diag.range["start"].line+1
  print("diag", lnum_start)
  lnum_start = require"ntangle-ts".reverse_lookup(fname, lnum_start)
  if lnum_start then
    @append_text_diagnostics
  end
end

@script_variables+=
local all_messages = {}

@append_text_diagnostics+=
messages[lnum_start-1] = messages[lnum_start-1] or {}
table.insert(messages[lnum_start-1], diag)

@display_virtual_text_diagnostics+=
local lcount = vim.api.nvim_buf_line_count(0)
for lnum, msgs in pairs(messages) do
  local chunk = vim.lsp.diagnostic.get_virtual_text_chunks_for_line(0, lnum, msgs, {})
  if lnum < lcount then
    vim.api.nvim_buf_set_extmark(0, diag_ns, lnum, 0, {
      virt_text = chunk,
    })
  end
end
