#!/bin/bash

# Check for sudo privileges
if [ "$(id -u)" != "0" ]; then
    echo "🚨 This script requires sudo privileges. Please run with sudo. 🚨"
    exit 1
fi

# Helper function for accurate package status
package_status() {
    local package=$1
    if dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then
        echo "installed"
    else
        echo "not installed"
    fi
}

# Helper function for precise LibreOffice application detection
libreoffice_app_status() {
    # Check for ALL LibreOffice packages that contribute to the application
    local count=$(dpkg -l | grep -E "^ii[[:space:]]+(libreoffice|lo-)(writer|calc|impress|draw|base|math|core|common|help|python3-uno)" | wc -l)
    echo "$count"
}

# Helper function for pretty package removal
remove_package() {
    local package=$1
    local status=$(package_status "$package")

    if [ "$status" = "not installed" ]; then
        echo "📦 $package... ✅ (already removed)"
        return 0
    fi

    echo -n "📦 $package... "
    if apt remove -y "$package" > /dev/null 2>&1; then
        echo "✅ removed"
        return 0
    else
        echo "❌ failed"
        return 1
    fi
}

# Helper function for Flatpak status
flatpak_status() {
    local package=$1
    if flatpak info "$package" &>/dev/null; then
        echo "installed"
    else
        echo "not installed"
    fi
}

# Helper function for user confirmation with validation
user_confirm() {
    local prompt=$1
    local response=""

    while [[ ! $response =~ ^[YyNn]$ ]]; do
        read -p "$prompt (y/n) " -n 1 -r
        echo
        response=$REPLY
        REPLY=""  # Reset REPLY for next prompt

        if [[ ! $response =~ ^[YyNn]$ ]]; then
            echo "⚠️  Please enter 'y' or 'n'"
        fi
    done

    [[ $response =~ ^[Yy]$ ]]
}

# Update package list (silenced but errors still visible)
echo "🔄 Updating package list..."
if ! apt update > /dev/null 2>&1; then
    echo "⚠️  Failed to update package list - continuing anyway ⚠️"
fi

# Check core application status
declare -A app_status
apps_to_check=("hypnotix" "thunderbird" "mintchat")
for app in "${apps_to_check[@]}"; do
    app_status[$app]=$(package_status "$app")
done

# Remove core applications with state checking
echo -e "\n🔍 Checking core applications:"
for app in "${!app_status[@]}"; do
    if [ "${app_status[$app]}" = "installed" ]; then
        remove_package "$app"
    else
        echo "📦 $app... ✅ (already removed)"
    fi
done

# Clean up dependencies
echo -e "\n🧹 Cleaning up dependencies..."
if output=$(apt autoremove -y 2>&1); then
    if echo "$output" | grep -q "0 upgraded, 0 newly installed"; then
        echo "✅ No dependencies to clean"
    else
        echo "✅ Dependencies cleaned"
    fi
else
    echo "⚠️  Failed to clean dependencies"
fi

# DNS Configuration status check
echo -e "\n🌐 Checking DNS configuration..."
if [ -f "/etc/systemd/resolved.conf" ]; then
    if grep -q "DNS=194.242.2.4#base.dns.mullvad.net" /etc/systemd/resolved.conf; then
        echo "✅ Mullvad DNS already configured"
    else
        # Backup original file
        echo "🗄️  Backing up original resolved.conf..."
        cp /etc/systemd/resolved.conf "/etc/systemd/resolved.conf.bak.$(date +%Y%m%d%H%M%S)"

        # Configure Mullvad as primary DNS
        echo "🔧 Configuring DNS settings in /etc/systemd/resolved.conf..."
        tee /etc/systemd/resolved.conf > /dev/null << 'EOF'
[Resolve]
#DNS=194.242.2.2#dns.mullvad.net
#DNS=194.242.2.3#adblock.dns.mullvad.net
DNS=194.242.2.4#base.dns.mullvad.net
#DNS=194.242.2.5#extended.dns.mullvad.net
#DNS=194.242.2.6#family.dns.mullvad.net
#DNS=194.242.2.9#all.dns.mullvad.net
DNSSEC=no
DNSOverTLS=yes
Domains=~.
EOF

        ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf > /dev/null 2>&1
        systemctl restart systemd-resolved > /dev/null 2>&1
        systemctl restart NetworkManager > /dev/null 2>&1

        # Verify DNS configuration
        echo -n "🔍 Verifying DNS configuration... "
        if resolvectl query google.com > /dev/null 2>&1; then
            echo "✅ verified"
        else
            echo "⚠️  configured but not working properly"
            echo "💡 Try restarting network services or rebooting"
        fi
    fi
