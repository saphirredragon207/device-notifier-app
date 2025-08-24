# Development Guide

## Prerequisites

- **Rust**: 1.70+ (install from [rustup.rs](https://rustup.rs/))
- **Node.js**: 18+ (install from [nodejs.org](https://nodejs.org/))
- **Git**: Latest version
- **Platform-specific tools**:
  - **Windows**: Visual Studio Build Tools, WiX Toolset
  - **macOS**: Xcode Command Line Tools

## Project Structure

```
device-notifier-app/
├── agent/                 # Rust agent service
│   ├── src/
│   │   ├── main.rs       # Main entry point
│   │   ├── config.rs     # Configuration management
│   │   ├── discord.rs    # Discord integration
│   │   ├── events.rs     # Event monitoring
│   │   ├── security.rs   # Security & encryption
│   │   ├── storage.rs    # Secure storage
│   │   ├── system.rs     # System operations
│   │   └── commands.rs   # Command execution
│   └── Cargo.toml        # Rust dependencies
├── gui/                   # Tauri GUI application
│   ├── src/              # React components
│   ├── package.json      # Node.js dependencies
│   └── tauri.conf.json   # Tauri configuration
├── discord-bot/          # Discord bot implementation
│   ├── src/
│   │   └── index.ts      # Bot main logic
│   ├── package.json      # Node.js dependencies
│   └── env.example       # Environment variables
├── installers/           # Platform-specific installers
├── scripts/              # Build and packaging scripts
├── docs/                 # Documentation
└── tests/                # Test suites
```

## Development Setup

### 1. Clone and Setup

```bash
git clone <repository-url>
cd device-notifier-app
```

### 2. Rust Agent Development

```bash
cd agent
cargo build
cargo test
cargo run
```

**Key Dependencies:**
- `tokio`: Async runtime
- `serde`: Serialization
- `ring`: Cryptography
- `sysinfo`: System monitoring
- `reqwest`: HTTP client

### 3. GUI Development

```bash
cd gui
npm install
npm run tauri dev
```

**Key Dependencies:**
- `@tauri-apps/api`: Tauri API bindings
- `react`: UI framework
- `tailwindcss`: Styling

### 4. Discord Bot Development

```bash
cd discord-bot
npm install
npm run dev
```

**Key Dependencies:**
- `discord.js`: Discord API client
- `winston`: Logging
- `dotenv`: Environment configuration

## Building

### Development Build

```bash
# Build Rust agent
cd agent && cargo build

# Build GUI
cd gui && npm run tauri dev

# Build Discord bot
cd discord-bot && npm run build
```

### Production Build

```bash
# Build everything
./scripts/build-installers.sh

# Or build individually
cd agent && cargo build --release
cd gui && npm run tauri build
cd discord-bot && npm run build
```

## Testing

### Rust Tests

```bash
cd agent
cargo test                    # Unit tests
cargo test --test integration # Integration tests
cargo test --release          # Release mode tests
```

### GUI Tests

```bash
cd gui
npm test                      # Unit tests
npm run test:e2e             # End-to-end tests
```

### Integration Tests

```bash
# Test Discord integration
cd discord-bot
npm run test:integration

# Test full system
./scripts/test-integration.sh
```

## Security Considerations

### Code Review Checklist

- [ ] Input validation and sanitization
- [ ] Secure random number generation
- [ ] Proper error handling (no information leakage)
- [ ] Authentication and authorization checks
- [ ] Rate limiting implementation
- [ ] Secure storage of secrets
- [ ] Audit logging for sensitive operations

### Security Testing

```bash
# Run security lints
cargo audit
cargo clippy -- -D warnings

# Run fuzzing tests
cargo install cargo-fuzz
cargo fuzz run security_tests
```

## Contributing

### Code Style

- **Rust**: Follow [rust-lang/rustfmt](https://github.com/rust-lang/rustfmt)
- **TypeScript**: Use Prettier and ESLint
- **Commits**: Follow [Conventional Commits](https://conventionalcommits.org/)

### Pull Request Process

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes with tests
4. Run the full test suite
5. Commit with conventional commit format
6. Push to your fork
7. Create a Pull Request

### Testing Checklist

- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Security tests pass
- [ ] Cross-platform compatibility verified
- [ ] Documentation updated
- [ ] No breaking changes (or documented)

## Debugging

### Rust Agent

```bash
# Enable debug logging
RUST_LOG=debug cargo run

# Profile with flamegraph
cargo install flamegraph
cargo flamegraph

# Debug with GDB/LLDB
cargo build --debug
gdb target/debug/device-notifier
```

### GUI Application

```bash
# Enable Tauri debug mode
npm run tauri dev -- --debug

# View console logs
# Check browser dev tools in the Tauri window
```

### Discord Bot

```bash
# Enable verbose logging
LOG_LEVEL=debug npm run dev

# Test commands locally
npm run test:commands
```

## Performance Optimization

### Rust Agent

- Use `cargo build --release` for production builds
- Profile with `cargo install cargo-profiler`
- Monitor memory usage with `cargo install cargo-valgrind`

### GUI Application

- Bundle size optimization with `npm run tauri build --analyze`
- Lazy loading of components
- Virtual scrolling for large lists

## Deployment

### Release Process

1. Update version numbers in all files
2. Run full test suite
3. Build release artifacts
4. Create GitHub release
5. Update documentation

### CI/CD Pipeline

The project uses GitHub Actions for:
- Automated testing
- Security scanning
- Cross-platform builds
- Release automation

## Troubleshooting

### Common Issues

1. **Build failures**
   - Check Rust/Node.js versions
   - Clear cargo/node_modules and rebuild
   - Verify platform-specific dependencies

2. **Runtime errors**
   - Check log files
   - Verify configuration
   - Test with minimal configuration

3. **Cross-platform issues**
   - Test on target platforms
   - Use CI/CD for validation
   - Check platform-specific code paths

### Getting Help

- Check existing issues on GitHub
- Review documentation
- Ask in discussions
- Contact maintainers for security issues
