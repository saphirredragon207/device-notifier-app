use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;
use std::collections::HashMap;
use config::{Config as ConfigFile, File};
use dirs;
use tracing::{info, warn, error};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub user_consent: UserConsent,
    pub discord: DiscordConfig,
    pub features: FeatureConfig,
    pub security: SecurityConfig,
    pub app_rules: HashMap<String, AppRule>,
    pub device: DeviceConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserConsent {
    pub telemetry_enabled: bool,
    pub remote_commands_enabled: bool,
    pub discord_integration_enabled: bool,
    pub consent_timestamp: Option<chrono::DateTime<chrono::Utc>>,
    pub consent_version: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiscordConfig {
    pub bot_token: Option<String>,
    pub channel_id: Option<String>,
    pub webhook_url: Option<String>,
    pub allowed_users: Vec<String>,
    pub allowed_roles: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FeatureConfig {
    pub login_notifications: bool,
    pub logout_notifications: bool,
    pub failed_auth_notifications: bool,
    pub heartbeat_enabled: bool,
    pub audit_logging: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecurityConfig {
    pub hmac_secret: Option<String>,
    pub command_timeout_seconds: u64,
    pub max_commands_per_minute: u32,
    pub require_local_auth_for_critical: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppRule {
    pub requires_remote_password: bool,
    pub requires_local_password: bool,
    pub blocked: bool,
    pub custom_message: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeviceConfig {
    pub alias: String,
    pub device_id: String,
    pub platform: String,
    pub version: String,
}

impl Config {
    pub fn load() -> Result<Self, Box<dyn std::error::Error>> {
        let config_dir = Self::get_config_dir()?;
        let config_file = config_dir.join("config.toml");
        
        let mut config_builder = ConfigFile::builder();
        
        // Add default configuration
        config_builder = config_builder
            .set_default("user_consent.telemetry_enabled", false)?
            .set_default("user_consent.remote_commands_enabled", false)?
            .set_default("user_consent.discord_integration_enabled", false)?
            .set_default("user_consent.consent_version", "1.0")?
            .set_default("features.login_notifications", false)?
            .set_default("features.logout_notifications", false)?
            .set_default("features.failed_auth_notifications", false)?
            .set_default("features.heartbeat_enabled", true)?
            .set_default("features.audit_logging", true)?
            .set_default("security.command_timeout_seconds", 30)?
            .set_default("security.max_commands_per_minute", 10)?
            .set_default("security.require_local_auth_for_critical", true)?
            .set_default("device.platform", std::env::consts::OS)?
            .set_default("device.version", env!("CARGO_PKG_VERSION"))?;

        // Load existing config file if it exists
        if config_file.exists() {
            config_builder = config_builder.add_source(File::from(config_file));
        }

        let config = config_builder.build()?;
        
        let mut app_rules = HashMap::new();
        if let Ok(rules) = config.get_table("app_rules") {
            for (app_name, rule_value) in rules {
                if let Ok(rule) = serde_json::from_value(serde_json::Value::String(rule_value.to_string())) {
                    app_rules.insert(app_name, rule);
                }
            }
        }

        let device_config = DeviceConfig {
            alias: config.get_string("device.alias").unwrap_or_else(|_| "Unknown Device".to_string()),
            device_id: Self::generate_device_id(),
            platform: config.get_string("device.platform").unwrap_or_else(|_| std::env::consts::OS.to_string()),
            version: config.get_string("device.version").unwrap_or_else(|_| env!("CARGO_PKG_VERSION").to_string()),
        };

        let user_consent = UserConsent {
            telemetry_enabled: config.get_bool("user_consent.telemetry_enabled").unwrap_or(false),
            remote_commands_enabled: config.get_bool("user_consent.remote_commands_enabled").unwrap_or(false),
            discord_integration_enabled: config.get_bool("user_consent.discord_integration_enabled").unwrap_or(false),
            consent_timestamp: None, // Will be set when consent is given
            consent_version: config.get_string("user_consent.consent_version").unwrap_or_else(|_| "1.0".to_string()),
        };

        let discord_config = DiscordConfig {
            bot_token: config.get_string("discord.bot_token").ok(),
            channel_id: config.get_string("discord.channel_id").ok(),
            webhook_url: config.get_string("discord.webhook_url").ok(),
            allowed_users: config.get_array("discord.allowed_users").unwrap_or_default().iter()
                .filter_map(|v| v.to_string().ok()).collect(),
            allowed_roles: config.get_array("discord.allowed_roles").unwrap_or_default().iter()
                .filter_map(|v| v.to_string().ok()).collect(),
        };

        let features = FeatureConfig {
            login_notifications: config.get_bool("features.login_notifications").unwrap_or(false),
            logout_notifications: config.get_bool("features.logout_notifications").unwrap_or(false),
            failed_auth_notifications: config.get_bool("features.failed_auth_notifications").unwrap_or(false),
            heartbeat_enabled: config.get_bool("features.heartbeat_enabled").unwrap_or(true),
            audit_logging: config.get_bool("features.audit_logging").unwrap_or(true),
        };

        let security = SecurityConfig {
            hmac_secret: config.get_string("security.hmac_secret").ok(),
            command_timeout_seconds: config.get_int("security.command_timeout_seconds").unwrap_or(30) as u64,
            max_commands_per_minute: config.get_int("security.max_commands_per_minute").unwrap_or(10) as u32,
            require_local_auth_for_critical: config.get_bool("security.require_local_auth_for_critical").unwrap_or(true),
        };

        let config = Config {
            user_consent,
            discord: DiscordConfig {
                bot_token: config.get_string("discord.bot_token").ok(),
                channel_id: config.get_string("discord.channel_id").ok(),
                webhook_url: config.get_string("discord.webhook_url").ok(),
                allowed_users: config.get_array("discord.allowed_users").unwrap_or_default().iter()
                    .filter_map(|v| v.to_string().ok()).collect(),
                allowed_roles: config.get_array("discord.allowed_roles").unwrap_or_default().iter()
                    .filter_map(|v| v.to_string().ok()).collect(),
            },
            features,
            security,
            app_rules,
            device: device_config,
        };

        // Save the configuration
        config.save()?;
        
        info!("Configuration loaded successfully");
        Ok(config)
    }

    pub fn save(&self) -> Result<(), Box<dyn std::error::Error>> {
        let config_dir = Self::get_config_dir()?;
        fs::create_dir_all(&config_dir)?;
        
        let config_file = config_dir.join("config.toml");
        let config_str = toml::to_string_pretty(self)?;
        fs::write(config_file, config_str)?;
        
        info!("Configuration saved successfully");
        Ok(())
    }

    pub fn is_emergency_disabled(&self) -> bool {
        let config_dir = match Self::get_config_dir() {
            Ok(dir) => dir,
            Err(_) => return false,
        };
        
        let emergency_file = config_dir.join("EMERGENCY_DISABLE");
        emergency_file.exists()
    }

    pub fn emergency_disable(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        let config_dir = Self::get_config_dir()?;
        let emergency_file = config_dir.join("EMERGENCY_DISABLE");
        fs::write(emergency_file, "EMERGENCY_DISABLE")?;
        
        // Disable all features
        self.user_consent.telemetry_enabled = false;
        self.user_consent.remote_commands_enabled = false;
        self.user_consent.discord_integration_enabled = false;
        
        self.features.login_notifications = false;
        self.features.logout_notifications = false;
        self.features.failed_auth_notifications = false;
        self.features.heartbeat_enabled = false;
        
        self.save()?;
        
        warn!("Emergency disable activated");
        Ok(())
    }

    pub fn emergency_enable(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        let config_dir = Self::get_config_dir()?;
        let emergency_file = config_dir.join("EMERGENCY_DISABLE");
        
        if emergency_file.exists() {
            fs::remove_file(emergency_file)?;
        }
        
        info!("Emergency disable deactivated");
        Ok(())
    }

    pub fn get_config_dir() -> Result<PathBuf, Box<dyn std::error::Error>> {
        let config_dir = dirs::config_dir()
            .ok_or("Could not determine config directory")?
            .join("device-notifier");
        Ok(config_dir)
    }

    fn generate_device_id() -> String {
        use std::collections::hash_map::DefaultHasher;
        use std::hash::{Hash, Hasher};
        
        let mut hasher = DefaultHasher::new();
        if let Ok(hostname) = std::env::var("COMPUTERNAME") {
            hostname.hash(&mut hasher);
        } else if let Ok(hostname) = std::env::var("HOSTNAME") {
            hostname.hash(&mut hasher);
        }
        
        std::env::var("USERNAME").unwrap_or_default().hash(&mut hasher);
        std::env::consts::OS.hash(&mut hasher);
        
        format!("{:x}", hasher.finish())
    }
}

impl Default for Config {
    fn default() -> Self {
        Self {
            user_consent: UserConsent {
                telemetry_enabled: false,
                remote_commands_enabled: false,
                discord_integration_enabled: false,
                consent_timestamp: None,
                consent_version: "1.0".to_string(),
            },
            discord: DiscordConfig {
                bot_token: None,
                channel_id: None,
                webhook_url: None,
                allowed_users: Vec::new(),
                allowed_roles: Vec::new(),
            },
            features: FeatureConfig {
                login_notifications: false,
                logout_notifications: false,
                failed_auth_notifications: false,
                heartbeat_enabled: true,
                audit_logging: true,
            },
            security: SecurityConfig {
                hmac_secret: None,
                command_timeout_seconds: 30,
                max_commands_per_minute: 10,
                require_local_auth_for_critical: true,
            },
            app_rules: HashMap::new(),
            device: DeviceConfig {
                alias: "Unknown Device".to_string(),
                device_id: "unknown".to_string(),
                platform: std::env::consts::OS.to_string(),
                version: env!("CARGO_PKG_VERSION").to_string(),
            },
        }
    }
}
