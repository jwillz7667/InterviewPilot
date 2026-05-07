#!/usr/bin/env bash
# install.sh: opt-in installer that wires this repo to use ./.githooks for git hooks.
#
# Run once per clone:  ./.githooks/install.sh
# Reverses with:       git config --unset core.hooksPath

set -euo pipefail

repo_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [[ -z "$repo_root" ]]; then
  echo "error: must be run inside the InterviewPilot git working tree." >&2
  exit 1
fi

cd "$repo_root"
chmod +x .githooks/pre-commit
git config core.hooksPath .githooks

echo "Installed: core.hooksPath -> .githooks"
echo "pre-commit hook will run gitleaks on every commit."

if ! command -v gitleaks >/dev/null 2>&1; then
  cat <<'MSG'

gitleaks is not installed yet. The hook will warn-and-skip until you install it:
  brew install gitleaks                                   # macOS
  go install github.com/gitleaks/gitleaks/v8@latest       # via Go
MSG
fi
