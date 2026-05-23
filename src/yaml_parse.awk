BEGIN {
    yaml_parse_doc_id = 0
    yaml_parse_started = 0
    yaml_parse_tag_handle["!!"] = "tag:yaml.org,2002:"
}

function yaml_parse_start_document() {
    if (yaml_parse_started) {
        return
    }
    yaml_parse_started = 1
    yaml_event_emit_doc_start(yaml_parse_doc_id)
}

function yaml_parse_finish(    i) {
    if (!yaml_parse_started) {
        return
    }
    yaml_parse_finish_plain_scalar()
    for (i = yaml_parse_depth; i >= 1; i--) {
        yaml_parse_close_container()
    }
    yaml_event_emit_doc_end(yaml_parse_doc_id)
}

function yaml_parse_end_document(    i) {
    yaml_parse_finish_block_scalar()
    yaml_parse_finish()
    if (yaml_parse_started) {
        yaml_parse_doc_id++
        yaml_parse_started = 0
        yaml_parse_depth = 0
        yaml_parse_pending_item_path = ""
        yaml_parse_pending_node_anchor = ""
    }
}

function yaml_parse_close_container(    type, path) {
    type = yaml_parse_stack_type[yaml_parse_depth]
    path = yaml_parse_stack_path[yaml_parse_depth]
    if (type == "seq") {
        yaml_event_emit_seq_end(yaml_parse_doc_id, path)
    } else if (type == "map") {
        yaml_parse_emit_pending_map_null()
        yaml_event_emit_map_end(yaml_parse_doc_id, path)
    }
    yaml_parse_depth--
}

function yaml_parse_close_for_line(indent, seq_item) {
    while (yaml_parse_depth > 0) {
        if (seq_item) {
            if (indent < yaml_parse_stack_indent[yaml_parse_depth]) {
                yaml_parse_close_container()
            } else if (yaml_parse_stack_type[yaml_parse_depth] != "seq" && indent <= yaml_parse_stack_indent[yaml_parse_depth]) {
                yaml_parse_close_container()
            } else {
                break
            }
        } else if (!seq_item) {
            if (yaml_parse_stack_type[yaml_parse_depth] == "seq" && indent <= yaml_parse_stack_indent[yaml_parse_depth]) {
                yaml_parse_close_container()
            } else if (indent < yaml_parse_stack_indent[yaml_parse_depth]) {
                yaml_parse_close_container()
            } else {
                break
            }
        } else {
            break
        }
    }
}

function yaml_parse_start_seq(path, indent,    anchor, tag) {
    anchor = yaml_parse_take_pending_anchor()
    tag = yaml_parse_take_pending_tag()
    if (tag == "") {
        tag = "tag:yaml.org,2002:seq"
    }
    yaml_event_emit_seq_start(yaml_parse_doc_id, path, tag, anchor)
    yaml_parse_depth++
    yaml_parse_stack_type[yaml_parse_depth] = "seq"
    yaml_parse_stack_path[yaml_parse_depth] = path
    yaml_parse_stack_indent[yaml_parse_depth] = indent
    yaml_parse_stack_next[yaml_parse_depth] = 0
}

function yaml_parse_start_map(path, indent,    anchor, tag) {
    anchor = yaml_parse_take_pending_anchor()
    tag = yaml_parse_take_pending_tag()
    if (tag == "") {
        tag = "tag:yaml.org,2002:map"
    }
    yaml_event_emit_map_start(yaml_parse_doc_id, path, tag, anchor)
    yaml_parse_depth++
    yaml_parse_stack_type[yaml_parse_depth] = "map"
    yaml_parse_stack_path[yaml_parse_depth] = path
    yaml_parse_stack_indent[yaml_parse_depth] = indent
}

function yaml_parse_take_pending_anchor(    anchor) {
    anchor = yaml_parse_pending_node_anchor
    yaml_parse_pending_node_anchor = ""
    return anchor
}

function yaml_parse_take_pending_tag(    tag) {
    tag = yaml_parse_pending_node_tag
    yaml_parse_pending_node_tag = ""
    return tag
}

