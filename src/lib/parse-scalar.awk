function yaml_parse_quoted_scalar_start(value) {
    value = yaml_parse_trim(value)
    return yaml_parse_quote_start_char(substr(value, 1, 1))
}

function yaml_parse_quoted_scalar_end(value,    quote, i, ch) {
    value = yaml_parse_trim(value)
    quote = substr(value, 1, 1)
    if (!yaml_parse_quote_start_char(quote)) {
        return 0
    }
    for (i = 2; i <= length(value); i++) {
        ch = substr(value, i, 1)
        if (yaml_parse_quote_escape_char(quote, ch)) {
            i++
        } else if (quote == "'" && ch == "'" && substr(value, i + 1, 1) == "'") {
            i++
        } else if (ch == quote) {
            return i
        }
    }
    return 0
}

function yaml_parse_quoted_scalar_complete(value,    end) {
    value = yaml_parse_trim(value)
    end = yaml_parse_quoted_scalar_end(value)
    return end && yaml_parse_trim(substr(value, end + 1)) == ""
}

function yaml_parse_quoted_scalar_closed_prefix(value) {
    return yaml_parse_quoted_scalar_end(value)
}

function yaml_parse_quoted_scalar_has_invalid_trailing(value,    trimmed, prefix, trailing) {
    trimmed = yaml_parse_trim(value)
    prefix = yaml_parse_quoted_scalar_closed_prefix(trimmed)
    if (!prefix) {
        return 0
    }
    trailing = substr(trimmed, prefix + 1)
    if (substr(trailing, 1, 1) == "#") {
        return 1
    }
    return yaml_parse_trim(yaml_parse_strip_inline_comment(trailing)) != ""
}

function yaml_parse_start_quoted_scalar(path, value, indent) {
    yaml_parse_pending_quote = 1
    yaml_parse_quote_path = path
    yaml_parse_quote_indent = indent
    yaml_parse_quote_text = value
    yaml_parse_quote_tag = yaml_parse_take_pending_tag()
    yaml_parse_quote_tag_explicit = yaml_parse_take_pending_tag_explicit()
    if (yaml_parse_quote_tag == "") {
        yaml_parse_quote_tag = "tag:yaml.org,2002:str"
    }
    yaml_parse_quote_anchor = yaml_parse_take_pending_anchor()
}

function yaml_parse_append_quoted_scalar(line) {
    yaml_parse_quote_text = yaml_parse_quote_text "\n" line
    if (yaml_parse_quoted_scalar_complete(yaml_parse_quote_text)) {
        yaml_parse_finish_quoted_scalar()
    }
}

function yaml_parse_reset_quoted_scalar() {
    yaml_parse_pending_quote = 0
    yaml_parse_quote_path = ""
    yaml_parse_quote_text = ""
    yaml_parse_quote_tag = ""
    yaml_parse_quote_tag_explicit = 0
    yaml_parse_quote_anchor = ""
}

function yaml_parse_finish_quoted_scalar(    value, quote, style) {
    if (!yaml_parse_pending_quote) {
        return
    }
    if (!yaml_parse_quoted_scalar_complete(yaml_parse_quote_text)) {
        yaml_parse_error()
        return
    }
    value = yaml_parse_multiline_quoted_value(yaml_parse_quote_text)
    quote = substr(yaml_parse_trim(yaml_parse_quote_text), 1, 1)
    style = (quote == "\"" ? "double" : "single")
    yaml_event_emit_scalar(yaml_parse_doc_id, yaml_parse_quote_path, yaml_parse_quote_tag, yaml_parse_quote_anchor, style, value, (yaml_parse_quote_tag_explicit ? "explicit-tag" : ""))
    yaml_parse_reset_quoted_scalar()
}

function yaml_parse_multiline_quoted_value(text,    quote, content, i, ch, lines, count, out, line, raw_line, blank, first_nonempty, j) {
    text = yaml_parse_trim(text)
    quote = substr(text, 1, 1)
    content = substr(text, 2, length(text) - 2)
    if (quote == "\"") {
        gsub(/\\\t[ \t]*\n */, "\t ", content)
        gsub(/\\ *\n */, "", content)
    }
    count = split(content, lines, "\n")
    out = ""
    blank = 0
    first_nonempty = 1
    for (i = 1; i <= count; i++) {
        raw_line = lines[i]
        line = raw_line
        sub(/^[ \t]+/, "", line)
        if (i < count) {
            sub(/[ \t]+$/, "", line)
        }
        if (line == "" && raw_line ~ /^[ \t]+$/ && i == count) {
            line = " "
        }
        if (line == "") {
            blank++
            continue
        }
        if (line == " " && blank && out == "") {
            if (blank == 1) {
                out = " "
            } else {
                for (j = 1; j < blank; j++) {
                    out = out "\n"
                }
            }
            first_nonempty = 0
            blank = 0
            continue
        }
        if (out != "") {
            out = out (blank ? "\n" : " ")
        }
        if (first_nonempty && raw_line ~ /^[ \t]/ && line != " ") {
            line = " " line
        }
        out = out line
        first_nonempty = 0
        blank = 0
    }
    if (blank && out != "") {
        out = out " "
    }
    if (quote == "\"") {
        out = yaml_parse_unescape_double_quoted(out)
    } else {
        gsub(/''/, "'", out)
    }
    return out
}

