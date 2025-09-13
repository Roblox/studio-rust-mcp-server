fn main() {
    // Only build the plugin if rojo is available
    #[cfg(feature = "roblox-integration")]
    {
        use librojo::cli;

        let out_dir = std::env::var_os("OUT_DIR").unwrap();
        let dest_path = std::path::PathBuf::from(&out_dir).join("MCPStudioPlugin.rbxm");
        eprintln!("Rebuilding plugin: {dest_path:?}");
        let options = cli::Options {
            global: cli::GlobalOptions {
                verbosity: 1,
                color: cli::ColorChoice::Always,
            },
            subcommand: cli::Subcommand::Build(cli::BuildCommand {
                project: std::path::PathBuf::from("plugin"),
                output: Some(dest_path),
                plugin: None,
                watch: false,
            }),
        };
        options.run().unwrap();
        println!("cargo:rerun-if-changed=plugin");
    }

    #[cfg(not(feature = "roblox-integration"))]
    {
        println!("cargo:warning=Roblox integration disabled - plugin will not be built");
    }
}
