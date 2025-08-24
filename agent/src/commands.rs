use crate::config::Config;
use crate::discord::{DiscordClient, DiscordCommand, CommandResponse, CommandType};
use crate::system::SystemManager;
use crate::security::SecurityManager;
use crate::storage::SecureStorage;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{info, warn, error, debug};
use chrono::{DateTime, Utc};
use std::collections::HashMap;
use std::time::{Duration, Instant};

pub struct CommandExecutor {
    system: Arc<SystemManager>,
    security: Arc<SecurityManager>,
    storage: Arc<SecureStorage>,
    command_history: Arc<RwLock<HashMap<String, CommandHistoryEntry>>>,
    rate_limiter: Arc<RwLock<RateLimiter>>,
}

#[derive(Debug, Clone)]
struct CommandHistoryEntry {
    command_id: String,
    command_type: CommandType,
    authorized_user: String,
    timestamp: DateTime<Utc>,
    success: bool,
    details: String,
}

struct RateLimiter {
    commands: HashMap<String, Vec<Instant>>,
    max_commands: u32,
    window_duration: Duration,
}

impl RateLimiter {
    fn new(max_commands: u32, window_duration: Duration) -> Self {
        Self {
            commands: HashMap::new(),
            max_commands,
            window_duration,
        }
    }

    fn can_execute(&mut self, user_id: &str) -> bool {
        let now = Instant::now();
        let window_start = now - self.window_duration;
        
        let user_commands = self.commands.entry(user_id.to_string()).or_insert_with(Vec::new);
        
        // Remove old commands outside the window
        user_commands.retain(|&time| time > window_start);
        
        if user_commands.len() < self.max_commands as usize {
            user_commands.push(now);
            true
        } else {
            false
        }
    }
}

impl CommandExecutor {
    pub fn new(
        system: Arc<SystemManager>,
        security: Arc<SecurityManager>,
        storage: Arc<SecureStorage>,
    ) -> Self {
        Self {
            system,
            security,
            storage,
            command_history: Arc::new(RwLock::new(HashMap::new())),
            rate_limiter: Arc::new(RwLock::new(RateLimiter::new(10, Duration::from_secs(60)))),
        }
    }

    pub async fn start_listening(&self, discord: Arc<DiscordClient>) -> Result<(), Box<dyn std::error::Error>> {
        info!("Starting command listener...");
        
        // In a real implementation, this would listen for commands from Discord
        // For now, we'll simulate command processing
        loop {
            tokio::time::sleep(Duration::from_secs(1)).await;
            
            // Check for emergency disable
            if self.is_emergency_disabled().await? {
                warn!("Emergency disable detected, stopping command listener");
                break;
            }
        }
        
        Ok(())
    }

    pub async fn execute_command(&self, command: DiscordCommand) -> Result<CommandResponse, Box<dyn std::error::Error>> {
        let command_id = command.command_id.clone();
        let authorized_user = command.authorized_user.clone();
        let command_type = command.command.clone();
        
        info!("Executing command: {:?} from user: {}", command_type, authorized_user);
        
        // Check rate limiting
        if !self.check_rate_limit(&authorized_user).await? {
            let response = CommandResponse {
                command_id: command_id.clone(),
                success: false,
                message: "Rate limit exceeded".to_string(),
                timestamp: Utc::now(),
            };
            
            self.log_command(&command_id, &command_type, &authorized_user, false, "Rate limit exceeded").await?;
            return Ok(response);
        }
        
        // Execute the command
        let (success, details) = match command_type {
            CommandType::Lock => {
                match self.system.lock_screen().await {
                    Ok(_) => (true, "Screen locked successfully".to_string()),
                    Err(e) => (false, format!("Failed to lock screen: {}", e)),
                }
            }
            CommandType::Logout => {
                match self.system.logout_user().await {
                    Ok(_) => (true, "User logged out successfully".to_string()),
                    Err(e) => (false, format!("Failed to logout user: {}", e)),
                }
            }
            CommandType::Ping => {
                (true, "Pong! Device is responsive".to_string())
            }
            CommandType::Status => {
                match self.system.get_system_info().await {
                    Ok(info) => (true, format!("Status: {:?}", info)),
                    Err(e) => (false, format!("Failed to get status: {}", e)),
                }
            }
        };
        
        let response = CommandResponse {
            command_id: command_id.clone(),
            success,
            message: details.clone(),
            timestamp: Utc::now(),
        };
        
        // Log the command execution
        self.log_command(&command_id, &command_type, &authorized_user, success, &details).await?;
        
        // Store in command history
        self.store_command_history(&command_id, &command_type, &authorized_user, success, &details).await?;
        
        info!("Command executed: {:?} - {}", command_type, if success { "SUCCESS" } else { "FAILED" });
        
        Ok(response)
    }