function yaml_parse_pending_node_property(text,    token) {
    text = yaml_parse_trim(text)
    if (substr(text, 1, 1) == "&") {
        token = text
        sub(/[ \t].*$/, "", token)
        if (token == text) {
            yaml_parse_pending_node_anchor = substr(token, 2)
            return 1
        }
    } else if (substr(text, 1, 1) == "!") {
        token = text
        sub(/[ \t].*$/, "", token)
        if (token == text) {
            if (substr(token, 1, 2) == "!!") {
                yaml_parse_pending_node_tag = "tag:yaml.org,2002:" substr(token, 3)
            } else {
                yaml_parse_pending_node_tag = yaml_parse_resolve_tag(token)
            }
            return 1
        }
    }
    return 0
}

function yaml_parse_pending_node_is_container() {
    return yaml_parse_pending_node_tag == "tag:yaml.org,2002:map" || yaml_parse_pending_node_tag == "tag:yaml.org,2002:seq"
}

function yaml_parse_current_seq_path(indent) {
    if (yaml_parse_depth == 0 || yaml_parse_stack_type[yaml_parse_depth] != "seq" || yaml_parse_stack_indent[yaml_parse_depth] != indent) {
        yaml_parse_start_seq("", indent)
    }
    return yaml_parse_stack_path[yaml_parse_depth]
}

function yaml_parse_next_seq_item_path(indent,    seq_path, item_index) {
    seq_path = yaml_parse_current_seq_path(indent)
    item_index = yaml_parse_stack_next[yaml_parse_depth]
    yaml_parse_stack_next[yaml_parse_depth]++
    return yaml_event_path_join(seq_path, item_index)
}

function yaml_parse_emit_scalar(path, value,    parsed, tag, anchor) {
    parsed = yaml_parse_scalar(value)
    if (parsed == "alias") {
        yaml_event_emit_alias(yaml_parse_doc_id, path, yaml_parse_scalar_anchor)
    } else {
        tag = yaml_parse_take_pending_tag()
        if (tag == "") {
            tag = yaml_parse_scalar_tag
        }
        anchor = yaml_parse_take_pending_anchor()
        if (anchor == "") {
            anchor = yaml_parse_scalar_anchor
        }
        yaml_event_emit_scalar(yaml_parse_doc_id, path, tag, anchor, yaml_parse_scalar_style, yaml_parse_scalar_value_text)
        if (anchor != "") {
            yaml_parse_anchor_scalar_value[anchor] = yaml_parse_scalar_value_text
        }
    }
}

function yaml_parse_emit_value(path, value) {
    if (yaml_parse_flow_sequence(value, path)) {
        return
    }
    if (yaml_parse_flow_mapping(value, path)) {
        return
    }
    yaml_parse_emit_scalar(path, value)
}

