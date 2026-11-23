#!/usr/bin/env bash
cd "$(jq -r '.cwd')" 2>/dev/null || exit 0
nohup "$(dirname "$0")/../bin/wk" board-sync >/dev/null 2>&1 &
exit 0
