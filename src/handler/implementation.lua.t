##../ntangle_lsp
@functions+=
local function implementation()
	local pos, candidates = get_candidates_position()

	send_did_change_all(client_clangd)

	local function action(sel)
		local params = make_position_params(pos, candidates, sel)
		buf_request('textDocument/implementation', params)
	end

	@do_action_and_open_context_menu_if_multiple_choices
end

@export_symbols+=
implementation = implementation,

@client_handlers+=
["textDocument/implementation"] = make_location_handler(),
