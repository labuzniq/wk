#!/usr/bin/env bats
# The starter check configs against a file with each mistake, run by the real linter when it is on this machine without a download.

# shellcheck disable=SC2154 # kit and the helpers come from helpers.bash
load helpers

setup() {
  starter="$kit/templates/checks/starter"
  cd "$BATS_TEST_TMPDIR" || return 1
}

# found <rule>...: every rule is named in $output.
found() {
  local rule
  for rule in "$@"; do
    [[ "$output" == *"$rule"* ]] || { printf 'no finding for %s in:\n%s\n' "$rule" "$output"; return 1; }
  done
}

@test "ruff reports each Python mistake, and nothing in a clean file or an excluded folder" {
  ruff=$(grep -o 'ruff@[0-9.]*' "$kit/libexec/wk-adopt")
  UV_CACHE_DIR="$(uv cache dir)" && export UV_CACHE_DIR
  uvx --offline "$ruff" --version > /dev/null 2>&1 || skip "$ruff is not in the uv cache; test/run puts it there"
  printf 'try:\n    x = 1\nexcept:\n    x = 2\ntry:\n    x = 1\nexcept Exception:\n    x = 2\ntry:\n    x = 1\nexcept ValueError:\n    pass\nprint(x)\ny: int = "a"  # type: ignore\nimport os  # noqa\n' > bad.py
  run uvx --offline "$ruff" check --config "$starter/python.toml" --output-format concise
  [ "$status" -eq 1 ]
  found E722 BLE001 S110 T201 PGH003 PGH004
  mkdir gen
  mv bad.py gen/
  sed 's/^extend-exclude = .*/extend-exclude = ["gen"]/' "$starter/python.toml" > python.toml
  printf 'import logging\n\ntry:\n    x = 1\nexcept ValueError:\n    logging.exception("no x")\n    raise\n' > good.py
  run uvx --offline "$ruff" check --config python.toml
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "SwiftLint reports each Swift mistake, and nothing in a clean file or an empty project" {
  command -v swiftlint > /dev/null || skip "swiftlint is not installed"
  mkdir -p checks/starter
  cp "$starter/swift.yml" checks/starter/
  run swiftlint lint --strict --quiet --config checks/starter/swift.yml
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  printf 'func f(a: Int?, b: Any) throws {\n    _ = a!\n    _ = try! g()\n    _ = b as! Int\n    print(a)\n}\n' > bad.swift
  run swiftlint lint --strict --quiet --config checks/starter/swift.yml
  [ "$status" -ne 0 ]
  found force_unwrapping force_try force_cast debug_print
  printf 'func f() {\n    do { try g() } catch {}\n    do { try g() } catch let error {}\n    do { try g() } catch MyError.gone {\n    }\n}\n' > bad.swift
  run swiftlint lint --strict --quiet --config checks/starter/swift.yml
  is "$(grep -c empty_catch <<< "$output")" 3
  printf 'func f(log: Log) {\n    do { try g() } catch let error { log.dump(error) }\n    let text = "print(x)" // print(x)\n    log.print(text)\n}\n' > bad.swift
  run swiftlint lint --strict --quiet --config checks/starter/swift.yml
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}
