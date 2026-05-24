BEGIN {
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

function yaml_parse_emit_scalar(path, value,    parsed, tag, anchor) {
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
            text = yaml_parse_trim(yaml_parse_strip_inline_comment(substr(text, length(token) + 1)))
        } else if (substr(text, 1, 2) == "!<" && index(text, ">")) {
            token = substr(text, 1, index(text, ">"))
            yaml_parse_pending_node_tag = substr(token, 3, length(token) - 3)
            text = yaml_parse_trim(yaml_parse_strip_inline_comment(substr(text, length(token) + 1)))
        } else if (substr(text, 1, 1) == "!") {
            token = text
            sub(/[ \t].*$/, "", token)
            yaml_parse_pending_node_tag = yaml_parse_resolve_tag(token)
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

function yaml_parse_quoted_scalar_start(value) {
    value = yaml_parse_trim(value)
    return yaml_parse_quote_start_char(substr(value, 1, 1))
}

function yaml_parse_quoted_scalar_end(value,    quote, i, ch) {
    value = yaml_parse_trim(value)
    quote = substr(value, 1, 1)
    if (!yaml_parse_quote_start_char(quote)) {
        return 0
    }
    for (i = 2; i <= length(value); i++) {
        ch = substr(value, i, 1)
        if (yaml_parse_quote_escape_char(quote, ch)) {
            i++
        } else if (quote == "'" && ch == "'" && substr(value, i + 1, 1) == "'") {
            i++
        } else if (ch == quote) {
            return i
        }
    }
    return 0
}

function yaml_parse_quoted_scalar_complete(value,    end) {
    value = yaml_parse_trim(value)
    end = yaml_parse_quoted_scalar_end(value)
    return end && yaml_parse_trim(substr(value, end + 1)) == ""
}

function yaml_parse_quoted_scalar_closed_prefix(value) {
    return yaml_parse_quoted_scalar_end(value)
}

function yaml_parse_quoted_scalar_has_invalid_trailing(value,    trimmed, prefix, trailing) {
    trimmed = yaml_parse_trim(value)
    prefix = yaml_parse_quoted_scalar_closed_prefix(trimmed)
    if (!prefix) {
        return 0
    }
    trailing = substr(trimmed, prefix + 1)
    if (substr(trailing, 1, 1) == "#") {
        return 1
    }
    return yaml_parse_trim(yaml_parse_strip_inline_comment(trailing)) != ""
}

function yaml_parse_start_quoted_scalar(path, value, indent) {
    yaml_parse_pending_quote = 1
    yaml_parse_quote_path = path
    yaml_parse_quote_indent = indent
    yaml_parse_quote_text = value
    yaml_parse_quote_tag = yaml_parse_take_pending_tag()
    if (yaml_parse_quote_tag == "") {
        yaml_parse_quote_tag = "tag:yaml.org,2002:str"
    }
    yaml_parse_quote_anchor = yaml_parse_take_pending_anchor()
}

function yaml_parse_append_quoted_scalar(line) {
    yaml_parse_quote_text = yaml_parse_quote_text "\n" line
    if (yaml_parse_quoted_scalar_complete(yaml_parse_quote_text)) {
        yaml_parse_finish_quoted_scalar()
    }
}

function yaml_parse_finish_quoted_scalar(    value, quote, style) {
    if (!yaml_parse_pending_quote) {
        return
    }
    if (!yaml_parse_quoted_scalar_complete(yaml_parse_quote_text)) {
        yaml_parse_error()
        return
    }
    value = yaml_parse_multiline_quoted_value(yaml_parse_quote_text)
    quote = substr(yaml_parse_trim(yaml_parse_quote_text), 1, 1)
    style = (quote == "\"" ? "double" : "single")
    yaml_event_emit_scalar(yaml_parse_doc_id, yaml_parse_quote_path, yaml_parse_quote_tag, yaml_parse_quote_anchor, style, value)
    yaml_parse_pending_quote = 0
    yaml_parse_quote_path = ""
    yaml_parse_quote_text = ""
    yaml_parse_quote_tag = ""
    yaml_parse_quote_anchor = ""
}

function yaml_parse_multiline_quoted_value(text,    quote, content, i, ch, lines, count, out, line, raw_line, blank, first_nonempty, j) {
    text = yaml_parse_trim(text)
    quote = substr(text, 1, 1)
    content = substr(text, 2, length(text) - 2)
    if (quote == "\"") {
        gsub(/\\\t[ \t]*\n */, "\t ", content)
        gsub(/\\ *\n */, "", content)
    }
    count = split(content, lines, "\n")
    out = ""
    blank = 0
    first_nonempty = 1
    for (i = 1; i <= count; i++) {
        raw_line = lines[i]
        line = raw_line
        sub(/^[ \t]+/, "", line)
        if (i < count) {
            sub(/[ \t]+$/, "", line)
        }
        if (line == "" && raw_line ~ /^[ \t]+$/ && i == count) {
            line = " "
        }
        if (line == "") {
            blank++
            continue
        }
        if (line == " " && blank && out == "") {
            if (blank == 1) {
                out = " "
            } else {
                for (j = 1; j < blank; j++) {
                    out = out "\n"
                }
            }
            first_nonempty = 0
            blank = 0
            continue
        }
        if (out != "") {
            out = out (blank ? "\n" : " ")
        }
        if (first_nonempty && raw_line ~ /^[ \t]/ && line != " ") {
            line = " " line
        }
        out = out line
        first_nonempty = 0
        blank = 0
    }
    if (blank && out != "") {
        out = out " "
    }
    if (quote == "\"") {
        out = yaml_parse_unescape_double_quoted(out)
    } else {
        gsub(/''/, "'", out)
    }
    return out
}

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
        yaml_event_emit_scalar(yaml_parse_doc_id, yaml_parse_block_path, yaml_parse_block_tag, yaml_parse_block_anchor, yaml_parse_block_scalar_style_name(), text)
    }
    yaml_parse_pending_block = 0
    yaml_parse_block_path = ""
    yaml_parse_block_text = ""
    yaml_parse_block_indentless = 0
    yaml_parse_block_last_blank = 0
    yaml_parse_block_blank_after_text = 0
    yaml_parse_block_leading_blank_indent = 0
    yaml_parse_block_tag = ""
    yaml_parse_block_anchor = ""
    yaml_parse_block_is_key = 0
    yaml_parse_block_key_depth = 0
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
    yaml_parse_plain_comment_break = (yaml_parse_strip_inline_comment(value) != value)
}

