#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::Config;
    use crate::security::SecurityManager;
    use crate::storage::SecureStorage;
    use tempfile::tempdir;

    #[tokio::test]
    async fn test_config_loading() {
        let config = Config::load().unwrap();
        assert_eq!(config.user_consent.telemetry_enabled, false);
        assert_eq!(config.user_consent.remote_commands_enabled, false);
        assert_eq!(config.features.audit_logging, true);
    }

    #[tokio::test]
    async fn test_emergency_disable() {
        let mut config = Config::load().unwrap();
        config.emergency_disable().unwrap();
        assert!(config.is_emergency_disabled());
        
        config.emergency_enable().unwrap();
        assert!(!config.is_emergency_disabled());
    }

    #[tokio::test]
    async fn test_security_manager() {
        let config = Config::load().unwrap();
        let security = SecurityManager::new(&config).unwrap();
        
        security.initialize_encryption().await.unwrap();
        
        let test_data = b"Hello, World!";
        let encrypted = security.encrypt_data(test_data).await.unwrap();
        let decrypted = security.decrypt_data(&encrypted).await.unwrap();
        
        assert_eq!(test_data, decrypted.as_slice());
    }

    #[tokio::test]
    async fn test_secure_storage() {
        let temp_dir = tempdir().unwrap();
        let mut storage = SecureStorage::new().unwrap();
        
        let test_data = b"Test audit log entry";
        let log_entry = serde_json::json!({
            "test": "data",
            "timestamp": chrono::Utc::now().to_rfc3339()
        });
        
        storage.log_audit_event("test_event", &log_entry).await.unwrap();
        
        let logs = storage.get_audit_logs(Some(10), None).await.unwrap();
        assert_eq!(logs.len(), 1);
        assert_eq!(logs[0].event_type, "test_event");
    }

    #[tokio::test]
    async fn test_hmac_verification() {
        let config = Config::load().unwrap();
        let security = SecurityManager::new(&config).unwrap();
        
        let data = "test_data";
        let secret = "test_secret";
        
        let hmac = security.generate_hmac(data, secret).await.unwrap();
        let is_valid = security.verify_hmac(data, secret, &hmac).await.unwrap();
        
        assert!(is_valid);
    }

    #[tokio::test]
    async fn test_jwt_token() {
        let config = Config::load().unwrap();
        let security = SecurityManager::new(&config).unwrap();
        
        let payload = serde_json::json!({
            "user_id": "123",
            "exp": chrono::Utc::now().timestamp() + 3600
        });
        
        let secret = "test_secret";
        let token = security.generate_jwt_token(&payload, secret).await.unwrap();
        let decoded = security.verify_jwt_token(&token, secret).await.unwrap();
        
        assert_eq!(decoded["user_id"], "123");
    }
}
