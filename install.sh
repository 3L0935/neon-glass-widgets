#!/usr/bin/env bash
# Install (or update) the Neon Glass widgets for the current user.
#   ./install.sh            both widgets
#   ./install.sh player     only one of them (player | monitor)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pkgs=("$@"); [ $# -eq 0 ] && pkgs=(player monitor)
for pkg in "${pkgs[@]}"; do
  id="$(sed -n 's/.*"Id": "\(.*\)".*/\1/p' "$ROOT/$pkg/metadata.json")"
  if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -qx "$id"; then
    kpackagetool6 -t Plasma/Applet -u "$ROOT/$pkg"
  else
    kpackagetool6 -t Plasma/Applet -i "$ROOT/$pkg"
  fi
done
echo
echo "Done. Add them with: right click on the desktop or a panel → Add Widgets → \"Neon Glass\"."
echo "After an update, restart Plasma: systemctl --user restart plasma-plasmashell"
