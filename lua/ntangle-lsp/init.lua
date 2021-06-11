-- Generated using ntangle.nvim
local tick = {}

local changes = {}

local changes_timer = {}

local active_clients = {}

local configs = require("lspconfig/configs")

local lsp = vim.lsp

local clients = {}

local diag_ns = vim.api.nvim_create_namespace("")

local M = {}
function M.on_change(fname, start_byte, old_byte, new_byte,
    start_row, start_col,
    old_row, old_end_col,
    new_row, new_end_col, lines)
  local rpc = clients[fname]
  
  if rpc then
    local did_change = function()
      local version = tick[fname]
      version =  version + 1
      tick[fname] = version
      
      local uri = vim.uri_from_fname(fname)
      local params = {
        textDocument = {
          uri = uri,
          version = version,
        },
        contentChanges = changes[fname],
      }
      
      rpc.notify("textDocument/didChange", params)
      
      changes = {}
      
    end

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
    
    if changes_timer[fname] then
      changes_timer[fname]:stop()
      changes_timer[fname] = nil
    end
    
    
    local timer = vim.loop.new_timer()
    changes_timer[fname] = timer 
    timer:start(500, 0, vim.schedule_wrap(did_change))
  end
end

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
        text = "\n" .. table.concat(lines, "\n"),
      }
    }
    
    rpc.notify('textDocument/didOpen', params)
    
    tick[filename] = 0
    
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
        local lnum_start = diag.range["start"].line
        lnum_start = require"ntangle-ts".reverse_lookup(fname, lnum_start)
        if lnum_start then
          messages[lnum_start-1] = messages[lnum_start-1] or {}
          table.insert(messages[lnum_start-1], diag)
          
        end
      end
      
      local lcount = vim.api.nvim_buf_line_count(0)
      for lnum, msgs in pairs(messages) do
        local chunk = vim.lsp.diagnostic.get_virtual_text_chunks_for_line(0, lnum, msgs, {})
        if lnum < lcount then
          vim.api.nvim_buf_set_extmark(0, diag_ns, lnum, 0, {
            virt_text = chunk,
          })
        end
      end
    end
    
    dispatch.notification = function(method, params)
      local handler = handlers[method]
      if handler then
        return handler(params)
      else
        -- print(method, vim.inspect(params))
      end
      
    end
    
    dispatch.server_request = function(method, params)
      local handler = handlers[method]
      if handler then
        return handler(params)
      else
        -- print(method, vim.inspect(params))
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
      
      -- local resolved_capabilities = vim.lsp.protocol.resolve_capabilities(result.capabilities)
      did_open(rpc)
    end)
    
    
  end
  
  local rpc = active_clients[ft][root_dir]
  clients[filename] = rpc
  

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
