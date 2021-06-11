##../ntangle-lsp
@lsp_handlers+=
handlers["textDocument/publishDiagnostics"] = function(params)
  @clear_diagnostics
  @convert_uri_publish_diagnostics
  @convert_tangled_lnums
  @display_virtual_text_diagnostics
  @call_native_publish_diagnostics
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
for _, diag in ipairs(params.diagnostics) do
  print(vim.inspect(diag))
  local lnum_start = diag.range["start"].line
  lnum_start = require"ntangle-ts".reverse_lookup(fname, lnum_start)
  if lnum_start then
    @append_text_diagnostics
  end
end

@append_text_diagnostics+=
messages[lnum_start-1] = messages[lnum_start-1] or {}
table.insert(messages[lnum_start-1], diag)

@display_virtual_text_diagnostics+=
for lnum, msgs in pairs(messages) do
  local chunk = vim.lsp.diagnostic.get_virtual_text_chunks_for_line(0, lnum, msgs, {})
  vim.api.nvim_buf_set_extmark(0, diag_ns, lnum, 0, {
    virt_text = chunk,
  })
end