function yaml_parse_plain_scalar_candidate(value,    parsed) {
    parsed = yaml_parse_scalar(value)
    return parsed == "scalar" && yaml_parse_scalar_style == "plain"
}

function yaml_parse_start_plain_scalar(path, value, indent, root_continues,    tag, anchor) {
    yaml_parse_scalar(value)
    tag = yaml_parse_take_pending_tag()
    yaml_parse_plain_tag_explicit = yaml_parse_take_pending_tag_explicit()
    if (tag == "") {
        tag = yaml_parse_scalar_tag
        yaml_parse_plain_tag_explicit = yaml_parse_scalar_tag_explicit
    }
    anchor = yaml_parse_take_pending_anchor()
    if (anchor == "") {
        anchor = yaml_parse_scalar_anchor
    }
    yaml_parse_pending_plain = 1
    yaml_parse_plain_path = path
    yaml_parse_plain_tag = tag
    yaml_parse_plain_anchor = anchor
    yaml_parse_plain_indent = indent
    yaml_parse_plain_root_continues = root_continues
    yaml_parse_plain_text = yaml_parse_scalar_value_text
    yaml_parse_plain_blank = 0
    yaml_parse_plain_comment_break = (yaml_parse_strip_inline_comment(value) != value)
}

function yaml_parse_append_plain_scalar(line,    text, stripped, had_comment) {
    if (line ~ /^[ \t]*#/) {
        yaml_parse_plain_comment_break = 1
        yaml_parse_plain_blank++
        return
    }
    if (line ~ /^[ \t]*$/) {
        yaml_parse_plain_blank++
        return
    }
    stripped = yaml_parse_strip_inline_comment(line)
    had_comment = (stripped != line)
    text = yaml_parse_trim(stripped)
    if (text == "") {
        return
    }
    if (yaml_parse_plain_blank) {
        yaml_parse_plain_text = yaml_parse_plain_text "\n" text
        yaml_parse_plain_blank = 0
    } else if (yaml_parse_plain_text != "") {
        yaml_parse_plain_text = yaml_parse_plain_text " " text
    } else {
        yaml_parse_plain_text = text
    }
    yaml_parse_plain_comment_break = had_comment
}

function yaml_parse_reset_plain_scalar() {
    yaml_parse_pending_plain = 0
    yaml_parse_plain_path = ""
    yaml_parse_plain_text = ""
    yaml_parse_plain_blank = 0
    yaml_parse_plain_comment_break = 0
    yaml_parse_plain_tag_explicit = 0
}

function yaml_parse_finish_plain_scalar() {
    if (!yaml_parse_pending_plain) {
        return
    }
    yaml_event_emit_scalar(yaml_parse_doc_id, yaml_parse_plain_path, yaml_parse_plain_tag, yaml_parse_plain_anchor, "plain", yaml_parse_plain_text, (yaml_parse_plain_tag_explicit ? "explicit-tag" : ""))
    if (yaml_parse_plain_anchor != "") {
        yaml_parse_anchor_scalar_value[yaml_parse_plain_anchor] = yaml_parse_plain_text
    }
    yaml_parse_reset_plain_scalar()
}

