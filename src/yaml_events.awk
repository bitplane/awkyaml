function yaml_event_escape(text,    out, i, ch) {
    out = ""
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        if (ch == "\\") {
            out = out "\\\\"
        } else if (ch == "\t") {
            out = out "\\t"
        } else if (ch == "\n") {
            out = out "\\n"
        } else if (ch == "\r") {
            out = out "\\r"
        } else if (ch == "/") {
            out = out "\\/"
        } else {
            out = out ch
        }
    }
    return out
}

function yaml_event_unescape(text,    out, i, ch, next_ch) {
    out = ""
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        next_ch = substr(text, i + 1, 1)
        if (ch == "\\" && next_ch != "") {
            if (next_ch == "t") {
                out = out "\t"
            } else if (next_ch == "n") {
                out = out "\n"
            } else if (next_ch == "r") {
                out = out "\r"
            } else if (next_ch == "\\" || next_ch == "/") {
                out = out next_ch
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

function yaml_event_path_join(parent, key) {
    key = yaml_event_escape(key)
    if (parent == "") {
        return key
    }
    return parent "/" key
}

function yaml_event_emit_doc_start(doc_id) {
    print "DOC_START" "\t" doc_id
}

function yaml_event_emit_doc_end(doc_id) {
    print "DOC_END" "\t" doc_id
}

function yaml_event_emit_map_start(doc_id, path, tag, anchor) {
    print "MAP_START" "\t" doc_id "\t" yaml_event_escape(path) "\t" yaml_event_escape(tag) "\t" yaml_event_escape(anchor)
}

function yaml_event_emit_map_end(doc_id, path) {
    print "MAP_END" "\t" doc_id "\t" yaml_event_escape(path)
}

function yaml_event_emit_seq_start(doc_id, path, tag, anchor) {
    print "SEQ_START" "\t" doc_id "\t" yaml_event_escape(path) "\t" yaml_event_escape(tag) "\t" yaml_event_escape(anchor)
}

function yaml_event_emit_seq_end(doc_id, path) {
    print "SEQ_END" "\t" doc_id "\t" yaml_event_escape(path)
}

function yaml_event_emit_scalar(doc_id, path, tag, anchor, style, value) {
    print "SCALAR" "\t" doc_id "\t" yaml_event_escape(path) "\t" yaml_event_escape(tag) "\t" yaml_event_escape(anchor) "\t" yaml_event_escape(style) "\t" yaml_event_escape(value)
}

function yaml_event_emit_alias(doc_id, path, anchor_name) {
    print "ALIAS" "\t" doc_id "\t" yaml_event_escape(path) "\t" yaml_event_escape(anchor_name)
}

function yaml_event_read(line, fields,    i, count) {
    count = split(line, fields, "\t")
    for (i = 3; i <= count; i++) {
        fields[i] = yaml_event_unescape(fields[i])
    }
    return count
}
