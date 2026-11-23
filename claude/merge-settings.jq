def add_missing($new): reduce $new[] as $x (.; if index([$x]) then . else . + [$x] end);

($fragment[0] | walk(if type == "string" then sub("__KIT__"; $kit) else . end)) as $wanted
| .permissions.allow = ((.permissions.allow // []) | add_missing($wanted.permissions.allow))
| .skillOverrides |= ((. // {}) | with_entries(select(.key as $name | $skills | index($name) | not)))
| reduce ($wanted.hooks | to_entries[]) as $event (.;
    .hooks[$event.key] = ((.hooks[$event.key] // []) | add_missing($event.value)))
