function yaml_parse_init() {
    yaml_parse_doc_id = 0
    yaml_parse_started = 0
    yaml_parse_tag_handle["!!"] = "tag:yaml.org,2002:"
    yaml_parse_direct_unicode = (sprintf("%c", 9786) != ":")
}

function yaml_parse_start_document() {
    if (yaml_parse_started) {
        return
    }
    yaml_parse_started = 1
    yaml_parse_root_complete = 0
    yaml_event_emit_doc_start(yaml_parse_doc_id)
}

function yaml_parse_error(reason) {
    yaml_parse_failed = 1
    if (ENVIRON["YAML_DEBUG"]) {
        if (reason == "") {
            reason = "parse error"
        }
        print FILENAME ":" FNR ": " reason > "/dev/stderr"
    }
}

function yaml_parse_finish(    i) {
    if (!yaml_parse_started) {
        return
    }
    if (yaml_parse_failed) {
        return
    }
    yaml_parse_finish_quoted_scalar()
    if (yaml_parse_failed) {
        return
    }
    yaml_parse_finish_plain_scalar()
    yaml_parse_finalize_explicit_key()
    if (yaml_parse_empty_doc_pending) {
        yaml_event_emit_scalar(yaml_parse_doc_id, "", "tag:yaml.org,2002:str", "", "plain", "")
        yaml_parse_empty_doc_pending = 0
    }
    if (yaml_parse_pending_item_path != "") {
        yaml_parse_emit_scalar(yaml_parse_pending_item_path, "")
        yaml_parse_pending_item_path = ""
    }
    if (yaml_parse_depth == 0 && (yaml_parse_pending_node_tag != "" || yaml_parse_pending_node_anchor != "")) {
        yaml_parse_emit_scalar("", "")
    }
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
        yaml_parse_pending_node_tag = ""
        yaml_parse_pending_node_tag_explicit = 0
        yaml_parse_failed = 0
        yaml_parse_ignore_to_doc_end = 0
        yaml_parse_empty_doc_pending = 0
        yaml_parse_root_complete = 0
        yaml_parse_seen_yaml_directive = 0
        yaml_parse_deferred_doc_start = 0
        yaml_parse_clear_anchor_values()
        yaml_parse_reset_tag_handles()
    }
}

function yaml_parse_clear_anchor_values(    anchor) {
    for (anchor in yaml_parse_anchor_scalar_value) {
        delete yaml_parse_anchor_scalar_value[anchor]
    }
}

function yaml_parse_start_deferred_document() {
    if (yaml_parse_deferred_doc_start && !yaml_parse_failed) {
        yaml_parse_deferred_doc_start = 0
        yaml_parse_start_document()
        yaml_parse_empty_doc_pending = 1
    }
}

function yaml_parse_reset_tag_handles(    handle) {
    for (handle in yaml_parse_tag_handle) {
        if (handle != "!!") {
            delete yaml_parse_tag_handle[handle]
        }
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
        } else {
            if (yaml_parse_stack_type[yaml_parse_depth] == "seq" && indent <= yaml_parse_stack_indent[yaml_parse_depth]) {
                yaml_parse_close_container()
            } else if (indent < yaml_parse_stack_indent[yaml_parse_depth]) {
                yaml_parse_close_container()
            } else {
                break
            }
        }
    }
}

function yaml_parse_start_seq(path, indent,    anchor, tag) {
    anchor = yaml_parse_take_pending_anchor()
    tag = yaml_parse_take_pending_tag()
    yaml_parse_take_pending_tag_explicit()
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
    yaml_parse_take_pending_tag_explicit()
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

function yaml_parse_take_pending_tag_explicit(    explicit) {
    explicit = yaml_parse_pending_node_tag_explicit
    yaml_parse_pending_node_tag_explicit = 0
    return explicit
}

function yaml_parse_pending_node_property(text,    token) {
    text = yaml_parse_trim(text)
    text = yaml_parse_strip_inline_comment(text)
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
            yaml_parse_pending_node_tag_explicit = 1
            return 1
        }
    }
    return 0
}

