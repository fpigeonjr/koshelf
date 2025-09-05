# Agent Guidelines for KOShelf

## Project Overview
KOShelf is a containerized ebook library management system that generates static websites from EPUB collections with KOReader synchronization. This is a deployment repository using prebuilt binaries with Podman/Docker orchestration.

## Core Architecture
- **Application**: KOShelf v1.0.20 ARM64 binary with file watching and auto-detection
- **Auto-Detection**: Real-time Syncthing monitoring for automatic highlight and progress sync
- **Synchronization**: Syncthing integration for KOReader devices  
- **Web Server**: nginx reverse proxy for static site delivery
- **Data**: Persistent volumes for books, generated sites, and sync data
- **Orchestration**: Podman Compose with streamlined service dependencies

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
- **Dual Detection System**: Combines inotify watchers with backup polling for maximum reliability
- **inotify Watchers**: Primary detection method for real-time file system events
- **Backup Polling**: Secondary detection (configurable interval, default 30s) for macOS Docker compatibility
- **Enhanced Content Detection**: Monitors both directory creation AND file modifications within .sdr folders
- **Event Filtering**: Focus on create, delete, modify, move events
- **Auto-detection Triggers**: New .sdr folder creation, EPUB additions, highlight updates
- **Graceful Handling**: Robust handling of rapid file changes and file system limitations
- **macOS Compatibility**: Polling mechanism ensures reliable detection with Docker bind mounts
- **Cross-platform**: Works on Linux (primarily inotify) and macOS (primarily polling)

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

## Syncthing Integration System

### Architecture
The Syncthing integration provides real-time bidirectional sync between KOReader devices and the KOShelf library.

### Key Components
1. **Dual Folder Sync**: Separate sync for settings and documents directories
2. **Dual Detection System**: inotify watchers + backup polling for reliability across platforms
3. **Real-time Monitoring**: Primary inotify detection with polling fallback
4. **Smart Conflict Resolution**: Syncthing handles file conflicts gracefully
5. **Auto-regeneration**: Site updates automatically when content changes detected by either system
6. **Enhanced Content Detection**: Monitors file modifications within existing .sdr directories

### Implementation Details
- **Settings Sync**: `/mnt/us/koreader/settings/` ↔ `~/Code/koshelf/data/koreader-settings/`
  - Statistics database (reading progress, highlight counts)
  - KOReader configuration and preferences
- **Documents Sync**: `/mnt/us/documents/` ↔ `~/Code/koshelf/data/books/`
  - EPUB files and .sdr metadata directories
  - Complete highlight and annotation content
- **File Handling**: Automatic sync with configurable ignore patterns
- **Error Recovery**: Graceful handling of sync conflicts and network issues

### Sync Locations
1. **KOReader Settings Directory** - Configuration and statistics
2. **Documents Directory** - EPUBs and metadata (.sdr folders)
3. **Bidirectional Sync** - Changes flow both ways seamlessly
4. **Real-time Updates** - No manual intervention required

### Configuration
- **Ignore Patterns**: Configured to avoid syncing temporary and system files
- **Conflict Resolution**: Syncthing handles file conflicts automatically
- **Monitoring**: Dual detection system (inotify + polling) triggers immediate site regeneration
- **Security**: Local network sync with device authentication
- **Polling Interval**: Configurable via `POLL_INTERVAL` environment variable (default: 30s)
- **Platform Compatibility**: Optimized for both Linux (inotify-primary) and macOS (polling-primary)

## Auto-Regeneration System

### Technical Background
The auto-regeneration system addresses a critical issue with file watching in containerized environments, particularly on macOS where Docker bind mounts don't reliably trigger inotify events for file changes made on the host system.

### Problem Statement
- **inotify Limitations**: inotify file watchers inside Docker containers don't detect file changes made by external processes (like Syncthing) on macOS host systems
- **Syncthing Integration**: File changes from KOReader devices sync to the host via Syncthing, but containers don't detect these changes
- **Manual Intervention**: Previously required container restarts to detect new highlights and content

### Solution Architecture
A robust dual-detection system that combines the efficiency of inotify with the reliability of polling:

#### Primary Detection (inotify)
- **Real-time Events**: Detects file system changes instantly when supported
- **Low Resource Usage**: Minimal CPU overhead for event-driven detection
- **Event Types**: Monitors create, delete, modify, move operations
- **Multiple Watchers**: Separate processes for books, settings, and statistics directories

#### Backup Detection (Polling)
- **Cross-platform Compatibility**: Works reliably on all platforms and container environments
- **Content Change Detection**: Monitors file modification timestamps within .sdr directories
- **Configurable Intervals**: Default 30-second polling with `POLL_INTERVAL` environment variable
- **Comprehensive Monitoring**: Tracks directory counts AND content modifications

