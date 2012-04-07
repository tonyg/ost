all: image

clean:
	rm -f *~
	find include -name '*~' -exec rm -f '{}' ';'
	$(MAKE) -C kernel clean
	$(MAKE) -C tools clean

image:
	$(MAKE) -C kernel
	$(MAKE) -C tools image.iso

bootable: image
	$(MAKE) -C tools bootable PARTITION=$(PARTITION)

run:	image
	$(MAKE) -C tools run

stoprun: image
	$(MAKE) -C tools stoprun
