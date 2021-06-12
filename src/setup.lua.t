##ntangle-lsp
@implement+=
function M.setup(opts)
  @verify_ntangle_ts_is_installed
  @setup_ntangle_ts_callback
  @start_ntangle_lsp_autocommands
  @register_insert_exit_autocommand
  @end_ntangle_lsp_autocommands
end

@verify_ntangle_ts_is_installed+=
local succ = pcall(require, "ntangle-ts")
assert(succ, [[ntangle-ts is not installed ("require"ntangle-ts" returns false)!]])

@setup_ntangle_ts_callback+=
require"ntangle-ts".register({ on_init = vim.schedule_wrap(M.on_init), on_change = M.on_change })
