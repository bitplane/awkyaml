function yaml_json_escape(text,    out, i, ch) {
    out = ""
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        if (ch == "\\") {
            out = out "\\\\"
        } else if (ch == "\"") {
            out = out "\\\""
        } else if (ch == "\t") {
            out = out "\\t"
        } else if (ch == "\n") {
            out = out "\\n"
        } else if (ch == "\r") {
            out = out "\\r"
        } else if (ch == "\b") {
            out = out "\\b"
        } else if (ch == "\f") {
            out = out "\\f"
        } else {
            out = out ch
        }
    }
    return "\"" out "\""
}

function yaml_json_hex_digit(ch) {
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

function yaml_json_hex_value(hex,    i, n) {
    n = 0
    for (i = 1; i <= length(hex); i++) {
        n = n * 16 + yaml_json_hex_digit(substr(hex, i, 1))
    }
    return n
}

function yaml_json_number(value) {
    sub(/^\+/, "", value)
    if (value ~ /^[+-]?[0-9]+[.][0-9]+$/) {
        sub(/0+$/, "", value)
        sub(/[.]$/, "", value)
    }
    return value
}

function yaml_json_path_key(path,    i, ch, prev, key) {
    if (path == "") {
        return ""
    }
    key = ""
    for (i = 1; i <= length(path); i++) {
        ch = substr(path, i, 1)
        prev = substr(path, i - 1, 1)
        if (ch == "/" && prev != "\\") {
            key = ""
        } else {
            key = key ch
        }
    }
    return yaml_event_unescape(yaml_event_unescape(key))
}

function yaml_json_prefix(path,    key) {
    if (yaml_json_depth == 0) {
        return
    }
    if (yaml_json_count[yaml_json_depth] > 0) {
        yaml_json_out = yaml_json_out ","
    }
    if (yaml_json_type[yaml_json_depth] == "map") {
        key = yaml_json_path_key(path)
        yaml_json_out = yaml_json_out yaml_json_escape(key) ":"
    }
    yaml_json_count[yaml_json_depth]++
}

function yaml_json_push(type) {
    yaml_json_depth++
    yaml_json_type[yaml_json_depth] = type
    yaml_json_count[yaml_json_depth] = 0
}

function yaml_json_pop(    anchor, start) {
    anchor = yaml_json_anchor[yaml_json_depth]
    start = yaml_json_start[yaml_json_depth]
    if (anchor != "" && start > 0) {
        yaml_json_anchor_value[anchor] = substr(yaml_json_out, start)
    }
    delete yaml_json_type[yaml_json_depth]
    delete yaml_json_count[yaml_json_depth]
    delete yaml_json_anchor[yaml_json_depth]
    delete yaml_json_start[yaml_json_depth]
    yaml_json_depth--
}

function yaml_json_scalar(tag, style, value) {
    if (style != "plain" && style != "") {
        return yaml_json_escape(value)
    }
    if (tag == "!") {
        return yaml_json_escape(value)
    }
    if (yaml_json_fields[8] == "explicit-tag" && tag == "tag:yaml.org,2002:str") {
        return yaml_json_escape(value)
    }
    if (tag == "tag:yaml.org,2002:null" || value == "" || value == "~" || value == "null" || value == "Null" || value == "NULL") {
        return "null"
    }
    if (tag == "tag:yaml.org,2002:bool") {
        return (value == "false" || value == "False" || value == "FALSE") ? "false" : "true"
    }
    if (value == "true" || value == "True" || value == "TRUE") {
        return "true"
    }
    if (value == "false" || value == "False" || value == "FALSE") {
        return "false"
    }
    if (value ~ /^[-+]?0x[0-9A-Fa-f]+$/) {
        sub(/^\+/, "", value)
        return (substr(value, 1, 1) == "-" ? "-" yaml_json_hex_value(substr(value, 4)) : yaml_json_hex_value(substr(value, 3)))
    }
    if (value ~ /^[-+]?(0|[1-9][0-9]*)$/ || value ~ /^[-+]?(0|[1-9][0-9]*)[.][0-9]+([eE][-+]?[0-9]+)?$/ || value ~ /^[-+]?[0-9]+[eE][-+]?[0-9]+$/) {
        return yaml_json_number(value)
    }
    return yaml_json_escape(value)
}

function yaml_json_emit_document() {
    if (!yaml_json_doc_started || yaml_json_doc_emitted) {
        return
    }
    print yaml_json_out
    yaml_json_doc_emitted = 1
}
