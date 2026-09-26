
# Proxmox VMID Renamer

Stop playing Tetris with your VMIDs! This script provides a safe, reliable, and automated way to rename (re-ID) your Proxmox Virtual Machines (QEMU) and Containers (LXC) in-place.

Proxmox VE lacks a native "Rename VMID" feature. While manual renaming involves hacking config files and storage backends, this script handles everything—from storage backend renaming (LVM, ZFS, directory) to configuration file updates—all in one command.

## Features
- **Universal Storage Support:** Automatically detects and renames volumes on LVM, LVM-Thin, ZFS, and file-based (directory/NFS/qcow2) storage backends.
- **Smart Detection:** Automatically distinguishes between QEMU VMs and LXC Containers.
- **Safety First:** Performs checks to ensure the machine is stopped, the target ID is available, and configuration files are valid.
- **Config Migration:** Automatically updates configuration references, including disks, snapshots, and other machine settings.

## Prerequisites
- Proxmox VE (Debian-based environment).
- Root access (required for `lvrename`, `zfs`, and editing `/etc/pve/`).

## Installation

1. Create the script file on your Proxmox node:
   ```bash
   nano /usr/local/bin/pve-rename-vmid.sh
   ```
2. Paste the script content from this repository.
3. Make it executable:
   ```bash
   chmod +x /usr/local/bin/pve-rename-vmid.sh
   ```

## Usage

Run the script with the current VMID and the new desired VMID:

```bash
pve-rename-vmid.sh <OLD_ID> <NEW_ID>
```

**Example:**
To rename VM ID `107` to `300`:
```bash
pve-rename-vmid.sh 107 300
```

## How It Works
1. **Validation:** Checks if the machine exists and is currently `stopped`.
2. **Backups:** Creates a safety backup of the configuration file in `/tmp/`.
3. **Storage Renaming:**
   - **LVM:** Uses `lvrename`.
   - **ZFS:** Uses `zfs rename`.
   - **File-based:** Uses `mv` to update file paths and directories.
4. **Configuration Update:** Rewrites the `.conf` file to point to the new volume names and updates any internal references.
5. **Finalization:** Removes the old configuration file to finalize the rename in the Proxmox cluster.

> **⚠️ CRITICAL WARNING: ALWAYS BACKUP!**
> While this script has been tested and includes safety checks, **always** ensure you have a backup of your VM configuration and data before performing operations that modify storage and configuration files. Use at your own risk.

## Contributing
Feedback, bug reports, and pull requests are welcome! If you encounter an edge case with a specific storage backend (e.g., Ceph RBD), feel free to open an issue.

---
*Created with passion for the Homelab community.*
