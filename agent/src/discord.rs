use crate::config::Config;
use serde::{Deserialize, Serialize};
use reqwest::Client;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{info, warn, error, debug};
use chrono::{DateTime, Utc};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiscordEvent {
    pub device_alias: String,
    pub device_id_hash: String,
    pub event_type: EventType,
    pub timestamp: DateTime<Utc>,
    pub user_local: Option<String>,
    pub notes: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum EventType {
    Login,
    Logout,
    FailedAuth,
    Heartbeat,
    CommandExecuted,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiscordCommand {
    pub command: CommandType,
    pub command_id: String,
    pub authorized_user: String,
    pub timestamp: DateTime<Utc>,
    pub signature: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum CommandType {
    Lock,
    Logout,
    Ping,
    Status,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CommandResponse {
    pub command_id: String,
    pub success: bool,
    pub message: String,
    pub timestamp: DateTime<Utc>,
}

pub struct DiscordClient {
    config: Arc<RwLock<Config>>,
    http_client: Client,
    last_heartbeat: Arc<RwLock<DateTime<Utc>>>,
}

impl DiscordClient {
    pub fn new(config: &Config) -> Result<Self, Box<dyn std::error::Error>> {
        let http_client = Client::builder()
            .timeout(std::time::Duration::from_secs(30))
            .build()?;

        Ok(Self {
            config: Arc::new(RwLock::new(config.clone())),
            http_client,
            last_heartbeat: Arc::new(RwLock::new(Utc::now())),
        })
    }

    pub async fn send_event(&self, event: DiscordEvent) -> Result<(), Box<dyn std::error::Error>> {
        let config = self.config.read().await;
        
        if !config.user_consent.discord_integration_enabled {
            debug!("Discord integration disabled, skipping event");
            return Ok(());
        }

        let webhook_url = match &config.discord.webhook_url {
            Some(url) => url,
            None => {
                warn!("No Discord webhook URL configured");
                return Ok(());
            }
        };

        let embed = self.create_event_embed(&event);
        let payload = serde_json::json!({
            "embeds": [embed]
        });

        let response = self.http_client
            .post(webhook_url)
            .json(&payload)
            .send()
            .await?;

        if response.status().is_success() {
            info!("Event sent to Discord successfully: {:?}", event.event_type);
        } else {
            error!("Failed to send event to Discord: {}", response.status());
        }

        Ok(())
    }

    pub async fn send_heartbeat(&self) -> Result<(), Box<dyn std::error::Error>> {
        let config = self.config.read().await;
        
        if !config.features.heartbeat_enabled {
            return Ok(());
        }

        let event = DiscordEvent {
            device_alias: config.device.alias.clone(),
            device_id_hash: self.hash_device_id(&config.device.device_id),
            event_type: EventType::Heartbeat,
            timestamp: Utc::now(),
            user_local: None,
            notes: Some("System heartbeat".to_string()),
        };

        self.send_event(event).await?;
        
        let mut last_heartbeat = self.last_heartbeat.write().await;
        *last_heartbeat = Utc::now();
        
        Ok(())
    }

    pub async fn send_login_event(&self, username: &str) -> Result<(), Box<dyn std::error::Error>> {
        let config = self.config.read().await;
        
        if !config.features.login_notifications {
            return Ok(());
        }

        let event = DiscordEvent {
            device_alias: config.device.alias.clone(),
            device_id_hash: self.hash_device_id(&config.device.device_id),
            event_type: EventType::Login,
            timestamp: Utc::now(),
            user_local: Some(username.to_string()),
            notes: None,
        };

        self.send_event(event).await
    }

    pub async fn send_logout_event(&self, username: &str) -> Result<(), Box<dyn std::error::Error>> {
        let config = self.config.read().await;
        
        if !config.features.logout_notifications {
            return Ok(());
        }

        let event = DiscordEvent {
            device_alias: config.device.alias.clone(),
            device_id_hash: self.hash_device_id(&config.device.device_id),
            event_type: EventType::Logout,
            timestamp: Utc::now(),
            user_local: Some(username.to_string()),
            notes: None,
        };

        self.send_event(event).await
    }

    pub async fn send_failed_auth_event(&self, username: &str, details: &str) -> Result<(), Box<dyn std::error::Error>> {
        let config = self.config.read().await;
        
        if !config.features.failed_auth_notifications {
            return Ok(());
        }

        let event = DiscordEvent {
            device_alias: config.device.alias.clone(),
            device_id_hash: self.hash_device_id(&config.device.device_id),
            event_type: EventType::FailedAuth,
            timestamp: Utc::now(),
            user_local: Some(username.to_string()),
            notes: Some(details.to_string()),
        };

        self.send_event(event).await
    }

    pub async fn send_command_executed_event(&self, command: &str, success: bool, details: &str) -> Result<(), Box<dyn std::error::Error>> {
        let config = self.config.read().await;
        
        if !config.features.audit_logging {
            return Ok(());
        }

        let event = DiscordEvent {
            device_alias: config.device.alias.clone(),
            device_id_hash: self.hash_device_id(&config.device.device_id),
            event_type: EventType::CommandExecuted,
            timestamp: Utc::now(),
            user_local: None,
            notes: Some(format!("Command '{}' executed: {} - {}", command, if success { "SUCCESS" } else { "FAILED" }, details)),
        };

        self.send_event(event).await
    }

    fn create_event_embed(&self, event: &DiscordEvent) -> serde_json::Value {
        let color = match event.event_type {
            EventType::Login => 0x00ff00,      // Green
            EventType::Logout => 0xff8800,     // Orange
            EventType::FailedAuth => 0xff0000, // Red
            EventType::Heartbeat => 0x0088ff,  // Blue
            EventType::CommandExecuted => 0x8800ff, // Purple
        };

        let title = match event.event_type {
            EventType::Login => "🔓 User Login",
            EventType::Logout => "🔒 User Logout",
            EventType::FailedAuth => "⚠️ Failed Authentication",
            EventType::Heartbeat => "💓 System Heartbeat",
            EventType::CommandExecuted => "⚡ Command Executed",
        };

        let mut fields = vec![
            serde_json::json!({
                "name": "Device",
                "value": event.device_alias,
                "inline": true
            }),
            serde_json::json!({
                "name": "Event Type",
                "value": format!("{:?}", event.event_type),
                "inline": true
            }),
            serde_json::json!({
                "name": "Timestamp",
                "value": event.timestamp.format("%Y-%m-%d %H:%M:%S UTC").to_string(),
                "inline": true
            }),
        ];

        if let Some(ref user) = event.user_local {
            fields.push(serde_json::json!({
                "name": "User",
                "value": user,
                "inline": true
            }));
        }

        if let Some(ref notes) = event.notes {
            fields.push(serde_json::json!({
                "name": "Details",
                "value": notes,
                "inline": false
            }));
        }

        serde_json::json!({
            "title": title,
            "color": color,
            "fields": fields,
            "timestamp": event.timestamp.to_rfc3339(),
            "footer": {
                "text": "Device Notifier"
            }
        })
    }

    fn hash_device_id(&self, device_id: &str) -> String {
        use sha2::{Sha256, Digest};
        let mut hasher = Sha256::new();
        hasher.update(device_id.as_bytes());
        format!("{:x}", hasher.finalize())
    }

    pub async fn validate_command(&self, command: &DiscordCommand) -> Result<bool, Box<dyn std::error::Error>> {
        let config = self.config.read().await;
        
        if !config.user_consent.remote_commands_enabled {
            return Ok(false);
        }

        // Check if command is from an authorized user
        if !config.discord.allowed_users.contains(&command.authorized_user) {
            warn!("Command from unauthorized user: {}", command.authorized_user);
            return Ok(false);
        }

        // Check timestamp freshness (within 5 minutes)
        let now = Utc::now();
        let command_time = command.timestamp;
        let time_diff = now.signed_duration_since(command_time);
        
        if time_diff.num_seconds() > 300 {
            warn!("Command timestamp too old: {} seconds", time_diff.num_seconds());
            return Ok(false);
        }

        // Validate HMAC signature if configured
        if let Some(ref hmac_secret) = config.security.hmac_secret {
            if !self.verify_signature(command, hmac_secret).await? {
                warn!("Invalid command signature");
                return Ok(false);
            }
        }

        Ok(true)
    }

    async fn verify_signature(&self, command: &DiscordCommand, secret: &str) -> Result<bool, Box<dyn std::error::Error>> {
        use hmac::{Hmac, Mac};
        use sha2::Sha256;
        
        let payload = format!("{}{}{}", command.command_id, command.authorized_user, command.timestamp.timestamp());
        let mut mac = Hmac::<Sha256>::new_from_slice(secret.as_bytes())?;
        mac.update(payload.as_bytes());
        
        let expected_signature = base64::encode(mac.finalize().into_bytes());
        Ok(command.signature == expected_signature)
    }

    pub async fn get_status(&self) -> serde_json::Value {
        let config = self.config.read().await;
        let last_heartbeat = self.last_heartbeat.read().await;
        
        serde_json::json!({
            "device_alias": config.device.alias,
            "platform": config.device.platform,
            "version": config.device.version,
            "discord_connected": config.discord.webhook_url.is_some(),
            "features_enabled": {
                "login_notifications": config.features.login_notifications,
                "logout_notifications": config.features.logout_notifications,
                "remote_commands": config.user_consent.remote_commands_enabled,
                "audit_logging": config.features.audit_logging
            },
            "last_heartbeat": last_heartbeat.to_rfc3339(),
            "timestamp": Utc::now().to_rfc3339()
        })
    }
}
