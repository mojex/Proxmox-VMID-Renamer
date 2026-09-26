#!/usr/bin/env bash
# ==============================================================================
# Script Name: pve-rename-vmid.sh (Universal Storage Backend Version)
# Author: mojex
# ==============================================================================

set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo -e "\033[1;33mUsage:\033[0m $0 <OLD_ID> <NEW_ID>"
    exit 1
fi

OLD_ID="$1"
NEW_ID="$2"

if ! [[ "$OLD_ID" =~ ^[0-9]+$ ]] || ! [[ "$NEW_ID" =~ ^[0-9]+$ ]]; then
    echo -e "\033[1;31m[ERROR]\033[0m Both IDs must be numeric."
    exit 1
fi

if [ -f "/etc/pve/qemu-server/${OLD_ID}.conf" ]; then
    CONF_DIR="/etc/pve/qemu-server"
    TYPE="qemu"
elif [ -f "/etc/pve/lxc/${OLD_ID}.conf" ]; then
    CONF_DIR="/etc/pve/lxc"
    TYPE="lxc"
else
    echo -e "\033[1;31m[ERROR]\033[0m Machine with ID ${OLD_ID} does not exist!"
    exit 1
fi

if [ -f "/etc/pve/qemu-server/${NEW_ID}.conf" ] || [ -f "/etc/pve/lxc/${NEW_ID}.conf" ]; then
    echo -e "\033[1;31m[ERROR]\033[0m Target ID ${NEW_ID} already exists!"
    exit 1
fi

if [ "$TYPE" == "qemu" ]; then
    STATUS=$(qm status "$OLD_ID" 2>/dev/null | awk '{print $2}')
    if [ "$STATUS" != "stopped" ]; then
        echo -e "\033[1;31m[ERROR]\033[0m VM ${OLD_ID} is ${STATUS}! Stop it first (qm stop ${OLD_ID})."
        exit 1
    fi
else
    STATUS=$(pct status "$OLD_ID" 2>/dev/null | awk '{print $2}')
    if [ "$STATUS" != "stopped" ]; then
        echo -e "\033[1;31m[ERROR]\033[0m Container ${OLD_ID} is ${STATUS}! Stop it first (pct stop ${OLD_ID})."
        exit 1
    fi
fi

echo -e "\033[1;34m[*] Found ${TYPE^^} ${OLD_ID}. Renaming to ${NEW_ID}...\033[0m"

OLD_CONF="${CONF_DIR}/${OLD_ID}.conf"
NEW_CONF="${CONF_DIR}/${NEW_ID}.conf"

cp "$OLD_CONF" "/tmp/${OLD_ID}.conf.bak"
cp "$OLD_CONF" "$NEW_CONF"


VOLUMES=$(grep -oE '[a-zA-Z0-9_\-]+:(vm|subvol)-'"${OLD_ID}"'-[a-zA-Z0-9_\.\-]+' "$OLD_CONF" | sort -u || true)

for FULL_VOL in $VOLUMES; do
    STORAGE=$(echo "$FULL_VOL" | cut -d':' -f1)
    VOL_NAME=$(echo "$FULL_VOL" | cut -d':' -f2)
    NEW_VOL_NAME=$(echo "$VOL_NAME" | sed "s/-${OLD_ID}-/-${NEW_ID}-/")
    NEW_FULL_VOL="${STORAGE}:${NEW_VOL_NAME}"

    echo -e "\033[1;36m  -> Renaming [${STORAGE}]: ${VOL_NAME} -> ${NEW_VOL_NAME}\033[0m"


    REAL_PATH=$(pvesm path "$FULL_VOL")
    

    if [[ "$REAL_PATH" =~ ^/dev/ ]]; then
        VG_NAME=$(lvs --noheadings -o vg_name "$REAL_PATH" | tr -d '[:space:]')
        lvrename "$VG_NAME" "$VOL_NAME" "$NEW_VOL_NAME"

    elif zfs list "$REAL_PATH" &>/dev/null; then
        ZPOOL_DATA=$(echo "$REAL_PATH" | sed 's|^/dev/zvol/||')
        NEW_ZFS_PATH=$(echo "$ZPOOL_DATA" | sed "s/-${OLD_ID}-/-${NEW_ID}-/")
        zfs rename "$ZPOOL_DATA" "$NEW_ZFS_PATH"

    elif [ -f "$REAL_PATH" ]; then
        PARENT_DIR=$(dirname "$REAL_PATH")
        
        if [[ "$PARENT_DIR" =~ /${OLD_ID}$ ]]; then
            NEW_DIR=$(echo "$PARENT_DIR" | sed "s|/${OLD_ID}$|/${NEW_ID}|")
            mkdir -p "$NEW_DIR"
            mv "$REAL_PATH" "${NEW_DIR}/${NEW_VOL_NAME}"
            rmdir "$PARENT_DIR" 2>/dev/null || true
        else
            mv "$REAL_PATH" "${PARENT_DIR}/${NEW_VOL_NAME}"
        fi
    else
        echo -e "\033[1;31m  [!] Warning: Unknown backend for ${REAL_PATH}. Rename it manually.\033[0m"
    fi

      sed -i "s|${FULL_VOL}|${NEW_FULL_VOL}|g" "$NEW_CONF"
done

sed -i "s/\b${OLD_ID}\b/${NEW_ID}/g" "$NEW_CONF"

rm -f "$OLD_CONF"

echo -e "\033[1;32m[+] Successfully migrated ${OLD_ID} -> ${NEW_ID}!\033[0m"
