obj-m := test_module.o

#KDIR ?= /tmp/linux-v6.14
KDIR ?= /lib/modules/6.14.0-37-generic/build

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
