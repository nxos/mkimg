#! /bin/sh

# Prepare the root filesystem.

mkdir -p filesystem

wget -q http://cdimage.ubuntu.com/ubuntu-base/bionic/daily/current/bionic-base-amd64.tar.gz
tar xf *.tar.gz -C filesystem


# Run a command in a chroot safely.

FS_DIR=filesystem

rm -rf $FS_DIR/dev/*
cp /etc/resolv.conf filesystem/etc

mount -t proc none $FS_DIR/proc || exit 1
mount -t devtmpfs none $FS_DIR/dev || exit 1

mkdir -p /dev/pts
mount -t devpts none $FS_DIR/dev/pts || exit 1

cp ./config/config.sh $FS_DIR
chroot $FS_DIR/ sh -c "/config.sh"
rm -r $FS_DIR/config.sh

umount -f $FS_DIR/dev/pts
umount -f $FS_DIR/dev
umount -f $FS_DIR/proc

cp $FS_DIR/vmlinuz iso/boot/kernel
cp $FS_DIR/initrd.img iso/boot/initramfs


# Clean the filesystem.

rm -rf $FS_DIR/tmp/* \
	$FS_DIR/boot \
	$FS_DIR/vmlinuz* \
	$FS_DIR/initrd.img* \
	$FS_DIR/var/log/* \
	$FS_DIR/var/lib/dbus/machine-id


# Compress the root filesystem.

(sleep 300; echo +) &
echo "Compressing the root filesystem"
mkdir -p iso/casper
mksquashfs $FS_DIR iso/casper/filesystem.squashfs -comp xz -no-progress


# Prepare the ISO filesystem tree.

wget -q -nc https://www.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.xz
tar xf syslinux-6.03.tar.xz

SL=syslinux-6.03
cp $SL/bios/core/isolinux.bin \
	$SL/bios/mbr/isohdpfx.bin \
	$SL/bios/com32/menu/menu.c32 \
	$SL/bios/com32/lib/libcom32.c32 \
	$SL/bios/com32/menu/vesamenu.c32 \
	$SL/bios/com32/libutil/libutil.c32 \
	$SL/bios/com32/elflink/ldlinux/ldlinux.c32 \
	iso/boot/isolinux

mkdir -p iso/efi/boot
grub-mkimage -C xz -O x86_64-efi -o iso/efi/boot/bootx64.efi -p /boot/grub \
	boot linux search normal configfile \
	part_gpt btrfs fat iso9660 loopback \
	test keystatus gfxmenu regexp probe \
	efi_gop efi_uga all_video gfxterm font \
	echo read help ls cat png jpeg halt reboot

git clone https://github.com/nomad-desktop/isolinux-theme-nomad --depth=1
git clone https://github.com/nomad-desktop/nomad-grub-theme --depth=1

cp nomad-grub-theme/nomad/* iso/boot/grub
cp isolinux-theme-nomad/* iso/boot/isolinux


# Create the ISO image.

cd iso

echo -n $(du -sx --block-size=1 . | tail -n 1 | awk '{ print $1 }') > casper/filesystem.size

xorriso -as mkisofs \
	-iso-level 3 \
	-full-iso9660-filenames \
	-volid "Nitrux_testing" \
	-appid "-" \
	-publisher "Nitrux Latinoamericana." \
	-preparer "mkiso" \
	-eltorito-boot boot/isolinux/isolinux.bin \
	-eltorito-catalog boot/isolinux/boot.cat \
	-boot-load-size 4 \
	-boot-info-table \
	-isohybrid-mbr boot/isolinux/isohdpfx.bin \
	-eltorito-alt-boot \
	-e efi/boot/bootx64.efi \
	-no-emul-boot \
	-isohybrid-gpt-basdat \
	-output ../nitrux_testing.iso ./

cd ..

zsyncmake nitrux_testing.iso
echo "zsync|http://server.domain/path/your.iso.zsync" | dd of=nitrux_testing.iso bs=1 seek=33651 count=512 conv=notrunc
