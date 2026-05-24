function yaml_parse_emit_flow_token(kind, token, path, count,    child_path) {
    if (kind == "seq") {
        if (yaml_parse_trim_flow_token(token) != "") {
            child_path = yaml_event_path_join(path, count)
            yaml_parse_flow_item(token, child_path)
            return 1
        }
        return 0
    }
    yaml_parse_flow_mapping_item(token, path)
    return 1
}

function yaml_parse_flow_tokens(kind, body, path,    i, ch, quote, depth, token, count) {
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
            } else if (yaml_parse_quote_escape_char(quote, ch)) {
                i++
                token = token substr(body, i, 1)
            }
        } else if (yaml_parse_quote_start_char(ch)) {
            quote = ch
            token = token ch
        } else if (ch == "[" || ch == "{") {
            depth++
            token = token ch
        } else if (ch == "]" || ch == "}") {
            depth--
            token = token ch
        } else if (kind == "seq" && ch == "#" && depth == 0 && yaml_parse_trim_flow_token(token) == "") {
            yaml_parse_error()
            return count
        } else if (ch == "," && depth == 0) {
            if (yaml_parse_emit_flow_token(kind, token, path, count)) {
                if (yaml_parse_failed) {
                    return count
                }
                count++
            } else if (kind == "seq") {
                yaml_parse_error()
                return count
            }
            token = ""
        } else {
            token = token ch
        }
    }
    yaml_parse_emit_flow_token(kind, token, path, count)
    return count
}