function yaml_parse_block_scalar_indicator(text) {
    text = yaml_parse_trim(text)
    return text ~ /^[|>][-+0-9]*([ \t]*#.*)?$/
}

function yaml_parse_start_block_scalar(path, indicator, indent,    trimmed) {
    trimmed = yaml_parse_trim(indicator)
    yaml_parse_pending_block = 1
    yaml_parse_block_path = path
    yaml_parse_block_style = substr(trimmed, 1, 1)
    yaml_parse_block_chomp = ""
    if (index(trimmed, "-")) {
        yaml_parse_block_chomp = "-"
    } else if (index(trimmed, "+")) {
        yaml_parse_block_chomp = "+"
    }
    yaml_parse_block_indent = indent + 2
    yaml_parse_block_text = ""
    yaml_parse_block_started = 0
}

function yaml_parse_append_block_scalar(line,    part) {
    if (length(line) >= yaml_parse_block_indent) {
        part = substr(line, yaml_parse_block_indent + 1)
    } else {
        part = ""
    }
    yaml_parse_block_started = 1
    if (yaml_parse_block_style == "|") {
        yaml_parse_block_text = yaml_parse_block_text part "\n"
    } else if (part == "") {
        yaml_parse_block_text = yaml_parse_block_text "\n"
    } else {
        if (yaml_parse_block_text != "" && substr(yaml_parse_block_text, length(yaml_parse_block_text), 1) != "\n") {
            yaml_parse_block_text = yaml_parse_block_text " "
        }
        yaml_parse_block_text = yaml_parse_block_text part
    }
}

function yaml_parse_finish_block_scalar(    text) {
    if (!yaml_parse_pending_block) {
        return
    }
    text = yaml_parse_block_text
    if (yaml_parse_block_style == ">") {
        if (yaml_parse_block_chomp != "-" && substr(text, length(text), 1) != "\n") {
            text = text "\n"
        }
    }
    if (yaml_parse_block_chomp == "-") {
        sub(/\n+$/, "", text)
    }
    yaml_event_emit_scalar(yaml_parse_doc_id, yaml_parse_block_path, "tag:yaml.org,2002:str", "", yaml_parse_block_scalar_style_name(), text)
    yaml_parse_pending_block = 0
    yaml_parse_block_path = ""
    yaml_parse_block_text = ""
}

function yaml_parse_plain_scalar_candidate(value,    parsed) {
    parsed = yaml_parse_scalar(value)
    return parsed == "scalar" && yaml_parse_scalar_style == "plain"
}

function yaml_parse_start_plain_scalar(path, value, indent, root_continues,    tag, anchor) {
    yaml_parse_scalar(value)
    tag = yaml_parse_take_pending_tag()
    if (tag == "") {
        tag = yaml_parse_scalar_tag
    }
    anchor = yaml_parse_take_pending_anchor()
    if (anchor == "") {
        anchor = yaml_parse_scalar_anchor
    }
    yaml_parse_pending_plain = 1
    yaml_parse_plain_path = path
    yaml_parse_plain_tag = tag
    yaml_parse_plain_anchor = anchor
    yaml_parse_plain_indent = indent
    yaml_parse_plain_root_continues = root_continues
    yaml_parse_plain_text = yaml_parse_scalar_value_text
    yaml_parse_plain_blank = 0
}

function yaml_parse_append_plain_scalar(line,    text) {
    if (line ~ /^[ \t]*$/) {
        yaml_parse_plain_blank++
        return
    }
    text = yaml_parse_trim(line)
    if (yaml_parse_plain_blank) {
        yaml_parse_plain_text = yaml_parse_plain_text "\n" text
        yaml_parse_plain_blank = 0
    } else if (yaml_parse_plain_text != "") {
        yaml_parse_plain_text = yaml_parse_plain_text " " text
    } else {
        yaml_parse_plain_text = text
    }
}

function yaml_parse_finish_plain_scalar() {
    if (!yaml_parse_pending_plain) {
        return
    }
    yaml_event_emit_scalar(yaml_parse_doc_id, yaml_parse_plain_path, yaml_parse_plain_tag, yaml_parse_plain_anchor, "plain", yaml_parse_plain_text)
    if (yaml_parse_plain_anchor != "") {
        yaml_parse_anchor_scalar_value[yaml_parse_plain_anchor] = yaml_parse_plain_text
    }
    yaml_parse_pending_plain = 0
    yaml_parse_plain_path = ""
    yaml_parse_plain_text = ""
    yaml_parse_plain_blank = 0
}

function yaml_parse_line_continues_plain(line, indent) {
    if (!yaml_parse_pending_plain) {
        return 0
    }
    if (line ~ /^(---|\.\.\.)([ \t]|$)/) {
        return 0
    }
    if (yaml_parse_plain_root_continues) {
        return 1
    }
    if (indent == yaml_parse_plain_indent && (substr(yaml_parse_trim(line), 1, 1) == "?" || substr(yaml_parse_trim(line), 1, 1) == ":")) {
        return 0
    }
    if (indent == yaml_parse_plain_indent && yaml_parse_mapping_pair(substr(line, indent + 1))) {
        return 0
    }
    return line ~ /^[ \t]*$/ || indent >= yaml_parse_plain_indent
}

function yaml_parse_block_scalar_style_name() {
    if (yaml_parse_block_style == "|") {
        return "literal"
    }
    return "folded"
}

function yaml_parse_flow_sequence(text, path,    body, i, ch, quote, depth, token, count, child_path) {
    body = yaml_parse_trim(text)
    if (substr(body, 1, 1) != "[" || substr(body, length(body), 1) != "]") {
        return 0
    }
    body = substr(body, 2, length(body) - 2)

    yaml_event_emit_seq_start(yaml_parse_doc_id, path, "tag:yaml.org,2002:seq", "")
    quote = ""
    depth = 0
    token = ""
    count = 0
    for (i = 1; i <= length(body); i++) {
        ch = substr(body, i, 1)
        if (quote != "") {
            token = token ch
            if (ch == quote) {
                quote = ""
            } else if (ch == "\\" && quote == "\"") {
                i++
                token = token substr(body, i, 1)
            }
        } else if (ch == "\"" || ch == "'") {
            quote = ch
            token = token ch
        } else if (ch == "[" || ch == "{") {
            depth++
            token = token ch
        } else if (ch == "]" || ch == "}") {
            depth--
            token = token ch
        } else if (ch == "," && depth == 0) {
            if (yaml_parse_trim_flow_token(token) != "") {
                child_path = yaml_event_path_join(path, count)
                yaml_parse_flow_item(token, child_path)
                count++
            }
            token = ""
        } else {
            token = token ch
        }
    }
    if (yaml_parse_trim_flow_token(token) != "") {
        child_path = yaml_event_path_join(path, count)
        yaml_parse_flow_item(token, child_path)
    }
    yaml_event_emit_seq_end(yaml_parse_doc_id, path)
    return 1
}

function yaml_parse_flow_item(text, path,    item, child_path) {
    item = yaml_parse_trim_flow_token(text)
    if (substr(item, 1, 1) == "[" && substr(item, length(item), 1) == "]") {
        yaml_parse_flow_sequence(item, path)
    } else if (substr(item, 1, 1) == "{" && substr(item, length(item), 1) == "}") {
        yaml_parse_flow_mapping(item, path)
    } else if (yaml_parse_flow_mapping_pair(item)) {
        yaml_event_emit_map_start(yaml_parse_doc_id, path, "tag:yaml.org,2002:map", "")
        child_path = yaml_event_path_join(path, yaml_parse_key_text(yaml_parse_key))
        yaml_parse_emit_value(child_path, yaml_parse_value)
        yaml_event_emit_map_end(yaml_parse_doc_id, path)
    } else {
        yaml_parse_emit_scalar(path, item)
    }
}

function yaml_parse_flow_mapping(text, path,    body, i, ch, quote, depth, token) {
    body = yaml_parse_trim(text)
    if (substr(body, 1, 1) != "{" || substr(body, length(body), 1) != "}") {
        return 0
    }
    body = substr(body, 2, length(body) - 2)

    yaml_event_emit_map_start(yaml_parse_doc_id, path, "tag:yaml.org,2002:map", "")
    quote = ""
    depth = 0
    token = ""
    for (i = 1; i <= length(body); i++) {
        ch = substr(body, i, 1)
        if (quote != "") {
            token = token ch
            if (ch == quote) {
                quote = ""
            } else if (ch == "\\" && quote == "\"") {
                i++
                token = token substr(body, i, 1)
            }
        } else if (ch == "\"" || ch == "'") {
            quote = ch
            token = token ch
        } else if (ch == "[" || ch == "{") {
            depth++
            token = token ch
        } else if (ch == "]" || ch == "}") {
            depth--
            token = token ch
        } else if (ch == "," && depth == 0) {
            yaml_parse_flow_mapping_item(token, path)
            token = ""
        } else {
            token = token ch
        }
    }
    yaml_parse_flow_mapping_item(token, path)
    yaml_event_emit_map_end(yaml_parse_doc_id, path)
    return 1
}

function yaml_parse_flow_mapping_item(text, path,    child_path) {
    if (yaml_parse_trim_flow_token(text) == "") {
        return
    }
    if (!yaml_parse_flow_mapping_pair(text)) {
        yaml_parse_key = yaml_parse_trim_flow_token(text)
        yaml_parse_value = ""
    }
    child_path = yaml_event_path_join(path, yaml_parse_key_text(yaml_parse_key))
    yaml_parse_emit_value(child_path, yaml_parse_value)
}

function yaml_parse_flow_mapping_pair(text,    colon) {
    colon = yaml_parse_flow_mapping_colon(text)
    if (!colon) {
        return 0
    }
    yaml_parse_key = yaml_parse_trim_flow_token(substr(text, 1, colon - 1))
    yaml_parse_value = yaml_parse_trim_flow_token(substr(text, colon + 1))
    return yaml_parse_key != ""
}

function yaml_parse_flow_mapping_colon(text,    i, ch, quote, in_tag, depth, next_ch) {
    quote = ""
    in_tag = 0
    depth = 0
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        next_ch = substr(text, i + 1, 1)
        if (quote != "") {
            if (ch == quote) {
                quote = ""
            } else if (ch == "\\" && quote == "\"") {
                i++
            }
        } else if (in_tag) {
            if (ch == ">") {
                in_tag = 0
            }
        } else if (ch == "\"" || ch == "'") {
            quote = ch
        } else if (ch == "!" && next_ch == "<") {
            in_tag = 1
            i++
        } else if (ch == "[" || ch == "{") {
            depth++
        } else if (ch == "]" || ch == "}") {
            depth--
        } else if (ch == ":" && depth == 0 && (next_ch == "" || next_ch == " " || next_ch == "\t" || substr(yaml_parse_trim(text), 1, 1) == "\"" || substr(yaml_parse_trim(text), 1, 1) == "'")) {
            return i
        }
    }
    return 0
}

