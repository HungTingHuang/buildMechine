obj-m := rust_test.o

KDIR ?= /tmp/linux-v6.14

all:
	$(MAKE) LLVM=1 -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) LLVM=1 -C $(KDIR) M=$(PWD) clean