function yaml_parse_pending_node_is_container() {
    return yaml_parse_pending_node_tag == "tag:yaml.org,2002:map" || yaml_parse_pending_node_tag == "tag:yaml.org,2002:seq"
}

function yaml_parse_quote_start_char(ch) {
    return ch == "\"" || ch == "'"
}

function yaml_parse_quote_escape_char(quote, ch) {
    return quote == "\"" && ch == "\\"
}

function yaml_parse_strip_inline_comment(text,    i, ch, quote, prev, out) {
    quote = ""
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        prev = substr(text, i - 1, 1)
        if (quote != "") {
            if (ch == quote) {
                quote = ""
            } else if (yaml_parse_quote_escape_char(quote, ch)) {
                i++
            }
        } else if (yaml_parse_quote_start_char(ch)) {
            quote = ch
        } else if (ch == "#" && (i == 1 || prev == " " || prev == "\t")) {
            out = substr(text, 1, i - 1)
            sub(/[ \t]+$/, "", out)
            return out
        }
    }
    return text
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

function yaml_parse_emit_scalar(path, value,    parsed, tag, anchor, explicit_tag) {
    parsed = yaml_parse_scalar(value)
    if (yaml_parse_failed) {
        return
    }
    if (parsed == "alias") {
        if (yaml_parse_pending_node_anchor != "" || yaml_parse_pending_node_tag != "") {
            yaml_parse_error()
            return
        }
        yaml_event_emit_alias(yaml_parse_doc_id, path, yaml_parse_scalar_anchor)
    } else {
        tag = yaml_parse_take_pending_tag()
        explicit_tag = yaml_parse_take_pending_tag_explicit()
        if (tag == "") {
            tag = yaml_parse_scalar_tag
            explicit_tag = yaml_parse_scalar_tag_explicit
        }
        anchor = yaml_parse_take_pending_anchor()
        if (anchor == "") {
            anchor = yaml_parse_scalar_anchor
        }
        yaml_event_emit_scalar(yaml_parse_doc_id, path, tag, anchor, yaml_parse_scalar_style, yaml_parse_scalar_value_text, (explicit_tag ? "explicit-tag" : ""))
        if (anchor != "") {
            yaml_parse_anchor_scalar_value[anchor] = yaml_parse_scalar_value_text
        }
    }
}

function yaml_parse_emit_value(path, value) {
    value = yaml_parse_extract_node_properties(value)
    if (yaml_parse_flow_sequence(value, path)) {
        return
    }
    if (yaml_parse_flow_mapping(value, path)) {
        return
    }
    yaml_parse_emit_scalar(path, value)
}

function yaml_parse_extract_node_properties(text,    token) {
    text = yaml_parse_trim(text)
    while (text != "") {
        if (substr(text, 1, 1) == "&") {
            token = text
            sub(/[ \t].*$/, "", token)
            yaml_parse_pending_node_anchor = substr(token, 2)
            text = yaml_parse_trim(yaml_parse_strip_inline_comment(substr(text, length(token) + 1)))
        } else if (substr(text, 1, 2) == "!!") {
            token = text
            sub(/[ \t].*$/, "", token)
            if (token ~ /,/) {
                yaml_parse_error()
                return ""
            }
            yaml_parse_pending_node_tag = yaml_parse_tag_handle["!!"] substr(token, 3)
            yaml_parse_pending_node_tag_explicit = 1
            text = yaml_parse_trim(yaml_parse_strip_inline_comment(substr(text, length(token) + 1)))
        } else if (substr(text, 1, 2) == "!<" && index(text, ">")) {
            token = substr(text, 1, index(text, ">"))
            yaml_parse_pending_node_tag = substr(token, 3, length(token) - 3)
            yaml_parse_pending_node_tag_explicit = 1
            text = yaml_parse_trim(yaml_parse_strip_inline_comment(substr(text, length(token) + 1)))
        } else if (substr(text, 1, 1) == "!") {
            token = text
            sub(/[ \t].*$/, "", token)
            yaml_parse_pending_node_tag = yaml_parse_resolve_tag(token)
            yaml_parse_pending_node_tag_explicit = 1
            text = yaml_parse_trim(yaml_parse_strip_inline_comment(substr(text, length(token) + 1)))
        } else {
            break
        }
    }
    return text
}