function yaml_parse_flow_sequence(text, path,    body) {
    if (yaml_parse_trim(text) ~ /^\[/ && text ~ /\n[ \t]*:/) {
        body = substr(text, index(text, "[") + 1)
        sub(/\n.*/, "", body)
        body = yaml_parse_trim_flow_token(body)
        yaml_parse_start_seq(path, 0)
        if (body != "") {
            child_path = yaml_event_path_join(path, 0)
            yaml_parse_emit_value(child_path, body)
        }
        yaml_parse_error()
        return 1
    }
    body = yaml_parse_trim_flow_token(text)
    if (substr(body, 1, 1) != "[" || substr(body, length(body), 1) != "]") {
        return 0
    }
    body = substr(body, 2, length(body) - 2)

    yaml_parse_start_seq(path, 0)
    yaml_parse_flow_tokens("seq", body, path)
    if (yaml_parse_failed) {
        return 1
    }
    yaml_parse_close_container()
    return 1
}

function yaml_parse_flow_item(text, path,    item, child_path) {
    item = yaml_parse_trim_flow_token(text)
    if (item == "-") {
        yaml_parse_error()
    } else if (item == "---" || item == "...") {
        yaml_parse_error()
    } else if (substr(item, 1, 1) == "[" && substr(item, length(item), 1) == "]") {
        yaml_parse_flow_sequence(item, path)
    } else if (substr(item, 1, 1) == "{" && substr(item, length(item), 1) == "}") {
        yaml_parse_flow_mapping(item, path)
    } else if (yaml_parse_flow_mapping_pair(item)) {
        yaml_parse_start_map(path, 0)
        child_path = yaml_event_path_join(path, yaml_parse_key_text(yaml_parse_key))
        yaml_parse_emit_value(child_path, yaml_parse_value)
        yaml_parse_close_container()
    } else {
        yaml_parse_emit_value(path, item)
    }
}

function yaml_parse_emit_partial_flow_sequence_first(text, path,    body, comma, item, child_path) {
    body = yaml_parse_trim_flow_token(text)
    if (substr(body, 1, 1) != "[") {
        return 0
    }
    body = substr(body, 2)
    comma = index(body, ",")
    if (comma) {
        item = substr(body, 1, comma - 1)
    } else {
        item = body
    }
    item = yaml_parse_trim_flow_token(item)
    yaml_parse_start_seq(path, 0)
    if (item != "") {
        child_path = yaml_event_path_join(path, 0)
        yaml_parse_emit_value(child_path, item)
    }
    return 1
}

function yaml_parse_flow_mapping(text, path,    body) {
    body = yaml_parse_trim_flow_token(text)
    if (substr(body, 1, 1) != "{" || substr(body, length(body), 1) != "}") {
        return 0
    }
    body = substr(body, 2, length(body) - 2)

    yaml_parse_start_map(path, 0)
    if (text ~ /\n:[ \t]*(\n|$)/) {
        yaml_parse_error()
        return 1
    }
    yaml_parse_flow_tokens("map", body, path)
    if (!yaml_parse_failed) {
        yaml_parse_close_container()
    }
    return 1
}

function yaml_parse_flow_mapping_item(text, path,    child_path) {
    if (yaml_parse_trim_flow_token(text) == "") {
        return
    }
    if (text ~ /\n:[ \t]*(\n|$)/) {
        yaml_parse_error()
        return
    }
    if (!yaml_parse_flow_mapping_pair(text)) {
        yaml_parse_key = yaml_parse_trim_flow_token(text)
        if (yaml_parse_key == "?") {
            yaml_parse_key = ""
        }
        yaml_parse_value = ""
    } else if (yaml_parse_flow_mapping_colon(yaml_parse_value)) {
        yaml_parse_error()
        return
    }
    child_path = yaml_event_path_join(path, yaml_parse_key_text(yaml_parse_key))
    yaml_parse_emit_value(child_path, yaml_parse_value)
}

function yaml_parse_flow_mapping_pair(text,    colon) {
    text = yaml_parse_trim_flow_token(text)
    colon = yaml_parse_flow_mapping_colon(text)
    if (!colon) {
        return 0
    }
    yaml_parse_key = yaml_parse_trim_flow_token(substr(text, 1, colon - 1))
    if (yaml_parse_key ~ /^\?[ \t]/) {
        yaml_parse_key = yaml_parse_trim(substr(yaml_parse_key, 2))
    }
    yaml_parse_value = yaml_parse_trim_flow_token(substr(text, colon + 1))
    return 1
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
            } else if (yaml_parse_quote_escape_char(quote, ch)) {
                i++
            }
        } else if (in_tag) {
            if (ch == ">") {
                in_tag = 0
            }
        } else if (yaml_parse_quote_start_char(ch)) {
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

function yaml_parse_partial_incomplete_outer_sequence(text, path,    body, inner, item_path) {
    body = yaml_parse_trim_flow_token(text)
    if (body !~ /^\[[ \t]*\[[^]]*\]$/) {
        return 0
    }
    inner = yaml_parse_trim(substr(body, 2))
    yaml_parse_start_seq(path, 0)
    item_path = yaml_event_path_join(path, 0)
    yaml_parse_flow_sequence(inner, item_path)
    return 1
}

function yaml_parse_trim_flow_token(text) {
    text = yaml_parse_strip_flow_comments(text)
    gsub(/[ \t\r\n]+/, " ", text)
    return yaml_parse_trim(text)
}

function yaml_parse_strip_flow_comments(text,    lines, count, i, line, out) {
    count = split(text, lines, "\n")
    out = ""
    for (i = 1; i <= count; i++) {
        line = yaml_parse_strip_inline_comment(lines[i])
        if (yaml_parse_trim(line) == "") {
            continue
        }
        out = out (out == "" ? "" : "\n") line
    }
    return out
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
            } else if (yaml_parse_quote_escape_char(quote, ch)) {
                i++
            }
        } else if (yaml_parse_quote_start_char(ch)) {
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

function yaml_parse_continue_pending_flow(line, indent) {
    if (!yaml_parse_pending_flow) {
        return 0
    }
    if (line ~ /^[ \t]*$/) {
        return 1
    }
    if (line ~ /^[ \t]*#/) {
        if (yaml_parse_pending_flow_path != "" && index(yaml_parse_flow_buffer, ",") == 0 && yaml_parse_emit_partial_flow_sequence_first(yaml_parse_flow_buffer, yaml_parse_pending_flow_path)) {
            yaml_parse_error()
        }
        return 1
    }
    if (yaml_parse_pending_flow_path == "" && yaml_parse_flow_buffer ~ /^[ \t]*\[/ && line ~ /^\][ \t]*:/) {
        yaml_parse_emit_partial_flow_sequence_first(yaml_parse_flow_buffer, "")
        yaml_parse_error()
        return 1
    }
    if (yaml_parse_pending_flow_path != "" && indent <= yaml_parse_pending_flow_indent && line !~ /^[\]}]/ && yaml_parse_emit_partial_flow_sequence_first(yaml_parse_flow_buffer, yaml_parse_pending_flow_path)) {
        yaml_parse_error()
        return 1
    }
    yaml_parse_flow_buffer = yaml_parse_flow_buffer "\n" line
    if (yaml_parse_flow_complete(yaml_parse_flow_buffer)) {
        yaml_parse_emit_value(yaml_parse_pending_flow_path, yaml_parse_flow_buffer)
        if (yaml_parse_pending_flow_path == "" && !yaml_parse_failed) {
            yaml_parse_root_complete = 1
        }
        yaml_parse_pending_flow = 0
        yaml_parse_flow_buffer = ""
        yaml_parse_pending_flow_path = ""
    }
    return 1
}
