use color_eyre::eyre::{eyre, Result, WrapErr};
use color_eyre::Help;
use roblox_install::RobloxStudio;
use serde_json::{json, Value};
use std::fs::File;
use std::io::BufReader;
use std::io::Write;
use std::path::Path;
use std::path::PathBuf;
use std::vec;
use std::{env, fs, io};

fn get_message(successes: String) -> String {
    format!("Roblox Studio MCP is ready to go.
Please restart Studio and MCP clients to apply the changes.

Tools included:
- run_code
- insert_model
- get_console_output
- start_stop_play
- run_script_in_play_mode
- get_studio_mode

MCP Clients set up:
{successes}

Note: connecting a third-party LLM to Roblox Studio via an MCP server will share your data with that external service provider. Please review their privacy practices carefully before proceeding.
To uninstall, delete the MCPStudioPlugin.rbxm from your Plugins directory.")
}

// returns OS dependant claude_desktop_config.json path
fn get_claude_config() -> Vec<PathBuf> {
    let mut paths = Vec::new();

    if cfg!(target_os = "macos") {
        if let Some(home_dir) = env::var_os("HOME") {
            paths.push(
                Path::new(&home_dir)
                    .join("Library")
                    .join("Application Support")
                    .join("Claude")
                    .join("claude_desktop_config.json"),
            );
        }
    } else if cfg!(target_os = "windows") {
        if let Some(app_data) = env::var_os("APPDATA") {
            paths.push(
                Path::new(&app_data)
                    .join("Claude")
                    .join("claude_desktop_config.json"),
            );
        }
        if let Some(local_app_data) = env::var_os("LOCALAPPDATA") {
            let packages_dir = Path::new(&local_app_data).join("Packages");
            if let Ok(entries) = fs::read_dir(&packages_dir) {
                for entry in entries.flatten() {
                    if let Some(name) = entry.file_name().to_str() {
                        if name.starts_with("Claude_") {
                            paths.push(
                                entry
                                    .path()
                                    .join("LocalCache")
                                    .join("Roaming")
                                    .join("Claude")
                                    .join("claude_desktop_config.json"),
                            );
                        }
                    }
                }
            }
        }
    }

    paths
}

fn get_cursor_config() -> Vec<PathBuf> {
    let mut paths = Vec::new();
    if let Some(home_dir) = env::var_os("HOME").or_else(|| env::var_os("USERPROFILE")) {
        paths.push(Path::new(&home_dir).join(".cursor").join("mcp.json"));
    }
    paths
}

fn get_antigravity_config() -> Vec<PathBuf> {
    let mut paths = Vec::new();
    if let Some(home_dir) = env::var_os("HOME").or_else(|| env::var_os("USERPROFILE")) {
        paths.push(
            Path::new(&home_dir)
                .join(".gemini")
                .join("antigravity")
                .join("mcp_config.json"),
        );
    }
    paths
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

pub fn suggest_to_config_claude_code(exe_path: &Path) -> Result<String> {
    let home_dir = env::var_os("HOME")
        .or_else(|| env::var_os("USERPROFILE"))
        .unwrap();
    let config_path = Path::new(&home_dir).join(".claude.json");

    if config_path.exists() {
        Ok(format!("To add the MCP to Claude Code CLI run:\nclaude mcp add --transport stdio Roblox_Studio -- '{}' --stdio", exe_path.display()))
    } else {
        Err(eyre!("No config file found"))
    }
}

pub fn install_to_config(
    config_paths: Vec<PathBuf>,
    exe_path: &Path,
    name: &str,
) -> Result<String> {
    if config_paths.is_empty() {
        return Err(eyre!("No config paths found for {name}"));
    }

    // Filter to paths whose parent directory exists
    let valid_paths: Vec<_> = config_paths
        .into_iter()
        .filter(|p| p.parent().is_some_and(|dir| dir.exists()))
        .collect();

    if valid_paths.is_empty() {
        return Err(eyre!("No valid config directories found for {name}"));
    }

    for config_path in &valid_paths {
        let mut config: serde_json::Map<String, Value> = {
            if !config_path.exists() {
                let mut file = File::create(config_path).map_err(|e| {
                    eyre!("Could not create {name} config file at {config_path:?}: {e:#?}")
                })?;
                file.write_all(serde_json::to_string(&serde_json::Map::new())?.as_bytes())?;
            }
            let config_file = File::open(config_path).map_err(|error| {
                eyre!("Could not read or create {name} config file: {error:#?}")
            })?;
            let reader = BufReader::new(config_file);
            serde_json::from_reader(reader).unwrap_or(serde_json::Map::new())
        };

        if !matches!(config.get("mcpServers"), Some(Value::Object(_))) {
            config.insert("mcpServers".to_string(), json!({}));
        }

        // Remove old key if it exists
        if let Some(Value::Object(mcp_servers)) = config.get_mut("mcpServers") {
            mcp_servers.remove("Roblox Studio");
        }

        config["mcpServers"]["Roblox_Studio"] = json!({
          "command": &exe_path,
          "args": [
            "--stdio"
          ]
        });

        let mut file = File::create(config_path)?;
        file.write_all(serde_json::to_string_pretty(&config)?.as_bytes())
            .map_err(|e| {
                eyre!("Could not write to {name} config file at {config_path:?}: {e:#?}")
            })?;

        println!("Installed MCP Studio plugin to {name} config {config_path:?}");
    }

    Ok(name.to_string())
}

async fn install_internal() -> Result<String> {
    let plugin_bytes = include_bytes!(concat!(env!("OUT_DIR"), "/MCPStudioPlugin.rbxm"));
    let studio = RobloxStudio::locate()?;
    let plugins = studio.plugins_path();
    if let Err(err) = fs::create_dir(plugins) {
        if err.kind() != io::ErrorKind::AlreadyExists {
            return Err(err.into());
        }
    }
    let output_plugin = Path::new(&plugins).join("MCPStudioPlugin.rbxm");
    {
        let mut file = File::create(&output_plugin).wrap_err_with(|| {
            format!(
                "Could write Roblox Plugin file at {}",
                output_plugin.display()
            )
        })?;
        file.write_all(plugin_bytes)?;
    }
    println!(
        "Installed Roblox Studio plugin to {}",
        output_plugin.display()
    );

    let this_exe = get_exe_path()?;

    let mut errors = vec![];
    let results = vec![
        install_to_config(get_claude_config(), &this_exe, "Claude"),
        install_to_config(get_cursor_config(), &this_exe, "Cursor"),
        install_to_config(get_antigravity_config(), &this_exe, "Antigravity"),
        suggest_to_config_claude_code(&this_exe),
    ];

    let successes: Vec<_> = results
        .into_iter()
        .filter_map(|r| r.map_err(|e| errors.push(e)).ok())
        .collect();

    if successes.is_empty() {
        let error = errors.into_iter().fold(
            eyre!("\nFailed to automatically set up, please use manual instructions.\n"),
            |report, e| report.note(e),
        );
        return Err(error);
    }

    println!();
    let msg = get_message(successes.join("\n"));
    println!("{msg}");
    Ok(msg)
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
            .set_text(format!("Errors occurred: {e:#}")),
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
