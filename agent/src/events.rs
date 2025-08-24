use crate::config::Config;
use crate::discord::{DiscordClient, DiscordEvent, EventType};
use crate::storage::SecureStorage;
use crate::system::SystemManager;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{info, warn, error, debug};
use chrono::{DateTime, Utc};
use std::collections::HashMap;
use std::time::Duration;

pub struct EventMonitor {
    discord: Arc<DiscordClient>,
    storage: Arc<SecureStorage>,
    config: Arc<RwLock<Config>>,
    system: Arc<SystemManager>,
    last_events: Arc<RwLock<HashMap<String, DateTime<Utc>>>>,
    monitoring: Arc<RwLock<bool>>,
}

impl EventMonitor {
    pub fn new(
        discord: Arc<DiscordClient>,
        storage: Arc<SecureStorage>,
        config: Arc<RwLock<Config>>,
    ) -> Self {
        Self {
            discord,
            storage,
            config,
            system: Arc::new(SystemManager::new().unwrap_or_else(|_| {
                error!("Failed to create system manager");
                SystemManager::new().unwrap_or_else(|_| panic!("System manager creation failed"))
            })),
            last_events: Arc::new(RwLock::new(HashMap::new())),
            monitoring: Arc::new(RwLock::new(false)),
        }
    }

    pub async fn start(&self) -> Result<(), Box<dyn std::error::Error>> {
        let mut monitoring = self.monitoring.write().await;
        *monitoring = true;
        drop(monitoring);

        info!("Event monitoring started");
        
        // Start system monitoring
        self.system.start_monitoring().await?;
        
        // Spawn monitoring tasks
        self.spawn_login_monitor().await?;
        self.spawn_system_health_monitor().await?;
        self.spawn_network_monitor().await?;
        
        Ok(())
    }

    pub async fn stop(&self) -> Result<(), Box<dyn std::error::Error>> {
        let mut monitoring = self.monitoring.monitoring.write().await;
        *monitoring = false;
        
        // Stop system monitoring
        self.system.stop_monitoring().await?;
        
        info!("Event monitoring stopped");
        Ok(())
    }

