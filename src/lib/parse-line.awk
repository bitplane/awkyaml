function yaml_parse_mapping_pair(text,    colon) {
    colon = yaml_parse_mapping_colon(text)
    if (!colon) {
        return 0
    }
    yaml_parse_key = yaml_parse_trim(substr(text, 1, colon - 1))
    yaml_parse_value = yaml_parse_trim(substr(text, colon + 1))
    if (substr(yaml_parse_value, 1, 1) == "#") {
        yaml_parse_value = ""
    }
    return yaml_parse_key != ""
}

function yaml_parse_mapping_colon(text,    i, ch, quote, in_tag, next_ch, prev_ch, first_nonblank, token) {
    quote = ""
    in_tag = 0
    first_nonblank = match(text, /[^ \t]/)
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        next_ch = substr(text, i + 1, 1)
        prev_ch = substr(text, i - 1, 1)
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
        } else if ((ch == "&" || ch == "*") && i == first_nonblank) {
            token = substr(text, i)
            sub(/[ \t].*$/, "", token)
            i += length(token) - 1
        } else if (yaml_parse_quote_start_char(ch) && i == first_nonblank) {
            quote = ch
        } else if (ch == "!" && next_ch == "<") {
            in_tag = 1
            i++
        } else if (ch == "#" && (i == 1 || prev_ch == " " || prev_ch == "\t")) {
            return 0
        } else if (ch == ":" && (next_ch == "" || next_ch == " " || next_ch == "\t")) {
            return i
        }
    }
    return 0
}

function yaml_parse_explicit_key(text, indent,    key) {
    if (text !~ /^\?([ \t].*)?$/) {
        return 0
    }
    yaml_parse_current_map_path(indent)
    yaml_parse_emit_pending_map_null()
    key = yaml_parse_trim(substr(text, 2))
    if (yaml_parse_block_scalar_indicator(key)) {
        yaml_parse_start_block_scalar_key(key, indent)
    } else {
        yaml_parse_pending_explicit_key = 1
        yaml_parse_pending_explicit_key_text = yaml_parse_key_text(key)
        yaml_parse_pending_explicit_key_depth = yaml_parse_depth
        yaml_parse_pending_explicit_key_indent = indent
    }
    yaml_parse_stack_pending_container_value[yaml_parse_depth] = 0
    return 1
}

function yaml_parse_explicit_value(text, indent,    value, explicit_child_path, item_path, map_depth) {
    if (text !~ /^:([ \t].*)?$/) {
        return 0
    }
    yaml_parse_current_map_path(indent)
    yaml_parse_finalize_explicit_key()
    map_depth = yaml_parse_depth
    value = yaml_parse_trim(substr(text, 2))
    explicit_child_path = yaml_parse_stack_pending_value_path[yaml_parse_depth]
    if (explicit_child_path == "") {
        explicit_child_path = yaml_event_path_join(yaml_parse_stack_path[yaml_parse_depth], "")
    }
    if (value == "-" || value ~ /^-[ \t]/) {
        yaml_parse_start_seq(explicit_child_path, indent + 2)
        item_path = yaml_parse_next_seq_item_path(indent + 2)
        value = yaml_parse_trim(substr(value, 2))
        if (value == "") {
            yaml_parse_pending_item_path = item_path
            yaml_parse_pending_item_indent = indent + 2
        } else {
            yaml_parse_emit_value(item_path, value)
        }
    } else {
        if (yaml_parse_plain_scalar_candidate(value)) {
            yaml_parse_start_plain_scalar(explicit_child_path, value, indent, 0)
        } else {
            yaml_parse_emit_value(explicit_child_path, value)
        }
    }
    yaml_parse_stack_pending_value_path[map_depth] = ""
    yaml_parse_stack_pending_container_value[map_depth] = 0
    return 1
}