function yaml_parse_flow_collection_start(value) {
    value = yaml_parse_trim(value)
    return substr(value, 1, 1) == "[" || substr(value, 1, 1) == "{"
}

function yaml_parse_flow_closed_prefix(text,    open_ch, close_ch, i, ch, quote, depth) {
    text = yaml_parse_trim(text)
    open_ch = substr(text, 1, 1)
    if (open_ch == "[") {
        close_ch = "]"
    } else if (open_ch == "{") {
        close_ch = "}"
    } else {
        return 0
    }
    quote = ""
    depth = 0
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
        } else if (ch == "]" || ch == "}") {
            depth--
            if (depth == 0) {
                return i
            }
        }
    }
    return 0
}

function yaml_parse_emit_or_start_flow(path, value) {
    yaml_parse_flow_prefix = yaml_parse_flow_closed_prefix(value)
    if (yaml_parse_flow_prefix) {
        yaml_parse_emit_value(path, substr(yaml_parse_trim(value), 1, yaml_parse_flow_prefix))
        if (path == "" && !yaml_parse_failed) {
            yaml_parse_root_complete = 1
        }
        yaml_parse_flow_trailing_raw = substr(yaml_parse_trim(value), yaml_parse_flow_prefix + 1)
        if (substr(yaml_parse_flow_trailing_raw, 1, 1) == "#") {
            yaml_parse_error()
            return
        }
        yaml_parse_flow_trailing = yaml_parse_trim(yaml_parse_strip_inline_comment(yaml_parse_flow_trailing_raw))
        if (yaml_parse_flow_trailing != "") {
            if (path != "") {
                yaml_parse_error()
            }
        }
    } else if (yaml_parse_flow_complete(value)) {
        yaml_parse_emit_value(path, value)
        if (path == "" && !yaml_parse_failed) {
            yaml_parse_root_complete = 1
        }
    } else {
        yaml_parse_pending_flow = 1
        yaml_parse_pending_flow_path = path
        yaml_parse_flow_buffer = value
        yaml_parse_pending_flow_indent = yaml_parse_current_line_indent
    }
}

function yaml_parse_emit_or_start_node_value(path, value, indent, plain_indent, root_continues, block_indent, allow_plain, allow_block, invalid_block_errors, invalid_quote_trailing_errors, mapping_colon_errors) {
    if (invalid_block_errors && yaml_parse_invalid_block_scalar_indicator(value)) {
        yaml_parse_error()
        return 1
    }
    if (allow_block && yaml_parse_block_scalar_indicator(value)) {
        yaml_parse_start_block_scalar(path, value, block_indent)
        return 1
    }
    if (invalid_quote_trailing_errors && yaml_parse_quoted_scalar_has_invalid_trailing(value)) {
        yaml_parse_emit_value(path, substr(yaml_parse_trim(value), 1, yaml_parse_quoted_scalar_closed_prefix(value)))
        yaml_parse_error()
        return 1
    }
    if (yaml_parse_quoted_scalar_start(value) && !yaml_parse_quoted_scalar_complete(value)) {
        yaml_parse_start_quoted_scalar(path, value, indent)
        return 1
    }
    if (yaml_parse_flow_collection_start(value)) {
        yaml_parse_emit_or_start_flow(path, value)
        return 1
    }
    if (mapping_colon_errors && yaml_parse_mapping_colon(value)) {
        yaml_parse_error()
        return 1
    }
    if (allow_plain && yaml_parse_plain_scalar_candidate(value)) {
        yaml_parse_start_plain_scalar(path, value, plain_indent, root_continues)
    } else {
        yaml_parse_emit_scalar(path, value)
    }
    return 1
}

function yaml_parse_last_pending_key_path(    i) {
    for (i = yaml_parse_depth; i >= 1; i--) {
        if (yaml_parse_stack_type[i] == "map" && yaml_parse_stack_pending_value_path[i] != "") {
            return yaml_parse_stack_pending_value_path[i]
        }
    }
    return ""
}

