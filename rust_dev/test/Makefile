# Tell the kernel build system to build rust_test.o
obj-m := rust_test.o

KDIR ?= /tmp/linux-v6.8

all:
	$(MAKE) LLVM=1 -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) LLVM=1 -C $(KDIR) M=$(PWD) clean