function yaml_parse_trim_flow_token(text) {
    gsub(/[ \t\r\n]+/, " ", text)
    return yaml_parse_trim(text)
}

function yaml_parse_flow_complete(text,    i, ch, quote, depth, seen) {
    quote = ""
    depth = 0
    seen = 0
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        if (quote != "") {
            if (ch == quote) {
                quote = ""
            } else if (ch == "\\" && quote == "\"") {
                i++
            }
        } else if (ch == "\"" || ch == "'") {
            quote = ch
        } else if (ch == "[" || ch == "{") {
            depth++
            seen = 1
        } else if (ch == "]" || ch == "}") {
            depth--
            if (seen && depth == 0) {
                return 1
            }
        }
    }
    return 0
}

function yaml_parse_scalar_value(value) {
    value = yaml_parse_trim(value)
    if (substr(value, 1, 1) == "\"" && substr(value, length(value), 1) == "\"") {
        value = substr(value, 2, length(value) - 2)
        value = yaml_parse_unescape_double_quoted(value)
    } else if (substr(value, 1, 1) == "'" && substr(value, length(value), 1) == "'") {
        value = substr(value, 2, length(value) - 2)
        gsub(/''/, "'", value)
    }
    return value
}

function yaml_parse_unescape_double_quoted(value,    out, i, ch, next_ch) {
    out = ""
    for (i = 1; i <= length(value); i++) {
        ch = substr(value, i, 1)
        if (ch == "\\" && i < length(value)) {
            i++
            next_ch = substr(value, i, 1)
            if (next_ch == "n") {
                out = out "\n"
            } else if (next_ch == "t") {
                out = out "\t"
            } else if (next_ch == "r") {
                out = out "\r"
            } else if (next_ch == "b") {
                out = out "\b"
            } else if (next_ch == "f") {
                out = out "\f"
            } else {
                out = out next_ch
            }
        } else {
            out = out ch
        }
    }
    return out
}

