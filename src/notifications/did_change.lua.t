##../ntangle-lsp
@script_variables+=
local tick = {}

@init_document_version+=
tick[filename] = 10

@increment_document_version+=
local version = tick[fname]
version =  version + 1
tick[fname] = version

@implement+=
function M.on_change(fname, start_byte, old_byte, new_byte,
    start_row, start_col,
    old_row, old_end_col,
    new_row, new_end_col, lines)
  @get_client_rpc
  if rpc then
    local did_change = function()
      @increment_document_version
      @send_did_change
      @reset_changes
    end

    @append_changes
    @if_not_insert_mode_send_immediatly
    @add_callback_if_not_added
  end
end

@get_client_rpc+=
local rpc = clients[fname]

@script_variables+=
local changes = {}

@append_changes+=
local new_text = ""
if new_row == 1 then
  new_text = lines[1] .. "\n"
end

local changed_range = {
  range = {
    -- +1 is caused by the generated header
    start = { line = start_row, character = 0},
    ["end"] = { line = start_row+old_row, character = 0}
  },
  text = new_text,
}

changes[fname] = changes[fname] or {}

table.insert(changes[fname], changed_range)

@send_did_change+=
local uri = vim.uri_from_fname(fname)
local params = {
  textDocument = {
    uri = uri,
    version = version,
  },
  contentChanges = changes[fname],
}

print(vim.inspect(params))

rpc.notify("textDocument/didChange", params)

@reset_changes+=
changes[fname] = {}

@if_not_insert_mode_send_immediatly+=
local mode = vim.api.nvim_get_mode()
if mode.mode ~= "i" then
  did_change()
end

@script_variables+=
local changes_cbs = {}

@add_callback_if_not_added+=
if #changes[fname] == 1 then
  table.insert(changes_cbs, did_change)
end

@start_ntangle_lsp_autocommands+=
vim.api.nvim_command [[augroup ntanglelsp]]
vim.api.nvim_command [[autocmd!]]

@end_ntangle_lsp_autocommands+=
vim.api.nvim_command [[augroup END]]

@register_insert_exit_autocommand+=
vim.api.nvim_command [[autocmd InsertLeave *.t lua require"ntangle-lsp".insert_leave()]]

@implement+=
function M.insert_leave()
  for _, cbs in ipairs(changes_cbs) do
    cbs()
  end
  changes_cbs = {}
end