function yaml_parse_continue_pending_quote(line, indent) {
    if (!yaml_parse_pending_quote) {
        return 0
    }
    if (line ~ /^(---|\.\.\.)([ \t]|$)/) {
        yaml_parse_error()
        return 1
    }
    if (yaml_parse_quote_path != "" && indent < yaml_parse_quote_indent && line !~ /^[ \t]*$/) {
        yaml_parse_error()
        return 1
    }
    if (yaml_parse_quote_path != "" && yaml_parse_quote_indent == 0 && indent <= yaml_parse_quote_indent && line !~ /^[ \t]*$/) {
        yaml_parse_error()
        return 1
    }
    if (yaml_parse_quote_path != "" && line ~ /^\t/) {
        yaml_parse_error()
        return 1
    }
    yaml_parse_append_quoted_scalar(line)
    return 1
}

function yaml_parse_plain_line_invalid_mapping_continuation(line, indent) {
    return (yaml_parse_plain_root_continues && indent > yaml_parse_plain_indent && yaml_parse_mapping_pair(yaml_parse_trim(line))) || (!yaml_parse_plain_root_continues && indent > yaml_parse_plain_indent && yaml_parse_mapping_pair(yaml_parse_trim(line))) || (!yaml_parse_plain_root_continues && indent == yaml_parse_plain_indent && yaml_parse_depth > 0 && indent > yaml_parse_stack_indent[yaml_parse_depth] && yaml_parse_mapping_pair(yaml_parse_trim(line)))
}

function yaml_parse_plain_line_invalid_comment_colon(line, indent) {
    return !yaml_parse_plain_root_continues && yaml_parse_depth > 0 && yaml_parse_stack_type[yaml_parse_depth] == "map" && indent == yaml_parse_stack_indent[yaml_parse_depth] && line ~ /[ \t]#.*:/ && !yaml_parse_mapping_pair(yaml_parse_trim(line))
}