    async fn check_rate_limit(&self, user_id: &str) -> Result<bool, Box<dyn std::error::Error>> {
        let mut rate_limiter = self.rate_limiter.write().await;
        Ok(rate_limiter.can_execute(user_id))
    }

    async fn log_command(&self, command_id: &str, command_type: &CommandType, user: &str, success: bool, details: &str) -> Result<(), Box<dyn std::error::Error>> {
        let log_entry = serde_json::json!({
            "command_id": command_id,
            "command_type": format!("{:?}", command_type),
            "authorized_user": user,
            "timestamp": Utc::now().to_rfc3339(),
            "success": success,
            "details": details,
            "ip_address": "remote", // In real implementation, get actual IP
            "user_agent": "discord-bot" // In real implementation, get actual user agent
        });
        
        self.storage.log_audit_event("command_executed", &log_entry).await?;
        Ok(())
    }

    async fn store_command_history(&self, command_id: &str, command_type: &CommandType, user: &str, success: bool, details: &str) -> Result<(), Box<dyn std::error::Error>> {
        let entry = CommandHistoryEntry {
            command_id: command_id.to_string(),
            command_type: command_type.clone(),
            authorized_user: user.to_string(),
            timestamp: Utc::now(),
            success,
            details: details.to_string(),
        };
        
        let mut history = self.command_history.write().await;
        history.insert(command_id.to_string(), entry);
        
        // Keep only last 1000 commands
        if history.len() > 1000 {
            let mut entries: Vec<_> = history.iter().collect();
            entries.sort_by_key(|(_, entry)| entry.timestamp);
            let to_remove = entries.len() - 1000;
            
            for (key, _) in entries.iter().take(to_remove) {
                history.remove(*key);
            }
        }
        
        Ok(())
    }

    pub async fn get_command_history(&self, limit: Option<usize>) -> Result<Vec<CommandHistoryEntry>, Box<dyn std::error::Error>> {
        let history = self.command_history.read().await;
        let mut entries: Vec<_> = history.values().cloned().collect();
        
        // Sort by timestamp (newest first)
        entries.sort_by_key(|entry| entry.timestamp);
        entries.reverse();
        
        if let Some(limit) = limit {
            entries.truncate(limit);
        }
        
        Ok(entries)
    }

    pub async fn clear_command_history(&self) -> Result<(), Box<dyn std::error::Error>> {
        let mut history = self.command_history.write().await;
        history.clear();
        info!("Command history cleared");
        Ok(())
    }

    pub async fn get_command_stats(&self) -> Result<serde_json::Value, Box<dyn std::error::Error>> {
        let history = self.command_history.read().await;
        
        let mut total_commands = 0;
        let mut successful_commands = 0;
        let mut failed_commands = 0;
        let mut command_type_counts: HashMap<String, u32> = HashMap::new();
        let mut user_counts: HashMap<String, u32> = HashMap::new();
        
        for entry in history.values() {
            total_commands += 1;
            
            if entry.success {
                successful_commands += 1;
            } else {
                failed_commands += 1;
            }
            
            let command_type = format!("{:?}", entry.command_type);
            *command_type_counts.entry(command_type).or_insert(0) += 1;
            
            *user_counts.entry(entry.authorized_user.clone()).or_insert(0) += 1;
        }
        
        let success_rate = if total_commands > 0 {
            (successful_commands as f64 / total_commands as f64) * 100.0
        } else {
            0.0
        };
        
        Ok(serde_json::json!({
            "total_commands": total_commands,
            "successful_commands": successful_commands,
            "failed_commands": failed_commands,
            "success_rate_percent": success_rate,
            "command_type_breakdown": command_type_counts,
            "user_breakdown": user_counts,
            "timestamp": Utc::now().to_rfc3339()
        }))
    }

    async fn is_emergency_disabled(&self) -> Result<bool, Box<dyn std::error::Error>> {
        // Check for emergency disable file
        let config_dir = crate::config::Config::get_config_dir()?;
        let emergency_file = config_dir.join("EMERGENCY_DISABLE");
        Ok(emergency_file.exists())
    }

    pub async fn validate_command_permissions(&self, command: &DiscordCommand, config: &Config) -> Result<bool, Box<dyn std::error::Error>> {
        // Check if remote commands are enabled
        if !config.user_consent.remote_commands_enabled {
            return Ok(false);
        }
        
        // Check if user is authorized
        if !config.discord.allowed_users.contains(&command.authorized_user) {
            return Ok(false);
        }
        
        // Check if specific command type is allowed
        match command.command {
            CommandType::Lock => {
                // Lock is always allowed if remote commands are enabled
                Ok(true)
            }
            CommandType::Logout => {
                // Logout might require additional confirmation
                Ok(true) // In real implementation, check additional permissions
            }
            CommandType::Ping | CommandType::Status => {
                // These are always allowed
                Ok(true)
            }
        }
    }
}
