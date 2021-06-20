##../ntangle-lsp
@script_variables+=
local mappings = {}
local mappings_lookup = {}
local has_mappings = {}

@save_mappings+=
mappings = (opts and opts.mappings or {}) or {}

local mapping_id = 1
for lhs, rhs in pairs(mappings) do
  table.insert(mappings_lookup, {lhs, rhs})
end

@setup_mappings+=
if not has_mappings[buf] then
  for i, map in ipairs(mappings_lookup) do
    local lhs, rhs = unpack(map)

    vim.api.nvim_buf_set_keymap(buf, "n", lhs, [[<cmd>:lua require"ntangle-lsp".do_mapping(]] .. i .. [[)<CR>]], { noremap = true })
  end
  has_mappings[buf] = true
end

@implement+=
function M.do_mapping(id)
  if mappings_lookup[id] then
    local _, rhs = unpack(mappings_lookup[id])
    if rhs and type(rhs) == "function" then
      rhs()
    end
  end
end

@implement+=
function M.definition()
  @get_current_line_informations
  @get_client_rpc
  @send_pending_changes
  @make_position_params
  @send_definition_request
end

@get_current_line_informations+=
local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
local buf = vim.api.nvim_get_current_buf()
local _, _, fname = require"ntangle-ts".lookup(buf, row)

@send_definition_request+=
rpc.request("textDocument/definition", params, function(_, result)
  if result then
    if #result >= 1 then
      result = result[#result]
    end

    @parse_result_location
    @open_definition_file
    @go_to_defintion_line
  end
end)

@parse_result_location+=
local fn, lnum
if result.targetUri then
  @parse_location_link
elseif result.uri then
  @parse_location
else
  return
end

@parse_location_link+=
fn = vim.uri_to_fname(result.targetUri)
lnum = result.targetRange.start.line + 1

@parse_location+=
fn = vim.uri_to_fname(result.uri)
lnum = result.range.start.line + 1

@open_definition_file+=
if fn ~= vim.api.nvim_buf_get_name(buf) then
  vim.api.nvim_command("e " .. fn)
end

@go_to_defintion_line+=
vim.api.nvim_win_set_cursor(0, { lnum, 0 })