function yaml_parse_scalar(text,    token, tag) {
    text = yaml_parse_trim(text)
    yaml_parse_scalar_tag = "tag:yaml.org,2002:str"
    yaml_parse_scalar_anchor = ""
    yaml_parse_scalar_style = "plain"

    while (text != "") {
        if (substr(text, 1, 1) == "&") {
            token = text
            sub(/[ \t].*$/, "", token)
            yaml_parse_scalar_anchor = substr(token, 2)
            text = yaml_parse_trim(substr(text, length(token) + 1))
        } else if (substr(text, 1, 2) == "!!") {
            token = text
            sub(/[ \t].*$/, "", token)
            yaml_parse_scalar_tag = "tag:yaml.org,2002:" substr(token, 3)
            text = yaml_parse_trim(substr(text, length(token) + 1))
        } else if (substr(text, 1, 2) == "!<" && index(text, ">")) {
            token = substr(text, 1, index(text, ">"))
            yaml_parse_scalar_tag = substr(token, 3, length(token) - 3)
            text = yaml_parse_trim(substr(text, length(token) + 1))
        } else if (substr(text, 1, 1) == "!") {
            token = text
            sub(/[ \t].*$/, "", token)
            yaml_parse_scalar_tag = yaml_parse_resolve_tag(token)
            text = yaml_parse_trim(substr(text, length(token) + 1))
        } else {
            break
        }
    }

    if (substr(text, 1, 1) == "*") {
        yaml_parse_scalar_anchor = substr(text, 2)
        return "alias"
    }

    if (substr(text, 1, 1) == "\"") {
        yaml_parse_scalar_style = "double"
    } else if (substr(text, 1, 1) == "'") {
        yaml_parse_scalar_style = "single"
    }
    yaml_parse_scalar_value_text = yaml_parse_scalar_value(text)
    return "scalar"
}

