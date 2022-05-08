ARCH := arm
obj-m := zed_io.o
PWD := $(shell pwd)
export
default:
	$(MAKE) -C $(KERNEL) M=$(PWD) modules
clean:
	$(MAKE) -C $(KERNEL) M=$(PWD) clean
