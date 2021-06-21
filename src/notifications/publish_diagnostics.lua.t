##../ntangle-lsp
@lsp_handlers+=
handlers["textDocument/publishDiagnostics"] = function(params)
  @get_current_buf
  @postpone_if_insert_mode
  if attached[params.uri] then
    @create_diagnostics_namespace_if_none
    @clear_diagnostics
    @convert_uri_publish_diagnostics
    @convert_tangled_lnums
    @display_virtual_text_diagnostics
  end
end

@get_current_buf+=
local buf = vim.api.nvim_get_current_buf()

@script_variables+=
local diag_ns = {}

@create_diagnostics_namespace_if_none+=
if not diag_ns[params.uri] then
  diag_ns[params.uri] = vim.api.nvim_create_namespace("")
end
local ns = diag_ns[params.uri]

@clear_diagnostics+=
vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)

@convert_uri_publish_diagnostics+=
local fname = vim.uri_to_fname(params.uri)
fname = fname:gsub("\\", "/")

@convert_tangled_lnums+=
local messages = {}
for _, diag in ipairs(params.diagnostics) do
  local lnum_start = diag.range["start"].line+1
  local lookup_buf
  local lc = lcount[fname]
  if lc then
    lnum_start = math.min(lc, lnum_start)
  end
  lnum_start, lookup_buf = require"ntangle-ts".reverse_lookup(fname, lnum_start)
  if lnum_start and lookup_buf == buf then
    @append_text_diagnostics
  end
end

@append_text_diagnostics+=
messages[lnum_start-1] = messages[lnum_start-1] or {}
table.insert(messages[lnum_start-1], diag)

@display_virtual_text_diagnostics+=
local lcount = vim.api.nvim_buf_line_count(0)
for lnum, msgs in pairs(messages) do
  local chunk = vim.lsp.diagnostic.get_virtual_text_chunks_for_line(0, lnum, msgs, {})
  if lnum < lcount then
    vim.api.nvim_buf_set_extmark(0, ns, lnum, 0, {
      virt_text = chunk,
    })
  else
    vim.api.nvim_buf_set_extmark(0, ns, lcount-1, 0, {
      virt_text = chunk,
    })
  end
end

@postpone_if_insert_mode+=
local mode = vim.api.nvim_get_mode()
if mode.mode == "i" then
  return
end
