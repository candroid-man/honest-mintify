#!/usr/bin/env bash
# Mint debloat + Brave Origin + ONLYOFFICE + AdGuard DoT
# Run with: sudo bash honest-mintify.sh   (Linux Mint 21/22/23, Cinnamon/X11)
set -euo pipefail

# ---------- colors (only if tty) ----------
if [[ -t 1 ]]; then
  C_RESET=$'\e[0m'; C_BOLD=$'\e[1m'; C_CYAN=$'\e[36m'
  C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'; C_RED=$'\e[31m'
else
  C_RESET=''; C_BOLD=''; C_CYAN=''; C_GREEN=''; C_YELLOW=''; C_RED=''
fi

die() { printf '%b!! %s%b\n' "$C_RED" "$1" "$C_RESET" >&2; exit 1; }
trap 'die "Failed on line $LINENO"' ERR

[[ $EUID -eq 0 ]] || die "Run with sudo. Bailing."

REAL_USER="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
USER_UID="$(id -u "$REAL_USER")"
# run a cmd as the real user WITH a working dbus/dconf session (needed for gsettings)
RUN_AS_USER() {
  sudo -u "$REAL_USER" env \
    HOME="$USER_HOME" \
    XDG_RUNTIME_DIR="/run/user/$USER_UID" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_UID/bus" \
    "$@"
}

# ---------- banner ----------
printf '%b' "$C_CYAN$C_BOLD"
cat <<'BANNER'
______                          _____                  _____       __________________        
___  /____________________________  /_      _______ ______(_)________  /___(_)__  __/____  __
__  __ \  __ \_  __ \  _ \_  ___/  __/________  __ `__ \_  /__  __ \  __/_  /__  /_ __  / / /
_  / / / /_/ /  / / /  __/(__  )/ /_ _/_____/  / / / / /  / _  / / / /_ _  / _  __/ _  /_/ / 
/_/ /_/\____//_/ /_/\___//____/ \__/        /_/ /_/ /_//_/  /_/ /_/\__/ /_/  /_/    _\__, /  
                                                                                    /____/
BANNER
printf '%b\n' "$C_RESET"

# ---------- progress bar ----------
TOTAL_STEPS=8; STEP=0
progress() {
  STEP=$((STEP+1))
  local width=34 pct filled empty bar
  pct=$(( STEP * 100 / TOTAL_STEPS ))
  filled=$(( STEP * width / TOTAL_STEPS ))
  empty=$(( width - filled ))
  bar=$(printf '█%.0s' $(seq 1 "$filled"))
  (( empty > 0 )) && bar+=$(printf '░%.0s' $(seq 1 "$empty"))
  printf '%b%s%b %3d%%  %b(%d/%d)%b %s\n\n' \
    "$C_GREEN" "$bar" "$C_RESET" "$pct" "$C_BOLD" "$STEP" "$TOTAL_STEPS" "$C_RESET" "$1"
}
section() { printf '\n%b━━ %s%b\n' "$C_CYAN$C_BOLD" "$1" "$C_RESET"; }
ask() { read -rp "$(printf '%b? %s%b [y/N] ' "$C_YELLOW" "$1" "$C_RESET")" a < /dev/tty; [[ "$a" =~ ^[Yy]$ ]]; }

# ---------- helpers ----------
purge_pkgs() {                 # one apt call for whatever's actually installed
  local p list=()
  for p in "$@"; do
    dpkg-query -W -f='${Status}\n' "$p" 2>/dev/null | grep -q "install ok installed" && list+=("$p")
  done
  if ((${#list[@]})); then
    echo ">> apt purge ${list[*]}"
    apt-get purge -y "${list[@]}"
  fi
}

remove_flatpak() {
  command -v flatpak >/dev/null || return 0
  local id
  for id in "$@"; do
    flatpak list --app --columns=application 2>/dev/null | grep -qix "$id" || continue
    echo ">> flatpak remove $id"
    flatpak uninstall -y --delete-data "$id" || true
  done
}

remove_snap() {
  command -v snap >/dev/null || return 0
  local s
  for s in "$@"; do
    snap list 2>/dev/null | grep -q "^$s " || continue
    echo ">> snap remove $s"
    snap remove --purge "$s" || true
  done
}

clean_desktop_icons() {        # delete launcher files matching name patterns
  local pat
  for pat in "$@"; do
    find /usr/share/applications \
         /usr/local/share/applications \
         "$USER_HOME/.local/share/applications" \
         /var/lib/flatpak/exports/share/applications \
         -maxdepth 1 -iname "*${pat}*.desktop" -print -delete 2>/dev/null || true
  done
}

unpin_apps() {                 # remove pinned menu favorites by name pattern
  command -v gsettings >/dev/null || return 0
  local cur new id
  cur=$(RUN_AS_USER gsettings get org.cinnamon favorite-apps 2>/dev/null) || return 0
  new="$cur"
  for id in "$@"; do
    new=$(sed -E "s/'[^']*${id}[^']*\.desktop',? ?//g" <<<"$new")
  done
  new=$(sed -E 's/, *]/]/' <<<"$new")
  if [[ "$new" != "$cur" ]]; then
    RUN_AS_USER gsettings set org.cinnamon favorite-apps "$new"
  fi
  return 0
}

pin_to_taskbar() {             # add a .desktop to the grouped-window-list pins
  local desktop="$1"
  command -v jq >/dev/null || apt-get install -y jq
  local dir="$USER_HOME/.config/cinnamon/spices/grouped-window-list@cinnamon.org"
  [[ -d "$dir" ]] || { echo ">> no taskbar applet config, skip pin"; return 0; }
  local cfg tmp
  for cfg in "$dir"/*.json; do
    [[ -f "$cfg" ]] || continue
    jq -e '.["pinned-apps"].value' "$cfg" >/dev/null 2>&1 || continue
    if jq -e --arg d "$desktop" '.["pinned-apps"].value|index($d)' "$cfg" >/dev/null 2>&1; then
      echo ">> $desktop already pinned"; continue
    fi
    tmp=$(mktemp)
    jq --indent 4 --arg d "$desktop" '.["pinned-apps"].value += [$d]' "$cfg" > "$tmp" && cat "$tmp" > "$cfg"
    rm -f "$tmp"
    echo ">> pinned $desktop to taskbar"
  done
}

refresh_menu() {
  update-desktop-database /usr/share/applications 2>/dev/null || true
  RUN_AS_USER update-desktop-database "$USER_HOME/.local/share/applications" 2>/dev/null || true
  gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true
}

# ====================================================================
section "0. Refresh package lists"
apt-get update
progress "Repos updated"

section "1. Remove Hypnotix (IPTV)"
purge_pkgs hypnotix
remove_flatpak org.x.hypnotix
clean_desktop_icons hypnotix
unpin_apps hypnotix
progress "Hypnotix removed"

section "2. Remove Matrix / Element (mintchat)"
purge_pkgs mintchat element-desktop nheko
remove_flatpak im.riot.Riot io.element.Element im.fluffychat.Fluffychat
remove_snap element-desktop
clean_desktop_icons matrix mintchat element riot nheko
unpin_apps mintchat element riot
progress "Matrix/Element removed"

section "3. Remove Thunderbird + Transmission"
purge_pkgs thunderbird thunderbird-locale-en transmission-gtk transmission-common transmission-qt
remove_flatpak org.mozilla.Thunderbird com.transmissionbt.Transmission
remove_snap thunderbird
clean_desktop_icons thunderbird transmission
unpin_apps thunderbird transmission
progress "Thunderbird + Transmission removed"

# ---- 4. Optional: Firefox -> Brave Origin stable ----
section "4. Browser"
if ask "Replace Firefox with Brave Origin (stable)?"; then
  command -v curl >/dev/null || apt-get install -y curl
  echo ">> installing Brave Origin stable"
  curl -fsS https://dl.brave.com/install.sh | FLAVOR=origin sh || true
  if command -v brave-browser >/dev/null 2>&1 || ls /usr/bin/brave* >/dev/null 2>&1; then
    echo ">> Brave OK, purging Firefox"
    purge_pkgs firefox firefox-locale-en
    clean_desktop_icons firefox
    unpin_apps firefox
    brave_desktop=$(find /usr/share/applications /var/lib/flatpak/exports/share/applications \
                      -maxdepth 1 -iname 'brave*.desktop' -printf '%f\n' 2>/dev/null | head -n1)
    if [[ -n "$brave_desktop" ]]; then
      pin_to_taskbar "$brave_desktop"
    else
      printf '%b!! Brave .desktop not found, skipping taskbar pin%b\n' "$C_YELLOW" "$C_RESET"
    fi
  else
    printf '%b!! Brave not detected, KEEPING Firefox%b\n' "$C_YELLOW" "$C_RESET"
  fi
else
  echo ">> skipped"
fi
progress "Browser step done"

# ---- 5. Optional: LibreOffice -> ONLYOFFICE (Flathub) ----
section "5. Office"
if ask "Replace LibreOffice with ONLYOFFICE (Flathub)?"; then
  command -v flatpak >/dev/null || apt-get install -y flatpak
  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  echo ">> installing ONLYOFFICE"
  flatpak install -y flathub org.onlyoffice.desktopeditors || true
  if flatpak list --app --columns=application | grep -qix org.onlyoffice.desktopeditors; then
    echo ">> ONLYOFFICE OK, purging LibreOffice"
    # enumerate ONLY real installed libreoffice* pkgs (no apt regex, no fonts touched)
    mapfile -t lo_pkgs < <(dpkg-query -W -f='${Package}\n' 'libreoffice*' 2>/dev/null || true)
    ((${#lo_pkgs[@]})) && purge_pkgs "${lo_pkgs[@]}"
    clean_desktop_icons libreoffice
    unpin_apps libreoffice
  else
    printf '%b!! ONLYOFFICE install failed, KEEPING LibreOffice%b\n' "$C_YELLOW" "$C_RESET"
  fi
else
  echo ">> skipped"
fi
progress "Office step done"

refresh_menu

# ---- 6. DNS-over-TLS + ad/tracker filtering (AdGuard DNS) ----
section "6. DoT + ad filtering (AdGuard)"
apt-get install -y systemd-resolved 2>/dev/null || true

install -d /etc/systemd/resolved.conf.d
cat > /etc/systemd/resolved.conf.d/99-adguard-dot.conf <<'EOF'
[Resolve]
# AdGuard DNS "Default" = blocks ads + trackers
DNS=94.140.14.14#dns.adguard.com 94.140.15.15#dns.adguard.com 2a10:50c0::ad1:ff#dns.adguard.com 2a10:50c0::ad2:ff#dns.adguard.com
DNSOverTLS=yes
DNSSEC=allow-downgrade
Domains=~.
EOF

systemctl enable --now systemd-resolved
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

install -d /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/dns-resolved.conf <<'EOF'
[main]
dns=systemd-resolved

# no-leak: ignore DHCP-pushed DNS on every connection, force AdGuard only
[connection]
ipv4.ignore-auto-dns=true
ipv6.ignore-auto-dns=true
EOF
systemctl restart NetworkManager 2>/dev/null || true
systemctl restart systemd-resolved
progress "AdGuard DoT configured"

# ---- 7. Upgrade everything + cleanup ----
section "7. Upgrade everything"
apt-get upgrade -y
apt-get autoremove -y
progress "System upgraded"

trap - ERR
printf '%b━━ DONE%b\n' "$C_GREEN$C_BOLD" "$C_RESET"
echo "Verify DoT:   resolvectl status | grep -A2 'Current DNS'"
echo "Test filter:  resolvectl query doubleclick.net   (should be blocked/0.0.0.0)"

# ---- reboot ----
printf '%b!! Rebooting in 10s to apply everything. Ctrl-C to cancel.%b\n' "$C_YELLOW" "$C_RESET"
for i in $(seq 10 -1 1); do printf '\r   %2ds...' "$i"; sleep 1; done
printf '\n'
reboot