function yaml_parse_append_plain_scalar(line,    text, stripped, had_comment) {
    if (line ~ /^[ \t]*#/) {
        yaml_parse_plain_comment_break = 1
        yaml_parse_plain_blank++
        return
    }
    if (line ~ /^[ \t]*$/) {
        yaml_parse_plain_blank++
        return
    }
    stripped = yaml_parse_strip_inline_comment(line)
    had_comment = (stripped != line)
    text = yaml_parse_trim(stripped)
    if (text == "") {
        return
    }
    if (yaml_parse_plain_blank) {
        yaml_parse_plain_text = yaml_parse_plain_text "\n" text
        yaml_parse_plain_blank = 0
    } else if (yaml_parse_plain_text != "") {
        yaml_parse_plain_text = yaml_parse_plain_text " " text
    } else {
        yaml_parse_plain_text = text
    }
    yaml_parse_plain_comment_break = had_comment
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
    yaml_parse_plain_comment_break = 0
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
    return line ~ /^[ \t]*($|#)/ || indent > yaml_parse_plain_indent || (indent == yaml_parse_plain_indent && yaml_parse_depth > 0 && yaml_parse_plain_indent > yaml_parse_stack_indent[yaml_parse_depth])
}

function yaml_parse_block_scalar_style_name() {
    if (yaml_parse_block_style == "|") {
        return "literal"
    }
    return "folded"
}

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

function yaml_parse_unescape_double_quoted(value,    out, i, ch, next_ch, hex) {
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
            } else if (next_ch == "\t") {
                out = out "\t"
            } else if (next_ch == "x" && i + 2 <= length(value)) {
                hex = substr(value, i + 1, 2)
                if (hex ~ /^[0-9A-Fa-f][0-9A-Fa-f]$/) {
                    out = out sprintf("%c", yaml_parse_hex_value(hex))
                    i += 2
                } else {
                    out = out next_ch
                }
            } else if (next_ch == "u" && i + 4 <= length(value)) {
                hex = substr(value, i + 1, 4)
                if (hex ~ /^[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]$/) {
                    out = out yaml_parse_utf8(yaml_parse_hex_value(hex))
                    i += 4
                } else {
                    yaml_parse_error()
                    return out
                }
            } else if (next_ch == "U" && i + 8 <= length(value)) {
                hex = substr(value, i + 1, 8)
                if (hex ~ /^[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]$/) {
                    out = out yaml_parse_utf8(yaml_parse_hex_value(hex))
                    i += 8
                } else {
                    yaml_parse_error()
                    return out
                }
            } else if (next_ch ~ /^[0abtnvfre "\\\/_NLP]$/) {
                out = out next_ch
            } else {
                yaml_parse_error()
                return out
            }
        } else {
            out = out ch
        }
    }
    return out
}

