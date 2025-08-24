use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{info, warn, error, debug};
use sysinfo::{System, SystemExt, UserExt};
use std::collections::HashMap;
use std::time::{Duration, Instant};
use chrono::{DateTime, Utc};

#[cfg(target_os = "windows")]
use winapi::um::winuser::LockWorkStation;

#[cfg(target_os = "macos")]
use std::process::Command;

pub struct SystemManager {
    system: Arc<RwLock<System>>,
    last_users: Arc<RwLock<HashMap<String, UserInfo>>>,
    monitoring: Arc<RwLock<bool>>,
}

#[derive(Debug, Clone)]
pub struct UserInfo {
    pub username: String,
    pub login_time: DateTime<Utc>,
    pub is_active: bool,
}

impl SystemManager {
    pub fn new() -> Result<Self, Box<dyn std::error::Error>> {
        let system = System::new_all();
        
        Ok(Self {
            system: Arc::new(RwLock::new(system)),
            last_users: Arc::new(RwLock::new(HashMap::new())),
            monitoring: Arc::new(RwLock::new(false)),
        })
    }

    pub async fn start_monitoring(&self) -> Result<(), Box<dyn std::error::Error>> {
        let mut monitoring = self.monitoring.write().await;
        *monitoring = true;
        drop(monitoring);

        info!("System monitoring started");
        
        // Spawn monitoring task
        let system = self.system.clone();
        let last_users = self.last_users.clone();
        let monitoring = self.monitoring.clone();
        
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(Duration::from_secs(5));
            
            while *monitoring.read().await {
                interval.tick().await;
                
                if let Err(e) = Self::check_user_changes(&system, &last_users).await {
                    error!("Error checking user changes: {}", e);
                }
            }
        });

        Ok(())
    }

    pub async fn stop_monitoring(&self) -> Result<(), Box<dyn std::error::Error>> {
        let mut monitoring = self.monitoring.write().await;
        *monitoring = false;
        
        info!("System monitoring stopped");
        Ok(())
    }

    async fn check_user_changes(
        system: &Arc<RwLock<System>>,
        last_users: &Arc<RwLock<HashMap<String, UserInfo>>>
    ) -> Result<(), Box<dyn std::error::Error>> {
        let mut system = system.write().await;
        system.refresh_users();
        
        let current_users: HashMap<String, UserInfo> = system
            .users()
            .iter()
            .map(|user| {
                let username = user.name().to_string();
                let login_time = Utc::now(); // Note: sysinfo doesn't provide exact login time
                let is_active = user.id() == system.current_user_id();
                
                (username.clone(), UserInfo {
                    username,
                    login_time,
                    is_active,
                })
            })
            .collect();

        let mut last_users = last_users.write().await;
        
        // Check for new logins
        for (username, user_info) in &current_users {
            if !last_users.contains_key(username) {
                info!("New user login detected: {}", username);
                // This would trigger a Discord notification
            }
        }
        
        // Check for logouts
        for (username, _) in last_users.iter() {
            if !current_users.contains_key(username) {
                info!("User logout detected: {}", username);
                // This would trigger a Discord notification
            }
        }
        
        *last_users = current_users;
        Ok(())
    }

    pub async fn lock_screen(&self) -> Result<(), Box<dyn std::error::Error>> {
        info!("Locking screen...");
        
        #[cfg(target_os = "windows")]
        {
            unsafe {
                if LockWorkStation() == 0 {
                    return Err("Failed to lock Windows workstation".into());
                }
            }
        }
        
        #[cfg(target_os = "macos")]
        {
            let output = Command::new("pmset")
                .args(&["displaysleepnow"])
                .output()?;
                
            if !output.status.success() {
                return Err(format!("Failed to lock macOS screen: {}", 
                    String::from_utf8_lossy(&output.stderr)).into());
            }
        }
        
        #[cfg(not(any(target_os = "windows", target_os = "macos")))]
        {
            return Err("Screen locking not implemented for this platform".into());
        }
        
        info!("Screen locked successfully");
        Ok(())
    }

    pub async fn logout_user(&self) -> Result<(), Box<dyn std::error::Error>> {
        info!("Logging out current user...");
        
        #[cfg(target_os = "windows")]
        {
            let output = std::process::Command::new("shutdown")
                .args(&["/l"])
                .output()?;
                
            if !output.status.success() {
                return Err(format!("Failed to logout Windows user: {}", 
                    String::from_utf8_lossy(&output.stderr)).into());
            }
        }
        
        #[cfg(target_os = "macos")]
        {
            let output = Command::new("osascript")
                .args(&["-e", "tell application \"System Events\" to log out"])
                .output()?;
                
            if !output.status.success() {
                return Err(format!("Failed to logout macOS user: {}", 
                    String::from_utf8_lossy(&output.stderr)).into());
            }
        }
        
        #[cfg(not(any(target_os = "windows", target_os = "macos")))]
        {
            return Err("User logout not implemented for this platform".into());
        }
        
        info!("User logged out successfully");
        Ok(())
    }

    pub async fn get_system_info(&self) -> Result<serde_json::Value, Box<dyn std::error::Error>> {
        let system = self.system.read().await;
        let last_users = self.last_users.read().await;
        
        let mut users_info = Vec::new();
        for (_, user_info) in last_users.iter() {
            users_info.push(serde_json::json!({
                "username": user_info.username,
                "login_time": user_info.login_time.to_rfc3339(),
                "is_active": user_info.is_active
            }));
        }
        
        Ok(serde_json::json!({
            "platform": std::env::consts::OS,
            "hostname": system.host_name().unwrap_or_else(|| "Unknown".to_string()),
            "kernel_version": system.kernel_version().unwrap_or_else(|| "Unknown".to_string()),
            "os_version": system.os_version().unwrap_or_else(|| "Unknown".to_string()),
            "total_memory": system.total_memory(),
            "used_memory": system.used_memory(),
            "cpu_count": system.cpu_count(),
            "users": users_info,
            "timestamp": Utc::now().to_rfc3339()
        }))
    }

    pub async fn get_current_user(&self) -> Result<Option<String>, Box<dyn std::error::Error>> {
        let username = std::env::var("USERNAME")
            .or_else(|_| std::env::var("USER"))
            .ok();
            
        Ok(username)
    }

    pub async fn is_screen_locked(&self) -> Result<bool, Box<dyn std::error::Error>> {
        // This is a simplified check - in a real implementation,
        // you'd use platform-specific APIs to check screen lock status
        
        #[cfg(target_os = "windows")]
        {
            // Windows: Check if workstation is locked
            // This is a simplified approach - real implementation would use
            // GetForegroundWindow() or similar APIs
            Ok(false) // Placeholder
        }
        
        #[cfg(target_os = "macos")]
        {
            // macOS: Check if screen is locked
            // This is a simplified approach - real implementation would use
            // CGSessionCopyCurrentDictionary or similar APIs
            Ok(false) // Placeholder
        }
        
        #[cfg(not(any(target_os = "windows", target_os = "macos")))]
        {
            Ok(false) // Placeholder for other platforms
        }
    }

    pub async fn get_uptime(&self) -> Result<Duration, Box<dyn std::error::Error>> {
        let system = self.system.read().await;
        let uptime = system.uptime();
        Ok(Duration::from_secs(uptime))
    }

    pub async fn get_memory_usage(&self) -> Result<serde_json::Value, Box<dyn std::error::Error>> {
        let system = self.system.read().await;
        
        Ok(serde_json::json!({
            "total_memory_mb": system.total_memory(),
            "used_memory_mb": system.used_memory(),
            "free_memory_mb": system.free_memory(),
            "memory_usage_percent": (system.used_memory() as f64 / system.total_memory() as f64) * 100.0,
            "timestamp": Utc::now().to_rfc3339()
        }))
    }

    pub async fn get_cpu_usage(&self) -> Result<serde_json::Value, Box<dyn std::error::Error>> {
        let system = self.system.read().await;
        
        let mut cpu_usage = Vec::new();
        for (i, cpu) in system.cpus().iter().enumerate() {
            cpu_usage.push(serde_json::json!({
                "core": i,
                "usage_percent": cpu.cpu_usage(),
                "frequency_mhz": cpu.frequency()
            }));
        }
        
        Ok(serde_json::json!({
            "cpu_count": system.cpu_count(),
            "global_cpu_usage": system.global_cpu_info().cpu_usage(),
            "cores": cpu_usage,
            "timestamp": Utc::now().to_rfc3339()
        }))
    }
}

impl Drop for SystemManager {
    fn drop(&mut self) {
        // Ensure monitoring is stopped
        if let Ok(mut monitoring) = self.monitoring.try_write() {
            *monitoring = false;
        }
    }
}
