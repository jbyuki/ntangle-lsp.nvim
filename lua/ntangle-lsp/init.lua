-- Generated using ntangle.nvim
local active_clients = {}

local configs = require("lspconfig/configs")

local lsp = vim.lsp

local diag_ns = vim.api.nvim_create_namespace("")

local M = {}
function M.on_init(filename, ft, lines)
  local config = M.get_config(ft)
  
  local root_dir = config.get_root_dir(filename)
  

  local skip_send = false
  local did_open = function(rpc)
    local params = {
      textDocument = {
        version = 0,
        uri = vim.uri_from_fname(filename),
        languageId = ft,
        text = table.concat(lines, "\n"),
      }
    }
    
    rpc.notify('textDocument/didOpen', params)
    
  end

  if not active_clients[ft] or not active_clients[ft][root] then
    local dispatch = {}
    local handlers = {}
    send_skip = true
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
    
    handlers['window/workDoneProgress/create'] = function(params)
      return vim.NIL
    end
    handlers["textDocument/publishDiagnostics"] = function(params)
      vim.api.nvim_buf_clear_namespace(0, diag_ns, 0, -1)
      
      local fname = vim.uri_to_fname(params.uri)
      fname = fname:gsub("\\", "/")
      
      local messages = {}
      for _, diag in ipairs(params.diagnostics) do
        print(vim.inspect(diag))
        local lnum_start = diag.range["start"].line
        lnum_start = require"ntangle-ts".reverse_lookup(fname, lnum_start)
        if lnum_start then
          messages[lnum_start-1] = messages[lnum_start-1] or {}
          table.insert(messages[lnum_start-1], { diag.message, "LspDiagnosticsError"})
          
        end
      end
      
      for lnum, msgs in pairs(messages) do
        vim.api.nvim_buf_set_extmark(0, diag_ns, lnum, 0, {
          virt_text = msgs,
        })
      end
    end
    
    dispatch.notification = function(method, params)
      local handler = handlers[method]
      if handler then
        return handler(params)
      else
        print(method, vim.inspect(params))
      end
      
    end
    
    dispatch.server_request = function(method, params)
      local handler = handlers[method]
      if handler then
        return handler(params)
      else
        print(method, vim.inspect(params))
      end
      
    end
    
    dispatch.on_error = function(...)
      print("on_error", vim.inspect({...}))
    end
    
    dispatch.on_exit = function(...)
      print("on_exit", vim.inspect({...}))
    end
    
    
    local cmd, cmd_args = lsp._cmd_parts(config.cmd)
    
    local rpc = lsp.rpc.start(cmd, cmd_args, dispatch, {
      cwd = config.cmd_cwd;
      env = config.cmd_env;
    })
    
    active_clients[ft] = active_clients[ft] or {}
    active_clients[ft][root_dir] = rpc
    
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
      rpc.notify('initialized', {[vim.type_idx]=vim.types.dictionary})
      
      if config.settings then
        rpc.notify('workspace/didChangeConfiguration', {
          settings = config.settings
        })
      end
      
      did_open(rpc)
    end)
    
    
  end
  
  local rpc = active_clients[ft][root_dir]
  active_clients[filename] = rpc
  

  if not skip_send then
    did_open(rpc)
  end
end

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

function M.lookup_section(settings, section)
  for part in vim.gsplit(section, '.', true) do
    settings = settings[part]
    if not settings then
      return
    end
  end
  return settings
end

function M.setup(opts)
  local succ = pcall(require, "ntangle-ts")
  assert(succ, [[ntangle-ts is not installed ("require"ntangle-ts" returns false)!]])
  
  require"ntangle-ts".register({ on_init = vim.schedule_wrap(M.on_init), on_change = M.on_change })
end

return M
