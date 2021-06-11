##../ntangle-lsp
@script_variables+=
local tick = {}

@init_document_version+=
tick[filename] = 0

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
      @send_did_open
      @reset_changes
    end

    @append_changes
    @start_debouce_timer
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
    start = { line = start_row+1, character = 0},
    ["end"] = { line = start_row+old_row+1, character = 0}
  },
  text = new_text,
}

changes[fname] = changes[fname] or {}

table.insert(changes[fname], changed_range)

@reset_debounce_timer

@send_did_open+=
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
changes = {}

@script_variables+=
local changes_timer = {}

@reset_debounce_timer+=
if changes_timer[fname] then
  changes_timer[fname]:stop()
  changes_timer[fname] = nil
end

@start_debouce_timer+=
local timer = vim.loop.new_timer()
changes_timer[fname] = timer 
timer:start(500, 0, vim.schedule_wrap(did_change))
