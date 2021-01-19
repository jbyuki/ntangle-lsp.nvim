##../ntangle_lsp
@declare_functions+=
local attach_to_buf 

@functions+=
function attach_to_buf(buf, client_id, language_id)
	@get_client_from_id

	@check_if_not_already_attached

	vim.api.nvim_buf_attach(buf, true, {
		on_lines = function(_, buf, changedtick, firstline, lastline, new_lastline, old_byte_size)
			@retrieve_current_buffer_info
			@apply_modifications_to_lines_of_buffer

			local curassembly
			local assembly_filename
			@read_assembly_name_if_any_and_figure_out_fictional_full_path
			@if_no_assembly_replace_with_current_filename

			@if_assembly_doesnt_match_move_lines_from_assembly

			@clear_sections
			@parse_tangle_from_lines

			@for_every_root_node_send_content_to_lsp_server
		end
	})

	vim.schedule(function()
		@get_lines_from_buffer

		local curassembly
		local assembly_filename
		@read_assembly_name_if_any_and_figure_out_fictional_full_path
		@if_no_assembly_replace_with_current_filename

		if not bufcontent[assembly_filename] then
			@glob_all_links
			@foreach_part_append_them_to_assembled
		end

		@put_lines_from_current_buffer_into_assembly
		@save_bufaddress_for_current_buffer

		@clear_sections
		@parse_tangle_from_lines
		@for_every_root_node_send_did_open_to_lsp_server
	end)
end

@get_client_from_id+=
local client = vim.lsp.get_client_by_id(client_id)
assert(client, "Could not find client_id")

@get_lines_from_buffer+=
local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)

@read_assembly_name_if_any_and_figure_out_fictional_full_path+=
local top = lines[1] or ""
if string.match(top, "^##%S*%s*$") then
	@extract_assembly_name
	@set_as_current_assembly
	@make_assembly_path
end

@extract_assembly_name+=
local name = string.match(top, "^##(%S*)%s*$")

@set_as_current_assembly+=
curassembly = name

@make_assembly_path+=
local bufname = vim.api.nvim_buf_get_name(buf)
local extname = vim.fn.fnamemodify(bufname, ":e:e")
local relname = vim.fn.fnamemodify(curassembly, ":h")
local assname = vim.fn.fnamemodify(curassembly, ":t")
local parent = vim.fn.fnamemodify(bufname, ":h")
assembly_filename = parent .. "/" .. relname .. "/" .. assname .. "." .. extname

@if_no_assembly_replace_with_current_filename+=
if not curassembly then
	assembly_filename = vim.api.nvim_buf_get_name(buf)
end

@glob_all_links+=
local extname = vim.fn.fnamemodify(assembly_filename, ":e:e")
local assembly_dir = vim.fn.fnamemodify(assembly_filename, ":h")
local assembly_name = vim.fn.fnamemodify(assembly_filename, ":t:r:r")

local parts = vim.split(vim.fn.glob(assembly_dir .. "/tangle/" .. assembly_name .. ".*." .. extname), "\n")

@script_variables+=
local bufaddress = {}
local bufcontent = {}

@declare_functions+=
local get_uri, get_uri_from_fn

@functions+=
function get_uri(buf)
	return string.lower(vim.uri_from_bufnr(buf))
end

function get_uri_from_fn(fn)
	return string.lower(vim.uri_from_fname(fn))
end

@save_bufaddress_for_current_buffer+=
local uri = get_uri(buf)
bufaddress[buf] = { assembly_filename, uri }

@foreach_part_append_them_to_assembled+=
bufcontent[assembly_filename] = {}

for _, part in ipairs(parts) do
	if part ~= "" then
		local origin_path
		@read_link_from_link_file
		local uri = get_uri_from_fn(origin_path)
		if origin_path ~= bufname and not bufcontent[assembly_filename][uri] then
			@append_lines_to_bufcontent_for_part
		end
	end
end

@read_link_from_link_file+=
local f = io.open(part, "r")
local origin_path = f:read("*line")
f:close()

@append_lines_to_bufcontent_for_part+=
local partlines = {}
local f = io.open(origin_path, "r")
if f then
	local lnum = 1
	while true do
		local line = f:read("*line")
		if not line then break end
		if lnum > 1 then
			table.insert(partlines, line)
		end
		lnum = lnum + 1
	end
	f:close()
end
bufcontent[assembly_filename][uri] = partlines

@put_lines_from_current_buffer_into_assembly+=
local uri = get_uri(buf)
bufcontent[assembly_filename][uri] = lines

@parse_tangle_from_lines+=
parse(bufcontent[assembly_filename])

