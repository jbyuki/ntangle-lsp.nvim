##../ntangle_lsp
@functions+=
local function declaration()
	local pos, candidates = get_candidates_position()

	local function action(sel)
		local params = make_position_params(pos, candidates, sel)
		buf_request('textDocument/declaration', params)
	end

	@do_action_and_open_context_menu_if_multiple_choices
end

@export_symbols+=
declaration = declaration,

@client_handlers+=
["textDocument/declaration"] = make_location_handler(),
