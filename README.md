# KOShelf Deployment

A sophisticated Podman-based deployment setup for [KOShelf](https://github.com/paviro/KoShelf) - a static site generator that creates beautiful library websites from your ebook collection with comprehensive KOReader synchronization.

## Features

- 📚 **Auto-generated library sites** with responsive design and search
- 🔄 **Real-time file watching** - instant site regeneration on library changes
- 📱 **WebDAV server** for seamless KOReader device synchronization
- 📊 **Reading statistics integration** from KOReader SQLite databases
- 🌐 **Local network access** via optimized nginx reverse proxy
- 📦 **Podman Compose orchestration** with proper service dependencies
- 💾 **Persistent data volumes** for books, generated sites, and sync data
- ⚡ **ARM64 optimized** with prebuilt binaries for performance

## Quick Start

1. **Clone and setup**:
   ```bash
   git clone https://github.com/fpigeonjr/koshelf.git
   cd koshelf
   podman-compose up -d
   ```

2. **Add your books**:
   ```bash
   cp /path/to/your/books/*.epub ./data/books/
   ```

3. **Access your library**:
   - 📖 **Web interface**: http://localhost:3000
   - ⚙️ **WebDAV (KOReader sync)**: http://YOUR_IP:8081

## Architecture

```
┌─────────────────────┐    ┌──────────────────────┐    ┌─────────────────────┐
│   KOShelf App       │    │   WebDAV Server      │    │  Nginx Proxy        │
│ (ARM64 v1.0.20)     │    │ (Apache/bytemark)    │    │ (Static Delivery)   │
│                     │    │                      │    │                     │
│ • inotify watching  │    │ • KOReader sync      │    │ • Optimized serving │
│ • Site generation   │    │ • Basic auth         │    │ • Gzip compression  │
│ • SQLite stats      │    │ • Progress tracking  │    │ • Cache headers     │
│ • Auto-rebuild      │    │ • Port 8081          │    │ • Port 3000         │
│ • Python3 server    │    │                      │    │                     │
└─────────────────────┘    └──────────────────────┘    └─────────────────────┘
          │                          │                          │
          └──────────────────────────┼──────────────────────────┘
                                     │
                         ┌───────────▼───────────┐
                         │  Persistent Volumes   │
                         │ (Host Bind Mounts)    │
                         │                       │
                         │ • ./data/books/       │
                         │ • ./data/site-output/ │
                         │ • ./data/koreader-*   │
                         └───────────────────────┘
```

### Service Communication
- **Internal Network**: Isolated `koshelf-network` bridge
- **Dependency Chain**: nginx → koshelf → webdav
- **Volume Sharing**: All services access shared data volumes
- **Health Monitoring**: Automatic container restart policies

## KOReader WebDAV Setup

### 1. Find Your Mac's IP Address
```bash
ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1
```

### 2. Configure KOReader
In KOReader: **Settings → Network → Cloud storage → WebDAV**
- **Address**: `http://YOUR_MAC_IP:8081`
- **Username**: `koreader`
- **Password**: `koreader123`
- **Directory**: Leave empty or use `/`

### 3. Test Connection
- Tap **"Test"** to verify connectivity
- Enable sync for reading progress, bookmarks, notes

## Management Commands

### Development Workflow
```bash
# Quick start
podman-compose up -d              # Start all services
podman-compose logs -f            # Follow all logs in real-time

# Service management  
podman-compose restart koshelf    # Restart KOShelf (triggers rebuild)
podman-compose down               # Stop all services
podman-compose build --no-cache   # Rebuild containers from scratch
```

### Monitoring & Debugging
```bash
# Check service health
podman-compose ps                 # Service status overview
podman-compose top               # Container process information

# Examine logs
podman-compose logs koshelf      # KOShelf application logs
podman-compose logs webdav       # WebDAV server logs  
podman-compose logs nginx        # Nginx proxy logs
podman-compose logs --tail=50 -f # Last 50 lines, follow mode
```

### Library Management
```bash
# Add books (triggers auto-regeneration)
cp ~/Downloads/books/*.epub ./data/books/
cp /Volumes/Kindle/documents/*.epub ./data/books/

# Bulk operations
find ~/Documents -name "*.epub" -exec cp {} ./data/books/ \;

# Force regeneration
podman-compose restart koshelf
```

### Advanced Operations
```bash
# Container shell access
podman exec -it koshelf-app /bin/bash
podman exec -it koshelf-webdav /bin/bash

# Volume inspection
podman volume ls | grep koshelf
podman volume inspect koshelf_books_data

# Network troubleshooting
podman network inspect koshelf_koshelf-network
```

## Directory Structure

```
koshelf/
├── docker-compose.yml           # Service orchestration
├── docker/                      # Container definitions
│   ├── koshelf/                 # KOShelf app container
│   │   ├── Dockerfile           # ARM64 binary deployment
│   │   └── entrypoint.sh        # File watching + HTTP server
│   ├── nginx/                   # Static site proxy
│   └── webdav/                  # WebDAV server config
├── data/                        # Persistent data
│   ├── books/                   # Your ebook library (.epub files)
│   ├── koreader-settings/       # KOReader sync data
│   └── site-output/             # Generated static site
├── scripts/                     # Utility scripts
└── .env.example                 # Environment template
```

## Troubleshooting

### KOReader Connectivity Issues
1. **Network Discovery**:
   ```bash
   # Find your machine's IP address
   ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1
   # Alternative methods
   hostname -I | awk '{print $1}'      # Linux
   ipconfig getifaddr en0              # macOS WiFi
   ```

2. **Connection Testing**:
   ```bash
   # Test WebDAV server directly
   curl -u koreader:koreader123 http://YOUR_IP:8081/
   curl -I http://YOUR_IP:8081/        # Check if service responds
   
   # Verify from KOReader device
   ping YOUR_MAC_IP                    # Network connectivity
   wget http://YOUR_IP:3000            # Web interface access
   ```

3. **Service Verification**:
   ```bash
   podman-compose ps                   # All containers running?
   podman port koshelf-webdav         # Port mapping confirmation
   podman-compose logs webdav         # Authentication issues?
   ```

### Library Generation Problems
1. **File Format Issues**:
   ```bash
   # Check file permissions and formats
   ls -la ./data/books/*.epub
   file ./data/books/*.epub           # Verify EPUB format
   
   # Common issues
   find ./data/books -name "*.epub" -size 0    # Empty files
   find ./data/books -name "*.epub.*"          # Damaged extensions
   ```

2. **Debug Site Generation**:
   ```bash
   # Manual generation with verbose output
   podman exec -it koshelf-app koshelf --books-path /app/books --output /app/site-output --title "Debug Library" --include-unread
   
   # Check output directory
   podman exec -it koshelf-app ls -la /app/site-output/
   ```

### WebDAV Synchronization Issues
1. **Authentication Testing**:
   ```bash
   # Test credentials manually
   curl -u koreader:koreader123 -X PROPFIND http://YOUR_IP:8081/
   
   # Check WebDAV configuration
   podman-compose exec webdav cat /etc/apache2/sites-enabled/000-default.conf
   ```

2. **Sync Data Investigation**:
   ```bash
   # Examine sync files
   ls -la ./data/koreader-settings/
   find ./data/koreader-settings -name "*.sdr" -exec ls -la {} \;
   
   # Statistics database
   file ./data/koreader-settings/data/statistics.sqlite3
   ```

### Performance & Resource Issues
1. **Container Resource Usage**:
   ```bash
   podman stats                       # Real-time resource usage
   podman system df                   # Disk usage
   podman system prune               # Clean unused resources
   ```

2. **File Watching Optimization**:
   ```bash
   # Check inotify limits (Linux)
   cat /proc/sys/fs/inotify/max_user_watches
   
   # Increase if needed
   echo 524288 | sudo tee /proc/sys/fs/inotify/max_user_watches
   ```

### Complete Reset & Rebuild
```bash
# Nuclear option - complete cleanup
podman-compose down
podman system prune -f
podman volume prune -f
podman-compose build --no-cache
podman-compose up -d

# Preserve data but reset containers
podman-compose down
podman-compose build --no-cache
podman-compose up -d
```

## Technical Details

### Application Stack
- **KOShelf Version**: v1.0.20 (ARM64 prebuilt binary)
- **WebDAV Server**: bytemark/webdav (Apache 2.4 based)
- **Reverse Proxy**: nginx:alpine (optimized for static content)
- **Container Runtime**: Podman Compose v4.x
- **Base Images**: debian:bookworm-slim, nginx:alpine

### Environment Variables & Configuration
```bash
# KOShelf Application
KOSHELF_WATCH_MODE=true                    # Enable file watching
KOSHELF_OUTPUT_DIR=/app/site-output        # Generated site location
KOSHELF_BOOKS_DIR=/app/books               # EPUB library path
KOSHELF_STATISTICS_DB=/app/koreader-settings/data/statistics.sqlite3
KOSHELF_WATCH_INTERVAL=5                   # Seconds between checks
KOSHELF_TITLE="KoShelf Library"            # Site title
KOSHELF_PORT=3000                          # Internal HTTP port

# WebDAV Server
AUTH_TYPE=Basic                            # Authentication method
USERNAME=koreader                          # WebDAV username
PASSWORD=koreader123                       # WebDAV password
```

### File System Layout
```
./data/
├── books/                          # EPUB library (bind mount)
│   ├── *.epub                      # Book files
│   └── *.sdr/                      # KOReader metadata directories
│       ├── metadata.epub.lua       # Book metadata
│       └── metadata.epub.lua.old   # Backup metadata
├── koreader-settings/              # KOReader sync data
│   └── data/
│       └── statistics.sqlite3      # Reading statistics
└── site-output/                    # Generated static website
    ├── index.html                  # Main library page
    ├── books/                      # Individual book pages
    ├── assets/                     # CSS, JS, images
    └── search/                     # Search functionality
```

### Network Architecture
- **Bridge Network**: `koshelf-network` (172.x.x.x/16 subnet)
- **External Ports**: 3000 (nginx), 8081 (webdav)
- **Internal Communication**: Container name resolution
- **Security**: No external database ports exposed

### Performance Considerations
- **File Watching**: inotify-based for minimal CPU overhead
- **Static Generation**: Full rebuild on any library change
- **Caching**: nginx serves static files with optimized headers
- **Resource Usage**: ~100MB RAM total for all containers
- **Storage**: Generated sites typically 1-5MB per 100 books

## License

This deployment configuration is provided under the same license as KOShelf. See the [original KOShelf repository](https://github.com/paviro/KoShelf) for details.
