# note: kernel.rel has to be first in the list!
OBJS		  = kernel.rel \
		    putchar.rel

CFLAGS		  = --std-sdcc99 -mz80

all: kernel.ihx

kernel.ihx: $(OBJS) Makefile
	sdcc $(CFLAGS) $(OBJS)

%.rel: %.c Makefile
	sdcc $(CFLAGS) -c $<

clean:
	rm -rf *.lst
	rm -rf *.sym
	rm -rf *.rel
	rm -rf $(OBJS:.rel=.asm)
	rm -rf $(OBJS:.rel=.rst)
	rm -rf kernel.map
	rm -rf kernel.mem
	rm -rf kernel.ihx
	rm -rf kernel.lk
	rm -rf kernel.noi