    async fn spawn_login_monitor(&self) -> Result<(), Box<dyn std::error::Error>> {
        let discord = self.discord.clone();
        let storage = self.storage.clone();
        let config = self.config.clone();
        let last_events = self.last_events.clone();
        let monitoring = self.monitoring.clone();
        
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(Duration::from_secs(10));
            
            while *monitoring.read().await {
                interval.tick().await;
                
                if let Err(e) = Self::check_login_events(&discord, &storage, &config, &last_events).await {
                    error!("Error checking login events: {}", e);
                }
            }
        });

        Ok(())
    }

    async fn spawn_system_health_monitor(&self) -> Result<(), Box<dyn std::error::Error>> {
        let discord = self.discord.clone();
        let storage = self.storage.clone();
        let config = self.config.clone();
        let monitoring = self.monitoring.clone();
        
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(Duration::from_secs(60)); // Check every minute
            
            while *monitoring.read().await {
                interval.tick().await;
                
                if let Err(e) = Self::check_system_health(&discord, &storage, &config).await {
                    error!("Error checking system health: {}", e);
                }
            }
        });

        Ok(())
    }

    async fn spawn_network_monitor(&self) -> Result<(), Box<dyn std::error::Error>> {
        let discord = self.discord.clone();
        let storage = self.storage.clone();
        let config = self.config.clone();
        let monitoring = self.monitoring.clone();
        
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(Duration::from_secs(30)); // Check every 30 seconds
            
            while *monitoring.read().await {
                interval.tick().await;
                
                if let Err(e) = Self::check_network_status(&discord, &storage, &config).await {
                    error!("Error checking network status: {}", e);
                }
            }
        });

        Ok(())
    }

    async fn check_login_events(
        discord: &DiscordClient,
        storage: &SecureStorage,
        config: &Arc<RwLock<Config>>,
        last_events: &Arc<RwLock<HashMap<String, DateTime<Utc>>>>
    ) -> Result<(), Box<dyn std::error::Error>> {
        let config = config.read().await;
        
        if !config.features.login_notifications && !config.features.logout_notifications {
            return Ok(());
        }

        // Get current users from system
        let system_info = self.system.get_system_info().await?;
        let current_users = system_info["users"].as_array()
            .unwrap_or(&Vec::new())
            .iter()
            .map(|user| user["username"].as_str().unwrap_or("Unknown").to_string())
            .collect::<Vec<_>>();

        let mut last_events = last_events.write().await;
        
        // Check for new logins
        for username in &current_users {
            let event_key = format!("login_{}", username);
            if !last_events.contains_key(&event_key) {
                if config.features.login_notifications {
                    let event = DiscordEvent {
                        device_alias: config.device.alias.clone(),
                        device_id_hash: "hash_placeholder".to_string(), // In real implementation, get actual hash
                        event_type: EventType::Login,
                        timestamp: Utc::now(),
                        user_local: Some(username.clone()),
                        notes: None,
                    };
                    
                    if let Err(e) = discord.send_event(event).await {
                        error!("Failed to send login event: {}", e);
                    }
                }
                
                last_events.insert(event_key, Utc::now());
            }
        }
        
        // Check for logouts (users that were logged in but are no longer present)
        let mut users_to_remove = Vec::new();
        for (event_key, _) in last_events.iter() {
            if event_key.starts_with("login_") {
                let username = event_key.strip_prefix("login_").unwrap_or("");
                if !current_users.contains(&username.to_string()) {
                    if config.features.logout_notifications {
                        let event = DiscordEvent {
                            device_alias: config.device.alias.clone(),
                            device_id_hash: "hash_placeholder".to_string(),
                            event_type: EventType::Logout,
                            timestamp: Utc::now(),
                            user_local: Some(username.to_string()),
                            notes: None,
                        };
                        
                        if let Err(e) = discord.send_event(event).await {
                            error!("Failed to send logout event: {}", e);
                        }
                    }
                    
                    users_to_remove.push(event_key.clone());
                }
            }
        }
        
        // Remove logged out users
        for event_key in users_to_remove {
            last_events.remove(&event_key);
        }
        
        Ok(())
    }

    async fn check_system_health(
        discord: &DiscordClient,
        storage: &SecureStorage,
        config: &Arc<RwLock<Config>>
    ) -> Result<(), Box<dyn std::error::Error>> {
        let config = config.read().await;
        
        if !config.features.audit_logging {
            return Ok(());
        }

        // Check memory usage
        let memory_info = self.system.get_memory_usage().await?;
        let memory_usage_percent = memory_info["memory_usage_percent"].as_f64().unwrap_or(0.0);
        
        if memory_usage_percent > 90.0 {
            let event = DiscordEvent {
                device_alias: config.device.alias.clone(),
                device_id_hash: "hash_placeholder".to_string(),
                event_type: EventType::Heartbeat,
                timestamp: Utc::now(),
                user_local: None,
                notes: Some(format!("High memory usage: {:.1}%", memory_usage_percent)),
            };
            
            if let Err(e) = discord.send_event(event).await {
                error!("Failed to send high memory warning: {}", e);
            }
        }
        
        // Check CPU usage
        let cpu_info = self.system.get_cpu_usage().await?;
        let global_cpu_usage = cpu_info["global_cpu_usage"].as_f64().unwrap_or(0.0);
        
        if global_cpu_usage > 95.0 {
            let event = DiscordEvent {
                device_alias: config.device.alias.clone(),
                device_id_hash: "hash_placeholder".to_string(),
                event_type: EventType::Heartbeat,
                timestamp: Utc::now(),
                user_local: None,
                notes: Some(format!("High CPU usage: {:.1}%", global_cpu_usage)),
            };
            
            if let Err(e) = discord.send_event(event).await {
                error!("Failed to send high CPU warning: {}", e);
            }
        }
        
        Ok(())
    }

    async fn check_network_status(
        discord: &DiscordClient,
        storage: &SecureStorage,
        config: &Arc<RwLock<Config>>
    ) -> Result<(), Box<dyn std::error::Error>> {
        let config = config.read().await;
        
        if !config.features.audit_logging {
            return Ok(());
        }

        // Simple network connectivity check
        let test_url = "https://httpbin.org/get";
        let client = reqwest::Client::new();
        
        match client.get(test_url).timeout(Duration::from_secs(10)).send().await {
            Ok(response) => {
                if !response.status().is_success() {
                    let event = DiscordEvent {
                        device_alias: config.device.alias.clone(),
                        device_id_hash: "hash_placeholder".to_string(),
                        event_type: EventType::Heartbeat,
                        timestamp: Utc::now(),
                        user_local: None,
                        notes: Some(format!("Network connectivity issue: HTTP {}", response.status())),
                    };
                    
                    if let Err(e) = discord.send_event(event).await {
                        error!("Failed to send network warning: {}", e);
                    }
                }
            }
            Err(e) => {
                let event = DiscordEvent {
                    device_alias: config.device.alias.clone(),
                    device_id_hash: "hash_placeholder".to_string(),
                    event_type: EventType::Heartbeat,
                    timestamp: Utc::now(),
                    user_local: None,
                    notes: Some(format!("Network connectivity lost: {}", e)),
                };
                
                if let Err(e) = discord.send_event(event).await {
                    error!("Failed to send network warning: {}", e);
                }
            }
        }
        
        Ok(())
    }

    pub async fn trigger_custom_event(
        &self,
        event_type: EventType,
        user: Option<String>,
        notes: Option<String>
    ) -> Result<(), Box<dyn std::error::Error>> {
        let config = self.config.read().await;
        
        let event = DiscordEvent {
            device_alias: config.device.alias.clone(),
            device_id_hash: "hash_placeholder".to_string(),
            event_type,
            timestamp: Utc::now(),
            user_local: user,
            notes,
        };
        
        if let Err(e) = self.discord.send_event(event).await {
            error!("Failed to send custom event: {}", e);
            return Err(e);
        }
        
        // Log the event
        let log_entry = serde_json::json!({
            "event_type": format!("{:?}", event_type),
            "user": user,
            "notes": notes,
            "timestamp": Utc::now().to_rfc3339()
        });
        
        self.storage.log_audit_event("custom_event", &log_entry).await?;
        
        Ok(())
    }

    pub async fn get_monitoring_status(&self) -> Result<serde_json::Value, Box<dyn std::error::Error>> {
        let monitoring = self.monitoring.read().await;
        let last_events = self.last_events.read().await;
        
        Ok(serde_json::json!({
            "monitoring_active": *monitoring,
            "active_event_monitors": last_events.len(),
            "last_events": last_events.iter().map(|(k, v)| {
                serde_json::json!({
                    "event": k,
                    "timestamp": v.to_rfc3339()
                })
            }).collect::<Vec<_>>(),
            "timestamp": Utc::now().to_rfc3339()
        }))
    }
}
