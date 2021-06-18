##../ntangle-lsp
@implement+=
function M.hover()
  local buf = vim.api.nvim_get_current_buf()
  @get_client_rpc
  @send_pending_changes
  @make_position_params
  @send_hover_request
end

@send_hover_request+=
rpc.request("textDocument/hover", params, function(_, result)
  if result then
    @create_buf_buffer
    @fill_buf_with_hover
    @create_hover_window
    @close_hover_window_on_move
  end
end)

@create_buf_buffer+=
local buf = vim.api.nvim_create_buf(false, true)

@fill_buf_with_hover+=
local lines = vim.split(result.contents.value, "\n")
vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)
vim.api.nvim_buf_set_option(buf, "ft", "markdown")

@create_hover_window+=
local max_width = 0
@compute_max_width

local win_hover = vim.api.nvim_open_win(buf, false, {
  relative = "cursor",
  row = 1,
  col = 0,
  width = math.min(max_width, 100),
  height = 20,
  style = "minimal",
  border = "single",
})

@compute_max_width+=
for _, line in ipairs(lines) do
  max_width = math.max(vim.api.nvim_strwidth(line), max_width)
end

@implement+=
function M.close_preview_autocmd(events, winnr)
  vim.api.nvim_command("autocmd "..table.concat(events, ',').." <buffer> ++once lua pcall(vim.api.nvim_win_close, "..winnr..", true)")
end

@close_hover_window_on_move+=
M.close_preview_autocmd({"CursorMoved", "CursorMovedI", "BufHidden", "BufLeave"}, win_hover)
