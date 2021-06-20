##../ntangle-lsp
@implement+=
function M.on_init(buf, filename, ft, lines)
  @get_client_config_from_lsp_config
  @find_root_dir
  @set_as_attached
  @setup_mappings

  local skip_send = false
  local did_open = function(rpc)
    @send_did_open_notification
    @init_document_version
  end

  @start_client_if_not_running
  @register_client_for_filename

  if not skip_send then
    did_open(rpc)
  end
end

@script_variables+=
local active_clients = {}

@start_client_if_not_running+=
if not active_clients[ft] or not active_clients[ft][root_dir] then
  @start_client
end

@script_variables+=
local configs = require("lspconfig/configs")

@implement+=
function M.get_config(ft)
  for _, config in pairs(configs) do
    if config.filetypes then
      for _, filetype_match in ipairs(config.filetypes) do
        if filetype_match == ft then
          @find_customized_config_with_debug
          return config
        end
      end
    end
  end
end

@find_customized_config_with_debug+=
-- This kind of a hack but it's the only way
-- I found to get the config from outside nvim-lspconfig
local _config = require"lspconfig"[config.name]
if _config and _config.manager and _config.manager.try_add_wrapper then
  local fn = _config.manager.try_add_wrapper
  local i = 1
  while true do
    local n, v = debug.getupvalue(fn, i)
    if not n then break end
    if n == "config" then
      config = v
      break
    end
    i = i + 1
  end
end

@get_client_config_from_lsp_config+=
local config = M.get_config(ft)

@start_client+=
local dispatch = {}
local handlers = {}
skip_send = true
@lsp_handlers
@dispatch_functions
@split_cmds_list
@start_client_through_lsp_rpc
@register_client_for_filetype
@send_initialize_request

@script_variables+=
local lsp = vim.lsp

@split_cmds_list+=
local cmd, cmd_args = lsp._cmd_parts(config.cmd)

@start_client_through_lsp_rpc+=
local rpc = lsp.rpc.start(cmd, cmd_args, dispatch, {
  cwd = config.cmd_cwd;
  env = config.cmd_env;
})

@register_client_for_filetype+=
active_clients[ft] = active_clients[ft] or {}
active_clients[ft][root_dir] = rpc

@script_variables+=
local clients = {}

@register_client_for_filename+=
local rpc = active_clients[ft][root_dir]
clients[filename] = rpc

@find_root_dir+=
local root_dir = config.root_dir(filename)
-- local root_dir = config.get_root_dir(filename)

@send_did_open_notification+=
local params = {
  textDocument = {
    version = 0,
    uri = vim.uri_from_fname(filename),
    languageId = ft,
    text = table.concat(lines, "\n"),
  }
}

rpc.notify('textDocument/didOpen', params)

@dispatch_functions+=
dispatch.notification = function(method, params)
  @handle_server_request
end

dispatch.server_request = function(method, params)
  @handle_server_request
end

dispatch.on_error = function(...)
  print("on_error", vim.inspect({...}))
end

dispatch.on_exit = function(...)
  print("on_exit", vim.inspect({...}))
end


@send_initialize_request+=
local version = vim.version()
local initialize_params = {
  processId = vim.loop.getpid(),
  clientInfo = {
    name = "Neovim",
    version = string.format("%s.%s.%s", version.major, version.minor, version.patch)
  },
  rootPath = root_dir,
  rootUri = vim.uri_from_fname(root_dir),
  initializationOptions = config.init_options,
  capabilities = config.capabilities or lsp.protocol.make_client_capabilities(),
  trace = 'off',
  workspaceFolders = {{
    uri = vim.uri_from_fname(root_dir),
    name = string.format("%s", root_dir),
  }},
}

rpc.request('initialize', initialize_params, function(_, result)
  @send_initialized_notify
  @send_did_change_configurations
  @resolve_server_capabilities
  @attach_signature_help_callback
  did_open(rpc)
end)

@send_initialized_notify+=
rpc.notify('initialized', {[vim.type_idx]=vim.types.dictionary})

@send_did_change_configurations+=
if config.settings then
  rpc.notify('workspace/didChangeConfiguration', {
    settings = config.settings
  })
end

@handle_server_request+=
local handler = handlers[method]
if handler then
  return handler(params)
else
  -- print(method, vim.inspect(params))
end

@implement+=
function M.lookup_section(settings, section)
  for part in vim.gsplit(section, '.', true) do
    settings = settings[part]
    if not settings then
      return
    end
  end
  return settings
end

@lsp_handlers+=
handlers["workspace/configuration"] = function(params)
  local result = {}
  for _, item in ipairs(params.items) do
    if item.section then
      local value = (config.settings and M.lookup_section(config.settings, item.section)) or vim.NIL
      -- For empty sections with no explicit '' key, return settings as is
      if value == vim.NIL and item.section == '' then
        value = config.settings or vim.NIL
      end
      table.insert(result, value)
    end
  end
  return result
end

@lsp_handlers+=
handlers['window/workDoneProgress/create'] = function()
  return vim.NIL
end

@resolve_server_capabilities+=
local resolved_capabilities = vim.lsp.protocol.resolve_capabilities(result.capabilities)

@script_variables+=
local attached = {}

@set_as_attached+=
attached[vim.uri_from_fname(filename)] = true
