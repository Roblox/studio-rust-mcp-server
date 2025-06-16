use color_eyre::eyre::{eyre, Result, WrapErr};
use roblox_install::RobloxStudio;
use serde_json::{json, Value};
use std::fs::File;
use std::io::BufReader;
use std::io::Write;
use std::path::Path;
use std::path::PathBuf;
use std::{env, fs, io};

// Original get_message, renamed:
fn get_message_claude_cursor(successes: String) -> String {
    format!(
        "Roblox Studio MCP is ready to go for integration with configured AI clients.
        Please restart Studio and any MCP clients (like Claude/Cursor) to apply the changes.

        MCP Clients successfully configured:
        {}

        Note: Connecting a third-party LLM to Roblox Studio via an MCP server will share your data with that external service provider. \
        Please review their privacy practices carefully before proceeding.
        To uninstall, delete MCPStudioPlugin.rbxm from your Plugins directory and remove entries from client configurations.",
        successes
    )
}

// New message function for gemini_python_broker mode:
fn get_message_gemini_python_broker() -> String {
    format!(
        "Roblox Studio MCP (Gemini Python Broker Mode) is set up!
        The necessary Roblox Studio plugin (MCPStudioPlugin.rbxm) has been installed.

        To use the Gemini AI capabilities with Roblox Studio:
        1. Ensure you have Python installed.
        2. Run the `setup_venv.bat` script once to create a Python virtual environment and install dependencies.
        3. Use the `run_agent.bat` script to start the Python-based Gemini agent.
        4. The `run_rust_server.bat` script can be used to start the MCP server that communicates with Roblox Studio (if not already started by another process or if you need to run it manually).

        The Python agent will connect to this MCP server to interact with Roblox Studio.
        To uninstall, delete MCPStudioPlugin.rbxm from your Plugins directory."
    )
}

// returns OS dependant claude_desktop_config.json path
fn get_claude_config() -> Result<PathBuf> {
    let home_dir = env::var_os("HOME");

    let config_path = if cfg!(target_os = "macos") {
        Path::new(&home_dir.unwrap())
            .join("Library/Application Support/Claude/claude_desktop_config.json")
    } else if cfg!(target_os = "windows") {
        let app_data =
            env::var_os("APPDATA").ok_or_else(|| eyre!("Could not find APPDATA directory"))?;
        Path::new(&app_data)
            .join("Claude")
            .join("claude_desktop_config.json")
    } else {
        return Err(eyre!("Unsupported operating system"));
    };

    Ok(config_path)
}

fn get_cursor_config() -> Result<PathBuf> {
    let home_dir = env::var_os("HOME")
        .or_else(|| env::var_os("USERPROFILE"))
        .unwrap();
    Ok(Path::new(&home_dir).join(".cursor").join("mcp.json"))
}

#[cfg(target_os = "macos")]
fn get_exe_path() -> Result<PathBuf> {
    use core_foundation::url::CFURL;

    let local_path = env::current_exe()?;
    let local_path_cref = CFURL::from_path(local_path, false).unwrap();
    let un_relocated = security_translocate::create_original_path_for_url(local_path_cref.clone())
        .or_else(move |_| Ok::<CFURL, io::Error>(local_path_cref.clone()))?;
    let ret = un_relocated.to_path().unwrap();
    Ok(ret)
}

#[cfg(not(target_os = "macos"))]
fn get_exe_path() -> io::Result<PathBuf> {
    env::current_exe()
}

pub fn install_to_config<'a>(
    config_path: Result<PathBuf>,
    exe_path: &Path,
    name: &'a str,
) -> Result<&'a str> {
    let config_path = config_path?;

    // 1. Ensure parent directory exists
    if let Some(parent_dir) = config_path.parent() {
        if !parent_dir.exists() {
            fs::create_dir_all(parent_dir).map_err(|e| {
                eyre!("Could not create parent directory {parent_dir:?} for {name} config: {e:#?}", parent_dir = parent_dir.display(), name = name)
            })?;
            println!("INFO: Created parent directory {} for {} configuration.", parent_dir.display(), name);
        }
    }

    let mut config: serde_json::Map<String, Value> = {
        if !config_path.exists() {
            let mut file = File::create(&config_path).map_err(|e| {
                eyre!("Could not create {name} config file at {config_path}: {e:#?}", config_path = config_path.display(), name = name)
            })?;
            // Initialize with an empty JSON object {}
            file.write_all(serde_json::to_string(&serde_json::Map::new())?.as_bytes())?;
            println!("INFO: Created empty config file for {} at {}.", name, config_path.display());
        }

        let config_file = File::open(&config_path)
            .map_err(|error| eyre!("Could not open {name} config file at {config_path}: {error:#?}", name = name, config_path = config_path.display()))?;
        let reader = BufReader::new(config_file);

        // 2. Enhance JSON parsing error context
        serde_json::from_reader(reader).map_err(|e| {
            eyre!("Could not parse JSON from {name} config file at {config_path}: {e:#?}", name = name, config_path = config_path.display())
        })?
    };

    if !matches!(config.get("mcpServers"), Some(Value::Object(_))) {
        config.insert("mcpServers".to_string(), json!({}));
    }

    config["mcpServers"]["Roblox Studio"] = json!({
      "command": exe_path, // Corrected: exe_path is already &Path
      "args": [
        "--stdio"
      ]
    });

    // Re-open for writing (truncate) - this also benefits from parent dir creation
    let mut file = File::create(&config_path).map_err(|e| {
        eyre!("Could not open {name} config file for writing at {config_path}: {e:#?}", name = name, config_path = config_path.display())
    })?;
    file.write_all(serde_json::to_string_pretty(&config)?.as_bytes())
        .map_err(|e| eyre!("Could not write to {name} config file at {config_path}: {e:#?}", name = name, config_path = config_path.display()))?;

    // 3. Update success println message
    println!("INFO: Successfully configured {} to use this Roblox Studio MCP server. Details in {}.", name, config_path.display());

    Ok(name)
}

