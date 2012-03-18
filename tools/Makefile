QEMU=qemu-system-x86_64
QEMU_MEM_MB=96

GRUB_ARCH=i386

init_files = $(wildcard ../inits/*.bin)
tree_files = ../kernel/kernel.elf $(init_files)

all:	image.iso

clean:
	rm -f image.iso build *~
	rm -rf tree

tree:	$(tree_files) menu.lst
	rm -rf tree
	mkdir -p tree/boot/ost
	cp $(tree_files) tree/boot/ost
	mkdir -p tree/boot/grub
	cp grub/$(GRUB_ARCH)-pc/stage2_eltorito tree/boot/grub
	cp menu.lst tree/boot/grub

image.iso:	tree
	mkisofs -R -b boot/grub/stage2_eltorito \
		-no-emul-boot \
		-boot-load-size 4 \
		-boot-info-table \
		-o image.iso tree

WHOLEDISK=$(shell echo $(PARTITION) | sed -e 's/[0-9]*$$//g')
bootable: tree
	@([ -b "$(PARTITION)" ] && [ -b "$(WHOLEDISK)" ]) || ( \
		echo "------------------------------------------------------------"; \
		echo "Please set PARTITION to one of your available disk partitions."; \
		echo "------------------------------------------------------------"; \
		false)
	mkdir tmp-mountpoint
	sudo mount $(PARTITION) tmp-mountpoint -t vfat -o uid=`id -u`
	@echo "Here's what that partition looks like now:"
	ls -l tmp-mountpoint
	@echo "Last chance to abort before installing using GRUB:"
	@echo " -- PARTITION is $(PARTITION)"
	@echo " -- WHOLEDISK is $(WHOLEDISK)"
	@if [ -n "$(INSTALLGRUB)" ]; then echo " ****** WILL INSTALL GRUB ******"; \
		else echo " -- will not install grub"; fi
	@echo "Press enter to continue, or Ctrl-C to interrupt."
	@read dummy
	rsync -rv tree/. tmp-mountpoint/.
	[ -z "$(INSTALLGRUB)" ] || \
		sudo grub-install --root-directory=`pwd`/tmp-mountpoint $(WHOLEDISK)
	sync
	sync
	sync
	$(MAKE) cleanup-after-bootable

cleanup-after-bootable:
	sudo umount tmp-mountpoint
	rmdir tmp-mountpoint

run:	image.iso
	$(QEMU) -m $(QEMU_MEM_MB) -d int -s -cdrom image.iso -monitor stdio

stoprun: image.iso
	$(QEMU) -m $(QEMU_MEM_MB) -d int -s -S -cdrom image.iso -monitor stdio

