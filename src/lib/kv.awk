function yaml_kv_shell_quote(value,    out, i, ch) {
    out = "'"
    for (i = 1; i <= length(value); i++) {
        ch = substr(value, i, 1)
        if (ch == "'") {
            out = out "'\\''"
        } else {
            out = out ch
        }
    }
    return out "'"
}

function yaml_kv_path_parent(path,    i, ch, slash, backslashes, j) {
    slash = 0
    for (i = 1; i <= length(path); i++) {
        ch = substr(path, i, 1)
        if (ch == "/") {
            backslashes = 0
            for (j = i - 1; j >= 1 && substr(path, j, 1) == "\\"; j--) {
                backslashes++
            }
            if (backslashes % 2 == 0) {
                slash = i
            }
        }
    }
    if (!slash) {
        return ""
    }
    return substr(path, 1, slash - 1)
}

function yaml_kv_path_split(path, parts,    i, ch, token, count, backslashes, j) {
    delete parts
    count = 0
    token = ""
    for (i = 1; i <= length(path); i++) {
        ch = substr(path, i, 1)
        if (ch == "/") {
            backslashes = 0
            for (j = i - 1; j >= 1 && substr(path, j, 1) == "\\"; j--) {
                backslashes++
            }
            if (backslashes % 2 == 0) {
                count++
                parts[count] = yaml_event_unescape(token)
                token = ""
                continue
            }
        }
        token = token ch
    }
    if (path != "" || token != "") {
        count++
        parts[count] = yaml_event_unescape(token)
    }
    return count
}

function yaml_kv_name(path,    parts, count, i, part, name) {
    name = ""
    count = yaml_kv_path_split(path, parts)
    for (i = 1; i <= count; i++) {
        part = parts[i]
        gsub(/[^A-Za-z0-9_]/, "_", part)
        name = name (name == "" ? "" : "_") part
    }
    if (prefix != "") {
        name = prefix (name == "" ? "" : "_" name)
    }
    if (name == "") {
        name = "_"
    }
    if (name !~ /^[A-Za-z_]/) {
        name = "_" name
    }
    return name
}

function yaml_kv_len_name(path,    name) {
    if (path == "" && prefix == "") {
        return "_len"
    }
    name = yaml_kv_name(path)
    return name "__len"
}

function yaml_kv_under_path(path, root) {
    return path == root || (root != "" && substr(path, 1, length(root) + 1) == root "/") || (root == "" && path != "")
}

function yaml_kv_repath(path, root, target,    suffix) {
    if (path == root) {
        return target
    }
    suffix = (root == "" ? path : substr(path, length(root) + 2))
    if (target == "") {
        return suffix
    }
    return target "/" suffix
}

function yaml_kv_note_parent_seq_child(path,    parent) {
    if (yaml_kv_depth <= 0 || yaml_kv_type[yaml_kv_depth] != "seq") {
        return
    }
    parent = yaml_kv_path_parent(path)
    if (parent == yaml_kv_path[yaml_kv_depth]) {
        yaml_kv_count[yaml_kv_depth]++
    }
}

function yaml_kv_emit_assignment(path, value,    line) {
    line = yaml_kv_name(path) "=" yaml_kv_shell_quote(value)
    print line
    yaml_kv_leaf_count++
    yaml_kv_leaf_path[yaml_kv_leaf_count] = path
    yaml_kv_leaf_value[yaml_kv_leaf_count] = value
}

function yaml_kv_emit_len(path, count,    line) {
    line = yaml_kv_len_name(path) "=" yaml_kv_shell_quote(count)
    print line
    yaml_kv_len_count++
    yaml_kv_len_path[yaml_kv_len_count] = path
    yaml_kv_len_value[yaml_kv_len_count] = count
}

function yaml_kv_push(type, path, anchor) {
    yaml_kv_note_parent_seq_child(path)
    yaml_kv_depth++
    yaml_kv_type[yaml_kv_depth] = type
    yaml_kv_path[yaml_kv_depth] = path
    yaml_kv_count[yaml_kv_depth] = 0
    if (anchor != "") {
        yaml_kv_anchor_kind[anchor] = "container"
        yaml_kv_anchor_path[anchor] = path
    }
}

function yaml_kv_pop_seq(path,    count) {
    count = yaml_kv_count[yaml_kv_depth]
    yaml_kv_emit_len(path, count)
}

function yaml_kv_pop() {
    if (yaml_kv_type[yaml_kv_depth] == "seq") {
        yaml_kv_pop_seq(yaml_kv_path[yaml_kv_depth])
    }
    delete yaml_kv_type[yaml_kv_depth]
    delete yaml_kv_path[yaml_kv_depth]
    delete yaml_kv_count[yaml_kv_depth]
    yaml_kv_depth--
}

function yaml_kv_emit_scalar(path, value, anchor) {
    yaml_kv_note_parent_seq_child(path)
    yaml_kv_emit_assignment(path, value)
    if (anchor != "") {
        yaml_kv_anchor_kind[anchor] = "scalar"
        yaml_kv_anchor_value[anchor] = value
    }
}

function yaml_kv_emit_alias(path, anchor,    i, root, target_path) {
    yaml_kv_note_parent_seq_child(path)
    if (yaml_kv_anchor_kind[anchor] == "scalar") {
        yaml_kv_emit_assignment(path, yaml_kv_anchor_value[anchor])
    } else if (yaml_kv_anchor_kind[anchor] == "container") {
        root = yaml_kv_anchor_path[anchor]
        for (i = 1; i <= yaml_kv_leaf_count; i++) {
            if (yaml_kv_under_path(yaml_kv_leaf_path[i], root)) {
                target_path = yaml_kv_repath(yaml_kv_leaf_path[i], root, path)
                yaml_kv_emit_assignment(target_path, yaml_kv_leaf_value[i])
            }
        }
        for (i = 1; i <= yaml_kv_len_count; i++) {
            if (yaml_kv_under_path(yaml_kv_len_path[i], root)) {
                target_path = yaml_kv_repath(yaml_kv_len_path[i], root, path)
                yaml_kv_emit_len(target_path, yaml_kv_len_value[i])
            }
        }
    } else {
        yaml_kv_emit_assignment(path, "")
    }
}
