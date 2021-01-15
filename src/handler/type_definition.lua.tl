##../ntangle_lsp
@functions+=
local function type_definition()
	local pos, candidates = get_candidates_position()

	local function action(sel)
		local params = make_position_params(pos, candidates, sel)
		buf_request('textDocument/typeDefinition', params)
	end

	@do_action_and_open_context_menu_if_multiple_choices
end

@export_symbols+=
type_definition = type_definition,

@client_handlers+=
["textDocument/typeDefinition"] = make_location_handler(),
