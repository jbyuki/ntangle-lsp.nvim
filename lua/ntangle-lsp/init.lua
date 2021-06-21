-- Generated using ntangle.nvim
local tick = {}

local changes = {}

local changes_cbs = {}

local lcount = {}

local active_clients = {}

local configs = require("lspconfig/configs")

local lsp = vim.lsp

local clients = {}

local save_configs = {}

local attached = {}

local diag_ns = {}

local mappings = {}
local mappings_lookup = {}
local has_mappings = {}

local signature_win

local M = {}
local dispatch = {}
local handlers = {}
handlers["workspace/configuration"] = function(params)
  local result = {}
  for _, item in ipairs(params.items) do
    if item.section then
      local config
      if item.scopeUri then
        config = save_configs[item.scopeUri]
      end

      if config then
        local value = (config.settings and M.lookup_section(config.settings, item.section)) or vim.NIL
        -- For empty sections with no explicit '' key, return settings as is
        if value == vim.NIL and item.section == '' then
          value = config.settings or vim.NIL
        end
        table.insert(result, value)
      end
    end
  end
  return result
end


handlers['window/workDoneProgress/create'] = function()
  return vim.NIL
end

handlers["textDocument/publishDiagnostics"] = function(params)
  local buf = vim.api.nvim_get_current_buf()

  local mode = vim.api.nvim_get_mode()
  if mode.mode == "i" then
    return
  end
  if attached[params.uri] then
    if not diag_ns[params.uri] then
      diag_ns[params.uri] = vim.api.nvim_create_namespace("")
    end
    local ns = diag_ns[params.uri]

    vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)

    local fname = vim.uri_to_fname(params.uri)
    fname = fname:gsub("\\", "/")

    local messages = {}
    for _, diag in ipairs(params.diagnostics) do
      local lnum_start = diag.range["start"].line+1
      local lookup_buf
      local lc = lcount[fname]
      if lc then
        lnum_start = math.min(lc, lnum_start)
      end
      lnum_start, lookup_buf = require"ntangle-ts".reverse_lookup(fname, lnum_start)
      if lnum_start and lookup_buf == buf then
        messages[lnum_start-1] = messages[lnum_start-1] or {}
        table.insert(messages[lnum_start-1], diag)

      end
    end

    local lcount = vim.api.nvim_buf_line_count(0)
    for lnum, msgs in pairs(messages) do
      local chunk = vim.lsp.diagnostic.get_virtual_text_chunks_for_line(0, lnum, msgs, {})
      if lnum < lcount then
        vim.api.nvim_buf_set_extmark(0, ns, lnum, 0, {
          virt_text = chunk,
        })
      else
        vim.api.nvim_buf_set_extmark(0, ns, lcount-1, 0, {
          virt_text = chunk,
        })
      end
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


function M.on_change(buf, fname, 
    _, _, _,
    start_row, _,
    old_row, _,
    new_row, new_end_col, 
    lines)
  local rpc = clients[fname]

  -- print(fname, start_row, old_row, new_row, vim.inspect(lines))
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

      changes[fname] = {}

    end

    local lc = lcount[fname]

    local new_text = ""
    if new_row == 1 then
      new_text = lines[1] .. "\n"
    end

    local changed_range
    if start_row >= lc then
      if start_row == 0 then
        changed_range = {
          range = {
            -- +1 is caused by the generated header
            start = { line = 0, character = 0 },
            ["end"] = { line = 0, character = 0 }
          },
          text = new_text,
        }


      else
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

      end
    elseif new_row == 0 then
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

    if lc then
      if new_row == 1 then
        lc = lc + 1
      else
        lc = lc - 1
      end
      lcount[fname] = lc
    end
    local mode = vim.api.nvim_get_mode()
    if mode.mode ~= "i" then
      did_change()
    end

    if #changes[fname] == 1 then
      table.insert(changes_cbs, did_change)
    end

  end
end

