{
    split($0, yaml_json_raw_fields, "\t")
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
        yaml_json_prefix(yaml_json_raw_fields[3])
        yaml_json_value_start = length(yaml_json_out) + 1
        yaml_json_out = yaml_json_out "{"
        yaml_json_push("map")
        yaml_json_anchor[yaml_json_depth] = yaml_json_fields[5]
        yaml_json_start[yaml_json_depth] = yaml_json_value_start
    } else if (yaml_json_event == "MAP_END") {
        yaml_json_out = yaml_json_out "}"
        yaml_json_pop()
    } else if (yaml_json_event == "SEQ_START") {
        yaml_json_prefix(yaml_json_raw_fields[3])
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
        yaml_json_prefix(yaml_json_raw_fields[3])
        yaml_json_out = yaml_json_out yaml_json_value
        if (yaml_json_fields[5] != "") {
            yaml_json_anchor_value[yaml_json_fields[5]] = yaml_json_value
        }
    } else if (yaml_json_event == "ALIAS") {
        yaml_json_prefix(yaml_json_raw_fields[3])
        if (yaml_json_fields[4] in yaml_json_anchor_value) {
            yaml_json_out = yaml_json_out yaml_json_anchor_value[yaml_json_fields[4]]
        } else {
            yaml_json_out = yaml_json_out "null"
        }
    } else if (yaml_json_event == "KEY_ANCHOR") {
        yaml_json_anchor_value[yaml_json_fields[3]] = yaml_json_escape(yaml_json_fields[4])
    }
}

END {
    yaml_json_emit_document()
}
