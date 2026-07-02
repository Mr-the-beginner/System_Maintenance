#!/bin/bash

LOGFILE="$HOME/maintenance-$(date +%F-%H%M%S).log"

exec > >(tee -a "$LOGFILE") 2>&1

echo "=== SYSTEM MAINTENANCE START ==="

# 1. Update package lists
echo "[1] apt-get update"
sudo apt-get update

# 2. Upgrade system
echo "[2] full upgrade"
sudo apt-get full-upgrade -y

# 3. Fix broken installs if any
echo "[3] fix broken installs"
sudo apt-get install --fix-broken -y

# 4. Ensure dpkg consistency
echo "[4] configure pending packages"
sudo dpkg --configure -a

# 5. Remove unused dependencies
echo "[5] autoremove"
sudo apt-get autoremove --purge -y

# 6. Clean APT cache
echo "[6] clean apt cache"
sudo apt-get clean

# 7. Purge leftover rc packages (safe guarded)
echo "[7] purge rc leftovers"
RC_PKGS=$(dpkg -l | awk '/^rc/ {print $2}')

if [ -n "$RC_PKGS" ]; then
    echo "$RC_PKGS" | xargs -r sudo dpkg --purge
else
    echo "No rc packages found"
fi

# 8. User cache cleanup
echo "[8] user cache cleanup"
rm -rf "$HOME/.cache/"*

# 9. Optional log trimming
echo "[9] journal cleanup (7 days)"
sudo journalctl --vacuum-time=7d

echo "=== MAINTENANCE COMPLETE ==="
echo "Log saved to: $LOGFILE"
