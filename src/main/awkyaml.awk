BEGIN {
    yaml_parse_init()
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
