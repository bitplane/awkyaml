function yaml_parse_trim(text) {
    sub(/^[ \t]+/, "", text)
    sub(/[ \t]+$/, "", text)
    return text
}

function yaml_parse_indent(line,    n) {
    n = match(line, /[^ ]/)
    if (!n) {
        return length(line)
    }
    return n - 1
}
function yaml_parse_leading_spaces(text,    n) {
    n = match(text, /[^ ]/)
    if (!n) {
        return length(text)
    }
    return n - 1
}

function yaml_parse_line_is_blank_or_comment(line) {
    return line ~ /^[ \t]*($|#)/
}

function yaml_parse_line_is_yaml_directive(line) {
    return line ~ /^%YAML[ \t]+/
}

function yaml_parse_line_has_invalid_yaml_directive(line) {
    return yaml_parse_line_is_yaml_directive(line) && line !~ /^%YAML[ \t]+[0-9]+[.][0-9]+([ \t]+#.*)?$/
}

function yaml_parse_line_is_tag_directive(line) {
    return line ~ /^%TAG[ \t]+/
}

function yaml_parse_line_is_directive(line) {
    return line ~ /^%/
}

function yaml_parse_line_is_document_start_with_content(line) {
    return line ~ /^---[ \t]+/
}

function yaml_parse_line_is_document_start(line) {
    return line ~ /^---[ \t]*$/
}

function yaml_parse_line_is_document_end(line) {
    return line ~ /^\.\.\.([ \t]|$)/
}

function yaml_parse_text_is_sequence_item(text) {
    return text == "-" || text ~ /^-[ \t]/
}

function yaml_parse_line_reenters_sequence_at_map_value_indent(indent) {
    return yaml_parse_depth > 1 && yaml_parse_stack_type[yaml_parse_depth] == "seq" && yaml_parse_stack_type[yaml_parse_depth - 1] == "map" && indent == yaml_parse_stack_indent[yaml_parse_depth] && indent > yaml_parse_stack_indent[yaml_parse_depth - 1]
}

function yaml_parse_line_indents_between_nested_maps(indent) {
    return yaml_parse_depth > 1 && yaml_parse_stack_type[yaml_parse_depth] == "map" && yaml_parse_stack_type[yaml_parse_depth - 1] == "map" && indent > yaml_parse_stack_indent[yaml_parse_depth - 1] && indent < yaml_parse_stack_indent[yaml_parse_depth]
}

function yaml_parse_line_starts_orphan_nested_mapping(text, indent) {
    return yaml_parse_depth > 0 && yaml_parse_stack_type[yaml_parse_depth] == "map" && indent > yaml_parse_stack_indent[yaml_parse_depth] && yaml_parse_mapping_pair(text) && yaml_parse_last_pending_key_path() == ""
}

function yaml_parse_line_closes_root_sequence_with_content(indent) {
    return yaml_parse_depth == 1 && yaml_parse_stack_type[yaml_parse_depth] == "seq" && yaml_parse_stack_path[yaml_parse_depth] == "" && indent <= yaml_parse_stack_indent[yaml_parse_depth]
}

