#!/usr/bin/env bash
# Install the music-cli extras for the Neon Glass Player widget:
#   - MPRIS + reshuffle + "neon-glass" theme hook, into music-cli's uv/pipx venv
#   - the neonglass-player and neonglass-mix commands, into ~/.local/bin
#   - a starter ~/.config/neonglass/mix.json (kept if it exists)
# Run it again after upgrading music-cli (an upgrade wipes the hook).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/.local/bin"

# music-cli's interpreter: the shebang of its launcher (uv tool / pipx / venv)
launcher="$(command -v music-cli || true)"
[ -n "$launcher" ] || { echo "music-cli not found in PATH"; exit 1; }
py="$(head -1 "$(readlink -f "$launcher")" | sed -n 's/^#!\s*//p' | awk '{print $1}')"
[ -x "$py" ] || { echo "can't find music-cli's Python (from $launcher)"; exit 1; }
site="$("$py" -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')"
"$py" -c 'import music_cli' 2>/dev/null || { echo "$py can't import music_cli"; exit 1; }

cp "$HERE/neonglass_music_cli.py" "$HERE/neonglass_mpris.py" "$site/"
echo "import neonglass_music_cli" > "$site/neonglass.pth"
echo "hook  → $site"

mkdir -p "$BIN" "$HOME/.local/share/neonglass"
cp "$HERE/neonglass-player.py" "$HERE/neonglass-mix.py" "$HOME/.local/share/neonglass/"
for cmd in neonglass-player neonglass-mix; do
  printf '#!/bin/sh\nexec "%s" -I "%s/.local/share/neonglass/%s.py" "$@"\n' "$py" "$HOME" "$cmd" > "$BIN/$cmd"
  chmod +x "$BIN/$cmd"
done
echo "cmds  → $BIN/neonglass-player, $BIN/neonglass-mix"

"$BIN/neonglass-mix" --init-config || true
echo
echo "Next:"
echo "  1. edit ~/.config/neonglass/mix.json (genres + keywords), then run: neonglass-mix --dry-run"
echo "  2. quit music-cli once (Ctrl+Q in the TUI) so its daemon loads the hook"
echo "  3. widget settings → General → enable \"music-cli integration\""