function yaml_parse_hex_value(hex,    i, n, ch) {
    n = 0
    for (i = 1; i <= length(hex); i++) {
        ch = substr(hex, i, 1)
        n = n * 16 + yaml_parse_hex_digit(ch)
    }
    return n
}

function yaml_parse_hex_digit(ch) {
    if (ch >= "0" && ch <= "9") {
        return ch + 0
    }
    if (ch >= "A" && ch <= "F") {
        return index("ABCDEF", ch) + 9
    }
    if (ch >= "a" && ch <= "f") {
        return index("abcdef", ch) + 9
    }
    return 0
}

function yaml_parse_utf8(cp) {
    if (cp > 1114111) {
        yaml_parse_error()
        return ""
    }
    if (cp < 128) {
        return sprintf("%c", cp)
    }
    if (yaml_parse_direct_unicode) {
        return sprintf("%c", cp)
    }
    if (cp < 2048) {
        return sprintf("%c%c", 192 + int(cp / 64), 128 + (cp % 64))
    }
    if (cp < 65536) {
        return sprintf("%c%c%c", 224 + int(cp / 4096), 128 + (int(cp / 64) % 64), 128 + (cp % 64))
    }
    return sprintf("%c%c%c%c", 240 + int(cp / 262144), 128 + (int(cp / 4096) % 64), 128 + (int(cp / 64) % 64), 128 + (cp % 64))
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
            if (token ~ /,/) {
                yaml_parse_error()
                return "scalar"
            }
            yaml_parse_scalar_tag = yaml_parse_tag_handle["!!"] substr(token, 3)
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
        if (yaml_parse_scalar_anchor != "" || yaml_parse_scalar_tag != "tag:yaml.org,2002:str") {
            yaml_parse_error()
            return "scalar"
        }
        yaml_parse_scalar_anchor = substr(yaml_parse_strip_inline_comment(text), 2)
        return "alias"
    }

    if (substr(text, 1, 1) == "\"") {
        yaml_parse_scalar_style = "double"
    } else if (substr(text, 1, 1) == "'") {
        yaml_parse_scalar_style = "single"
    } else {
        text = yaml_parse_strip_inline_comment(text)
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
            return yaml_parse_tag_handle[token] yaml_parse_tag_uri_decode(suffix)
        }
        yaml_parse_error()
        return token
    }
    if (substr(token, 1, 1) == "!" && ("!" in yaml_parse_tag_handle)) {
        return yaml_parse_tag_handle["!"] yaml_parse_tag_uri_decode(substr(token, 2))
    }
    return token
}

function yaml_parse_tag_uri_decode(text,    out, i, ch, hex) {
    out = ""
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        if (ch == "%" && i + 2 <= length(text)) {
            hex = substr(text, i + 1, 2)
            if (hex ~ /^[0-9A-Fa-f][0-9A-Fa-f]$/) {
                out = out sprintf("%c", yaml_parse_hex_value(hex))
                i += 2
                continue
            }
        }
        out = out ch
    }
    return out
}

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