function yaml_parse_continue_pending_plain(line, indent) {
    if (!yaml_parse_pending_plain) {
        return 0
    }
    if (yaml_parse_plain_line_invalid_mapping_continuation(line, indent)) {
        yaml_parse_error()
        return 1
    }
    if (!yaml_parse_plain_root_continues && indent <= yaml_parse_plain_indent && yaml_parse_quoted_scalar_start(line)) {
        yaml_parse_finish_plain_scalar()
        return 0
    }
    if (!yaml_parse_plain_root_continues && line ~ /^%/) {
        yaml_parse_finish_plain_scalar()
        yaml_parse_error()
        return 1
    }
    if (yaml_parse_plain_line_invalid_comment_colon(line, indent)) {
        yaml_parse_finish_plain_scalar()
        yaml_parse_error()
        return 1
    }
    if (yaml_parse_plain_comment_break && line !~ /^[ \t]*($|#)/ && line !~ /^(---|\.\.\.)([ \t]|$)/) {
        yaml_parse_finish_plain_scalar()
        if (yaml_parse_plain_root_continues && indent <= yaml_parse_plain_indent) {
            yaml_parse_ignore_to_doc_end = (line ~ /^%/ ? 2 : 1)
            return 1
        }
        if (indent > yaml_parse_plain_indent) {
            yaml_parse_error()
            return 1
        }
        return 0
    }
    if (yaml_parse_line_continues_plain(line, indent)) {
        yaml_parse_append_plain_scalar(line)
        return 1
    }
    yaml_parse_finish_plain_scalar()
    return 0
}

function yaml_parse_continue_pending_block(line, indent) {
    if (!yaml_parse_pending_block) {
        return 0
    }
    if (yaml_parse_block_line_is_document_boundary(line)) {
        yaml_parse_finish_block_scalar()
        return 0
    }
    if (yaml_parse_block_indent < 0 && line ~ /^\t/) {
        yaml_parse_error()
        return 1
    }
    if (yaml_parse_block_line_dedents(line, indent)) {
        yaml_parse_finish_block_scalar()
        return 0
    }
    if (yaml_parse_block_line_continues(line, indent)) {
        yaml_parse_append_block_scalar(line)
        return 1
    }
    yaml_parse_finish_block_scalar()
    return 0
}

function yaml_parse_continue_pending(line, indent) {
    if (yaml_parse_continue_pending_quote(line, indent)) {
        return 1
    }
    if (yaml_parse_continue_pending_plain(line, indent)) {
        return 1
    }
    if (yaml_parse_continue_pending_block(line, indent)) {
        return 1
    }
    if (yaml_parse_continue_pending_flow(line, indent)) {
        return 1
    }
    return 0
}

function yaml_parse_handle_directive_line(line) {
    if (yaml_parse_line_has_invalid_yaml_directive(line)) {
        yaml_parse_error()
        return 1
    }
    if (yaml_parse_line_is_yaml_directive(line) && yaml_parse_seen_yaml_directive) {
        yaml_parse_error()
        return 1
    }
    if (yaml_parse_line_is_yaml_directive(line)) {
        yaml_parse_seen_yaml_directive = 1
    }
    if (yaml_parse_line_is_directive(line) && yaml_parse_started) {
        yaml_parse_error()
        return 1
    }
    if (yaml_parse_line_is_tag_directive(line)) {
        yaml_parse_read_tag_directive(line)
        return 1
    }
    if (yaml_parse_line_is_directive(line)) {
        return 1
    }
    return 0
}

function yaml_parse_handle_document_marker(line,    property_text) {
    yaml_parse_document_marker_text = ""
    if (yaml_parse_line_is_document_start_with_content(line)) {
        yaml_parse_end_document()
        yaml_parse_start_document()
        yaml_parse_document_marker_text = substr(line, 4)
        sub(/^[ \t]+/, "", yaml_parse_document_marker_text)
        if (yaml_parse_document_marker_text == "" || substr(yaml_parse_document_marker_text, 1, 1) == "#") {
            yaml_parse_empty_doc_pending = 1
            return 1
        }
        property_text = yaml_parse_extract_node_properties(yaml_parse_document_marker_text)
        if (property_text != yaml_parse_document_marker_text && yaml_parse_mapping_pair(property_text)) {
            yaml_parse_error()
            return 1
        }
        if (yaml_parse_mapping_pair(property_text)) {
            yaml_parse_error()
            return 1
        }
        return 2
    }
    if (yaml_parse_line_is_document_start(line)) {
        if (!yaml_parse_started && yaml_parse_seen_yaml_directive) {
            yaml_parse_deferred_doc_start = 1
            return 1
        }
        yaml_parse_end_document()
        yaml_parse_start_document()
        yaml_parse_empty_doc_pending = 1
        return 1
    }
    if (yaml_parse_line_is_document_end(line)) {
        yaml_parse_start_deferred_document()
        yaml_parse_end_document()
        return 1
    }
    return 0
}

function yaml_parse_prepare_content_line(line, indent) {
    if (yaml_parse_started && yaml_parse_root_complete) {
        yaml_parse_error()
        return 1
    }
    if (!yaml_parse_started && indent == 0 && line ~ /^&[^ \t]+[ \t]+-[ \t]/) {
        yaml_parse_error()
        return 1
    }
    if (yaml_parse_deferred_doc_start) {
        yaml_parse_start_deferred_document()
    } else {
        yaml_parse_start_document()
    }
    yaml_parse_empty_doc_pending = 0
    yaml_parse_current_text = substr(line, indent + 1)
    if (yaml_parse_handle_unsupported_profile(yaml_parse_current_text, indent)) {
        return 1
    }
    if (yaml_parse_pending_explicit_key && indent > yaml_parse_pending_explicit_key_indent && yaml_parse_current_text !~ /^:/) {
        yaml_parse_pending_explicit_key_text = yaml_parse_pending_explicit_key_text " " yaml_parse_trim(yaml_parse_strip_inline_comment(yaml_parse_current_text))
        return 1
    }
    if (yaml_parse_explicit_key(yaml_parse_current_text, indent)) {
        return 1
    }
    if (yaml_parse_explicit_value(yaml_parse_current_text, indent)) {
        return 1
    }
    return 0
}

function yaml_parse_handle_sequence_item(text, indent,    item_path, seq_child_path, nested_indent, seq_gap) {
    if (!yaml_parse_text_is_sequence_item(text)) {
        return 0
    }
    if (yaml_parse_depth > 1 && yaml_parse_stack_type[yaml_parse_depth] == "map" && yaml_parse_stack_type[yaml_parse_depth - 1] == "seq" && indent > yaml_parse_stack_indent[yaml_parse_depth - 1] && indent < yaml_parse_stack_indent[yaml_parse_depth]) {
        yaml_parse_close_container()
        yaml_parse_error()
        return 1
    }
    if (yaml_parse_depth > 1 && yaml_parse_stack_type[yaml_parse_depth] == "seq" && yaml_parse_stack_type[yaml_parse_depth - 1] == "map" && indent < yaml_parse_stack_indent[yaml_parse_depth] && indent > yaml_parse_stack_indent[yaml_parse_depth - 1]) {
        yaml_parse_close_container()
        yaml_parse_error()
        return 1
    }
    seq_child_path = yaml_parse_last_pending_key_path()
    if (seq_child_path != "" && yaml_parse_stack_type[yaml_parse_depth] == "map" && yaml_parse_stack_pending_container_value[yaml_parse_depth] && (indent > yaml_parse_stack_indent[yaml_parse_depth] || yaml_parse_pending_node_is_container() || (yaml_parse_pending_node_tag == "" && yaml_parse_pending_node_anchor == "") || (yaml_parse_pending_node_tag == "" && yaml_parse_pending_node_anchor != "" && indent == yaml_parse_stack_indent[yaml_parse_depth]))) {
        yaml_parse_start_seq(seq_child_path, indent)
        yaml_parse_stack_pending_value_path[yaml_parse_depth - 1] = ""
        yaml_parse_stack_pending_container_value[yaml_parse_depth - 1] = 0
    } else if (yaml_parse_pending_item_path != "" && indent > yaml_parse_pending_item_indent) {
        yaml_parse_start_seq(yaml_parse_pending_item_path, indent)
        yaml_parse_pending_item_path = ""
    } else {
        if (yaml_parse_pending_item_path != "") {
            yaml_parse_emit_scalar(yaml_parse_pending_item_path, "")
            yaml_parse_pending_item_path = ""
        }
        yaml_parse_close_for_line(indent, 1)
    }
    item_path = yaml_parse_next_seq_item_path(indent)
    text = substr(text, 2)
    seq_gap = yaml_parse_leading_spaces(text)
    if (text ~ /^[ \t]*-$/ && text ~ /\t/) {
        yaml_parse_start_seq(item_path, indent + 1 + seq_gap)
        yaml_parse_error()
        return 1
    }
    text = yaml_parse_trim(text)
    if (text == "") {
        yaml_parse_pending_item_path = item_path
        yaml_parse_pending_item_indent = indent
        return 1
    }
    if (yaml_parse_block_scalar_indicator(text)) {
        yaml_parse_start_block_scalar(item_path, text, indent)
        return 1
    }
    if (yaml_parse_pending_node_property(text)) {
        yaml_parse_pending_item_path = item_path
        yaml_parse_pending_item_indent = indent
        return 1
    }
    nested_indent = indent
    while (yaml_parse_text_is_sequence_item(text)) {
        nested_indent += 1 + seq_gap
        yaml_parse_start_seq(item_path, nested_indent)
        item_path = yaml_parse_next_seq_item_path(nested_indent)
        text = substr(text, 2)
        seq_gap = yaml_parse_leading_spaces(text)
        text = yaml_parse_trim(text)
        if (text == "") {
            yaml_parse_pending_item_path = item_path
            yaml_parse_pending_item_indent = nested_indent
            return 1
        }
    }
    if (text == ":" || text ~ /^:[ \t]/) {
        yaml_parse_start_map(item_path, indent + 2)
        seq_child_path = yaml_event_path_join(item_path, "")
        yaml_parse_emit_value(seq_child_path, yaml_parse_trim(substr(text, 2)))
        yaml_parse_close_container()
        return 1
    }
    if (yaml_parse_flow_collection_start(text) || (yaml_parse_quoted_scalar_start(text) && !yaml_parse_quoted_scalar_complete(text))) {
        yaml_parse_emit_or_start_node_value(item_path, text, (nested_indent > indent ? nested_indent : indent), (nested_indent > indent ? nested_indent + 2 : nested_indent + 1), 0, indent, 1, 0, 0, 0, 0)
        return 1
    }
    if (yaml_parse_mapping_pair(text)) {
        yaml_parse_start_map(item_path, indent + 2)
        seq_child_path = yaml_event_path_join(item_path, yaml_parse_key_text(yaml_parse_key))
        if (yaml_parse_block_scalar_indicator(yaml_parse_value)) {
            yaml_parse_start_block_scalar(seq_child_path, yaml_parse_value, indent + 2)
        } else {
            yaml_parse_emit_value(seq_child_path, yaml_parse_value)
        }
    } else {
        yaml_parse_emit_or_start_node_value(item_path, text, (nested_indent > indent ? nested_indent : indent), (nested_indent > indent ? nested_indent + 2 : nested_indent + 1), 0, indent, 1, 0, 0, 0, 0)
    }
    return 1
}

function yaml_parse_handle_indent_errors(text, indent) {
    if (yaml_parse_line_reenters_sequence_at_map_value_indent(indent)) {
        yaml_parse_error()
        return 1
    }
    if (yaml_parse_line_indents_between_nested_maps(indent)) {
        yaml_parse_close_container()
        yaml_parse_error()
        return 1
    }
    if (yaml_parse_line_starts_orphan_nested_mapping(text, indent)) {
        yaml_parse_error()
        return 1
    }
    if (yaml_parse_line_closes_root_sequence_with_content(indent)) {
        yaml_parse_error()
        return 1
    }
    return 0
}

function yaml_parse_handle_root_value(text, indent,    property_text) {
    if (yaml_parse_depth != 0) {
        return 0
    }
    if (yaml_parse_flow_collection_start(text)) {
        yaml_parse_emit_or_start_flow("", text)
        return 1
    }
    if (yaml_parse_mapping_pair(text)) {
        return 0
    }
    if (yaml_parse_block_scalar_indicator(text)) {
        yaml_parse_start_block_scalar("", text, indent)
        return 1
    }
    property_text = yaml_parse_extract_node_properties(text)
    if (property_text == "") {
        return 1
    }
    if (property_text != text && yaml_parse_pending_node_tag ~ /[{}]/) {
        yaml_parse_error()
        return 1
    }
    if (yaml_parse_pending_node_property(text)) {
        return 1
    }
    if (yaml_parse_quoted_scalar_start(text) && !yaml_parse_quoted_scalar_complete(text)) {
        yaml_parse_start_quoted_scalar("", text, indent)
        return 1
    }
    yaml_parse_emit_or_start_node_value("", property_text, indent, indent, 1, indent, 1, 0, 0, 0, 0)
    return 1
}

function yaml_parse_handle_pending_map_value(text, indent,    pending_child_path) {
    if (!(yaml_parse_depth > 0 && yaml_parse_stack_type[yaml_parse_depth] == "map" && !yaml_parse_mapping_pair(text))) {
        return 0
    }
    pending_child_path = yaml_parse_last_pending_key_path()
    if (pending_child_path != "") {
        if (yaml_parse_pending_node_anchor != "" && text ~ /^&[^ \t]+[ \t]+/) {
            yaml_parse_error()
            return 1
        } else if (yaml_parse_pending_node_anchor != "" && yaml_parse_pending_node_tag == "" && indent <= yaml_parse_stack_indent[yaml_parse_depth] && text ~ /^!/) {
            yaml_parse_emit_scalar(pending_child_path, "")
            yaml_parse_error()
            return 1
        } else if (indent <= yaml_parse_stack_indent[yaml_parse_depth] && yaml_parse_pending_node_property(text)) {
            yaml_parse_error()
            return 1
        } else if (yaml_parse_pending_node_property(text)) {
            yaml_parse_stack_pending_value_path[yaml_parse_depth] = pending_child_path
            yaml_parse_stack_pending_container_value[yaml_parse_depth] = 1
            return 1
        } else {
            yaml_parse_emit_or_start_node_value(pending_child_path, text, indent, indent, 0, yaml_parse_stack_indent[yaml_parse_depth], 1, 1, 0, 0, 0)
        }
        yaml_parse_stack_pending_value_path[yaml_parse_depth] = ""
        yaml_parse_stack_pending_container_value[yaml_parse_depth] = 0
        return 1
    }
    if (yaml_parse_pending_item_path != "") {
        yaml_parse_emit_or_start_node_value(yaml_parse_pending_item_path, yaml_parse_extract_node_properties(text), indent, indent, 0, indent, 0, 0, 0, 0, 0)
        yaml_parse_pending_item_path = ""
        return 1
    }
    return 0
}

function yaml_parse_handle_pending_sequence_value(text, indent) {
    if (!(yaml_parse_pending_item_path != "" && !yaml_parse_mapping_pair(text))) {
        return 0
    }
    yaml_parse_emit_or_start_node_value(yaml_parse_pending_item_path, yaml_parse_extract_node_properties(text), indent, indent, 0, indent, 0, 1, 0, 0, 0)
    yaml_parse_pending_item_path = ""
    return 1
}

function yaml_parse_handle_mapping_pair(text, indent,    pair_child_path, property_text) {
    yaml_parse_current_map_path(indent)
    if (yaml_parse_stack_type[yaml_parse_depth] == "map" && yaml_parse_mapping_pair(text)) {
        yaml_parse_emit_pending_map_null()
        pair_child_path = yaml_event_path_join(yaml_parse_stack_path[yaml_parse_depth], yaml_parse_key_text(yaml_parse_key))
        if (yaml_parse_value == "") {
            yaml_parse_stack_pending_value_path[yaml_parse_depth] = pair_child_path
            yaml_parse_stack_pending_container_value[yaml_parse_depth] = 1
        } else if (yaml_parse_text_is_sequence_item(yaml_parse_value)) {
            yaml_parse_error()
        } else {
            property_text = yaml_parse_extract_node_properties(yaml_parse_value)
            if (property_text == "") {
                yaml_parse_stack_pending_value_path[yaml_parse_depth] = pair_child_path
                yaml_parse_stack_pending_container_value[yaml_parse_depth] = 1
            } else {
                yaml_parse_emit_or_start_node_value(pair_child_path, property_text, indent, indent, 0, indent, 1, 1, 1, 1, 1)
                yaml_parse_stack_pending_value_path[yaml_parse_depth] = ""
                yaml_parse_stack_pending_container_value[yaml_parse_depth] = 0
            }
        }
        return 1
    }
    if (yaml_parse_depth > 0 && yaml_parse_stack_type[yaml_parse_depth] == "map") {
        yaml_parse_error()
        return 1
    }
    return 0
}

function yaml_parse_line(line,    marker, indent, text) {
    if (yaml_parse_failed) {
        return
    }
    indent = yaml_parse_indent(line)
    yaml_parse_current_line_indent = indent
    if (yaml_parse_ignore_to_doc_end) {
        if (yaml_parse_line_is_directive(line)) {
            yaml_parse_ignore_to_doc_end = 2
            return
        }
        if (yaml_parse_ignore_to_doc_end == 1 && (yaml_parse_line_is_document_start(line) || yaml_parse_line_is_document_start_with_content(line) || yaml_parse_line_is_document_end(line))) {
            yaml_parse_ignore_to_doc_end = 0
        } else {
            return
        }
    }
    if (yaml_parse_continue_pending(line, indent)) {
        return
    }

    if (yaml_parse_depth > 0 && line ~ /^ *\t/ && line ~ /:/) {
        yaml_parse_error()
        return
    }

    if (yaml_parse_line_is_blank_or_comment(line)) {
        return
    }

    if (yaml_parse_line_is_directive(line)) {
        yaml_parse_handle_directive_line(line)
        return
    }

    marker = yaml_parse_handle_document_marker(line)
    if (marker == 1) {
        return
    }
    if (marker == 2) {
        line = yaml_parse_document_marker_text
        indent = 0
    }

    if (yaml_parse_prepare_content_line(line, indent)) {
        return
    }
    text = yaml_parse_current_text
    if (yaml_parse_handle_sequence_item(text, indent)) {
        return
    }
    if (yaml_parse_handle_indent_errors(text, indent)) {
        return
    }
    yaml_parse_close_for_line(indent, 0)
    if (yaml_parse_handle_root_value(text, indent)) {
        return
    }
    if (yaml_parse_handle_pending_map_value(text, indent)) {
        return
    }
    if (yaml_parse_handle_pending_sequence_value(text, indent)) {
        return
    }
    yaml_parse_handle_mapping_pair(text, indent)
}
