#!/usr/bin/env bash
# Install gpuq/gpuqd symlinks into ~/.local/bin, enable the user systemd unit,
# and wire the agent instructions into the user-level CLAUDE.md.
#
# Safe to run multiple times.
set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/.local/bin"
UNIT_DIR="$HOME/.config/systemd/user"
CLAUDE_DIR="$HOME/.claude"

mkdir -p "$BIN" "$UNIT_DIR" "$CLAUDE_DIR"

ln -sf "$REPO/gpuq"  "$BIN/gpuq"
ln -sf "$REPO/gpuqd" "$BIN/gpuqd"
install -m 0644 "$REPO/systemd/gpuqd.service" "$UNIT_DIR/gpuqd.service"

systemctl --user daemon-reload
systemctl --user enable --now gpuqd.service

# Wire the agent-facing snippet into ~/.claude/CLAUDE.md via an @import, so
# the file stays in the repo and edits here flow through to every session.
IMPORT_LINE="@$REPO/CLAUDE.md"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
if [[ ! -f "$CLAUDE_MD" ]] || ! grep -qF "$IMPORT_LINE" "$CLAUDE_MD"; then
    {
        [[ -s "$CLAUDE_MD" ]] && echo ""
        echo "$IMPORT_LINE"
    } >> "$CLAUDE_MD"
    echo "wrote import line to $CLAUDE_MD"
fi

echo
echo "installed. try:"
echo "  gpuq status"
echo "  gpuq submit -p 5 -- nvidia-smi"
echo "  systemctl --user status gpuqd"