function yaml_parse_explicit_key(text, indent,    key, child_path) {
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

function yaml_parse_explicit_value(text, indent,    value, child_path, item_path, map_depth) {
    if (text !~ /^:([ \t].*)?$/) {
        return 0
    }
    yaml_parse_current_map_path(indent)
    yaml_parse_finalize_explicit_key()
    map_depth = yaml_parse_depth
    value = yaml_parse_trim(substr(text, 2))
    child_path = yaml_parse_stack_pending_value_path[yaml_parse_depth]
    if (child_path == "") {
        child_path = yaml_event_path_join(yaml_parse_stack_path[yaml_parse_depth], "")
    }
    if (value == "-" || value ~ /^-[ \t]/) {
        yaml_parse_start_seq(child_path, indent + 2)
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
            yaml_parse_start_plain_scalar(child_path, value, indent, 0)
        } else {
            yaml_parse_emit_value(child_path, value)
        }
    }
    yaml_parse_stack_pending_value_path[map_depth] = ""
    yaml_parse_stack_pending_container_value[map_depth] = 0
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
    if (yaml_parse_scalar_anchor != "") {
        yaml_parse_anchor_scalar_value[yaml_parse_scalar_anchor] = yaml_parse_scalar_value_text
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

function yaml_parse_leading_spaces(text,    n) {
    n = match(text, /[^ ]/)
    if (!n) {
        return length(text)
    }
    return n - 1
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
    if (yaml_parse_unsupported_compact_complex_key(yaml_parse_current_text)) {
        yaml_parse_emit_unsupported_complex_key_sequence(indent)
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

function yaml_parse_handle_sequence_item(text, indent,    item_path, child_path, nested_indent, seq_gap) {
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
    child_path = yaml_parse_last_pending_key_path()
    if (child_path != "" && yaml_parse_stack_type[yaml_parse_depth] == "map" && yaml_parse_stack_pending_container_value[yaml_parse_depth] && (indent > yaml_parse_stack_indent[yaml_parse_depth] || yaml_parse_pending_node_is_container() || (yaml_parse_pending_node_tag == "" && yaml_parse_pending_node_anchor == "") || (yaml_parse_pending_node_tag == "" && yaml_parse_pending_node_anchor != "" && indent == yaml_parse_stack_indent[yaml_parse_depth]))) {
        yaml_parse_start_seq(child_path, indent)
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
    if (yaml_parse_flow_collection_start(text)) {
        yaml_parse_emit_or_start_flow(item_path, text)
        return 1
    }
    if (yaml_parse_quoted_scalar_start(text) && !yaml_parse_quoted_scalar_complete(text)) {
        yaml_parse_start_quoted_scalar(item_path, text, (nested_indent > indent ? nested_indent : indent))
        return 1
    }
    if (text == ":" || text ~ /^:[ \t]/) {
        yaml_parse_start_map(item_path, indent + 2)
        child_path = yaml_event_path_join(item_path, "")
        yaml_parse_emit_value(child_path, yaml_parse_trim(substr(text, 2)))
        yaml_parse_close_container()
        return 1
    }
    if (yaml_parse_mapping_pair(text)) {
        yaml_parse_start_map(item_path, indent + 2)
        child_path = yaml_event_path_join(item_path, yaml_parse_key_text(yaml_parse_key))
        if (yaml_parse_block_scalar_indicator(yaml_parse_value)) {
            yaml_parse_start_block_scalar(child_path, yaml_parse_value, indent + 2)
        } else {
            yaml_parse_emit_value(child_path, yaml_parse_value)
        }
    } else if (yaml_parse_plain_scalar_candidate(text)) {
        yaml_parse_start_plain_scalar(item_path, text, (nested_indent > indent ? nested_indent + 2 : nested_indent + 1), 0)
    } else {
        yaml_parse_emit_value(item_path, text)
    }
    return 1
}

function yaml_parse_handle_indent_errors(text, indent) {
    if (yaml_parse_depth > 1 && yaml_parse_stack_type[yaml_parse_depth] == "seq" && yaml_parse_stack_type[yaml_parse_depth - 1] == "map" && indent == yaml_parse_stack_indent[yaml_parse_depth] && indent > yaml_parse_stack_indent[yaml_parse_depth - 1]) {
        yaml_parse_error()
        return 1
    }
    if (yaml_parse_depth > 1 && yaml_parse_stack_type[yaml_parse_depth] == "map" && yaml_parse_stack_type[yaml_parse_depth - 1] == "map" && indent > yaml_parse_stack_indent[yaml_parse_depth - 1] && indent < yaml_parse_stack_indent[yaml_parse_depth]) {
        yaml_parse_close_container()
        yaml_parse_error()
        return 1
    }
    if (yaml_parse_depth > 0 && yaml_parse_stack_type[yaml_parse_depth] == "map" && indent > yaml_parse_stack_indent[yaml_parse_depth] && yaml_parse_mapping_pair(text) && yaml_parse_last_pending_key_path() == "") {
        yaml_parse_error()
        return 1
    }
    if (yaml_parse_depth == 1 && yaml_parse_stack_type[yaml_parse_depth] == "seq" && yaml_parse_stack_path[yaml_parse_depth] == "" && indent <= yaml_parse_stack_indent[yaml_parse_depth]) {
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
    if (yaml_parse_flow_collection_start(property_text)) {
        yaml_parse_emit_or_start_flow("", property_text)
        return 1
    }
    if (yaml_parse_pending_node_property(text)) {
        return 1
    }
    if (yaml_parse_quoted_scalar_start(text) && !yaml_parse_quoted_scalar_complete(text)) {
        yaml_parse_start_quoted_scalar("", text, indent)
    } else if (yaml_parse_plain_scalar_candidate(text)) {
        yaml_parse_start_plain_scalar("", text, indent, 1)
    } else {
        yaml_parse_emit_scalar("", text)
    }
    return 1
}

function yaml_parse_handle_pending_map_value(text, indent,    child_path) {
    if (!(yaml_parse_depth > 0 && yaml_parse_stack_type[yaml_parse_depth] == "map" && !yaml_parse_mapping_pair(text))) {
        return 0
    }
    child_path = yaml_parse_last_pending_key_path()
    if (child_path != "") {
        if (yaml_parse_flow_collection_start(text)) {
            yaml_parse_emit_or_start_flow(child_path, text)
        } else if (yaml_parse_pending_node_anchor != "" && text ~ /^&[^ \t]+[ \t]+/) {
            yaml_parse_error()
            return 1
        } else if (yaml_parse_pending_node_anchor != "" && yaml_parse_pending_node_tag == "" && indent <= yaml_parse_stack_indent[yaml_parse_depth] && text ~ /^!/) {
            yaml_parse_emit_scalar(child_path, "")
            yaml_parse_error()
            return 1
        } else if (indent <= yaml_parse_stack_indent[yaml_parse_depth] && yaml_parse_pending_node_property(text)) {
            yaml_parse_error()
            return 1
        } else if (yaml_parse_pending_node_property(text)) {
            yaml_parse_stack_pending_value_path[yaml_parse_depth] = child_path
            yaml_parse_stack_pending_container_value[yaml_parse_depth] = 1
            return 1
        } else if (yaml_parse_block_scalar_indicator(text)) {
            yaml_parse_start_block_scalar(child_path, text, yaml_parse_stack_indent[yaml_parse_depth])
        } else if (yaml_parse_quoted_scalar_start(text) && !yaml_parse_quoted_scalar_complete(text)) {
            yaml_parse_start_quoted_scalar(child_path, text, indent)
        } else if (yaml_parse_plain_scalar_candidate(text)) {
            yaml_parse_start_plain_scalar(child_path, text, indent, 0)
        } else {
            yaml_parse_emit_scalar(child_path, text)
        }
        yaml_parse_stack_pending_value_path[yaml_parse_depth] = ""
        yaml_parse_stack_pending_container_value[yaml_parse_depth] = 0
        return 1
    }
    if (yaml_parse_pending_item_path != "") {
        if (yaml_parse_quoted_scalar_start(text) && !yaml_parse_quoted_scalar_complete(text)) {
            yaml_parse_start_quoted_scalar(yaml_parse_pending_item_path, text, indent)
        } else {
            yaml_parse_emit_value(yaml_parse_pending_item_path, text)
        }
        yaml_parse_pending_item_path = ""
        return 1
    }
    return 0
}

function yaml_parse_handle_pending_sequence_value(text, indent) {
    if (!(yaml_parse_pending_item_path != "" && !yaml_parse_mapping_pair(text))) {
        return 0
    }
    if (yaml_parse_block_scalar_indicator(text)) {
        yaml_parse_start_block_scalar(yaml_parse_pending_item_path, text, indent)
    } else if (yaml_parse_quoted_scalar_start(text) && !yaml_parse_quoted_scalar_complete(text)) {
        yaml_parse_start_quoted_scalar(yaml_parse_pending_item_path, text, indent)
    } else {
        yaml_parse_emit_value(yaml_parse_pending_item_path, text)
    }
    yaml_parse_pending_item_path = ""
    return 1
}

function yaml_parse_handle_mapping_pair(text, indent,    child_path, property_text) {
    yaml_parse_current_map_path(indent)
    if (yaml_parse_stack_type[yaml_parse_depth] == "map" && yaml_parse_mapping_pair(text)) {
        yaml_parse_emit_pending_map_null()
        child_path = yaml_event_path_join(yaml_parse_stack_path[yaml_parse_depth], yaml_parse_key_text(yaml_parse_key))
        if (yaml_parse_value == "") {
            yaml_parse_stack_pending_value_path[yaml_parse_depth] = child_path
            yaml_parse_stack_pending_container_value[yaml_parse_depth] = 1
        } else if (yaml_parse_text_is_sequence_item(yaml_parse_value)) {
            yaml_parse_error()
        } else {
            property_text = yaml_parse_extract_node_properties(yaml_parse_value)
            if (property_text == "") {
                yaml_parse_stack_pending_value_path[yaml_parse_depth] = child_path
                yaml_parse_stack_pending_container_value[yaml_parse_depth] = 1
            } else if (yaml_parse_invalid_block_scalar_indicator(property_text)) {
                yaml_parse_error()
            } else if (yaml_parse_block_scalar_indicator(property_text)) {
                yaml_parse_start_block_scalar(child_path, property_text, indent)
                yaml_parse_stack_pending_value_path[yaml_parse_depth] = ""
                yaml_parse_stack_pending_container_value[yaml_parse_depth] = 0
            } else if (yaml_parse_quoted_scalar_has_invalid_trailing(property_text)) {
                yaml_parse_emit_value(child_path, substr(yaml_parse_trim(property_text), 1, yaml_parse_quoted_scalar_closed_prefix(property_text)))
                yaml_parse_stack_pending_value_path[yaml_parse_depth] = ""
                yaml_parse_stack_pending_container_value[yaml_parse_depth] = 0
                yaml_parse_error()
            } else if (yaml_parse_quoted_scalar_start(property_text) && !yaml_parse_quoted_scalar_complete(property_text)) {
                yaml_parse_start_quoted_scalar(child_path, property_text, indent)
                yaml_parse_stack_pending_value_path[yaml_parse_depth] = ""
                yaml_parse_stack_pending_container_value[yaml_parse_depth] = 0
            } else if (yaml_parse_flow_collection_start(property_text)) {
                yaml_parse_emit_or_start_flow(child_path, property_text)
                yaml_parse_stack_pending_value_path[yaml_parse_depth] = ""
                yaml_parse_stack_pending_container_value[yaml_parse_depth] = 0
            } else if (yaml_parse_mapping_colon(property_text)) {
                yaml_parse_error()
            } else if (yaml_parse_plain_scalar_candidate(property_text)) {
                yaml_parse_start_plain_scalar(child_path, property_text, indent, 0)
                yaml_parse_stack_pending_value_path[yaml_parse_depth] = ""
                yaml_parse_stack_pending_container_value[yaml_parse_depth] = 0
            } else {
                yaml_parse_emit_value(child_path, property_text)
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
    if (yaml_parse_pending_flow && yaml_parse_partial_incomplete_outer_sequence(yaml_parse_flow_buffer, yaml_parse_pending_flow_path)) {
        yaml_parse_error()
    }
    yaml_parse_start_deferred_document()
    yaml_parse_finish_block_scalar()
    yaml_parse_finish()
}
