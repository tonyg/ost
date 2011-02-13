all: image

clean:
	rm -f *~
	find include -name '*~' -exec rm -f '{}' ';'
	make -C kernel clean
	make -C tools clean

image:
	make -C kernel
	make -C tools image.iso

bootable: image
	make -C tools bootable PARTITION=$(PARTITION)

run:	image
	make -C tools run

stoprun: image
	make -C tools stoprun
