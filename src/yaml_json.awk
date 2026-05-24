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

function yaml_json_path_key(path,    parts, count) {
    if (path == "") {
        return ""
    }
    count = split(path, parts, "/")
    return parts[count]
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
    if (tag == "tag:yaml.org,2002:null" || value == "" || value == "~" || value == "null" || value == "Null" || value == "NULL") {
        return "null"
    }
    if (tag == "tag:yaml.org,2002:bool" || value == "true" || value == "True" || value == "TRUE") {
        return "true"
    }
    if (tag == "tag:yaml.org,2002:bool" || value == "false" || value == "False" || value == "FALSE") {
        return "false"
    }
    if (value ~ /^[-+]?(0|[1-9][0-9]*)$/ || value ~ /^[-+]?(0|[1-9][0-9]*)[.][0-9]+([eE][-+]?[0-9]+)?$/ || value ~ /^[-+]?[0-9]+[eE][-+]?[0-9]+$/) {
        sub(/^\+/, "", value)
        return value
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

{
    yaml_event_read($0, yaml_json_fields)
    yaml_json_event = yaml_json_fields[1]
    if (yaml_json_event == "DOC_START") {
        yaml_json_out = ""
        yaml_json_depth = 0
        yaml_json_doc_started = 1
        yaml_json_doc_emitted = 0
    } else if (yaml_json_event == "DOC_END") {
        yaml_json_emit_document()
    } else if (yaml_json_event == "MAP_START") {
        yaml_json_prefix(yaml_json_fields[3])
        yaml_json_value_start = length(yaml_json_out) + 1
        yaml_json_out = yaml_json_out "{"
        yaml_json_push("map")
        yaml_json_anchor[yaml_json_depth] = yaml_json_fields[5]
        yaml_json_start[yaml_json_depth] = yaml_json_value_start
    } else if (yaml_json_event == "MAP_END") {
        yaml_json_out = yaml_json_out "}"
        yaml_json_pop()
    } else if (yaml_json_event == "SEQ_START") {
        yaml_json_prefix(yaml_json_fields[3])
        yaml_json_value_start = length(yaml_json_out) + 1
        yaml_json_out = yaml_json_out "["
        yaml_json_push("seq")
        yaml_json_anchor[yaml_json_depth] = yaml_json_fields[5]
        yaml_json_start[yaml_json_depth] = yaml_json_value_start
    } else if (yaml_json_event == "SEQ_END") {
        yaml_json_out = yaml_json_out "]"
        yaml_json_pop()
    } else if (yaml_json_event == "SCALAR") {
        yaml_json_value = yaml_json_scalar(yaml_json_fields[4], yaml_json_fields[6], yaml_json_fields[7])
        yaml_json_prefix(yaml_json_fields[3])
        yaml_json_out = yaml_json_out yaml_json_value
        if (yaml_json_fields[5] != "") {
            yaml_json_anchor_value[yaml_json_fields[5]] = yaml_json_value
        }
    } else if (yaml_json_event == "ALIAS") {
        yaml_json_prefix(yaml_json_fields[3])
        if (yaml_json_fields[4] in yaml_json_anchor_value) {
            yaml_json_out = yaml_json_out yaml_json_anchor_value[yaml_json_fields[4]]
        } else {
            yaml_json_out = yaml_json_out "null"
        }
    }
}

END {
    yaml_json_emit_document()
}