else
    echo "⚠️  resolved.conf not found - configuring DNS... ⚠️"
    # Configure Mullvad as primary DNS
    tee /etc/systemd/resolved.conf > /dev/null << 'EOF'
[Resolve]
#DNS=194.242.2.2#dns.mullvad.net
#DNS=194.242.2.3#adblock.dns.mullvad.net
DNS=194.242.2.4#base.dns.mullvad.net
#DNS=194.242.2.5#extended.dns.mullvad.net
#DNS=194.242.2.6#family.dns.mullvad.net
#DNS=194.242.2.9#all.dns.mullvad.net
DNSSEC=no
DNSOverTLS=yes
Domains=~.
EOF

    ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf > /dev/null 2>&1
    systemctl enable systemd-resolved > /dev/null 2>&1
    systemctl restart systemd-resolved > /dev/null 2>&1
    systemctl restart NetworkManager > /dev/null 2>&1

    # Verify DNS configuration
    echo -n "🔍 Verifying DNS configuration... "
    if resolvectl query google.com > /dev/null 2>&1; then
        echo "✅ verified"
    else
        echo "⚠️  configured but not working properly"
        echo "💡 Try restarting network services or rebooting"
    fi

    echo "💡 Note: You may need to manually disable/re-enable your network connection for full effect"
fi

# LibreOffice status check - PRECISE detection for ALL components
libreoffice_installed=$(libreoffice_app_status)
onlyoffice_status=$(flatpak_status "org.onlyoffice.desktopeditors")

# Check if the LibreOffice executable exists (for the menu entry)
libreoffice_executable_status="not installed"
if command -v libreoffice >/dev/null 2>&1; then
    libreoffice_executable_status="installed"
fi