function yaml_parse_line_continues_plain(line, indent) {
    if (!yaml_parse_pending_plain) {
        return 0
    }
    if (line ~ /^(---|\.\.\.)([ \t]|$)/) {
        return 0
    }
    if (yaml_parse_plain_root_continues) {
        return 1
    }
    if (indent == yaml_parse_plain_indent && (substr(yaml_parse_trim(line), 1, 1) == "?" || substr(yaml_parse_trim(line), 1, 1) == ":")) {
        return 0
    }
    if (indent == yaml_parse_plain_indent && yaml_parse_mapping_pair(substr(line, indent + 1))) {
        return 0
    }
    return line ~ /^[ \t]*($|#)/ || indent > yaml_parse_plain_indent || (indent == yaml_parse_plain_indent && yaml_parse_depth > 0 && yaml_parse_plain_indent > yaml_parse_stack_indent[yaml_parse_depth])
}

function yaml_parse_scalar_value(value) {
    value = yaml_parse_trim(value)
    if (substr(value, 1, 1) == "\"" && substr(value, length(value), 1) == "\"") {
        value = substr(value, 2, length(value) - 2)
        value = yaml_parse_unescape_double_quoted(value)
    } else if (substr(value, 1, 1) == "'" && substr(value, length(value), 1) == "'") {
        value = substr(value, 2, length(value) - 2)
        gsub(/''/, "'", value)
    }
    return value
}

function yaml_parse_unescape_double_quoted(value,    out, i, ch, next_ch, hex) {
    out = ""
    for (i = 1; i <= length(value); i++) {
        ch = substr(value, i, 1)
        if (ch == "\\" && i < length(value)) {
            i++
            next_ch = substr(value, i, 1)
            if (next_ch == "n") {
                out = out "\n"
            } else if (next_ch == "t") {
                out = out "\t"
            } else if (next_ch == "r") {
                out = out "\r"
            } else if (next_ch == "b") {
                out = out "\b"
            } else if (next_ch == "f") {
                out = out "\f"
            } else if (next_ch == "\t") {
                out = out "\t"
            } else if (next_ch == "x" && i + 2 <= length(value)) {
                hex = substr(value, i + 1, 2)
                if (hex ~ /^[0-9A-Fa-f][0-9A-Fa-f]$/) {
                    out = out sprintf("%c", yaml_parse_hex_value(hex))
                    i += 2
                } else {
                    out = out next_ch
                }
            } else if (next_ch == "u" && i + 4 <= length(value)) {
                hex = substr(value, i + 1, 4)
                if (hex ~ /^[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]$/) {
                    out = out yaml_parse_utf8(yaml_parse_hex_value(hex))
                    i += 4
                } else {
                    yaml_parse_error()
                    return out
                }
            } else if (next_ch == "U" && i + 8 <= length(value)) {
                hex = substr(value, i + 1, 8)
                if (hex ~ /^[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]$/) {
                    out = out yaml_parse_utf8(yaml_parse_hex_value(hex))
                    i += 8
                } else {
                    yaml_parse_error()
                    return out
                }
            } else if (next_ch ~ /^[0abtnvfre "\\\/_NLP]$/) {
                out = out next_ch
            } else {
                yaml_parse_error()
                return out
            }
        } else {
            out = out ch
        }
    }
    return out
}

function yaml_parse_hex_value(hex,    i, n, ch) {
    n = 0
    for (i = 1; i <= length(hex); i++) {
        ch = substr(hex, i, 1)
        n = n * 16 + yaml_parse_hex_digit(ch)
    }
    return n
}

function yaml_parse_hex_digit(ch) {
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

function yaml_parse_utf8(cp) {
    if (cp > 1114111) {
        yaml_parse_error()
        return ""
    }
    if (cp < 128) {
        return sprintf("%c", cp)
    }
    if (yaml_parse_direct_unicode) {
        return sprintf("%c", cp)
    }
    if (cp < 2048) {
        return sprintf("%c%c", 192 + int(cp / 64), 128 + (cp % 64))
    }
    if (cp < 65536) {
        return sprintf("%c%c%c", 224 + int(cp / 4096), 128 + (int(cp / 64) % 64), 128 + (cp % 64))
    }
    return sprintf("%c%c%c%c", 240 + int(cp / 262144), 128 + (int(cp / 4096) % 64), 128 + (int(cp / 64) % 64), 128 + (cp % 64))
}

function yaml_parse_scalar(text,    token, tag) {
    text = yaml_parse_trim(text)
    yaml_parse_scalar_tag = "tag:yaml.org,2002:str"
    yaml_parse_scalar_tag_explicit = 0
    yaml_parse_scalar_anchor = ""
    yaml_parse_scalar_style = "plain"

    while (text != "") {
        if (substr(text, 1, 1) == "&") {
            token = text
            sub(/[ \t].*$/, "", token)
            yaml_parse_scalar_anchor = substr(token, 2)
            text = yaml_parse_trim(substr(text, length(token) + 1))
        } else if (substr(text, 1, 2) == "!!") {
            token = text
            sub(/[ \t].*$/, "", token)
            if (token ~ /,/) {
                yaml_parse_error()
                return "scalar"
            }
            yaml_parse_scalar_tag = yaml_parse_tag_handle["!!"] substr(token, 3)
            yaml_parse_scalar_tag_explicit = 1
            text = yaml_parse_trim(substr(text, length(token) + 1))
        } else if (substr(text, 1, 2) == "!<" && index(text, ">")) {
            token = substr(text, 1, index(text, ">"))
            yaml_parse_scalar_tag = substr(token, 3, length(token) - 3)
            yaml_parse_scalar_tag_explicit = 1
            text = yaml_parse_trim(substr(text, length(token) + 1))
        } else if (substr(text, 1, 1) == "!") {
            token = text
            sub(/[ \t].*$/, "", token)
            yaml_parse_scalar_tag = yaml_parse_resolve_tag(token)
            yaml_parse_scalar_tag_explicit = 1
            text = yaml_parse_trim(substr(text, length(token) + 1))
        } else {
            break
        }
    }

    if (substr(text, 1, 1) == "*") {
        if (yaml_parse_scalar_anchor != "" || yaml_parse_scalar_tag != "tag:yaml.org,2002:str") {
            yaml_parse_error()
            return "scalar"
        }
        yaml_parse_scalar_anchor = substr(yaml_parse_strip_inline_comment(text), 2)
        return "alias"
    }

    if (substr(text, 1, 1) == "\"") {
        yaml_parse_scalar_style = "double"
    } else if (substr(text, 1, 1) == "'") {
        yaml_parse_scalar_style = "single"
    } else {
        text = yaml_parse_strip_inline_comment(text)
    }
    yaml_parse_scalar_value_text = yaml_parse_scalar_value(text)
    return "scalar"
}