function M.insert_leave()
  M.send_pending()
  if signature_win then
    vim.api.nvim_win_close(signature_win, true)
    signature_win = nil
  end

end

function M.send_pending()
  for _, cbs in ipairs(changes_cbs) do
    cbs()
  end
  changes_cbs = {}
end

function M.on_deinit(buf, fname, ft)
  local rpc = clients[fname]

  if rpc then
    local uri = vim.uri_from_fname(fname)
    local params = {
      textDocument = {
        uri = uri,
      },
    }

    rpc.notify("textDocument/didClose", params)
  end
end

function M.on_init(buf, filename, ft, lines)
  local config = M.get_config(ft)

  save_configs[vim.uri_from_fname(filename)] = config

  local root_dir = config.root_dir(filename)
  -- local root_dir = config.get_root_dir(filename)

  attached[vim.uri_from_fname(filename)] = true

  if not has_mappings[buf] then
    for i, map in ipairs(mappings_lookup) do
      local lhs, rhs = unpack(map)

      vim.api.nvim_buf_set_keymap(buf, "n", lhs, [[<cmd>:lua require"ntangle-lsp".do_mapping(]] .. i .. [[)<CR>]], { noremap = true })
    end
    has_mappings[buf] = true
  end


  local skip_send = false
  local did_open = function(rpc)
    lcount[filename] = #lines

    local params = {
      textDocument = {
        version = 0,
        uri = vim.uri_from_fname(filename),
        languageId = ft,
        text = table.concat(lines, "\n"),
      }
    }

    rpc.notify('textDocument/didOpen', params)

    tick[filename] = 10

  end

  if not active_clients[ft] or not active_clients[ft][root_dir] then
    skip_send = true
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

    rpc.request('initialize', initialize_params, function(_, result)
      rpc.notify('initialized', {[vim.type_idx]=vim.types.dictionary})

      if config.settings then
        rpc.notify('workspace/didChangeConfiguration', {
          settings = config.settings
        })
      end

      local resolved_capabilities = vim.lsp.protocol.resolve_capabilities(result.capabilities)

      vim.api.nvim_buf_attach(0, true, {
        on_bytes = function(_, _, _, 
          start_row, start_col, start_byte,
          end_row, end_col, end_byte,
          new_end_row, new_end_col, new_end_byte) 
          if not (end_byte == 0 and new_end_byte == 1) then
            return
          end


          local line = vim.api.nvim_buf_get_lines(0, start_row, start_row+1, true)[1]
          local c = line:sub(start_col+1,start_col+1)

          if c == ')' then
            vim.schedule(function()
              if signature_win then
                vim.api.nvim_win_close(signature_win, true)
                signature_win = nil
              end

            end)
          end
          local match = false
          for _, t in ipairs(resolved_capabilities.signature_help_trigger_characters) do
            if c == t then
              match = true
            end
          end

          if match then
            vim.schedule(function()
              M.send_pending()

              local params = M.make_position_param()

              rpc.request("textDocument/signatureHelp", params, function(_, result)
                if result then
                  local sigs = result.signatures
                  local sig = sigs[#sigs]

                  if sig then
                    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
                    local buf = vim.api.nvim_get_current_buf()

                    local buf = vim.api.nvim_create_buf(false, true)
                    vim.api.nvim_buf_set_lines(buf, 0, -1, true, { sig.label })

                    local new_signature_win = vim.api.nvim_open_win(buf, false,{
                      relative = "cursor",
                      row = 1,
                      col = 0,
                      width = string.len(sig.label),
                      height = 1,
                      style = "minimal",
                      border = "single",
                    })

                    local ns = vim.api.nvim_create_namespace("")
                    local active = sig.activeParameter
                    if active and sig.parameters then
                      active = math.max(active, 1)
                      if sig.parameters[active] and sig.parameters[active].label then
                        local col = sig.parameters[active].label
                        if type(col) == "string" then
                          col = { string.find(sig.label, col, 1, true) }
                          if col then
                            col[1] = col[1] - 1
                          end

                        end
                        vim.api.nvim_buf_set_extmark(buf, ns, 0, col[1], {
                          hl_group = "Cursor",
                          end_col = col[2],
                        })
                      end
                    end

                    if signature_win then
                      vim.api.nvim_win_close(signature_win, true)
                    end
                    signature_win = new_signature_win

                  end
                end
              end)

            end)
          end

        end
      })

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
  for _, config in pairs(configs) do
    if config.filetypes then
      for _, filetype_match in ipairs(config.filetypes) do
        if filetype_match == ft then
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

function M.do_mapping(id)
  if mappings_lookup[id] then
    local _, rhs = unpack(mappings_lookup[id])
    if rhs and type(rhs) == "function" then
      rhs()
    end
  end
end

function M.definition()
  local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
  local buf = vim.api.nvim_get_current_buf()
  local _, _, fname = require"ntangle-ts".lookup(buf, row)

  local rpc = clients[fname]

  M.send_pending()

  local params = M.make_position_param()

  rpc.request("textDocument/definition", params, function(_, result)
    if result then
      if #result >= 1 then
        result = result[#result]
      end

      local fn, lnum
      if result.targetUri then
        fn = vim.uri_to_fname(result.targetUri)
        lnum = result.targetRange.start.line + 1

      elseif result.uri then
        fn = vim.uri_to_fname(result.uri)
        lnum = result.range.start.line + 1

      else
        return
      end

      if fn ~= vim.api.nvim_buf_get_name(buf) then
        vim.api.nvim_command("e " .. fn)
      end

      vim.api.nvim_win_set_cursor(0, { lnum, 0 })
    end
  end)

end

function M.hover()
  local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
  local buf = vim.api.nvim_get_current_buf()
  local _, _, fname = require"ntangle-ts".lookup(buf, row)

  local rpc = clients[fname]

  M.send_pending()

  local params = M.make_position_param()

  rpc.request("textDocument/hover", params, function(_, result)
    if result then
      local buf = vim.api.nvim_create_buf(false, true)

      local lines = vim.split(result.contents.value, "\n")
      vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)
      vim.api.nvim_buf_set_option(buf, "ft", "markdown")

      local max_width = 0
      for _, line in ipairs(lines) do
        max_width = math.max(vim.api.nvim_strwidth(line), max_width)
      end


      local win_hover = vim.api.nvim_open_win(buf, false, {
        relative = "cursor",
        row = 1,
        col = 0,
        width = math.min(max_width, 100),
        height = #lines,
        style = "minimal",
        border = "single",
      })

      M.close_preview_autocmd({"CursorMoved", "CursorMovedI", "BufHidden", "BufLeave"}, win_hover)
    end
  end)

end

function M.close_preview_autocmd(events, winnr)
  vim.api.nvim_command("autocmd "..table.concat(events, ',').." <buffer> ++once lua pcall(vim.api.nvim_win_close, "..winnr..", true)")
end

function M.make_position_param()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local buf = vim.api.nvim_get_current_buf()

  local lnum, prefix_len, filename = require"ntangle-ts".lookup(buf, row)

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

  return params
end

function M.setup(opts)
  local succ = pcall(require, "ntangle-ts")
  assert(succ, [[ntangle-ts is not installed ("require"ntangle-ts" returns false)!]])

  require"ntangle-ts".register({ 
    on_init = vim.schedule_wrap(M.on_init), 
    on_change = M.on_change,
    on_deinit = vim.schedule_wrap(M.on_deinit), 
  })
  vim.api.nvim_command [[augroup ntanglelsp]]
  vim.api.nvim_command [[autocmd!]]

  vim.api.nvim_command [[autocmd InsertLeave *.t lua require"ntangle-lsp".insert_leave()]]

  vim.api.nvim_command [[augroup END]]

  mappings = (opts and opts.mappings or {}) or {}

  local mapping_id = 1
  for lhs, rhs in pairs(mappings) do
    table.insert(mappings_lookup, {lhs, rhs})
  end

end

return M