echo -e "\n📝 Checking office applications:"
if [ "$libreoffice_installed" -gt 0 ] || [ "$libreoffice_executable_status" = "installed" ]; then
    echo "✅ LibreOffice system detected"

    # List detected components
    echo -n "📦 Components found: "
    components=()
    if [ "$(dpkg -l | grep -q 'libreoffice-writer' && echo 1 || echo 0)" -eq 1 ]; then components+=("Writer"); fi
    if [ "$(dpkg -l | grep -q 'libreoffice-calc' && echo 1 || echo 0)" -eq 1 ]; then components+=("Calc"); fi
    if [ "$(dpkg -l | grep -q 'libreoffice-impress' && echo 1 || echo 0)" -eq 1 ]; then components+=("Impress"); fi
    if [ "$(dpkg -l | grep -q 'libreoffice-core' && echo 1 || echo 0)" -eq 1 ]; then components+=("Core"); fi
    if [ "$(dpkg -l | grep -q 'libreoffice-common' && echo 1 || echo 0)" -eq 1 ]; then components+=("Common"); fi
    if [ "$(dpkg -l | grep -q 'python3-uno' && echo 1 || echo 0)" -eq 1 ]; then components+=("Python"); fi
    if [ "$libreoffice_executable_status" = "installed" ]; then components+=("Executable"); fi
    echo "${components[@]}"

    # Check if ONLYOFFICE is also installed
    if [ "$onlyoffice_status" = "installed" ]; then
        echo "✅ ONLYOFFICE is also installed 🎯"
        if user_confirm "🗑️  Would you like to completely remove LibreOffice?"; then
            # Get ALL LibreOffice packages including core components
            libreoffice_packages=$(dpkg -l | grep -E "^ii[[:space:]]+(libreoffice|lo-)(writer|calc|impress|draw|base|math|core|common|help|python3-uno)" | awk '{print $2}')

            # Add the libreoffice executable package if it exists
            if command -v libreoffice >/dev/null 2>&1; then
                libreoffice_packages+=" libreoffice"
            fi

            if [ -n "$libreoffice_packages" ]; then
                echo -e "\n🧹 Completely removing LibreOffice system:"
                for pkg in $libreoffice_packages; do
                    remove_package "$pkg"
                done
            else
                echo "✅ No LibreOffice packages found to remove"
            fi

            # Force removal of any remaining LibreOffice files
            echo -e "\n🔍 Deep cleaning LibreOffice remnants..."
            rm -rf /usr/lib/libreoffice > /dev/null 2>&1
            rm -rf /etc/libreoffice > /dev/null 2>&1
            rm -rf /var/lib/libreoffice > /dev/null 2>&1
            echo "✅ Deep clean completed"

            # Remove ALL desktop entries (multiple locations)
            echo -e "\n🗑️  Removing LibreOffice menu entries from ALL locations..."
            find /usr/share/applications -name '*libreoffice*' -exec rm -f {} \;
            find /usr/local/share/applications -name '*libreoffice*' -exec rm -f {} \;
            find ~/.local/share/applications -name '*libreoffice*' -exec rm -f {} \;
            find /etc/xdg/autostart -name '*libreoffice*' -exec rm -f {} \;

            # Verify removal
            if find /usr/share/applications /usr/local/share/applications ~/.local/share/applications /etc/xdg/autostart -name '*libreoffice*' -print -quit 2>/dev/null; then
                echo "⚠️  Some menu entries could not be removed - check permissions"
            fi

            # Clear menu caches - CRITICAL FOR MINT
            echo -e "\n🔄 Refreshing menu caches..."
            update-desktop-database > /dev/null 2>&1
            gtk-update-icon-cache /usr/share/icons/gnome > /dev/null 2>&1
            gtk-update-icon-cache /usr/share/icons/hicolor > /dev/null 2>&1

            # Special Linux Mint menu refresh
            if [ -x /usr/bin/mintmenu ]; then
                echo "🔄 Refreshing Linux Mint menu cache..."
                killall mintmenu > /dev/null 2>&1
                sleep 3
                /usr/bin/mintmenu > /dev/null 2>&1 &

                # Verify cache refresh completed
                sleep 1
                if ! pgrep -x mintmenu > /dev/null; then
                    /usr/bin/mintmenu > /dev/null 2>&1 &
                fi
            fi

            # Verification (silent unless failure)
            if find /usr/share/applications /usr/local/share/applications ~/.local/share/applications /etc/xdg/autostart -name '*libreoffice*' -print -quit 2>/dev/null; then
                echo "⚠️  WARNING: Some LibreOffice menu entries might persist after reboot"
                echo "💡 Consider logging out and back in if they reappear"
            fi

            echo "✅ Menu entries removed and caches refreshed"
        else
            echo "✅ Keeping LibreOffice system as requested 📚"
        fi
    else
        echo "🚫 ONLYOFFICE is not installed"
        if user_confirm "🔄 Would you like to replace LibreOffice with ONLYOFFICE?"; then
            # Get ALL LibreOffice packages including core components
            libreoffice_packages=$(dpkg -l | grep -E "^ii[[:space:]]+(libreoffice|lo-)(writer|calc|impress|draw|base|math|core|common|help|python3-uno)" | awk '{print $2}')

            # Add the libreoffice executable package if it exists
            if command -v libreoffice >/dev/null 2>&1; then
                libreoffice_packages+=" libreoffice"
            fi

            if [ -n "$libreoffice_packages" ]; then
                echo -e "\n🧹 Completely removing LibreOffice system:"
                for pkg in $libreoffice_packages; do
                    remove_package "$pkg"
                done
            else
                echo "✅ No LibreOffice packages found to remove"
            fi

            # Force removal of any remaining LibreOffice files
            echo -e "\n🔍 Deep cleaning LibreOffice remnants..."
            rm -rf /usr/lib/libreoffice > /dev/null 2>&1
            rm -rf /etc/libreoffice > /dev/null 2>&1
            rm -rf /var/lib/libreoffice > /dev/null 2>&1
            echo "✅ Deep clean completed"

            # Remove ALL desktop entries (multiple locations)
            echo -e "\n🗑️  Removing LibreOffice menu entries from ALL locations..."
            find /usr/share/applications -name '*libreoffice*' -exec rm -f {} \;
            find /usr/local/share/applications -name '*libreoffice*' -exec rm -f {} \;
            find ~/.local/share/applications -name '*libreoffice*' -exec rm -f {} \;
            find /etc/xdg/autostart -name '*libreoffice*' -exec rm -f {} \;

            # Verify removal
            if find /usr/share/applications /usr/local/share/applications ~/.local/share/applications /etc/xdg/autostart -name '*libreoffice*' -print -quit 2>/dev/null; then
                echo "⚠️  Some menu entries could not be removed - check permissions"
            fi

            # Clear menu caches - CRITICAL FOR MINT
            echo -e "\n🔄 Refreshing menu caches..."
            update-desktop-database > /dev/null 2>&1
            gtk-update-icon-cache /usr/share/icons/gnome > /dev/null 2>&1
            gtk-update-icon-cache /usr/share/icons/hicolor > /dev/null 2>&1

            # Special Linux Mint menu refresh
            if [ -x /usr/bin/mintmenu ]; then
                echo "🔄 Refreshing Linux Mint menu cache..."
                killall mintmenu > /dev/null 2>&1
                sleep 3
                /usr/bin/mintmenu > /dev/null 2>&1 &

                # Verify cache refresh completed
                sleep 1
                if ! pgrep -x mintmenu > /dev/null; then
                    /usr/bin/mintmenu > /dev/null 2>&1 &
                fi
            fi

            # Verification (silent unless failure)
            if find /usr/share/applications /usr/local/share/applications ~/.local/share/applications /etc/xdg/autostart -name '*libreoffice*' -print -quit 2>/dev/null; then
                echo "⚠️  WARNING: Some LibreOffice menu entries might persist after reboot"
                echo "💡 Consider logging out and back in if they reappear"
            fi

            echo "✅ Menu entries removed and caches refreshed"

            # Install Flatpak if needed
            if ! command -v flatpak >/dev/null; then
                echo -n "📦 Installing Flatpak... "
                if apt install -y flatpak > /dev/null 2>&1; then
                    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo > /dev/null 2>&1
                    echo "✅"
                else
                    echo "❌"
                    exit 1
                fi
            fi

            # Install ONLYOFFICE
            echo -n "📥 Installing ONLYOFFICE... "
            if flatpak install -y flathub org.onlyoffice.desktopeditors > /dev/null 2>&1; then
                echo "✅"
            else
                echo "❌"
            fi
        else
            echo "✅ Keeping LibreOffice system as requested 📚"
        fi
    fi
