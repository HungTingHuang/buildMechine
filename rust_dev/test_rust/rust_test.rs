//! Simple Linux kernel Rust test module.

use kernel::prelude::*;

// Declare module metadata, equivalent to MODULE_LICENSE and MODULE_AUTHOR in C
module! {
    type: RustTestModule,
    name: "rust_test",
    author: "Linux Developer",
    description: "My first Linux kernel module written in Rust",
    license: "GPL",
}

struct RustTestModule;

// Implement kernel::Module trait to define initialization and exit behaviors
impl kernel::Module for RustTestModule {
    /// Initialization function executed when the module is loaded (equivalent to C's __init)
    fn init(_module: &'static ThisModule) -> Result<Self> {
        pr_info!("========================================\n");
        pr_info!("Hello! This Linux kernel module is written in Rust!\n");
        pr_info!("========================================\n");
        
        Ok(RustTestModule)
    }
}

/// Cleanup function executed when the module is unloaded (equivalent to C's __exit)
impl Drop for RustTestModule {
    fn drop(&mut self) {
        pr_info!("Goodbye! Rust kernel module unloaded successfully!\n");
    }
}