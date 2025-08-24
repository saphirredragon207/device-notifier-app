use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{info, error, warn};
use tracing_subscriber;

mod config;
mod discord;
mod events;
mod security;
mod storage;
mod system;
mod commands;

use config::Config;
use discord::DiscordClient;
use events::EventMonitor;
use security::SecurityManager;
use storage::SecureStorage;
use system::SystemManager;
use commands::CommandExecutor;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize logging
    tracing_subscriber::fmt::init();
    info!("Device Notifier Agent starting...");

    // Load configuration
    let config = Config::load()?;
    info!("Configuration loaded successfully");

    // Check for emergency disable
    if config.is_emergency_disabled() {
        warn!("Emergency disable detected, exiting");
        return Ok(());
    }

    // Initialize secure storage
    let storage = Arc::new(SecureStorage::new()?);
    info!("Secure storage initialized");

    // Initialize security manager
    let security = Arc::new(SecurityManager::new(&config)?);
    info!("Security manager initialized");

    // Initialize Discord client
    let discord = Arc::new(DiscordClient::new(&config)?);
    info!("Discord client initialized");

    // Initialize system manager
    let system = Arc::new(SystemManager::new()?);
    info!("System manager initialized");

    // Initialize command executor
    let executor = Arc::new(CommandExecutor::new(
        system.clone(),
        security.clone(),
        storage.clone(),
    ));
    info!("Command executor initialized");

    // Initialize event monitor
    let event_monitor = Arc::new(EventMonitor::new(
        discord.clone(),
        storage.clone(),
        config.clone(),
    ));
    info!("Event monitor initialized");

    // Start event monitoring
    let event_handle = tokio::spawn({
        let monitor = event_monitor.clone();
        async move {
            if let Err(e) = monitor.start().await {
                error!("Event monitor failed: {}", e);
            }
        }
    });

    // Start command listener
    let command_handle = tokio::spawn({
        let executor = executor.clone();
        let discord = discord.clone();
        async move {
            if let Err(e) = executor.start_listening(discord).await {
                error!("Command listener failed: {}", e);
            }
        }
    });

    // Start heartbeat
    let heartbeat_handle = tokio::spawn({
        let discord = discord.clone();
        let config = config.clone();
        async move {
            loop {
                tokio::time::sleep(tokio::time::Duration::from_secs(300)).await; // 5 minutes
                if let Err(e) = discord.send_heartbeat().await {
                    warn!("Failed to send heartbeat: {}", e);
                }
            }
        }
    });

    info!("Agent started successfully. Waiting for events...");

    // Wait for shutdown signal
    tokio::signal::ctrl_c().await?;
    info!("Shutdown signal received, stopping agent...");

    // Graceful shutdown
    event_handle.abort();
    command_handle.abort();
    heartbeat_handle.abort();

    info!("Agent stopped successfully");
    Ok(())
}