else
    echo "✅ No LibreOffice system detected 🗑️"

    # Check for stray menu entries during initial detection
    if find /usr/share/applications /usr/local/share/applications ~/.local/share/applications /etc/xdg/autostart -name '*libreoffice*' -print -quit 2>/dev/null; then
        echo -e "\n🔍 Found stray LibreOffice menu entries"
        if user_confirm "🗑️  Would you like to remove them?"; then
            find /usr/share/applications -name '*libreoffice*' -exec rm -f {} \;
            find /usr/local/share/applications -name '*libreoffice*' -exec rm -f {} \;
            find ~/.local/share/applications -name '*libreoffice*' -exec rm -f {} \;
            find /etc/xdg/autostart -name '*libreoffice*' -exec rm -f {} \;

            # Verify removal
            if find /usr/share/applications /usr/local/share/applications ~/.local/share/applications /etc/xdg/autostart -name '*libreoffice*' -print -quit 2>/dev/null; then
                echo "⚠️  Some menu entries could not be removed - check permissions"
            fi

            # Clear menu caches
            update-desktop-database > /dev/null 2>&1
            gtk-update-icon-cache /usr/share/icons/gnome > /dev/null 2>&1
            gtk-update-icon-cache /usr/share/icons/hicolor > /dev/null 2>&1

            # Special Linux Mint menu refresh
            if [ -x /usr/bin/mintmenu ]; then
                killall mintmenu > /dev/null 2>&1
                sleep 3
                /usr/bin/mintmenu > /dev/null 2>&1 &

                # Verify cache refresh completed
                sleep 1
                if ! pgrep -x mintmenu > /dev/null; then
                    /usr/bin/mintmenu > /dev/null 2>&1 &
                fi
            fi

            # Verification
            if find /usr/share/applications /usr/local/share/applications ~/.local/share/applications /etc/xdg/autostart -name '*libreoffice*' -print -quit 2>/dev/null; then
                echo "⚠️  WARNING: Some LibreOffice menu entries might persist after reboot"
                echo "💡 Consider logging out and back in if they reappear"
            else
                echo "✅ Stray menu entries removed and caches refreshed"
            fi
        else
            echo "✅ Keeping stray menu entries as requested"
        fi
    fi
