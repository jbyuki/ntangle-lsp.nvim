##../ntangle_lsp
@declare_functions+=
local parse

@functions+=
function parse(assembly_lines)
	@list_keys_and_sort_them_for_deterministic_iteration

	for _, part in ipairs(parts) do
		local lines = assembly_lines[part]
		local lnum = 1
		for _,line in ipairs(lines) do
			@check_if_line_escape_double_at
			@check_if_line_is_section
			@check_if_line_is_reference
			@check_if_line_is_assembly_name
			@otherwise_add_to_section
			lnum = lnum+1;
		end
	end
end

@list_keys_and_sort_them_for_deterministic_iteration+=
local parts = vim.tbl_keys(assembly_lines)
table.sort(parts)

@check_if_line_is_section+=
elseif string.match(line, "^@[^@]%S*[+-]?=%s*$") then
	@parse_section_name
	@create_new_section
	@link_to_previous_section_if_needed
	@otherwise_just_save_section
	@set_section_as_current_section

@parse_section_name+=
local _, _, name, op = string.find(line, "^@(%S-)([+-]?=)%s*$")

@line_types+=
SECTION = 3,

@create_new_section+=
local section = { linetype = LineType.SECTION, str = name, lines = {}}

@requires+=
require("linkedlist")

@parse_variables+=
local sections = {}
local curSection = nil

@clear_sections+=
sections = {}
curSection = nil

@link_to_previous_section_if_needed+=
if op == '+=' or op == '-=' then
	if sections[name] then
		if op == '+=' then
			@add_back_to_section
		elseif op == '-=' then
			@add_front_to_section
		end
	else
		@create_section_linked_list_non_root
		@add_back_to_section
	end

@add_back_to_section+=
linkedlist.push_back(sections[name].list, section)

@add_front_to_section+=
linkedlist.push_front(sections[name].list, section)

@create_section_linked_list_non_root+=
sections[name] = { root = false, list = {} }

@otherwise_just_save_section+=
else 
	@create_section_linked_list_root
	@add_back_to_section
end

@create_section_linked_list_root+=
sections[name] = { root = true, list = {} }

@set_section_as_current_section+=
curSection = section

@check_if_line_is_reference+=
elseif string.match(line, "^%s*@[^@]%S*%s*$") then
	@get_reference_name
	-- @check_that_sections_is_not_empty
	@create_line_reference
	@quit_if_no_current_section
	@add_line_to_section

@get_reference_name+=
local _, _, prefix, name = string.find(line, "^(%s*)@(%S+)%s*$")

@check_that_sections_is_not_empty+=
if sections[name] then
	hasSection = true
end

@parse_variables+=
local LineType = {
	@line_types
}

@line_types+=
REFERENCE = 1,

@create_line_reference+=
local l = { 
	linetype = LineType.REFERENCE, 
	str = name,
	prefix = prefix
}

@otherwise_add_to_section+=
else
	@check_that_sections_is_not_empty
	@create_text_line
	@quit_if_no_current_section
	@add_line_to_section
end

@line_types+=
TEXT = 2,

@create_text_line+=
local l = { 
	linetype = LineType.TEXT, 
	str = line 
}

@check_if_line_escape_double_at+=
if string.match(line, "^%s*@@") then
	local hasSection = false
	@check_that_sections_is_not_empty
	if hasSection then
		@create_text_line_without_at
		@add_line_to_section
	end

@create_text_line_without_at+=
local _,_,pre,post = string.find(line, '^(.*)@@(.*)$')
local text = pre .. "@" .. post
local l = { 
	linetype = LineType.TEXT, 
	str = text 
}

@add_line_to_section+=
linkedlist.push_back(curSection.lines, l)

@create_text_line+=
l.lnum = lnum
l.part = part

@create_line_reference+=
l.lnum = lnum
l.part = part

@create_text_line_without_at+=
l.lnum = lnum
l.part = part

@check_if_line_is_assembly_name+=
elseif string.match(line, "^##%S*%s*$") then

@quit_if_no_current_section+=
if not curSection then
	return
end
