function yaml_parse_reset_tag_handles(    handle) {
    for (handle in yaml_parse_tag_handle) {
        if (handle != "!!") {
            delete yaml_parse_tag_handle[handle]
        }
    }
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
function yaml_parse_read_tag_directive(line,    parts) {
    split(line, parts, /[ \t]+/)
    if (parts[2] != "" && parts[3] != "") {
        yaml_parse_tag_handle[parts[2]] = parts[3]
    }
}