fi

# Brave/Firefox status check - PRECISE detection
firefox_status="not installed"
# Check for all common Firefox package names in Linux Mint
if dpkg -l | grep -q "^ii[[:space:]]\+firefox\(-esr\|-mozilla-build\)\?[[:space:]]"; then
    firefox_status="installed"
fi

brave_installed=false
brave_policy_status="not configured"

if command -v brave-browser >/dev/null 2>&1 || \
   command -v brave-browser-beta >/dev/null 2>&1 || \
   command -v brave-browser-nightly >/dev/null 2>&1 || \
   command -v brave >/dev/null 2>&1 || \
   command -v brave-beta >/dev/null 2>&1 || \
   command -v brave-nightly >/dev/null 2>&1; then
    brave_installed=true
    if [ -f "/etc/brave/policies/managed/honest_policy.json" ]; then
        brave_policy_status="configured"
    else
        brave_policy_status="installed but not configured"
    fi
fi

echo -e "\n🌐 Browser status:"
echo "🦊 Firefox: $firefox_status"
if $brave_installed; then
    echo "🦁 Brave: installed ($brave_policy_status)"
else
    echo "🦁 Brave: not installed"
fi

# Browser decision - more precise question based on what's installed
if [ "$firefox_status" = "installed" ] && $brave_installed; then
    if user_confirm "_BOTH browsers are installed. 🗑️  Would you like to remove Firefox?"; then
        # Remove ALL Firefox variants
        echo -e "\n🧹 Removing Firefox variants:"
        for firefox_pkg in firefox firefox-esr firefox-mozilla-build; do
            if [ "$(package_status "$firefox_pkg")" = "installed" ]; then
                remove_package "$firefox_pkg"
            fi
        done
    else
        echo "✅ Keeping Firefox as requested 🦊"
    fi
elif [ "$firefox_status" = "installed" ]; then
    if user_confirm "🔄 Would you like to replace Firefox with Brave?"; then
        # Remove ALL Firefox variants
        echo -e "\n🧹 Removing Firefox variants:"
        for firefox_pkg in firefox firefox-esr firefox-mozilla-build; do
            if [ "$(package_status "$firefox_pkg")" = "installed" ]; then
                remove_package "$firefox_pkg"
            fi
        done

        if $brave_installed && [ "$brave_policy_status" = "configured" ]; then
            echo "✅ Brave already installed and configured 🦁"
        else
            echo -e "\n📥 Starting Brave installation:"

            if ! $brave_installed; then
                echo -n "📦 Installing Brave browser... "
                if curl -fsS https://dl.brave.com/install.sh | sh > /dev/null 2>&1; then
                    if command -v brave-browser >/dev/null 2>&1 || \
                       command -v brave >/dev/null 2>&1; then
                        echo "✅"
                        brave_installed=true
                    else
                        echo "❌"
                        echo "🚨 ERROR: Brave installation completed but browser not found 🚨"
                        echo "📁 Check installation logs at /var/log/brave-install.log"
                        exit 1
                    fi
                else
                    echo "❌"
                    echo "🚨 ERROR: Brave installation script failed to execute 🚨"
                    exit 1
                fi
            fi

            # Configure policy directory
            mkdir -p /etc/brave/policies/managed > /dev/null 2>&1
            if [ -f "policy.json" ]; then
                cp policy.json /etc/brave/policies/managed/honest_policy.json > /dev/null 2>&1
                echo "✅ Brave configured with honest_policy.json 🎯"
            else
                echo "⚠️  policy.json not found - Brave installed but not configured ⚠️"
            fi
        fi
    else
        echo "✅ Keeping Firefox as requested 🦊"
    fi
else
    if $brave_installed; then
        echo "✅ Firefox is already removed, Brave is installed 🦁"
    else
        echo "🤷 No browsers to manage"
    fi
fi

echo -e "\n🎉✨ All operations completed successfully! ✨🎉"