@for_every_root_node_send_did_open_to_lsp_server+=
local parendir = vim.fn.fnamemodify(assembly_filename, ":p:h")
for name, section in pairs(sections) do
	if section.root then
		local fn
		@if_star_replace_with_current_filename
		@otherwise_put_node_name
		local lines = {}
		@get_text_document_uri
		@init_reverse_lookup
		@output_generated_header
		outputSections(assembly_filename, lines, uri, name, "")
		@send_did_open_to_lsp_server
	end
end

@if_star_replace_with_current_filename+=
if name == "*" then
	local tail = vim.fn.fnamemodify( assembly_filename, ":t:r" )
	fn = parendir .. "/tangle/" .. tail

@otherwise_put_node_name+=
else
	if string.find(name, "/") then
		fn = parendir .. "/" .. name
	else
		fn = parendir .. "/tangle/" .. name
	end
end

@declare_functions+=
local outputSections

@functions+=
function outputSections(assembly_filename, lines, uri, name, prefix)
	@check_if_section_exists_otherwise_return_nil
	for section in linkedlist.iter(sections[name].list) do
		for line in linkedlist.iter(section.lines) do
			@if_line_is_text_output_it
			@if_reference_recursively_call_output
		end
	end
end

@check_if_section_exists_otherwise_return_nil+=
if not sections[name] then
	return
end

@if_line_is_text_output_it+=
if line.linetype == LineType.TEXT then
	lines[#lines+1] = prefix .. line.str
	@save_also_reverse_lookup
end

@if_reference_recursively_call_output+=
if line.linetype == LineType.REFERENCE then
	outputSections(assembly_filename, lines, uri, line.str, prefix .. line.prefix)
end

@script_variables+=
local genmeta = {}

@init_reverse_lookup+=
genmeta[uri] = {}

@save_also_reverse_lookup+=
table.insert(genmeta[uri], {
	part = line.part,
	lnum = line.lnum,
	text = line.str,
	offset = string.len(prefix),
})

@put_dummy_line_in_reverse_lookup+=
table.insert(genmeta[name], {})

@get_text_document_uri+=
local uri = get_uri_from_fn(fn)

@send_did_open_to_lsp_server+=
local params = {
	textDocument = {
		version = 0,
		uri = uri,
		-- TODO make sure our filetypes are compatible with languageId names.
		languageId = language_id,
		text = table.concat(lines, "\n"),
	}
}
client.notify('textDocument/didOpen', params)

@retrieve_current_buffer_info+=
local assembly_filename, uri = unpack(bufaddress[buf])

@apply_modifications_to_lines_of_buffer+=
local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)

@if_assembly_doesnt_match_move_lines_from_assembly+=
if curassembly ~= assembly_filename then
	local uri = get_uri(buf)
	bufcontent[assembly_filename][uri] = nil

	if not bufcontent[assembly_filename] then
		@glob_all_links
		@foreach_part_append_them_to_assembled
	end

	@put_lines_from_current_buffer_into_assembly
	@save_bufaddress_for_current_buffer
end

@for_every_root_node_send_content_to_lsp_server+=
local parendir = vim.fn.fnamemodify(assembly_filename, ":p:h")
for name, section in pairs(sections) do
	if section.root then
		local fn
		@if_star_replace_with_current_filename
		@otherwise_put_node_name
		local lines = {}
		@get_text_document_uri
		@init_reverse_lookup
		@output_generated_header
		outputSections(assembly_filename, lines, uri, name, "")
		@send_new_content_to_lsp_server
	end
end


@output_generated_header+=
if string.match(fn, "lua$") then
	local relname
	if filename then
		relname = filename
	else
		relname = vim.api.nvim_buf_get_name(0)
	end
	relname = vim.api.nvim_call_function("fnamemodify", { relname, ":t" })
	table.insert(lines, "-- Generated from " .. relname .. " using ntangle.nvim")
	@put_dummy_line_in_reverse_lookup
elseif string.match(fn, "vim$") then
	local relname
	if filename then
		relname = filename
	else
		relname = vim.api.nvim_buf_get_name(0)
	end
	relname = vim.api.nvim_call_function("fnamemodify", { relname, ":t" })
	table.insert(lines, "\" Generated from " .. relname .. " using ntangle.nvim")
	@put_dummy_line_in_reverse_lookup
end

@script_variables+=
last_sent = {}

@send_new_content_to_lsp_server+=
last_sent[uri] = lines
client.notify("textDocument/didChange", {
	textDocument = {
	  uri = uri;
	  version = changedtick;
	};
	contentChanges = { {
		text = table.concat(lines, "\n")
	} }
})

@script_variables+=
local attached = {}

@check_if_not_already_attached+=
if attached[buf] then
	return
end

attached[buf] = true