### Implementation Details
Located in `docker/koshelf/entrypoint.sh`, the system implements:

1. **Multiple Background Processes**:
   - Books directory watcher (inotify)
   - KOReader settings watcher (inotify)  
   - Statistics database watcher (inotify)
   - Backup polling process (timed)

2. **Enhanced Detection Logic**:
   - EPUB file count monitoring
   - .sdr directory count monitoring
   - File modification timestamp tracking within .sdr directories
   - Statistics database change detection

3. **Graceful Degradation**:
   - If inotify fails, polling continues to provide detection
   - Both systems can trigger regeneration independently
   - No duplicate regenerations from simultaneous detection

### Environment Variables
```bash
KOSHELF_WATCH_INTERVAL=5    # inotify check interval (seconds)
POLL_INTERVAL=30            # Polling backup interval (seconds)
```

### Monitoring and Debugging
```bash
# Monitor all detection events
podman-compose logs -f koshelf | grep -E "file change detected|Polling detected"

# Check running watchers
podman exec koshelf ps aux | grep -E "inotifywait|backup_poll"

# Test polling manually
podman exec koshelf touch /app/books/test && rm /app/books/test
```

### Performance Impact
- **inotify**: Negligible CPU usage, instant detection
- **Polling**: ~0.1% CPU usage, 30-second detection latency
- **Combined**: Reliable detection with minimal resource overhead
- **Scalability**: Suitable for libraries with hundreds of books

## Testing & Validation

### Manual Testing Procedures
1. **Container Health**: `podman-compose ps` - all services running
2. **Web Interface**: Access http://koshelf.books (or http://localhost:8090)
3. **Syncthing Status**: Check sync status at http://localhost:8384
4. **File Watching**: Add EPUB to `data/books/`, verify regeneration
5. **Sync Testing**: Make highlight on device, verify sync and regeneration
6. **Domain Resolution**: `nslookup koshelf.books` should resolve to 192.168.1.150
7. **Auto-Regeneration**: Monitor logs for both inotify and polling detection messages
8. **Polling Verification**: Check watchers are running with `podman exec koshelf ps aux | grep -E "inotifywait|backup_poll"`

### Debugging Workflows
1. **Log Analysis**: Start with `podman-compose logs -f`
2. **Container Shell**: Use `podman exec -it` for internal investigation
3. **Network Testing**: Verify connectivity between containers
4. **Volume Inspection**: Check data persistence and permissions
5. **Resource Monitoring**: Use `podman stats` for performance issues

### Common Issues & Solutions
- **Port Conflicts**: Check for existing services on port 8090 (Calibre uses 8080)
- **File Permissions**: Ensure EPUB files are readable by container
- **Syncthing Issues**: Verify Syncthing is running and devices are connected
- **Auto-Regeneration Not Working**: Check both inotify watchers AND polling are running
- **macOS Docker Bind Mount Issues**: Polling provides backup detection when inotify fails
- **Resource Limits**: Monitor container memory/CPU usage
- **Volume Mounts**: Validate bind mount paths and permissions
- **Domain Access**: Ensure Pi-hole DNS and nginx reverse proxy are configured
- **DNS Resolution**: Flush DNS cache with `sudo dscacheutil -flushcache` if needed
- **File Detection**: Use `podman-compose logs -f koshelf | grep -E "file change detected|Polling detected"` to monitor detection events

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

### Mac Mini Server Configuration
- **Static IP**: 192.168.1.150 (reserved in router DHCP)
- **Domain**: koshelf.books (via Pi-hole DNS)
- **Services**: 
  - KOShelf on port 8090 (containerized)
  - Calibre on port 8080 (native)
  - nginx reverse proxy on port 80 (for domain access)
  - Syncthing on port 8384 (for device sync management)
- **DNS Setup**: Pi-hole at 192.168.1.100 resolves koshelf.books
- **Access**: http://koshelf.books (no port needed)

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

### When Debugging Auto-Regeneration Issues
- **Check Both Systems**: Verify both inotify and polling processes are running
- **Monitor Detection Logs**: Use grep patterns to filter for detection events
- **Test Each System**: Manually trigger file changes to test detection
- **Validate Container State**: Ensure watchers survive container restarts
- **Platform Considerations**: Remember macOS relies more heavily on polling
- **Timeout Issues**: Check if polling interval needs adjustment for large libraries

### When Debugging Issues
- Start with least invasive debugging (logs, status)
- Use container shell access for internal investigation
- Test individual components before full stack
- Document reproduction steps for complex issues