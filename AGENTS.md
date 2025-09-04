# Agent Guidelines for KOShelf

## Project Overview
KOShelf is a containerized ebook library management system that generates static websites from EPUB collections with KOReader synchronization. This is a deployment repository using prebuilt binaries with Podman/Docker orchestration.

## Core Architecture
- **Application**: KOShelf v1.0.20 ARM64 binary with file watching and auto-detection
- **Auto-Detection**: WebDAV monitoring for automatic EPUB import from OPDS downloads
- **Synchronization**: Apache WebDAV server for KOReader devices  
- **Web Server**: nginx reverse proxy for static site delivery
- **Data**: Persistent volumes for books, generated sites, and sync data
- **Orchestration**: Podman Compose with proper service dependencies

## Build/Test Commands
```bash
# Primary workflow commands
podman-compose up -d                    # Start all services
podman-compose down                     # Stop all services  
podman-compose build --no-cache         # Rebuild containers
podman-compose restart koshelf          # Restart KOShelf (triggers rebuild)

# Monitoring and debugging
podman-compose logs -f                  # Follow all logs
podman-compose logs koshelf             # KOShelf app logs only
podman-compose logs webdav              # WebDAV server logs
podman-compose ps                       # Service status overview
podman-compose top                      # Container processes

# Advanced operations
podman exec -it koshelf-app /bin/bash   # Shell into KOShelf container
podman system prune -f                  # Clean unused resources
podman volume inspect koshelf_books_data # Examine volume details
```

## Project Structure & Key Files
```
koshelf/
├── docker-compose.yml              # Service orchestration & dependencies
├── docker/                         # Container build contexts
│   ├── koshelf/                    # KOShelf application
│   │   ├── Dockerfile              # ARM64 binary + inotify tools
│   │   └── entrypoint.sh           # File watching + HTTP server logic
│   ├── nginx/                      # Static site proxy
│   │   ├── Dockerfile              # nginx:alpine configuration
│   │   └── default.conf            # Optimized static serving
│   └── webdav/                     # WebDAV server for KOReader
│       ├── Dockerfile              # bytemark/webdav customization
│       └── nginx.conf              # WebDAV-specific config
├── data/                           # Persistent data volumes
│   ├── books/                      # EPUB library (user content)
│   ├── koreader-settings/          # Sync data & reading statistics
│   └── site-output/                # Generated static websites
├── scripts/                        # Utility scripts
│   ├── auto-find-book.sh           # Auto EPUB detection and copying
│   ├── backup.sh                   # Data backup automation
│   ├── extract_highlights.py       # KOReader highlights from database
│   ├── extract_sdr_highlights.py   # Full highlight extraction from .sdr files
│   ├── setup.sh                    # Initial setup helper
│   └── sync-kindle-books.sh        # Kindle import automation
└── .env.example                    # Environment template
```

## Code Style Guidelines

### Shell Scripts (entrypoint.sh, utilities)
- Use `#!/bin/bash` with `set -e` for error handling
- Employ proper variable quoting: `"$VARIABLE"` 
- Use descriptive variable names: `BOOKS_DIR` not `BD`
- Environment variable pattern: `${VAR:-default_value}`
- Function definitions for complex logic
- Comprehensive error checking and logging

### Docker/Containerfiles
- Multi-stage builds when appropriate for size optimization
- Minimal base images (debian:bookworm-slim, nginx:alpine)
- Strategic COPY ordering for Docker layer caching
- Proper volume declarations and port exposure
- Security: non-root users where possible
- Resource limits and health checks for production

### Environment Variables
- Consistent naming: `KOSHELF_*` prefix for application vars
- Sensible defaults: `${KOSHELF_WATCH_INTERVAL:-5}`
- Documentation: Comment complex environment configurations
- Validation: Check required variables in entrypoint scripts

### File Organization
- Related configurations grouped in `docker/` subdirectories
- Utility scripts in dedicated `scripts/` directory
- Clear separation between build context and runtime data
- Consistent file naming conventions (kebab-case for scripts)

## Development Patterns

