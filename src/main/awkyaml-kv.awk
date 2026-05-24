{
    yaml_event_read($0, yaml_kv_fields)
    yaml_kv_event = yaml_kv_fields[1]
    yaml_kv_doc_id = yaml_kv_fields[2] + 0
    if (yaml_kv_done || yaml_kv_doc_id != 0) {
        next
    }
    if (yaml_kv_event == "DOC_END") {
        yaml_kv_done = 1
    } else if (yaml_kv_event == "MAP_START") {
        yaml_kv_push("map", yaml_kv_fields[3], yaml_kv_fields[5])
    } else if (yaml_kv_event == "MAP_END") {
        yaml_kv_pop()
    } else if (yaml_kv_event == "SEQ_START") {
        yaml_kv_push("seq", yaml_kv_fields[3], yaml_kv_fields[5])
    } else if (yaml_kv_event == "SEQ_END") {
        yaml_kv_pop()
    } else if (yaml_kv_event == "SCALAR") {
        yaml_kv_emit_scalar(yaml_kv_fields[3], yaml_kv_fields[7], yaml_kv_fields[5])
    } else if (yaml_kv_event == "ALIAS") {
        yaml_kv_emit_alias(yaml_kv_fields[3], yaml_kv_fields[4])
    } else if (yaml_kv_event == "KEY_ANCHOR") {
        yaml_kv_anchor_kind[yaml_kv_fields[3]] = "scalar"
        yaml_kv_anchor_value[yaml_kv_fields[3]] = yaml_kv_fields[4]
    }
}
