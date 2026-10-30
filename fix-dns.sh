#!/usr/bin/env bash
# Switch an already-mintified PC from Mullvad DNS to AdGuard DNS-over-TLS.
# Mullvad's public DNS is shutting down; machines set up by older versions of
# honest-mintify.sh have it hard-coded in /etc/systemd/resolved.conf and lose
# all name resolution once it's gone.
#
# One-liner:
#   curl -fsSL https://raw.githubusercontent.com/candroid-man/honest-mintify/main/fix-dns.sh | sudo bash
# If the PC already can't load websites (DNS is dead), pin GitHub's IP instead:
#   curl -fsSL --resolve raw.githubusercontent.com:443:185.199.108.133 https://raw.githubusercontent.com/candroid-man/honest-mintify/main/fix-dns.sh | sudo bash
set -euo pipefail

# ---------- colors (only if tty) ----------
if [[ -t 1 ]]; then
  C_RESET=$'\e[0m'; C_BOLD=$'\e[1m'; C_CYAN=$'\e[36m'
  C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'; C_RED=$'\e[31m'
else
  C_RESET=''; C_BOLD=''; C_CYAN=''; C_GREEN=''; C_YELLOW=''; C_RED=''
fi

die() { printf '%b!! %s%b\n' "$C_RED" "$1" "$C_RESET" >&2; exit 1; }
trap 'die "Failed on line $LINENO, please contact your technician."' ERR

[[ $EUID -eq 0 ]] || die "Run with sudo. Bailing."

section() { printf '\n%b━━ %s%b\n' "$C_CYAN$C_BOLD" "$1" "$C_RESET"; }
warn()    { printf '%b!! %s%b\n' "$C_YELLOW" "$1" "$C_RESET"; }

DROPIN=/etc/systemd/resolved.conf.d/99-adguard-dot.conf
STAMP=$(date +%Y%m%d%H%M%S)

write_dropin() {               # $1 = DNSOverTLS mode (yes | opportunistic)
  install -d /etc/systemd/resolved.conf.d
  cat > "$DROPIN" <<EOF
[Resolve]
# AdGuard DNS "Default" = blocks ads + trackers
# empty DNS= first wipes any servers left in resolved.conf by older setups
DNS=
DNS=94.140.14.14#dns.adguard-dns.com 94.140.15.15#dns.adguard-dns.com 2a10:50c0::ad1:ff#dns.adguard-dns.com 2a10:50c0::ad2:ff#dns.adguard-dns.com
DNSOverTLS=$1
DNSSEC=no
Domains=~.
EOF
}

dns_works() {                  # give the network up to ~20s to come back
  for _ in $(seq 1 20); do
    resolvectl query --cache=no --legend=no adguard-dns.com >/dev/null 2>&1 && return 0
    resolvectl query --cache=no --legend=no github.com      >/dev/null 2>&1 && return 0
    sleep 1
  done
  return 1
}

restart_dns() {
  systemctl restart systemd-resolved
  systemctl restart NetworkManager 2>/dev/null || true
}

# ====================================================================
section "1. Remove Mullvad DNS"
shopt -s nullglob
found=0
for f in /etc/systemd/resolved.conf /etc/systemd/resolved.conf.d/*.conf; do
  [[ -f "$f" ]] || continue
  grep -qiE '^[[:space:]]*[^#[:space:]].*(mullvad|194\.242\.2\.)' "$f" || continue
  cp -a "$f" "$f.bak.$STAMP"
  # comment out every active line that points at Mullvad
  sed -i -E '/mullvad|194\.242\.2\./I s/^[[:space:]]*([^#[:space:]])/#\1/' "$f"
  echo ">> cleaned $f (backup: $f.bak.$STAMP)"
  found=1
done
shopt -u nullglob
((found)) || echo ">> no Mullvad config found"

section "2. Configure AdGuard DNS-over-TLS"
command -v resolvectl >/dev/null || apt-get install -y systemd-resolved
write_dropin yes
echo ">> wrote $DROPIN"

systemctl enable systemd-resolved >/dev/null 2>&1 || true
systemctl start systemd-resolved
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
restart_dns

section "3. Test"
if dns_works; then
  mode="encrypted (DNS-over-TLS)"
else
  # some networks block port 853; fall back to AdGuard over plain DNS so the PC stays online
  warn "Encrypted DNS is blocked on this network, falling back to opportunistic mode"
  write_dropin opportunistic
  restart_dns
  dns_works || die "DNS still not working. Try rebooting; if that doesn't help, contact your technician."
  mode="opportunistic (encrypted when the network allows it)"
fi

trap - ERR
printf '\n%b━━ DONE: internet is working, using AdGuard DNS, %s.%b\n' "$C_GREEN$C_BOLD" "$mode" "$C_RESET"
echo "Nothing else to do, you can close this window."
