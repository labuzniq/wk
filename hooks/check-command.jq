# Reads the PreToolUse input of a Bash call. Prints one line per git call a rule covers: "<kind> TAB <folder> TAB <value>".
# Kinds: worktree-add, push (value: the branch a forced push would overwrite), message (value: first line), message-file (value: path).
# A folder or value the command does not spell out (a variable, a command substitution) is "?": the hook then lets the call pass.
# It reads the words of the command and runs nothing, so what an earlier part of the same command changes (the branch, a file) is not known.

# Quoted text, heredoc bodies and comments are lifted out of the command first, so words inside a message are never taken for a command.
def lift:
  . as $command
  | reduce match(
        "\"\\$\\(\\s*cat\\s*<<-?\\s*['\"]?(?<tag>\\w+)['\"]?[^\\n]*\\n(?<body>(.|\\n)*?)\\n\\s*\\k<tag>\\s*\\)\""
        + "|<<-?\\s*['\"]?(?<plain>\\w+)['\"]?(?<rest>[^\\n]*)\\n(.|\\n)*?\\n\\s*\\k<plain>(?![\\w-])"
        + "|'(?<single>[^']*)'"
        + "|\"(?<double>(\\\\(.|\\n)|[^\"\\\\])*)\""
        + "|(?<![^\\s;|&()])#(?<comment>[^\\n]*)"
        + "|\\\\\\n"; "g") as $m
      ({bare: [], at: 0, texts: []};
        ($m.captures | map(select(.name != null and .string != null) | {(.name): .string}) | add // {}) as $part
        | .bare += [$command[.at:$m.offset]]
        | .at = $m.offset + $m.length
        | if $part | has("plain") then .bare += [$part.rest]
          elif ($part | has("comment")) or $part == {} then .bare += [" "]
          else
            .bare += ["\u0001\(.texts | length)\u0001"]
            | .texts += [
                if $part | has("body") then {text: $part.body, known: true}
                elif $part | has("single") then {text: $part.single, known: true}
                else {text: ($part.double | gsub("\\\\(?<char>[\"\\\\$`])"; .char)), known: ($part.double | test("(^|[^\\\\])[$`]") | not)}
                end]
          end)
  | .bare = (.bare + [$command[.at:]] | join(""));

# A word of the bare command, with its quoted parts put back.
def word($texts):
  . as $word
  | {text: gsub("\u0001(?<index>\\d+)\u0001"; $texts[.index | tonumber].text),
     known: ((gsub("\u0001\\d+\u0001"; "") | test("[$`]") | not)
             and all($word | scan("\u0001(\\d+)\u0001") | $texts[.[0] | tonumber]; .known))};

def folder($from):
  if .known | not then "?"
  elif .text | startswith("/") then .text
  elif .text == "~" or (.text | startswith("~/")) then env.HOME + .text[1:]
  elif $from == "?" then "?"
  else $from + "/" + .text end;

def positional: map(select(.text | startswith("-") | not));

def option_value($short; $long):
  . as $args
  | first(range(length) as $i | $args[$i] as $arg
      | if $arg.text | test("^(" + $short + "|--" + $long + ")$") then $args[$i + 1] // empty
        elif $arg.text | test("^--" + $long + "=") then $arg | .text |= sub("^[^=]*="; "")
        elif $arg.text | test("^" + $short + ".") then $arg | .text |= sub("^" + $short; "")
        else empty end) // null;

def pushed($folder):
  . as $args
  | (any($args[].text; test("^(-[A-Za-z]*f[A-Za-z]*|--force|--force-with-lease(=.*)?|--force-if-includes)$"))) as $forced
  | (any($args[].text; test("^--(all|mirror|branches)$"))) as $every
  | ($args | positional | .[1:]) as $refs
  | (if $every then ["*"]
     elif $refs == [] then ["HEAD"]
     else $refs | map(select($forced or (.text | startswith("+")))
                      | if .known then .text | ltrimstr("+") | split(":") | last | ltrimstr("refs/heads/") else "?" end)
     end) as $targets
  | if $forced or ($refs | any(.text | startswith("+"))) then $targets[] | ["push", $folder, .] else empty end;

def committed($folder):
  if any(.[].text; test("^--(fixup|squash)")) then empty
  else
    option_value("-[aenpqsvz]*m"; "message") as $message
    | option_value("-F"; "file") as $file
    | if $message then (if $message.known then ["message", $folder, ($message.text | sub("^\\s+"; "") | split("\n")[0] // "")] else empty end)
      elif $file and $file.text != "-" then ["message-file", $folder, ($file | folder($folder))]
      else empty end
  end;

def git_call($from):
  {folder: $from, args: .}
  | until((.args[0].text // "") | startswith("-") | not;
      if .args[0].text == "-C" then .folder = ((.args[1] // {known: false}) | folder($from)) | .args |= .[2:]
      elif .args[0].text | IN("-c", "--git-dir", "--work-tree", "--namespace", "--config-env") then .args |= .[2:]
      else .args |= .[1:] end)
  | .folder as $folder
  | .args[0].text as $verb
  | .args[1:]
  | if $verb == "worktree" and (positional | .[0].text) == "add" then ["worktree-add", $folder, "-"]
    elif $verb == "push" then pushed($folder)
    elif $verb == "commit" then committed($folder)
    else empty end;

(.tool_input.command | lift) as $lifted
| reduce ($lifted.bare | splits("\\n|;|&&?|\\|\\|?|\\$\\(|`|\\(|\\)|\\{|\\}")) as $part
    ({folder: .cwd, calls: []};
      ([$part | scan("\\S+") | word($lifted.texts)]
        | until(length == 0 or (.[0].text | test("^(if|then|else|elif|do|while|until|!|time|command|builtin|exec|sudo|env|nohup|[A-Za-z_][A-Za-z0-9_]*=.*)$") | not); .[1:])) as $words
      | .folder as $from
      | if $words[0].text == "cd" then .folder = (($words[1] // {known: false}) | folder($from))
        elif ($words[0].text // "") | test("^(.*/)?git$") then .calls += [$words[1:] | git_call($from)]
        else . end)
| .calls[] | map(gsub("[\\t\\n]"; " ")) | join("\t")