function yaml_parse_resolve_tag(token,    bang, suffix) {
    if (token in yaml_parse_tag_handle) {
        return yaml_parse_tag_handle[token]
    }
    bang = index(substr(token, 2), "!")
    if (bang) {
        bang++
        suffix = substr(token, bang + 1)
        token = substr(token, 1, bang)
        if (token in yaml_parse_tag_handle) {
            return yaml_parse_tag_handle[token] suffix
        }
    }
    return token
}

function yaml_parse_mapping_pair(text,    colon) {
    colon = yaml_parse_mapping_colon(text)
    if (!colon) {
        return 0
    }
    yaml_parse_key = yaml_parse_trim(substr(text, 1, colon - 1))
    yaml_parse_value = yaml_parse_trim(substr(text, colon + 1))
    return yaml_parse_key != ""
}

function yaml_parse_mapping_colon(text,    i, ch, quote, in_tag, next_ch) {
    quote = ""
    in_tag = 0
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        next_ch = substr(text, i + 1, 1)
        if (quote != "") {
            if (ch == quote) {
                quote = ""
            } else if (ch == "\\" && quote == "\"") {
                i++
            }
        } else if (in_tag) {
            if (ch == ">") {
                in_tag = 0
            }
        } else if (ch == "\"" || ch == "'") {
            quote = ch
        } else if (ch == "!" && next_ch == "<") {
            in_tag = 1
            i++
        } else if (ch == ":" && (next_ch == "" || next_ch == " " || next_ch == "\t")) {
            return i
        }
    }
    return 0
}

function yaml_parse_last_pending_key_path(    i) {
    for (i = yaml_parse_depth; i >= 1; i--) {
        if (yaml_parse_stack_type[i] == "map" && yaml_parse_stack_pending_value_path[i] != "") {
            return yaml_parse_stack_pending_value_path[i]
        }
    }
    return ""
}

function yaml_parse_current_map_path(indent) {
    if (yaml_parse_pending_item_path != "") {
        yaml_parse_start_map(yaml_parse_pending_item_path, indent)
        yaml_parse_pending_item_path = ""
    } else if (yaml_parse_depth == 0 || yaml_parse_stack_type[yaml_parse_depth] != "map" || yaml_parse_stack_indent[yaml_parse_depth] != indent) {
        yaml_parse_start_map("", indent)
    }
    return yaml_parse_stack_path[yaml_parse_depth]
}

function yaml_parse_emit_pending_map_null() {
    if (yaml_parse_depth > 0 && yaml_parse_stack_type[yaml_parse_depth] == "map" && yaml_parse_stack_pending_value_path[yaml_parse_depth] != "") {
        yaml_parse_emit_scalar(yaml_parse_stack_pending_value_path[yaml_parse_depth], "")
        yaml_parse_stack_pending_value_path[yaml_parse_depth] = ""
        yaml_parse_stack_pending_container_value[yaml_parse_depth] = 0
    }
}

function yaml_parse_explicit_key(text, indent,    key, child_path) {
    if (text !~ /^\?[ \t]*(.*)$/) {
        return 0
    }
    yaml_parse_current_map_path(indent)
    yaml_parse_emit_pending_map_null()
    key = yaml_parse_trim(substr(text, 2))
    child_path = yaml_event_path_join(yaml_parse_stack_path[yaml_parse_depth], yaml_parse_key_text(key))
    yaml_parse_stack_pending_value_path[yaml_parse_depth] = child_path
    yaml_parse_stack_pending_container_value[yaml_parse_depth] = 0
    return 1
}

function yaml_parse_explicit_value(text, indent,    value, child_path) {
    if (text !~ /^:[ \t]*(.*)$/) {
        return 0
    }
    yaml_parse_current_map_path(indent)
    value = yaml_parse_trim(substr(text, 2))
    child_path = yaml_parse_stack_pending_value_path[yaml_parse_depth]
    if (child_path == "") {
        child_path = yaml_event_path_join(yaml_parse_stack_path[yaml_parse_depth], "")
    }
    yaml_parse_emit_value(child_path, value)
    yaml_parse_stack_pending_value_path[yaml_parse_depth] = ""
    return 1
}

