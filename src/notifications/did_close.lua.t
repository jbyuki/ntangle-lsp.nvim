##../ntangle-lsp
@implement+=
function M.on_deinit(buf, fname, ft)
  @get_client_rpc
  if rpc then
    @send_did_close
  end
end

@send_did_close+=
local uri = vim.uri_from_fname(fname)
local params = {
  textDocument = {
    uri = uri,
  },
}

print("did close " .. fname)
rpc.notify("textDocument/didClose", params)
