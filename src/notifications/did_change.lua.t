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
function M.on_change(buf, fname, 
    _, _, _,
    start_row, _,
    old_row, _,
    new_row, new_end_col, 
    lines)
  @get_client_rpc
  -- print(fname, start_row, old_row, new_row, vim.inspect(lines))
  if rpc then
    local did_change = function()
      @increment_document_version
      @send_did_change
      @reset_changes
    end

    @get_linecount_fname
    @append_changes
    @change_lcount
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

local changed_range
if start_row >= lc then
  if start_row == 0 then
    @append_newline_firstline
  else
    @append_newline_at_end_of_file
  end
elseif new_row == 0 then
  @delete_line_change
else
  changed_range = {
    range = {
      -- +1 is caused by the generated header
      start = { line = start_row, character = 0},
      ["end"] = { line = start_row+old_row, character = 0}
    },
    text = new_text,
  }
end

changes[fname] = changes[fname] or {}

if changed_range then
  table.insert(changes[fname], changed_range)
end

@append_newline_firstline+=
changed_range = {
  range = {
    -- +1 is caused by the generated header
    start = { line = 0, character = 0 },
    ["end"] = { line = 0, character = 0 }
  },
  text = new_text,
}


@append_newline_at_end_of_file+=
local _, _, line = require"ntangle-ts".reverse_lookup(fname, start_row)
local col = vim.str_utfindex(line)

changed_range = {
  range = {
    -- +1 is caused by the generated header
    start = { line = start_row-1, character = col },
    ["end"] = { line = start_row-1, character = col }
  },
  text = new_text,
}

@delete_line_change+=
local _, _, pline = require"ntangle-ts".reverse_lookup(fname, start_row)
local _, _, line = require"ntangle-ts".reverse_lookup(fname, start_row+1)

local pcol = vim.str_utfindex(pline)
local col = vim.str_utfindex(line)

changed_range = {
  range = {
    -- +1 is caused by the generated header
    start = { line = start_row-1, character = pcol },
    ["end"] = { line = start_row, character = col }
  },
  text = "",
}

@send_did_change+=
local uri = vim.uri_from_fname(fname)
local params = {
  textDocument = {
    uri = uri,
    version = version,
  },
  contentChanges = changes[fname],
}

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
  M.send_pending()
  @close_any_signature_help
end

@implement+=
function M.send_pending()
  for _, cbs in ipairs(changes_cbs) do
    cbs()
  end
  changes_cbs = {}
end

@script_variables+=
local lcount = {}

@save_line_count+=
lcount[filename] = #lines

@get_linecount_fname+=
local lc = lcount[fname]

@change_lcount+=
if lc then
  if new_row == 1 then
    lc = lc + 1
  else
    lc = lc - 1
  end
  lcount[fname] = lc
end
