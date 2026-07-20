#include <linux/init.h>
#include <linux/module.h>
#include <linux/kernel.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Ubuntu Tester");
MODULE_DESCRIPTION("A Simple C Kernel Module for Testing");
MODULE_VERSION("1.0");

static int __init test_module_init(void) {
    printk(KERN_INFO "==== TEST MODULE: Successfully loaded into the kernel! ====\n");
    return 0;
}

static void __exit test_module_exit(void) {
    printk(KERN_INFO "==== TEST MODULE: Successfully unloaded from the kernel! ====\n");
}

module_init(test_module_init);
module_exit(test_module_exit);