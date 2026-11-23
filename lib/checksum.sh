# shellcheck shell=bash
# skills_sha256 <name>...: one checksum over every file of the named skills in ~/.agents/skills.
# `wk skills-sync` writes the same value into skills.lock as installed_sha256.
skills_sha256() {
  (cd "$HOME/.agents/skills" 2>/dev/null && find "$@" -type f ! -name .DS_Store -exec shasum -a 256 {} + 2>/dev/null \
    | LC_ALL=C sort | shasum -a 256 | cut -d' ' -f1)
}
