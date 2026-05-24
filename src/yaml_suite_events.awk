BEGIN {
    suite_doc_id = -1
}

function suite_event_error(message) {
    print FILENAME ":" FNR ": " message > "/dev/stderr"
    suite_failed = 1
}

function suite_event_parse_attrs(rest,    token) {
    suite_anchor = ""
    suite_tag = ""
    suite_style = ""
    suite_value = ""

    rest = suite_ltrim(rest)
    while (rest != "") {
        if (substr(rest, 1, 2) == "[]" || substr(rest, 1, 2) == "{}") {
            rest = suite_ltrim(substr(rest, 3))
        } else if (substr(rest, 1, 1) == "&") {
            token = rest
            sub(/[ \t].*$/, "", token)
            suite_anchor = substr(token, 2)
            rest = suite_ltrim(substr(rest, length(token) + 1))
        } else if (substr(rest, 1, 1) == "<") {
            token = rest
            sub(/^<[^>]*>.*/, "&", token)
            token = substr(rest, 1, index(rest, ">"))
            suite_tag = substr(token, 2, length(token) - 2)
            rest = suite_ltrim(substr(rest, length(token) + 1))
        } else {
            suite_style = substr(rest, 1, 1)
            suite_value = substr(rest, 2)
            return
        }
    }
}

function suite_event_container_attrs(rest) {
    suite_event_parse_attrs(rest)
}

function suite_event_path_for_value(key,    parent_type, parent_path, path) {
    if (suite_depth == 0) {
        return ""
    }

    parent_type = suite_stack_type[suite_depth]
    parent_path = suite_stack_path[suite_depth]
    if (parent_type == "seq") {
        path = yaml_event_path_join(parent_path, suite_stack_next[suite_depth])
        suite_stack_next[suite_depth]++
        return path
    }

    if (parent_type == "map") {
        if (suite_stack_expect_key[suite_depth]) {
            suite_stack_pending_key[suite_depth] = key
            suite_stack_expect_key[suite_depth] = 0
            return "\034KEY\034"
        }
        path = yaml_event_path_join(parent_path, suite_stack_pending_key[suite_depth])
        suite_stack_pending_key[suite_depth] = ""
        suite_stack_expect_key[suite_depth] = 1
        return path
    }

    suite_event_error("unknown parent container: " parent_type)
    return ""
}

function suite_event_start_container(kind, rest,    path, tag) {
    suite_event_container_attrs(rest)
    path = suite_event_path_for_value("")
    if (path == "\034KEY\034") {
        suite_event_error("complex mapping keys are not supported by the path event normalizer yet")
        return
    }

    tag = suite_tag
    if (tag == "") {
        tag = (kind == "map" ? "tag:yaml.org,2002:map" : "tag:yaml.org,2002:seq")
    }

    if (kind == "map") {
        yaml_event_emit_map_start(suite_doc_id, path, tag, suite_anchor)
    } else {
        yaml_event_emit_seq_start(suite_doc_id, path, tag, suite_anchor)
    }

    suite_depth++
    suite_stack_type[suite_depth] = kind
    suite_stack_path[suite_depth] = path
    suite_stack_next[suite_depth] = 0
    suite_stack_expect_key[suite_depth] = (kind == "map")
    suite_stack_pending_key[suite_depth] = ""
}

function suite_event_end_container(kind,    path) {
    if (suite_depth < 1 || suite_stack_type[suite_depth] != kind) {
        suite_event_error("mismatched container end: " kind)
        return
    }

    path = suite_stack_path[suite_depth]
    if (kind == "map") {
        yaml_event_emit_map_end(suite_doc_id, path)
    } else {
        yaml_event_emit_seq_end(suite_doc_id, path)
    }
    suite_depth--
}

function suite_event_scalar(rest,    path, tag, style, value) {
    suite_event_parse_attrs(rest)
    value = suite_event_unescape_value(suite_value)
    if (suite_anchor != "") {
        suite_anchor_scalar_value[suite_anchor] = value
    }

    path = suite_event_path_for_value(value)
    if (path == "\034KEY\034") {
        if (suite_anchor != "") {
            yaml_event_emit_key_anchor(suite_doc_id, suite_anchor, value)
        }
        return
    }

    tag = suite_tag
    if (tag == "") {
        tag = "tag:yaml.org,2002:str"
    }
    style = suite_style
    if (style == ":") {
        style = "plain"
    } else if (style == "\"") {
        style = "double"
    } else if (style == "'") {
        style = "single"
    } else if (style == "|") {
        style = "literal"
    } else if (style == ">") {
        style = "folded"
    }

    yaml_event_emit_scalar(suite_doc_id, path, tag, suite_anchor, style, value, (suite_tag != "" ? "explicit-tag" : ""))
}

function suite_event_alias(rest,    path, name) {
    rest = suite_ltrim(rest)
    if (substr(rest, 1, 1) != "*") {
        suite_event_error("invalid alias event: " rest)
        return
    }
    name = substr(rest, 2)
    if (suite_depth && suite_stack_type[suite_depth] == "map" && suite_stack_expect_key[suite_depth]) {
        if (!(name in suite_anchor_scalar_value)) {
            suite_event_error("alias mapping key does not point to a known scalar anchor: " name)
            return
        }
        suite_stack_pending_key[suite_depth] = suite_anchor_scalar_value[name]
        suite_stack_expect_key[suite_depth] = 0
        return
    }

    path = suite_event_path_for_value("")
    if (path == "\034KEY\034") {
        suite_event_error("alias mapping keys are not supported by the path event normalizer yet")
        return
    }
    yaml_event_emit_alias(suite_doc_id, path, name)
}

function suite_event_unescape_value(text,    out, i, ch, next_ch) {
    out = ""
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        next_ch = substr(text, i + 1, 1)
        if (ch == "\\" && next_ch != "") {
            if (next_ch == "n") {
                out = out "\n"
            } else if (next_ch == "t") {
                out = out "\t"
            } else if (next_ch == "r") {
                out = out "\r"
            } else if (next_ch == "b") {
                out = out "\b"
            } else {
                out = out next_ch
            }
            i++
        } else {
            out = out ch
        }
    }
    return out
}

function suite_ltrim(text) {
    sub(/^[ \t]+/, "", text)
    return text
}

/^\+STR/ {
    next
}

/^-STR/ {
    next
}

/^\+DOC/ {
    suite_doc_id++
    suite_depth = 0
    yaml_event_emit_doc_start(suite_doc_id)
    next
}

/^-DOC/ {
    if (suite_depth != 0) {
        suite_event_error("document ended with open containers")
    }
    yaml_event_emit_doc_end(suite_doc_id)
    next
}

/^\+MAP/ {
    suite_event_start_container("map", substr($0, 5))
    next
}

/^-MAP/ {
    suite_event_end_container("map")
    next
}

/^\+SEQ/ {
    suite_event_start_container("seq", substr($0, 5))
    next
}

/^-SEQ/ {
    suite_event_end_container("seq")
    next
}

/^=VAL/ {
    suite_event_scalar(substr($0, 5))
    next
}

/^=ALI/ {
    suite_event_alias(substr($0, 5))
    next
}

{
    suite_event_error("unknown event line: " $0)
}

END {
    exit suite_failed ? 1 : 0
}
