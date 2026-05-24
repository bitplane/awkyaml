function yaml_parse_block_scalar_indicator(text) {
    text = yaml_parse_trim(text)
    return text ~ /^[|>][-+0-9]*([ \t]*#.*)?$/
}

function yaml_parse_invalid_block_scalar_indicator(text) {
    text = yaml_parse_trim(text)
    return text ~ /^[|>][-+0-9]*#/ || text ~ /^[|>][-+0-9]*[ \t]+[^#]/
}

function yaml_parse_start_block_scalar(path, indicator, indent,    trimmed, explicit_indent) {
    trimmed = yaml_parse_trim(indicator)
    if (trimmed ~ /^[|>][-+]?(0|[1-9][0-9])([ \t]*#.*)?$/ || trimmed ~ /^[|>](0|[1-9][0-9])[-+]?([ \t]*#.*)?$/) {
        yaml_parse_error()
        return
    }
    yaml_parse_pending_block = 1
    yaml_parse_block_path = path
    yaml_parse_block_style = substr(trimmed, 1, 1)
    yaml_parse_block_chomp = ""
    if (index(trimmed, "-")) {
        yaml_parse_block_chomp = "-"
    } else if (index(trimmed, "+")) {
        yaml_parse_block_chomp = "+"
    }
    explicit_indent = yaml_parse_block_explicit_indent(trimmed)
    if (explicit_indent) {
        yaml_parse_block_indent = indent + explicit_indent
    } else {
        yaml_parse_block_indent = -1
    }
    yaml_parse_block_parent_indent = indent
    yaml_parse_block_indentless = (path == "" && indent == 0)
    yaml_parse_block_tag = yaml_parse_take_pending_tag()
    yaml_parse_block_tag_explicit = yaml_parse_take_pending_tag_explicit()
    if (yaml_parse_block_tag == "") {
        yaml_parse_block_tag = "tag:yaml.org,2002:str"
    }
    yaml_parse_block_anchor = yaml_parse_take_pending_anchor()
    yaml_parse_block_is_key = 0
    yaml_parse_block_text = ""
    yaml_parse_block_started = 0
    yaml_parse_block_last_blank = 0
    yaml_parse_block_blank_after_text = 0
    yaml_parse_block_leading_blank_indent = 0
}

function yaml_parse_block_explicit_indent(indicator,    i, ch) {
    for (i = 1; i <= length(indicator); i++) {
        ch = substr(indicator, i, 1)
        if (ch >= "1" && ch <= "9") {
            return ch + 0
        }
    }
    return 0
}

function yaml_parse_append_block_scalar(line,    part, indent) {
    indent = yaml_parse_indent(line)
    if (yaml_parse_block_indent < 0 && line ~ /^\t/) {
        yaml_parse_error()
        return
    }
    if (yaml_parse_block_indent < 0 && line ~ /^ *$/) {
        if (indent > yaml_parse_block_leading_blank_indent) {
            yaml_parse_block_leading_blank_indent = indent
        }
    }
    if (yaml_parse_block_indent < 0 && line !~ /^ *$/) {
        if (yaml_parse_block_leading_blank_indent > 0 && indent < yaml_parse_block_leading_blank_indent) {
            yaml_parse_error()
            return
        }
        yaml_parse_block_indent = yaml_parse_indent(line)
    }
    if (yaml_parse_block_indent < 0) {
        part = ""
    } else if (length(line) >= yaml_parse_block_indent) {
        part = substr(line, yaml_parse_block_indent + 1)
    } else {
        part = ""
    }
    yaml_parse_block_started = 1
    if (yaml_parse_block_style == "|") {
        yaml_parse_block_text = yaml_parse_block_text part "\n"
        yaml_parse_block_last_blank = (part == "")
    } else if (part == "") {
        yaml_parse_block_blank_after_text = (yaml_parse_block_text != "" && substr(yaml_parse_block_text, length(yaml_parse_block_text), 1) != "\n")
        yaml_parse_block_text = yaml_parse_block_text "\n"
        yaml_parse_block_last_blank = 1
    } else if (indent > yaml_parse_block_indent || substr(part, 1, 1) == "\t") {
        if (yaml_parse_block_last_blank && yaml_parse_block_blank_after_text) {
            yaml_parse_block_text = yaml_parse_block_text "\n"
        }
        if (yaml_parse_block_text != "" && substr(yaml_parse_block_text, length(yaml_parse_block_text), 1) != "\n") {
            yaml_parse_block_text = yaml_parse_block_text "\n"
        }
        yaml_parse_block_text = yaml_parse_block_text part "\n"
        yaml_parse_block_last_blank = 0
        yaml_parse_block_blank_after_text = 0
    } else {
        if (yaml_parse_block_text != "" && substr(yaml_parse_block_text, length(yaml_parse_block_text), 1) != "\n") {
            yaml_parse_block_text = yaml_parse_block_text " "
        }
        yaml_parse_block_text = yaml_parse_block_text part
        yaml_parse_block_last_blank = 0
        yaml_parse_block_blank_after_text = 0
    }
}

function yaml_parse_block_line_continues(line, indent) {
    return line ~ /^ *$/ || yaml_parse_block_indent < 0 || indent >= yaml_parse_block_indent
}

function yaml_parse_block_line_is_document_boundary(line) {
    return line ~ /^(---|\.\.\.)([ \t]|$)/
}

function yaml_parse_block_line_dedents(line, indent) {
    return yaml_parse_block_indent < 0 && line !~ /^ *$/ && indent <= yaml_parse_block_parent_indent && !yaml_parse_block_indentless
}

function yaml_parse_reset_block_scalar() {
    yaml_parse_pending_block = 0
    yaml_parse_block_path = ""
    yaml_parse_block_text = ""
    yaml_parse_block_indentless = 0
    yaml_parse_block_last_blank = 0
    yaml_parse_block_blank_after_text = 0
    yaml_parse_block_leading_blank_indent = 0
    yaml_parse_block_tag = ""
    yaml_parse_block_tag_explicit = 0
    yaml_parse_block_anchor = ""
    yaml_parse_block_is_key = 0
    yaml_parse_block_key_depth = 0
}

function yaml_parse_finish_block_scalar(    text) {
    if (yaml_parse_failed) {
        return
    }
    if (!yaml_parse_pending_block) {
        return
    }
    text = yaml_parse_block_text
    if (yaml_parse_block_chomp == "-") {
        sub(/\n+$/, "", text)
    } else if (yaml_parse_block_chomp != "+") {
        sub(/\n+$/, "", text)
        if (text != "") {
            text = text "\n"
        }
    }
    if (yaml_parse_block_is_key) {
        yaml_parse_stack_pending_value_path[yaml_parse_block_key_depth] = yaml_event_path_join(yaml_parse_stack_path[yaml_parse_block_key_depth], text)
        yaml_parse_stack_pending_container_value[yaml_parse_block_key_depth] = 0
    } else {
        yaml_event_emit_scalar(yaml_parse_doc_id, yaml_parse_block_path, yaml_parse_block_tag, yaml_parse_block_anchor, yaml_parse_block_scalar_style_name(), text, (yaml_parse_block_tag_explicit ? "explicit-tag" : ""))
    }
    yaml_parse_reset_block_scalar()
}

function yaml_parse_block_scalar_style_name() {
    if (yaml_parse_block_style == "|") {
        return "literal"
    }
    return "folded"
}
