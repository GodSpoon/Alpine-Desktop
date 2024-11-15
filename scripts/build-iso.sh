#!/bin/bash
set -e

# Read configuration
source config/alpine-desktop.conf

# Create work directory
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# Download Alpine Linux minimal ISO
wget "https://dl-cdn.alpinelinux.org/alpine/v$(echo $ALPINE_VERSION | cut -d'.' -f1-2)/releases/x86_64/alpine-standard-$ALPINE_VERSION-x86_64.iso" -O "$WORK_DIR/base.iso"

# Mount the ISO
mkdir -p "$WORK_DIR/iso"
sudo mount -o loop "$WORK_DIR/base.iso" "$WORK_DIR/iso"

# Create new ISO structure
mkdir -p "$WORK_DIR/new_iso"
cp -a "$WORK_DIR/iso/"* "$WORK_DIR/new_iso/"

# Modify isolinux configuration
cat > "$WORK_DIR/new_iso/boot/syslinux/syslinux.cfg" << EOF
TIMEOUT 20
PROMPT 1
DEFAULT desktop

LABEL desktop
    MENU LABEL Alpine Linux Desktop
    KERNEL /boot/vmlinuz-lts
    APPEND initrd=/boot/initramfs-lts root=live:CDLABEL=Alpine modules=loop,squashfs quiet $KERNEL_PARAMS
EOF

# Create custom answer file
cat > "$WORK_DIR/new_iso/answer.cfg" << EOF
KEYMAPOPTS="$KEYMAP"
HOSTNAMEOPTS="-n $HOSTNAME"
INTERFACESOPTS="auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
    hostname $HOSTNAME"
TIMEZONEOPTS="-z $TIMEZONE"
PROXYOPTS="none"
APKREPOSOPTS="-1"
SSHDOPTS="-c openssh"
NTPOPTS="-c chrony"
DISKOPTS="-m sys /dev/sda"
EOF

# Create package list
echo "$PACKAGES" > "$WORK_DIR/new_iso/packages.txt"

# Create new ISO
xorriso -as mkisofs \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -c boot/syslinux/boot.cat \
    -b boot/syslinux/isolinux.bin \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -eltorito-alt-boot \
    -o "build/alpine-desktop-$ALPINE_VERSION.iso" \
    "$WORK_DIR/new_iso"

# Cleanup
sudo umount "$WORK_DIR/iso"
