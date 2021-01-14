##../ntangle_lsp
@declare_functions+=
local attach_to_buf 

@functions+=
function attach_to_buf(buf, client_id, language_id)
	@get_client_from_id

	vim.api.nvim_buf_attach(buf, true, {
		on_lines = function(_, buf, changedtick, firstline, lastline, new_lastline, old_byte_size)
			@get_lines_from_buffer
			local curassembly
			@read_assembly_name_if_any
			local filename
			if curassembly then
				@construct_path_for_link_file

				local assembled = {}
				@glob_all_links_and_assemble
				lines = assembled

				@set_filename_of_assembled
			end

			@clear_sections
			@parse_tangle_from_lines

			@for_every_root_node_send_content_to_lsp_server
		end
	})
	vim.schedule(function()
		@get_lines_from_buffer
		local curassembly
		@read_assembly_name_if_any
		local filename
		if curassembly then
			@construct_path_for_link_file

			local assembled = {}
			@glob_all_links_and_assemble
			lines = assembled

			@set_filename_of_assembled
		end

		@clear_sections
		@parse_tangle_from_lines
		@for_every_root_node_send_did_open_to_lsp_server
	end)
end

@get_client_from_id+=
local client = vim.lsp.get_client_by_id(client_id)
assert(client, "Could not find client_id")

@get_lines_from_buffer+=
local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)

@read_assembly_name_if_any+=
local line = lines[1] or ""
if string.match(lines[1], "^##%S*%s*$") then
	@extract_assembly_name
	@set_as_current_assembly
end

@extract_assembly_name+=
local name = string.match(line, "^##(%S*)%s*$")

@set_as_current_assembly+=
curassembly = name

@construct_path_for_link_file+=
local fn = vim.api.nvim_buf_get_name(0)
local parendir = vim.fn.fnamemodify(fn, ":p:h")
local assembly_parendir = vim.fn.fnamemodify(curassembly, ":h")
local assembly_tail = vim.fn.fnamemodify(curassembly, ":t")
local part_tail = vim.fn.fnamemodify(fn, ":t")
local link_name = parendir .. "/" .. assembly_parendir .. "/tangle/" .. assembly_tail .. "." .. part_tail
local path = vim.fn.fnamemodify(link_name, ":h")

@glob_all_links_and_assemble+=
path = vim.fn.fnamemodify(path, ":p")
local parts = vim.split(vim.fn.glob(path .. assembly_tail .. ".*.tl"), "\n")
link_name = vim.fn.fnamemodify(link_name, ":p")
for _, part in ipairs(parts) do
	if link_name ~= part then
		@read_link_from_link_file
		@append_lines_from_part_file
	else
		@add_to_parts_for_generated
		@append_current_buffer_to_the_assembled
	end
end

@read_link_from_link_file+=
local f = io.open(part, "r")
local origin_path = f:read("*line")
f:close()

@append_lines_from_part_file+=
local f = io.open(origin_path, "r")
if f then
	@add_to_parts_for_generated
	@put_offset_in_assembled_for_part
	local lnum = 1
	while true do
		local line = f:read("*line")
		if not line then break end
		if lnum > 1 then
			table.insert(assembled, line)
			@append_origin_to_assembled_array
		end
		lnum = lnum + 1
	end
	f:close()
else
	@remove_link_file
end

@remove_link_file+=
os.remove(part)

@glob_all_links_and_assemble-=
local origin = {}

@append_origin_to_assembled_array+=
table.insert(origin, origin_path)

@append_current_origin_to_assembled_array+=
table.insert(origin, fn)

@glob_all_links_and_assemble-=
local offset = {}

@put_offset_in_assembled_for_part+=
offset[origin_path] = #assembled

@put_offset_in_assembled_for_current+=
offset[fn] = #assembled

@append_current_buffer_to_the_assembled+=
@put_offset_in_assembled_for_current
for lnum, line in ipairs(lines) do
	if lnum > 1 then
		table.insert(assembled, line)
		@append_current_origin_to_assembled_array
	end
end

@glob_all_links_and_assemble-=
local valid_parts = {}

@add_to_parts_for_generated+=
table.insert(valid_parts, vim.fn.fnamemodify(part, ":t:e:e:e"))

@parse_tangle_from_lines+=
parse(lines)

@set_filename_of_assembled+=
local ext = vim.fn.fnamemodify(fn, ":e:e")
filename = parendir .. "/" .. assembly_parendir .. "/" .. assembly_tail .. "." .. ext

@for_every_root_node_send_content_to_lsp_server+=
if not filename then
	filename = vim.api.nvim_buf_get_name(0)
end
local parendir = vim.fn.fnamemodify(filename, ":p:h")
for name, section in pairs(sections) do
	if section.root then
		local fn
		@if_star_replace_with_current_filename
		@otherwise_put_node_name
		local lines = {}
		local refs = {}
		@output_generated_header
		@get_text_document_uri
		outputSections(lines, file, name, "", refs)
		@save_document_refs
		@send_new_content_to_lsp_server
	end
end

@if_star_replace_with_current_filename+=
if name == "*" then
	local tail = vim.api.nvim_call_function("fnamemodify", { filename, ":t:r" })
	fn = parendir .. "/tangle/" .. tail

@otherwise_put_node_name+=
else
	if string.find(name, "/") then
		fn = parendir .. "/" .. name
	else
		fn = parendir .. "/tangle/" .. name
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
elseif string.match(fn, "vim$") then
	local relname
	if filename then
		relname = filename
	else
		relname = vim.api.nvim_buf_get_name(0)
	end
	relname = vim.api.nvim_call_function("fnamemodify", { relname, ":t" })
	table.insert(lines, "\" Generated from " .. relname .. " using ntangle.nvim")
end

@get_text_document_uri+=
local uri = string.lower(vim.uri_from_fname(fn))

@declare_functions+=
local outputSections

@functions+=
function outputSections(lines, file, name, prefix, refs)
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
	@if_has_refs_save_lnum
end

@if_reference_recursively_call_output+=
if line.linetype == LineType.REFERENCE then
	outputSections(lines, file, line.str, prefix .. line.prefix, refs)
end

@if_has_refs_save_lnum+=
refs[#refs+1] = { string.len(prefix), line.lnum }

@script_variables+=
local document_lookup = {}

@save_document_refs+=
document_lookup[uri] = {buf, refs}

@send_new_content_to_lsp_server+=
client.notify("textDocument/didChange", {
	textDocument = {
	  uri = uri;
	  version = changedtick;
	};
	contentChanges = { {
		text = table.concat(lines, "\n")
	} }
})

@for_every_root_node_send_did_open_to_lsp_server+=
if not filename then
	filename = vim.api.nvim_buf_get_name(0)
end
local parendir = vim.fn.fnamemodify(filename, ":p:h")
for name, section in pairs(sections) do
	if section.root then
		local fn
		@if_star_replace_with_current_filename
		@otherwise_put_node_name
		local lines = {}
		local refs = {}
		@output_generated_header
		outputSections(lines, file, name, "", refs)
		@get_text_document_uri
		@save_document_refs
		@send_did_open_to_lsp_server
	end
end

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