function yaml_parse_current_map_path(indent,    child_path, parent_depth) {
    if (yaml_parse_pending_item_path != "") {
        yaml_parse_start_map(yaml_parse_pending_item_path, indent)
        yaml_parse_pending_item_path = ""
    } else if (yaml_parse_depth > 0 && yaml_parse_stack_type[yaml_parse_depth] == "map" && yaml_parse_stack_pending_container_value[yaml_parse_depth] && indent > yaml_parse_stack_indent[yaml_parse_depth]) {
        child_path = yaml_parse_stack_pending_value_path[yaml_parse_depth]
        parent_depth = yaml_parse_depth
        yaml_parse_start_map(child_path, indent)
        yaml_parse_stack_pending_value_path[parent_depth] = ""
        yaml_parse_stack_pending_container_value[parent_depth] = 0
    } else if (yaml_parse_depth == 0 || yaml_parse_stack_type[yaml_parse_depth] != "map" || yaml_parse_stack_indent[yaml_parse_depth] != indent) {
        yaml_parse_start_map("", indent)
    }
    return yaml_parse_stack_path[yaml_parse_depth]
}

function yaml_parse_unsupported_compact_complex_key(text) {
    return text ~ /^\?\t/ || text == "? -" || text ~ /^\? [^ \t].*:$/
}

function yaml_parse_emit_unsupported_complex_key_sequence(indent) {
    yaml_parse_start_seq("", indent)
    yaml_parse_start_seq(yaml_event_path_join("", 0), indent + 1)
    yaml_parse_error()
}

function yaml_parse_handle_unsupported_profile(text, indent) {
    if (yaml_parse_unsupported_compact_complex_key(text)) {
        yaml_parse_emit_unsupported_complex_key_sequence(indent)
        return 1
    }
    return 0
}

function yaml_parse_emit_pending_map_null() {
    yaml_parse_finalize_explicit_key()
    if (yaml_parse_depth > 0 && yaml_parse_stack_type[yaml_parse_depth] == "map" && yaml_parse_stack_pending_value_path[yaml_parse_depth] != "") {
        yaml_parse_emit_scalar(yaml_parse_stack_pending_value_path[yaml_parse_depth], "")
        yaml_parse_stack_pending_value_path[yaml_parse_depth] = ""
        yaml_parse_stack_pending_container_value[yaml_parse_depth] = 0
    }
}

function yaml_parse_finalize_explicit_key(    depth) {
    if (!yaml_parse_pending_explicit_key) {
        return
    }
    depth = yaml_parse_pending_explicit_key_depth
    yaml_parse_stack_pending_value_path[depth] = yaml_event_path_join(yaml_parse_stack_path[depth], yaml_parse_pending_explicit_key_text)
    yaml_parse_stack_pending_container_value[depth] = 0
    yaml_parse_pending_explicit_key = 0
    yaml_parse_pending_explicit_key_text = ""
    yaml_parse_pending_explicit_key_depth = 0
}

function yaml_parse_start_block_scalar_key(indicator, indent) {
    yaml_parse_start_block_scalar("", indicator, indent)
    yaml_parse_block_is_key = 1
    yaml_parse_block_key_depth = yaml_parse_depth
}

function yaml_parse_key_text(text,    parsed, anchor) {
    parsed = yaml_parse_scalar(text)
    if (yaml_parse_failed) {
        return yaml_parse_scalar_value_text
    }
    if (parsed == "alias") {
        anchor = yaml_parse_scalar_anchor
        if (anchor in yaml_parse_anchor_scalar_value) {
            return yaml_parse_anchor_scalar_value[anchor]
        }
        return "*" anchor
    }
    if (yaml_parse_scalar_anchor != "") {
        yaml_parse_anchor_scalar_value[yaml_parse_scalar_anchor] = yaml_parse_scalar_value_text
        yaml_event_emit_key_anchor(yaml_parse_doc_id, yaml_parse_scalar_anchor, yaml_parse_scalar_value_text)
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
