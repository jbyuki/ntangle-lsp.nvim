##../ntangle-lsp
@implement+=
function M.on_init(filename, ft, lines)
  @get_client_config_from_lsp_config
  @find_root_dir

  local skip_send = false
  local did_open = function(rpc)
    @send_did_open_notification
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
if not active_clients[ft] or not active_clients[ft][root] then
  @start_client
end

@script_variables+=
local configs = require("lspconfig/configs")

@implement+=
function M.get_config(ft)
  for client_name, config in pairs(configs) do
    if config.filetypes then
      for _, filetype_match in ipairs(config.filetypes) do
        if filetype_match == ft then
          return config
        end
      end
    end
  end
end

@get_client_config_from_lsp_config+=
local config = M.get_config(ft)

@start_client+=
local dispatch = {}
local handlers = {}
send_skip = true
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

@register_client_for_filename+=
local rpc = active_clients[ft][root_dir]
active_clients[filename] = rpc

@find_root_dir+=
local root_dir = config.get_root_dir(filename)

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
dispatch.notification = function(...)
  print("notification", vim.inspect({...}))
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

rpc.request('initialize', initialize_params, function(init_err, result)
  @send_initialized_notify
  @send_did_change_configurations
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
  print(method, vim.inspect(params))
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
handlers['window/workDoneProgress/create'] = function(params)
  return vim.NIL
end
