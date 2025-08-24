use crate::config::Config;
use ring::aead::{self, BoundKey, Nonce, UnboundKey, AES_256_GCM};
use ring::rand::{SecureRandom, SystemRandom};
use ring::digest::{Context, SHA256};
use base64::{Engine as _, engine::general_purpose};
use tracing::{info, warn, error, debug};
use std::sync::Arc;
use tokio::sync::RwLock;

pub struct SecurityManager {
    config: Arc<RwLock<Config>>,
    encryption_key: Arc<RwLock<Option<Vec<u8>>>>,
    rng: SystemRandom,
}

impl SecurityManager {
    pub fn new(config: &Config) -> Result<Self, Box<dyn std::error::Error>> {
        let rng = SystemRandom::new();
        
        Ok(Self {
            config: Arc::new(RwLock::new(config.clone())),
            encryption_key: Arc::new(RwLock::new(None)),
            rng,
        })
    }

    pub async fn initialize_encryption(&self) -> Result<(), Box<dyn std::error::Error>> {
        let mut encryption_key = self.encryption_key.write().await;
        
        if encryption_key.is_none() {
            let key = self.generate_encryption_key().await?;
            *encryption_key = Some(key);
            info!("Encryption key initialized");
        }
        
        Ok(())
    }

    async fn generate_encryption_key(&self) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
        let mut key = vec![0u8; 32]; // 256-bit key for AES-256-GCM
        self.rng.fill(&mut key)?;
        Ok(key)
    }

    pub async fn encrypt_data(&self, data: &[u8]) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
        let encryption_key = self.encryption_key.read().await;
        let key = encryption_key.as_ref()
            .ok_or("Encryption key not initialized")?;
        
        // Generate a random nonce
        let mut nonce_bytes = [0u8; 12];
        self.rng.fill(&mut nonce_bytes)?;
        let nonce = Nonce::assume_unique_for_key(nonce_bytes);
        
        // Create the encryption key
        let unbound_key = UnboundKey::new(&AES_256_GCM, key)?;
        let mut key = aead::OpeningKey::new(unbound_key, nonce);
        
        // Encrypt the data
        let mut encrypted_data = data.to_vec();
        let tag = key.seal_in_place_append_tag(aead::Aad::empty(), &mut encrypted_data)?;
        encrypted_data.extend_from_slice(tag.as_ref());
        
        // Prepend nonce to encrypted data
        let mut result = nonce_bytes.to_vec();
        result.extend_from_slice(&encrypted_data);
        
        Ok(result)
    }

    pub async fn decrypt_data(&self, encrypted_data: &[u8]) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
        if encrypted_data.len() < 28 { // 12 bytes nonce + 16 bytes tag + at least 1 byte data
            return Err("Encrypted data too short".into());
        }
        
        let encryption_key = self.encryption_key.read().await;
        let key = encryption_key.as_ref()
            .ok_or("Encryption key not initialized")?;
        
        // Extract nonce and encrypted data
        let (nonce_bytes, encrypted_with_tag) = encrypted_data.split_at(12);
        let nonce = Nonce::assume_unique_for_key(nonce_bytes.try_into()?);
        
        // Create the decryption key
        let unbound_key = UnboundKey::new(&AES_256_GCM, key)?;
        let mut key = aead::OpeningKey::new(unbound_key, nonce);
        
        // Decrypt the data
        let mut decrypted_data = encrypted_with_tag.to_vec();
        let decrypted_len = key.open_in_place(aead::Aad::empty(), &mut decrypted_data)?
            .len();
        
        decrypted_data.truncate(decrypted_len);
        Ok(decrypted_data)
    }

    pub async fn hash_password(&self, password: &str, salt: &[u8]) -> Result<String, Box<dyn std::error::Error>> {
        let mut context = Context::new(&SHA256);
        context.update(password.as_bytes());
        context.update(salt);
        
        let digest = context.finish();
        Ok(general_purpose::STANDARD.encode(digest.as_ref()))
    }

    pub async fn verify_password(&self, password: &str, salt: &[u8], expected_hash: &str) -> Result<bool, Box<dyn std::error::Error>> {
        let computed_hash = self.hash_password(password, salt).await?;
        Ok(computed_hash == expected_hash)
    }

    pub async fn generate_salt(&self) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
        let mut salt = vec![0u8; 32];
        self.rng.fill(&mut salt)?;
        Ok(salt)
    }

    pub async fn generate_hmac(&self, data: &str, secret: &str) -> Result<String, Box<dyn std::error::Error>> {
        use hmac::{Hmac, Mac};
        use sha2::Sha256;
        
        let mut mac = Hmac::<Sha256>::new_from_slice(secret.as_bytes())?;
        mac.update(data.as_bytes());
        
        let result = mac.finalize();
        Ok(general_purpose::STANDARD.encode(result.into_bytes()))
    }

    pub async fn verify_hmac(&self, data: &str, secret: &str, expected_hmac: &str) -> Result<bool, Box<dyn std::error::Error>> {
        let computed_hmac = self.generate_hmac(data, secret).await?;
        Ok(computed_hmac == expected_hmac)
    }

    pub async fn generate_jwt_token(&self, payload: &serde_json::Value, secret: &str) -> Result<String, Box<dyn std::error::Error>> {
        use hmac::{Hmac, Mac};
        use sha2::Sha256;
        
        let header = serde_json::json!({
            "alg": "HS256",
            "typ": "JWT"
        });
        
        let header_b64 = general_purpose::STANDARD.encode(header.to_string().as_bytes());
        let payload_b64 = general_purpose::STANDARD.encode(payload.to_string().as_bytes());
        
        let data_to_sign = format!("{}.{}", header_b64, payload_b64);
        
        let mut mac = Hmac::<Sha256>::new_from_slice(secret.as_bytes())?;
        mac.update(data_to_sign.as_bytes());
        
        let signature = mac.finalize();
        let signature_b64 = general_purpose::STANDARD.encode(signature.into_bytes());
        
        Ok(format!("{}.{}.{}", header_b64, payload_b64, signature_b64))
    }

    pub async fn verify_jwt_token(&self, token: &str, secret: &str) -> Result<serde_json::Value, Box<dyn std::error::Error>> {
        let parts: Vec<&str> = token.split('.').collect();
        if parts.len() != 3 {
            return Err("Invalid JWT token format".into());
        }
        
        let (header_b64, payload_b64, signature_b64) = (parts[0], parts[1], parts[2]);
        
        // Verify signature
        let data_to_verify = format!("{}.{}", header_b64, payload_b64);
        let expected_signature = self.generate_hmac(&data_to_verify, secret).await?;
        
        if signature_b64 != expected_signature {
            return Err("Invalid JWT signature".into());
        }
        
        // Decode payload
        let payload_bytes = general_purpose::STANDARD.decode(payload_b64)?;
        let payload_str = String::from_utf8(payload_bytes)?;
        let payload: serde_json::Value = serde_json::from_str(&payload_str)?;
        
        Ok(payload)
    }

    pub async fn generate_secure_random_string(&self, length: usize) -> Result<String, Box<dyn std::error::Error>> {
        let mut bytes = vec![0u8; length];
        self.rng.fill(&mut bytes)?;
        
        // Convert to base64 and truncate to desired length
        let base64_string = general_purpose::STANDARD.encode(&bytes);
        Ok(base64_string[..length].to_string())
    }

    pub async fn validate_file_integrity(&self, file_path: &str, expected_hash: &str) -> Result<bool, Box<dyn std::error::Error>> {
        use std::fs;
        use std::io::Read;
        
        let mut file = fs::File::open(file_path)?;
        let mut contents = Vec::new();
        file.read_to_end(&mut contents)?;
        
        let mut context = Context::new(&SHA256);
        context.update(&contents);
        let digest = context.finish();
        let computed_hash = general_purpose::STANDARD.encode(digest.as_ref());
        
        Ok(computed_hash == expected_hash)
    }

    pub async fn secure_wipe_file(&self, file_path: &str) -> Result<(), Box<dyn std::error::Error>> {
        use std::fs;
        use std::io::Write;
        
        // Overwrite with random data multiple times
        let mut file = fs::OpenOptions::new()
            .write(true)
            .open(file_path)?;
        
        let file_size = file.metadata()?.len() as usize;
        
        for _ in 0..3 {
            let mut random_data = vec![0u8; file_size];
            self.rng.fill(&mut random_data)?;
            file.write_all(&random_data)?;
            file.flush()?;
        }
        
        // Overwrite with zeros
        let zeros = vec![0u8; file_size];
        file.write_all(&zeros)?;
        file.flush()?;
        
        // Delete the file
        fs::remove_file(file_path)?;
        
        info!("File securely wiped: {}", file_path);
        Ok(())
    }

    pub async fn get_security_status(&self) -> Result<serde_json::Value, Box<dyn std::error::Error>> {
        let config = self.config.read().await;
        let encryption_key = self.encryption_key.read().await;
        
        Ok(serde_json::json!({
            "encryption_initialized": encryption_key.is_some(),
            "hmac_secret_configured": config.security.hmac_secret.is_some(),
            "remote_commands_enabled": config.user_consent.remote_commands_enabled,
            "audit_logging_enabled": config.features.audit_logging,
            "timestamp": chrono::Utc::now().to_rfc3339()
        }))
    }
}
