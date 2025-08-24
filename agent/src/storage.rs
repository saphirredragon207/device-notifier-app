use crate::config::Config;
use crate::security::SecurityManager;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;
use std::collections::VecDeque;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{info, warn, error, debug};
use chrono::{DateTime, Utc};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuditLogEntry {
    pub timestamp: DateTime<Utc>,
    pub event_type: String,
    pub user: Option<String>,
    pub details: serde_json::Value,
    pub severity: LogSeverity,
    pub source: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum LogSeverity {
    Info,
    Warning,
    Error,
    Security,
}

pub struct SecureStorage {
    config: Arc<RwLock<Config>>,
    security: Arc<SecurityManager>,
    audit_log: Arc<RwLock<VecDeque<AuditLogEntry>>>,
    max_log_entries: usize,
}

impl SecureStorage {
    pub fn new() -> Result<Self, Box<dyn std::error::Error>> {
        Ok(Self {
            config: Arc::new(RwLock::new(Config::default())),
            security: Arc::new(SecurityManager::new(&Config::default())?),
            audit_log: Arc::new(RwLock::new(VecDeque::new())),
            max_log_entries: 10000,
        })
    }

    pub async fn initialize(&mut self, config: Config, security: SecurityManager) -> Result<(), Box<dyn std::error::Error>> {
        self.config = Arc::new(RwLock::new(config));
        self.security = Arc::new(security);
        
        // Initialize encryption
        self.security.initialize_encryption().await?;
        
        // Load existing audit logs
        self.load_audit_logs().await?;
        
        info!("Secure storage initialized");
        Ok(())
    }

    pub async fn log_audit_event(&self, event_type: &str, details: &serde_json::Value) -> Result<(), Box<dyn std::error::Error>> {
        let config = self.config.read().await;
        
        if !config.features.audit_logging {
            return Ok(());
        }

        let entry = AuditLogEntry {
            timestamp: Utc::now(),
            event_type: event_type.to_string(),
            user: self.get_current_user().await?,
            details: details.clone(),
            severity: self.determine_severity(event_type),
            source: "agent".to_string(),
        };

        // Add to memory
        let mut audit_log = self.audit_log.write().await;
        audit_log.push_back(entry.clone());
        
        // Maintain max size
        while audit_log.len() > self.max_log_entries {
            audit_log.pop_front();
        }

        // Persist to disk
        self.persist_audit_logs().await?;
        
        debug!("Audit event logged: {} - {}", event_type, entry.timestamp);
        Ok(())
    }

    pub async fn get_audit_logs(&self, limit: Option<usize>, event_type: Option<&str>) -> Result<Vec<AuditLogEntry>, Box<dyn std::error::Error>> {
        let audit_log = self.audit_log.read().await;
        
        let mut filtered_logs: Vec<_> = if let Some(event_type_filter) = event_type {
            audit_log.iter()
                .filter(|entry| entry.event_type == event_type_filter)
                .cloned()
                .collect()
        } else {
            audit_log.iter().cloned().collect()
        };

        // Sort by timestamp (newest first)
        filtered_logs.sort_by_key(|entry| entry.timestamp);
        filtered_logs.reverse();

        if let Some(limit) = limit {
            filtered_logs.truncate(limit);
        }

        Ok(filtered_logs)
    }

    pub async fn export_audit_logs(&self, format: &str) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
        let logs = self.get_audit_logs(None, None).await?;
        
        match format.to_lowercase().as_str() {
            "json" => {
                let json_data = serde_json::to_string_pretty(&logs)?;
                Ok(json_data.into_bytes())
            }
            "csv" => {
                let mut csv_data = String::new();
                csv_data.push_str("Timestamp,Event Type,User,Severity,Source,Details\n");
                
                for log in logs {
                    let details = log.details.to_string().replace("\"", "\"\"");
                    csv_data.push_str(&format!("\"{}\",\"{}\",\"{}\",\"{:?}\",\"{}\",\"{}\"\n",
                        log.timestamp.to_rfc3339(),
                        log.event_type,
                        log.user.unwrap_or_else(|| "Unknown".to_string()),
                        log.severity,
                        log.source,
                        details
                    ));
                }
                
                Ok(csv_data.into_bytes())
            }
            _ => Err("Unsupported export format".into())
        }
    }

    pub async fn clear_audit_logs(&self) -> Result<(), Box<dyn std::error::Error>> {
        let mut audit_log = self.audit_log.write().await;
        audit_log.clear();
        
        // Clear persisted logs
        self.clear_persisted_logs().await?;
        
        info!("Audit logs cleared");
        Ok(())
    }

    pub async fn store_encrypted_data(&self, key: &str, data: &[u8]) -> Result<(), Box<dyn std::error::Error>> {
        let encrypted_data = self.security.encrypt_data(data).await?;
        let storage_path = self.get_storage_path()?;
        let file_path = storage_path.join(format!("{}.enc", key));
        
        fs::create_dir_all(&storage_path)?;
        fs::write(file_path, encrypted_data)?;
        
        debug!("Encrypted data stored: {}", key);
        Ok(())
    }

    pub async fn retrieve_encrypted_data(&self, key: &str) -> Result<Option<Vec<u8>>, Box<dyn std::error::Error>> {
        let storage_path = self.get_storage_path()?;
        let file_path = storage_path.join(format!("{}.enc", key));
        
        if !file_path.exists() {
            return Ok(None);
        }
        
        let encrypted_data = fs::read(file_path)?;
        let decrypted_data = self.security.decrypt_data(&encrypted_data).await?;
        
        Ok(Some(decrypted_data))
    }

    pub async fn delete_encrypted_data(&self, key: &str) -> Result<(), Box<dyn std::error::Error>> {
        let storage_path = self.get_storage_path()?;
        let file_path = storage_path.join(format!("{}.enc", key));
        
        if file_path.exists() {
            // Securely wipe the file
            self.security.secure_wipe_file(file_path.to_str().unwrap()).await?;
        }
        
        debug!("Encrypted data deleted: {}", key);
        Ok(())
    }

    pub async fn get_storage_stats(&self) -> Result<serde_json::Value, Box<dyn std::error::Error>> {
        let audit_log = self.audit_log.read().await;
        let storage_path = self.get_storage_path()?;
        
        let mut total_size = 0u64;
        let mut file_count = 0u32;
        
        if storage_path.exists() {
            for entry in fs::read_dir(&storage_path)? {
                let entry = entry?;
                let metadata = entry.metadata()?;
                total_size += metadata.len();
                file_count += 1;
            }
        }
        
        Ok(serde_json::json!({
            "audit_log_entries": audit_log.len(),
            "max_log_entries": self.max_log_entries,
            "storage_path": storage_path.to_string_lossy(),
            "total_storage_size_bytes": total_size,
            "encrypted_files_count": file_count,
            "timestamp": Utc::now().to_rfc3339()
        }))
    }

    async fn load_audit_logs(&self) -> Result<(), Box<dyn std::error::Error>> {
        let storage_path = self.get_storage_path()?;
        let log_file = storage_path.join("audit_log.enc");
        
        if !log_file.exists() {
            return Ok(());
        }
        
        let encrypted_data = fs::read(&log_file)?;
        let decrypted_data = self.security.decrypt_data(&encrypted_data).await?;
        
        let logs: Vec<AuditLogEntry> = serde_json::from_slice(&decrypted_data)?;
        
        let mut audit_log = self.audit_log.write().await;
        for log in logs {
            audit_log.push_back(log);
        }
        
        info!("Loaded {} audit log entries", audit_log.len());
        Ok(())
    }

    async fn persist_audit_logs(&self) -> Result<(), Box<dyn std::error::Error>> {
        let audit_log = self.audit_log.read().await;
        let logs: Vec<_> = audit_log.iter().cloned().collect();
        
        let json_data = serde_json::to_vec(&logs)?;
        let encrypted_data = self.security.encrypt_data(&json_data).await?;
        
        let storage_path = self.get_storage_path()?;
        let log_file = storage_path.join("audit_log.enc");
        
        fs::create_dir_all(&storage_path)?;
        fs::write(log_file, encrypted_data)?;
        
        Ok(())
    }

    async fn clear_persisted_logs(&self) -> Result<(), Box<dyn std::error::Error>> {
        let storage_path = self.get_storage_path()?;
        let log_file = storage_path.join("audit_log.enc");
        
        if log_file.exists() {
            self.security.secure_wipe_file(log_file.to_str().unwrap()).await?;
        }
        
        Ok(())
    }

    fn get_storage_path(&self) -> Result<PathBuf, Box<dyn std::error::Error>> {
        let config_dir = Config::get_config_dir()?;
        Ok(config_dir.join("storage"))
    }

    async fn get_current_user(&self) -> Result<Option<String>, Box<dyn std::error::Error>> {
        let username = std::env::var("USERNAME")
            .or_else(|_| std::env::var("USER"))
            .ok();
            
        Ok(username)
    }

    fn determine_severity(&self, event_type: &str) -> LogSeverity {
        match event_type {
            "login" | "logout" | "heartbeat" => LogSeverity::Info,
            "failed_auth" | "rate_limit_exceeded" => LogSeverity::Warning,
            "command_executed" => LogSeverity::Security,
            _ => LogSeverity::Info,
        }
    }
}

impl Drop for SecureStorage {
    fn drop(&mut self) {
        // Ensure logs are persisted on shutdown
        if let Ok(()) = tokio::runtime::Handle::try_current() {
            // We're in a tokio context, can spawn a task
            let storage = self.clone();
            tokio::spawn(async move {
                if let Err(e) = storage.persist_audit_logs().await {
                    error!("Failed to persist audit logs on shutdown: {}", e);
                }
            });
        }
    }
}
