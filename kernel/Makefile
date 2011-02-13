CFLAGS = -m64 -Wall -Wno-multichar \
	-ffreestanding -nostdlib \
	-mno-red-zone -mno-mmx -mno-sse -mno-sse2 -mno-sse3 -mno-3dnow \
	-I../include -g -O0
ASFLAGS = $(CFLAGS)
LFLAGS = -melf_i386 -T kernel.script -g # -r

objs =	start.o

all:	kernel.elf

clean:
	rm -f kernel.elf *.o *~

kernel.elf: $(objs)
	$(LD) $(LFLAGS) -o $@ $(objs)