### File Watching Implementation
- Use inotify for efficient file system monitoring
- Dual watchers: books directory + KOReader settings directory
- Configurable watch intervals to prevent excessive rebuilds
- Event filtering: focus on create, delete, modify, move
- Auto-detection triggers on new .sdr folder creation
- Graceful handling of rapid file changes

### Container Communication
- Internal bridge networks for service isolation
- Service dependencies in docker-compose.yml
- Environment-based configuration over hardcoded values
- Health checks and restart policies

### Data Management
- Bind mounts for development flexibility
- Named volumes for production data persistence
- Backup strategies for critical user data
- Clear separation of application and user data

## Auto-Detection System

### Architecture
The auto-detection system monitors KOReader WebDAV sync data to automatically import EPUBs when users start reading OPDS-downloaded books.

### Key Components
1. **WebDAV Watcher**: Monitors `koreader-settings/` for new `.sdr` metadata folders
2. **Auto-Find Script**: Searches mounted devices and common locations for EPUBs
3. **Smart Matching**: Handles filename variations and case sensitivity
4. **Fallback Logging**: Provides clear guidance when auto-detection fails

### Implementation Details
- **Detection Trigger**: New `.sdr` directory creation in WebDAV sync folder
- **Search Strategy**: Prioritized search through common device mount points
- **File Handling**: Automatic copying with filename normalization
- **Error Recovery**: Graceful degradation with user guidance

### Search Locations (Priority Order)
1. `/Volumes/Kindle/documents` - Kindle via USB
2. `/Volumes/*/documents` - Other e-readers via USB
3. `/mnt/*/documents` - Linux mount points
4. `/media/*/documents` - Alternative Linux mounts
5. `~/Downloads` - Common download location
6. `~/Documents` - Documents folder

### Configuration
- **Watch Interval**: Configurable via `KOSHELF_WATCH_INTERVAL`
- **Search Paths**: Extensible in `auto-find-book.sh`
- **Matching Logic**: Supports exact, case-insensitive, and partial matches
- **Logging Level**: Detailed output for debugging auto-detection issues

## Testing & Validation

### Manual Testing Procedures
1. **Container Health**: `podman-compose ps` - all services running
2. **Web Interface**: Access http://localhost:3000
3. **WebDAV Connectivity**: `curl -u koreader:koreader123 http://localhost:8081/`
4. **File Watching**: Add EPUB to `data/books/`, verify regeneration
5. **Auto-Detection**: Create test .sdr folder in `data/koreader-settings/`, verify detection
6. **KOReader Sync**: Test device connection and sync functionality

### Debugging Workflows
1. **Log Analysis**: Start with `podman-compose logs -f`
2. **Container Shell**: Use `podman exec -it` for internal investigation
3. **Network Testing**: Verify connectivity between containers
4. **Volume Inspection**: Check data persistence and permissions
5. **Resource Monitoring**: Use `podman stats` for performance issues

### Common Issues & Solutions
- **Port Conflicts**: Check for existing services on 3000/8081
- **File Permissions**: Ensure EPUB files are readable by container
- **Network Isolation**: Verify devices on same subnet for WebDAV
- **Resource Limits**: Monitor container memory/CPU usage
- **Volume Mounts**: Validate bind mount paths and permissions

## Environment Considerations

### Development Setup
- macOS with Podman Desktop recommended
- Local IP discovery for KOReader configuration
- Fast filesystem for efficient file watching
- Sufficient disk space for EPUB library and generated sites

### Production Deployment
- Consider security implications of WebDAV basic auth
- Implement proper backup strategies for user data
- Network firewall configuration for external access
- SSL/TLS termination for secure WebDAV connections

## Agent-Specific Notes

### When Modifying Containers
- Always test build process: `podman-compose build --no-cache`
- Verify volume mounts are preserved
- Check service dependencies remain correct
- Test full startup sequence: `podman-compose up -d`

### When Updating Configuration
- Validate environment variable usage in entrypoint scripts
- Test configuration changes in isolation
- Document breaking changes in commit messages
- Verify backward compatibility with existing data

### When Debugging Issues
- Start with least invasive debugging (logs, status)
- Use container shell access for internal investigation
- Test individual components before full stack
- Document reproduction steps for complex issues