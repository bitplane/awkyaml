BEGIN {
    ok = 1
}

{
    count = yaml_event_read($0, fields)
    event = fields[1]

    if (event == "DOC_START") {
        yaml_event_emit_doc_start(fields[2])
    } else if (event == "DOC_END") {
        yaml_event_emit_doc_end(fields[2])
    } else if (event == "MAP_START") {
        yaml_event_emit_map_start(fields[2], fields[3], fields[4], fields[5])
    } else if (event == "MAP_END") {
        yaml_event_emit_map_end(fields[2], fields[3])
    } else if (event == "SEQ_START") {
        yaml_event_emit_seq_start(fields[2], fields[3], fields[4], fields[5])
    } else if (event == "SEQ_END") {
        yaml_event_emit_seq_end(fields[2], fields[3])
    } else if (event == "SCALAR") {
        yaml_event_emit_scalar(fields[2], fields[3], fields[4], fields[5], fields[6], fields[7])
    } else if (event == "ALIAS") {
        yaml_event_emit_alias(fields[2], fields[3], fields[4])
    } else {
        print "unknown event: " event > "/dev/stderr"
        ok = 0
    }
}

END {
    exit ok ? 0 : 1
}