function yaml_parse_key_text(text,    parsed, anchor) {
    parsed = yaml_parse_scalar(text)
    if (parsed == "alias") {
        anchor = yaml_parse_scalar_anchor
        if (anchor in yaml_parse_anchor_scalar_value) {
            return yaml_parse_anchor_scalar_value[anchor]
        }
        return "*" anchor
    }
    return yaml_parse_scalar_value_text
}

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

function yaml_parse_line(line,    indent, text, item_path, map_path, child_path) {
    indent = yaml_parse_indent(line)
    if (yaml_parse_line_continues_plain(line, indent)) {
        yaml_parse_append_plain_scalar(line)
        return
    }
    yaml_parse_finish_plain_scalar()

    if (yaml_parse_pending_block) {
        if (line ~ /^[ \t]*$/ || indent >= yaml_parse_block_indent) {
            yaml_parse_append_block_scalar(line)
            return
        }
        yaml_parse_finish_block_scalar()
    }

    if (yaml_parse_pending_flow) {
        yaml_parse_flow_buffer = yaml_parse_flow_buffer "\n" line
        if (yaml_parse_flow_complete(yaml_parse_flow_buffer)) {
            yaml_parse_emit_value(yaml_parse_pending_flow_path, yaml_parse_flow_buffer)
            yaml_parse_pending_flow = 0
            yaml_parse_flow_buffer = ""
            yaml_parse_pending_flow_path = ""
        }
        return
    }

    if (line ~ /^[ \t]*($|#)/) {
        return
    }

    if (line ~ /^%TAG[ \t]+/) {
        yaml_parse_read_tag_directive(line)
        return
    }
    if (line ~ /^%/) {
        return
    }

    if (line ~ /^---[ \t]+/) {
        yaml_parse_end_document()
        yaml_parse_start_document()
        line = substr(line, 4)
        sub(/^[ \t]+/, "", line)
    } else if (line ~ /^---[ \t]*$/) {
        yaml_parse_end_document()
        return
    } else if (line ~ /^\.\.\.([ \t]|$)/) {
        yaml_parse_end_document()
        return
    }

    yaml_parse_start_document()
    text = substr(line, indent + 1)

    if (yaml_parse_explicit_key(text, indent)) {
        return
    }
    if (yaml_parse_explicit_value(text, indent)) {
        return
    }

    if (text ~ /^-[ \t]*(.*)$/) {
        child_path = yaml_parse_last_pending_key_path()
        if (child_path != "" && yaml_parse_stack_type[yaml_parse_depth] == "map" && yaml_parse_stack_pending_container_value[yaml_parse_depth]) {
            yaml_parse_start_seq(child_path, indent)
            yaml_parse_stack_pending_value_path[yaml_parse_depth - 1] = ""
            yaml_parse_stack_pending_container_value[yaml_parse_depth - 1] = 0
        } else if (yaml_parse_pending_item_path != "") {
            yaml_parse_start_seq(yaml_parse_pending_item_path, indent)
            yaml_parse_pending_item_path = ""
        } else {
            yaml_parse_close_for_line(indent, 1)
        }
        item_path = yaml_parse_next_seq_item_path(indent)
        text = substr(text, 2)
        text = yaml_parse_trim(text)
        if (text == "") {
            yaml_parse_pending_item_path = item_path
            yaml_parse_pending_item_indent = indent
            return
        }
        if (yaml_parse_block_scalar_indicator(text)) {
            yaml_parse_start_block_scalar(item_path, text, indent)
            return
        }
        if (yaml_parse_pending_node_property(text)) {
            if (yaml_parse_pending_node_is_container()) {
                yaml_parse_pending_item_path = item_path
            } else {
                yaml_parse_emit_scalar(item_path, "")
            }
            return
        }
        if (text ~ /^-[ \t]*(.*)$/) {
            yaml_parse_start_seq(item_path, indent + 2)
            item_path = yaml_parse_next_seq_item_path(indent + 2)
            text = substr(text, 2)
            text = yaml_parse_trim(text)
            if (text == "") {
                yaml_parse_pending_item_path = item_path
                yaml_parse_pending_item_indent = indent + 2
            } else {
                yaml_parse_emit_value(item_path, text)
            }
            return
        }
        if (substr(yaml_parse_trim(text), 1, 1) == "[" || substr(yaml_parse_trim(text), 1, 1) == "{") {
            yaml_parse_emit_value(item_path, text)
            return
        }
        if (yaml_parse_mapping_pair(text)) {
            yaml_parse_start_map(item_path, indent + 2)
            child_path = yaml_event_path_join(item_path, yaml_parse_key_text(yaml_parse_key))
            yaml_parse_emit_value(child_path, yaml_parse_value)
        } else {
            yaml_parse_emit_value(item_path, text)
        }
        return
    }

    yaml_parse_close_for_line(indent, 0)
    if (yaml_parse_depth == 0 && (substr(yaml_parse_trim(text), 1, 1) == "[" || substr(yaml_parse_trim(text), 1, 1) == "{")) {
        if (yaml_parse_flow_complete(text)) {
            yaml_parse_emit_value("", text)
        } else {
            yaml_parse_pending_flow = 1
            yaml_parse_pending_flow_path = ""
            yaml_parse_flow_buffer = text
        }
        return
    }
    if (yaml_parse_depth == 0 && !yaml_parse_mapping_pair(text)) {
        if (yaml_parse_block_scalar_indicator(text)) {
            yaml_parse_start_block_scalar("", text, indent)
            return
        }
        if (yaml_parse_pending_node_property(text)) {
            return
        }
        if (yaml_parse_plain_scalar_candidate(text)) {
            yaml_parse_start_plain_scalar("", text, indent, 1)
        } else {
            yaml_parse_emit_scalar("", text)
        }
        return
    }

    if (yaml_parse_depth > 0 && yaml_parse_stack_type[yaml_parse_depth] == "map" && !yaml_parse_mapping_pair(text)) {
        child_path = yaml_parse_last_pending_key_path()
        if (child_path != "") {
            yaml_parse_emit_scalar(child_path, text)
            yaml_parse_stack_pending_value_path[yaml_parse_depth] = ""
            return
        }
    }

    yaml_parse_current_map_path(indent)

    if (yaml_parse_stack_type[yaml_parse_depth] == "map" && yaml_parse_mapping_pair(text)) {
        yaml_parse_emit_pending_map_null()
        child_path = yaml_event_path_join(yaml_parse_stack_path[yaml_parse_depth], yaml_parse_key_text(yaml_parse_key))
        if (yaml_parse_value == "") {
            yaml_parse_stack_pending_value_path[yaml_parse_depth] = child_path
            yaml_parse_stack_pending_container_value[yaml_parse_depth] = 0
        } else if (yaml_parse_block_scalar_indicator(yaml_parse_value)) {
            yaml_parse_start_block_scalar(child_path, yaml_parse_value, indent)
            yaml_parse_stack_pending_value_path[yaml_parse_depth] = ""
            yaml_parse_stack_pending_container_value[yaml_parse_depth] = 0
        } else if (yaml_parse_pending_node_property(yaml_parse_value)) {
            if (yaml_parse_pending_node_is_container()) {
                yaml_parse_stack_pending_value_path[yaml_parse_depth] = child_path
                yaml_parse_stack_pending_container_value[yaml_parse_depth] = 1
            } else {
                yaml_parse_emit_scalar(child_path, "")
                yaml_parse_stack_pending_value_path[yaml_parse_depth] = ""
                yaml_parse_stack_pending_container_value[yaml_parse_depth] = 0
            }
        } else {
            if (substr(yaml_parse_trim(yaml_parse_value), 1, 1) == "[" || substr(yaml_parse_trim(yaml_parse_value), 1, 1) == "{") {
                yaml_parse_emit_value(child_path, yaml_parse_value)
            } else if (yaml_parse_plain_scalar_candidate(yaml_parse_value)) {
                yaml_parse_start_plain_scalar(child_path, yaml_parse_value, indent, 0)
            } else {
                yaml_parse_emit_value(child_path, yaml_parse_value)
            }
            yaml_parse_stack_pending_value_path[yaml_parse_depth] = ""
            yaml_parse_stack_pending_container_value[yaml_parse_depth] = 0
        }
    }
}

function yaml_parse_read_tag_directive(line,    parts) {
    split(line, parts, /[ \t]+/)
    if (parts[2] != "" && parts[3] != "") {
        yaml_parse_tag_handle[parts[2]] = parts[3]
    }
}

{
    yaml_parse_line($0)
}

END {
    yaml_parse_finish_block_scalar()
    yaml_parse_finish()
}