async fn install_internal() -> Result<String> {
    // Part 1: Install MCPStudioPlugin.rbxm (Always runs)
    let plugin_bytes = include_bytes!(concat!(env!("OUT_DIR"), "/MCPStudioPlugin.rbxm"));
    let studio = RobloxStudio::locate()?;
    let plugins_dir_path = studio.plugins_path(); // Renamed for clarity from 'plugins'
    if let Err(err) = fs::create_dir_all(&plugins_dir_path) { // Ensure parent dir for plugins exists
        // Note: create_dir_all doesn't error if path already exists and is a directory.
        // We only need to check if it's NOT ErrorKind::AlreadyExists if we were using fs::create_dir
        // For create_dir_all, any error is problematic.
        return Err(err).wrap_err("Failed to create Roblox Studio plugins directory");
    }
    let output_plugin_path = plugins_dir_path.join("MCPStudioPlugin.rbxm"); // Renamed for clarity
    {
        let mut file = File::create(&output_plugin_path).wrap_err_with(|| {
            format!(
                "Could not write Roblox Plugin file at {}",
                output_plugin_path.display()
            )
        })?;
        file.write_all(plugin_bytes)?;
    }
    println!(
        "INFO: Installed Roblox Studio plugin to {}",
        output_plugin_path.display()
    );

    // Part 2: Conditional Logic based on feature flag
    #[cfg(not(feature = "gemini_python_broker"))]
    {
        // Original logic for Claude/Cursor integration
        let this_exe = get_exe_path()?;
        let mut errors = vec![];
        let results = vec![
            install_to_config(get_claude_config(), &this_exe, "Claude"),
            install_to_config(get_cursor_config(), &this_exe, "Cursor"),
        ];
        let successes: Vec<_> = results
            .into_iter()
            .filter_map(|r| r.map_err(|e| errors.push(e)).ok())
            .collect();

        if successes.is_empty() {
            let error_detail = errors.into_iter().fold(
                eyre!("Failed to configure integration for either Claude or Cursor."),
                |report, e| report.note(e),
            );
            return Err(error_detail.wrap_err("MCP Server setup for external AI tools failed"));
        }

        println!();
        let msg = get_message_claude_cursor(successes.join("\n"));
        println!("{}", msg);
        Ok(msg)
    }

    #[cfg(feature = "gemini_python_broker")]
    {
        // New logic for Gemini Python Broker mode
        println!();
        let msg = get_message_gemini_python_broker();
        println!("{}", msg);
        Ok(msg)
    }
}

#[cfg(target_os = "windows")]
pub async fn install() -> Result<()> {
    use std::process::Command;
    if let Err(e) = install_internal().await {
        tracing::error!("Failed initialize Roblox MCP: {:#}", e);
    }
    let _ = Command::new("cmd.exe").arg("/c").arg("pause").status();
    Ok(())
}

#[cfg(target_os = "macos")]
pub async fn install() -> Result<()> {
    use native_dialog::{DialogBuilder, MessageLevel};
    let alert_builder = match install_internal().await {
        Err(e) => DialogBuilder::message()
            .set_level(MessageLevel::Error)
            .set_text(format!("Errors occurred: {:#}", e)),
        Ok(msg) => DialogBuilder::message()
            .set_level(MessageLevel::Info)
            .set_text(msg),
    };
    let _ = alert_builder.set_title("Roblox Studio MCP").alert().show();
    Ok(())
}

#[cfg(not(any(target_os = "macos", target_os = "windows")))]
pub async fn install() -> Result<()> {
    install_internal().await?;
    Ok(())
}
