##../ntangle-lsp
@attach_signature_help_callback+=
vim.api.nvim_buf_attach(0, true, { 
  on_bytes = function(_, _, _, 
    start_row, start_col, start_byte,
    end_row, end_col, end_byte,
    new_end_row, new_end_col, new_end_byte) 
    @skip_if_not_insert_single_char

    @get_inserted_char
    @if_close_paren_close_signature_window
    @if_char_match_trigger_send_signature_help
  end
})

@skip_if_not_insert_single_char+=
if not (end_byte == 0 and new_end_byte == 1) then
  return
end

@get_inserted_char+=
local line = vim.api.nvim_buf_get_lines(0, start_row, start_row+1, true)[1]
local c = line:sub(start_col+1,start_col+1)

@if_char_match_trigger_send_signature_help+=
local match = false
for _, t in ipairs(resolved_capabilities.signature_help_trigger_characters) do
  if c == t then
    match = true
  end
end

if match then
  vim.schedule(function()
    @send_pending_changes
    @make_position_params
    @send_signature_help
  end)
end

@send_pending_changes+=
M.send_pending()

@make_position_params+=
local params = M.make_position_param()

@implement+=
function M.make_position_param()
  @get_window_cursor_position
  @convert_to_tangled_position
  @create_position_param_structure
  return params
end

@get_window_cursor_position+=
local row, col = unpack(vim.api.nvim_win_get_cursor(0))
local buf = vim.api.nvim_get_current_buf()

@convert_to_tangled_position+=
local lnum, prefix_len, filename = require"ntangle-ts".lookup(buf, row)

@create_position_param_structure+=
local line = vim.api.nvim_buf_get_lines(0, row-1, row, true)[1]
local char = 0
if line then
  char = vim.str_utfindex(line, col)
end

local params = {
  textDocument = {
    uri = vim.uri_from_fname(filename),
  },
  position = {
    line = lnum - 1,
    character = char + prefix_len,
  }
}

@send_signature_help+=
rpc.request("textDocument/signatureHelp", params, function(_, result)
  if result then
    @pick_last_signature
    @get_window_cursor_position
    @position_signature_help_on_cursor_or_old
    @create_signature_help_window
    @highlight_active_parameter
    @if_already_open_replace_signature_window
  end
end)

@position_signature_help_on_cursor_or_old+=
local win_row, win_col
if signature_row and signature_col then
  win_row = signature_row
  win_col = signature_col
else
  win_row = row
  win_col = col + 4
end
signature_row, signature_col  = win_row, win_col 

@script_variables+=
local signature_win
local signature_row, signature_col

@pick_last_signature+=
local sigs = result.signatures
local sig = sigs[#sigs]

@create_signature_help_window+=
local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(buf, 0, -1, true, { sig.label })

local new_signature_win = vim.api.nvim_open_win(buf, false,{
  relative = "win",
  win = vim.api.nvim_get_current_win(),
  row = win_row,
  col = win_col,
  width = string.len(sig.label),
  height = 1,
  style = "minimal",
  border = "single",
})

@highlight_active_parameter+=
local ns = vim.api.nvim_create_namespace("")
local active = sig.activeParameter or 1
active = math.max(active, 1)
if sig.parameters then
  if sig.parameters[active] and sig.parameters[active].label then
    local col = sig.parameters[active].label
    vim.api.nvim_buf_set_extmark(buf, ns, 0, col[1], {
      hl_group = "Cursor",
      end_col = col[2],
    })
  end
end

@if_already_open_replace_signature_window+=
if signature_win then
  vim.api.nvim_win_close(signature_win, true)
end
signature_win = new_signature_win

@close_any_signature_help+=
if signature_win then
  vim.api.nvim_win_close(signature_win, true)
  signature_win = nil
  signature_row = nil
  signature_col = nil
end

@if_close_paren_close_signature_window+=
if c == ')' then
  vim.schedule(function()
    @close_any_signature_help
  end)
end
