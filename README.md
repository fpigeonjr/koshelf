# KOShelf Deployment

A sophisticated Podman-based deployment setup for [KOShelf](https://github.com/paviro/KoShelf) - a static site generator that creates beautiful library websites from your ebook collection with comprehensive KOReader synchronization.

## Features

- 📚 **Auto-generated library sites** with responsive design and search
- 🔄 **Real-time file watching** - instant site regeneration on library changes
- 🤖 **Auto-book detection** - automatically finds and imports EPUBs when you start reading
- 🔄 **Syncthing integration** for seamless KOReader device synchronization
- 📊 **Reading statistics integration** from KOReader SQLite databases
- 🌐 **Local network access** via optimized nginx reverse proxy
- 📦 **Podman Compose orchestration** with proper service dependencies
- 💾 **Persistent data volumes** for books, generated sites, and sync data
- ⚡ **ARM64 optimized** with prebuilt binaries for performance

## Quick Start

### 1. **Clone and setup**:
```bash
git clone https://github.com/fpigeonjr/koshelf.git
cd koshelf
podman-compose up -d
```

### 2. **Add your books**:
```bash
cp /path/to/your/books/*.epub ./data/books/
```

### 3. **Access your library**:
- 📖 **Web interface**: http://koshelf.books (see Custom Domain Setup below)
- 🔄 **Syncthing sync**: Configure KOReader Syncthing plugin (see KOReader Syncthing Setup below)

## Reading Workflows

### Option A: Syncthing Integration (Recommended)
1. **Install KOReader Syncthing plugin** - Download and install on your KOReader device
2. **Configure documents folder sync** - Sync your entire documents directory
3. **Start reading** - Books and highlights sync automatically in real-time
4. **Auto-detection** - KOShelf detects new books and highlights automatically

### Option B: Manual Book Management
1. **Copy EPUBs** - Manually place EPUB files in `./data/books/`
2. **Transfer to device** - Copy books to your KOReader device
3. **Manual sync** - Periodically copy .sdr metadata files back
4. **Read and manage** - Manual coordination of library updates

### Option C: Device Sync Scripts
Use the included scripts for device-specific workflows:
```bash
# Kindle device sync
./scripts/sync-kindle-books.sh

# Extract highlights to readable formats
./scripts/extract_sdr_highlights.py ./data/books --format markdown
```

## Architecture

```
┌─────────────────────┐    ┌─────────────────────┐
│   KOShelf App       │    │  Nginx Proxy        │
│ (ARM64 v1.0.20)     │    │ (Static Delivery)   │
│                     │    │                     │
│ • inotify watching  │    │ • Optimized serving │
│ • Auto-detection    │    │ • Gzip compression  │
│ • Site generation   │    │ • Cache headers     │
│ • SQLite stats      │    │ • Port 8090         │
│ • Auto-rebuild      │    │                     │
│ • Python3 server    │    │                     │
└─────────────────────┘    └─────────────────────┘
          │                          │
          └──────────────────────────┘
                     │
         ┌───────────▼───────────┐
         │  Persistent Volumes   │
         │ (Host Bind Mounts)    │
         │                       │
         │ • ./data/books/       │
         │ • ./data/site-output/ │
         │ • ./data/koreader-*   │
         └───────────────────────┘
                     │
         ┌───────────▼───────────┐
         │   Syncthing Sync      │
         │ (KOReader Device)     │
         │                       │
         │ • Real-time sync      │
         │ • Bidirectional       │
         │ • Auto-detection      │
         │ • .sdr metadata       │
         │ • Statistics DB       │
         └───────────────────────┘
```

### Service Communication
- **Internal Network**: Isolated `koshelf-network` bridge
- **Dependency Chain**: nginx → koshelf
- **Volume Sharing**: Services access shared data volumes
- **Health Monitoring**: Automatic container restart policies
- **External Sync**: Syncthing handles KOReader device communication

## Custom Domain Setup (koshelf.books)

For seamless access without port numbers, you can set up a custom domain on your local network:

### Prerequisites
- Pi-hole or local DNS server on your network
- nginx installed on your Mac (for reverse proxy)

### 1. Configure nginx reverse proxy
```bash
# Install nginx (if not already installed)
brew install nginx

# Create server configuration
sudo tee /opt/homebrew/etc/nginx/servers/koshelf.conf << 'EOF'
server {
    listen 80;
    server_name koshelf.books;

    location / {
        proxy_pass http://127.0.0.1:8090;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Test and start nginx
sudo nginx -t
sudo nginx
```

### 2. Add DNS record to Pi-hole
1. Access your Pi-hole admin interface (e.g., http://192.168.1.100/admin)
2. Go to "Local DNS" → "DNS Records"
3. Add new record:
   - **Domain**: `koshelf.books`
   - **IP Address**: Your Mac's IP (e.g., `192.168.1.150`)

### 3. Access your library
Once configured, access your library at: **http://koshelf.books**

### Note: Port Configuration
This setup assumes KOShelf runs on port 8090 (instead of 3000) to avoid conflicts with Calibre on port 8080. The docker-compose.yml has been configured accordingly.

## KOReader Syncthing Setup

### 1. Install Syncthing Plugin on KOReader
Download the Syncthing plugin for KOReader and install it manually:

1. **Download plugin**: Get the latest `syncthing.koplugin` from KOReader plugins repository
2. **Install manually**: Copy to `/mnt/us/koreader/plugins/syncthing.koplugin` on your Kindle
3. **Restart KOReader**: Plugin should appear in the Tools menu

### 2. Configure Syncthing on Mac
```bash
# Install Syncthing (if not already installed)
brew install syncthing

# Start Syncthing
syncthing
```

### 3. Set Up Two-Folder Sync (Required)
Configure Syncthing to sync BOTH directories for complete functionality:

#### Folder 1: Documents (Books + Metadata)
- **Mac path**: `~/Code/koshelf/data/books`
- **Kindle path**: `/mnt/us/documents`
- **Purpose**: EPUB files and .sdr metadata directories with highlights, reading progress
- **Type**: Receive Only (Mac receives changes from Kindle)

#### Folder 2: Settings (Statistics Database)
- **Mac path**: `~/Code/koshelf/data/koreader-settings`
- **Kindle path**: `/mnt/us/koreader/settings`
- **Purpose**: Statistics database, app settings, reading calendar data
- **Type**: Receive Only (Mac receives changes from Kindle)
- **Important**: Create symlink `data/statistics.sqlite3 → ../statistics.sqlite3` for KOShelf compatibility

### 4. Configure Ignore Patterns ⚠️ CRITICAL for Statistics
For both folders, use these ignore patterns (IMPORTANT: do NOT exclude SQLite WAL files):
```
/.syncthing/
/.stfolder
*.tmp
*.sync
*~
.DS_Store
DavLock*
```

**⚠️ WARNING**: Do NOT add `*-shm` or `*-wal` patterns to `.stignore` files. SQLite WAL (Write-Ahead Log) files contain recent database changes that must sync for statistics and calendar pages to update properly.

### 5. Test Sync
1. **Make a highlight** in KOReader
2. **Check sync status** in Syncthing web UI
3. **Verify files appear** in Mac `~/Code/koshelf/data/books` directory
4. **Confirm KOShelf updates** automatically

## Auto-Detection & Auto-Regeneration

KOShelf automatically detects when you start reading new books and when highlights are added through real-time Syncthing synchronization with a robust dual-detection system.

### How It Works
1. **Dual Detection System** - Combines inotify watchers with polling for maximum reliability
2. **inotify Watchers** - Real-time file system events for immediate detection (when supported)
3. **Backup Polling** - Periodic monitoring (30s intervals) for macOS Docker bind mount compatibility
4. **Syncthing Monitoring** - Watches synced directories for all types of file changes
5. **Enhanced Content Detection** - Monitors both directory changes AND file modifications within .sdr folders
6. **Automatic Regeneration** - Site updates immediately when new content is detected
7. **Seamless Integration** - No manual intervention required for most workflows

### Technical Implementation
The auto-regeneration system uses a sophisticated approach to handle the limitations of file watching in containerized environments:

- **Primary Detection**: inotify watchers for instant response when file system events work properly
- **Fallback Detection**: Polling mechanism that monitors:
  - EPUB file count changes
  - .sdr directory count changes  
  - File modification timestamps within .sdr directories (catches highlight updates)
  - Statistics database changes
- **macOS Compatibility**: Polling ensures detection works reliably with Docker bind mounts on macOS
- **Configurable Intervals**: `POLL_INTERVAL` environment variable (default: 30 seconds)

### Enhanced macOS Compatibility (September 2025)

The auto-regeneration system has been significantly improved with cross-platform compatibility fixes:

- **Cross-Platform Detection**: Automatically detects macOS vs Linux environments and uses appropriate `stat` command syntax
- **Simplified Pipeline**: Replaced complex command pipelines that failed with large file counts (625+ files)
- **Improved Error Handling**: Better fallback mechanisms when individual detection methods fail
- **Dual Statistics Tracking**: Enhanced monitoring of both symlink and real database file timestamps
- **Reduced Manual Intervention**: Auto-detection now works reliably for book additions and statistics changes on macOS

### What Gets Synced
- **EPUB files** - Your entire book library in `/mnt/us/documents`
- **Reading progress** - Progress data stored in .sdr metadata files
- **.sdr metadata** - Complete highlight and annotation data alongside each book
- **Reading statistics** - Session data from statistics database in settings directory
- **Statistics database** - `statistics.sqlite3` for calendar and reading analytics (requires symlink setup)
- **Note**: Both books directory (.sdr files) AND settings directory (database) sync are required for complete functionality

### Monitoring Auto-Regeneration
```bash
# Watch for auto-detection events
podman-compose logs -f koshelf | grep -E "file change detected|Polling detected|Site generated"

# Monitor polling activity
podman-compose logs -f koshelf | grep "Polling detected"

# Check all watchers are running
podman-compose exec koshelf ps aux | grep -E "inotifywait|backup_poll"

# Check Syncthing status
open http://localhost:8384  # Mac Syncthing web UI
```

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
podman-compose logs koshelf      # KOShelf application logs only
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
│   ├── books/                   # Your ebook library (.epub files + .sdr metadata)
│   ├── koreader-settings/       # Legacy sync data (not actively used)
│   └── site-output/             # Generated static site
├── scripts/                     # Utility scripts
│   ├── auto-find-book.sh        # Auto EPUB detection and copying
│   ├── backup.sh                # Data backup automation
│   ├── extract_highlights.py    # KOReader highlights from database
│   ├── extract_sdr_highlights.py # Full highlight extraction from .sdr files
│   ├── setup.sh                 # Initial setup helper
│   └── sync-kindle-books.sh     # Kindle import automation
└── .env.example                 # Environment template
```

## Troubleshooting

### Case Sensitivity Issues (Common)
Syncthing and KOShelf have specific requirements for file extensions:

1. **File Extension Requirements**:
   - KOShelf expects lowercase: `.epub` and `metadata.epub.lua`
   - Mixed case causes sync conflicts and excludes books from site generation

2. **Resolving Case Sensitivity Conflicts**:
   ```bash
   # Find conflict files
   find ./data/books -name "*sync-conflict*" -o -name "*.syncthing*"
   
   # Remove conflict files (after backing up if needed)
   find ./data/books -name "*sync-conflict*" -delete
   find ./data/books -name "*.syncthing*" -delete
   
   # Standardize to lowercase extensions
   find ./data/books -name "*.EPUB" -exec rename 's/\.EPUB$/\.epub/' {} \;
   find ./data/books -name "metadata.EPUB.lua" -exec rename 's/metadata\.EPUB\.lua/metadata.epub.lua/' {} \;
   ```

3. **Prevent Future Conflicts**:
   - Use Syncthing's "Override Changes" on the receive-only device (Mac) when conflicts occur
   - Ensure new books use lowercase `.epub` extensions before syncing

### Statistics Database Issues ⚠️ CRITICAL 
If reading statistics or calendar pages show outdated data:

1. **Check SQLite WAL File Sync (Most Common Issue)**:
   ```bash
   # CRITICAL: Verify .stignore files don't exclude WAL files
   cat ./data/koreader-settings/.stignore | grep -E "\*-wal|\*-shm"
   
   # If found, remove these lines from BOTH device and local .stignore files:
   # *-shm (SQLite shared memory files)  
   # *-wal (SQLite Write-Ahead Log files)
   
   # Recent database changes are stored in WAL files that must sync
   ```

2. **Verify Two-Folder Sync**: Both `koreader-books` and `koreader-settings` must be syncing
   ```bash
   # Check both folders have .syncthing directories  
   ls -la ./data/books/.syncthing
   ls -la ./data/koreader-settings/.syncthing
   ```

3. **Check Database Location**: 
   ```bash
   # Verify symlink exists
   ls -la ./data/koreader-settings/data/statistics.sqlite3
   
   # Create symlink if missing
   cd ./data/koreader-settings/data
   ln -sf ../statistics.sqlite3 statistics.sqlite3
   ```

4. **Compare Database Timestamps & WAL Files**:
   ```bash
   # Check main database and WAL files modification times
   ls -la ./data/koreader-settings/statistics.sqlite3*
   ls -la [device]/koreader/settings/statistics.sqlite3*
   
   # WAL files (*-wal, *-shm) contain recent changes
   # If WAL files exist but aren't syncing, statistics will be stale
   ```

5. **Force Database Commit (Advanced)**:
   ```bash
   # Force WAL checkpoint to commit changes (if WAL files persist)
   sqlite3 ./data/koreader-settings/statistics.sqlite3 "PRAGMA wal_checkpoint(FULL);"
   
   # Or restart KOReader completely to force statistics commit
   ```

**Understanding the Data Flow**:
- **.sdr files**: Immediate sync (highlights, annotations)
- **Statistics database**: Delayed sync (KOReader batches writes)
- **WAL files**: Recent database changes that must sync for current statistics

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

### Statistics and Calendar Page Issues  
1. **Stale Reading Statistics**:
   ```bash
   # Check if statistics database is syncing from device
   ls -la data/koreader-settings/statistics.sqlite3
   
   # Compare with device database when connected
   ls -la /Volumes/Kindle/koreader/settings/statistics.sqlite3
   
   # Test auto-regeneration detection
   touch data/koreader-settings/statistics.sqlite3 && sleep 35
   podman-compose logs --tail=10 koshelf | grep -E "Statistics database change detected|Site generated"
   
   # Manual sync if needed (replace Kindle path as appropriate)
   cp /Volumes/Kindle/koreader/settings/statistics.sqlite3 data/koreader-settings/statistics.sqlite3
   podman-compose restart koshelf
   ```

2. **Auto-Detection Not Working**:
   ```bash
   # Rebuild container with latest fixes
   podman-compose build --no-cache koshelf && podman-compose up -d
   
   # Monitor detection logs
   podman-compose logs -f koshelf | grep -E "Statistics database tracking|Polling baseline"
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
   # Examine sync files in books directory
   ls -la ./data/books/
   find ./data/books -name "*.sdr" -exec ls -la {} \;
   
   # Check for statistics data within .sdr files
   find ./data/books -name "*statistics*" -o -name "*session*"
   ```

### Auto-Regeneration Issues
1. **File Detection Problems**:
    ```bash
    # Check if watchers are running (should see 4-5 processes)
    podman-compose exec koshelf ps aux | grep -E "inotifywait|backup_poll"
    
    # Monitor detection logs (both inotify and polling)
    podman-compose logs -f koshelf | grep -E "file change detected|Polling detected|Site generated"
    
    # Test manual trigger
    touch ./data/books/test.epub && rm ./data/books/test.epub
    ```

2. **⚠️ CURRENT STATUS (September 2025)**: Auto-detection significantly improved but may still require testing
    ```bash
    # ✅ WORKING: Book count changes and statistics database updates now detected automatically
    # ✅ WORKING: Cross-platform compatibility fixes deployed (macOS + Linux)
    # ⚠️ TESTING NEEDED: .sdr metadata file changes (highlights) may need verification
    
    # LATEST FIXES DEPLOYED (rebuild if auto-detection failing):
    podman-compose build --no-cache koshelf && podman-compose up -d
    
    # VERIFY AUTO-DETECTION STATUS:
    # 1. Check polling baseline initialization:
    podman-compose logs koshelf | grep "Polling baseline initialized"
    
    # 2. Monitor for automatic detection (should see regular activity):
    podman-compose logs -f koshelf | grep -E "Polling detected|file change detected"
    
    # 3. Test book count detection:
    touch ./data/books/test.epub && rm ./data/books/test.epub
    # Should see "Polling detected book count change" within 30 seconds
    
    # 4. If detection still failing, temporary workaround:
    podman-compose restart koshelf    # Immediately detects all changes
    ```

3. **Cross-Platform Polling System (2025 Updates)**:
    ```bash
    # Enhanced polling system works reliably on both macOS and Linux
    # Auto-detects platform-specific stat command syntax
    # Simplified detection logic prevents command-line length failures
    
    # Both systems run simultaneously for maximum reliability
    # inotify: Real-time detection (when supported)
    # Polling: Backup detection every 30 seconds (cross-platform)
    
    # Check polling baseline initialization
    podman-compose logs koshelf | grep "Polling baseline initialized"
    
    # Monitor specific polling activity  
    podman-compose logs -f koshelf | grep "Polling detected"
    
    # Verify polling interval setting
    podman-compose exec koshelf env | grep POLL_INTERVAL
    
    # Force immediate regeneration if needed
    podman-compose restart koshelf
    ```

4. **Legacy Auto-Detection Fixes (2024)**:
4. **Legacy Auto-Detection Fixes (2024)**:
    ```bash
    # Historical fixes applied in 2024:
    # Fixed: Polling mechanism breaking with large file counts (625+ files)
    # Fixed: WAL file exclusion preventing statistics sync
    # Fixed: Feedback loops from watching output directories
    
    # If experiencing 2024-era issues, rebuild container:
    podman-compose build --no-cache koshelf
    podman-compose up -d
    
    # Check for simplified polling success
    podman-compose logs koshelf | tail -20 | grep -E "backup_poll|Polling detected"
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
KOSHELF_STATISTICS_DB=/app/koreader-settings/data/statistics.sqlite3  # Computed statistics cache
KOSHELF_WATCH_INTERVAL=5                   # Seconds between inotify checks
POLL_INTERVAL=30                           # Seconds between polling checks (backup detection)
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
├── books/                          # EPUB library and metadata (bind mount)
│   ├── *.epub                      # Book files
│   └── *.sdr/                      # KOReader metadata directories
│       ├── metadata.epub.lua       # Book metadata, highlights, and reading progress
│       ├── statistics.epub.lua     # Reading session statistics
│       └── metadata.epub.lua.old   # Backup metadata
├── koreader-settings/              # KOReader settings and statistics database
│   ├── statistics.sqlite3          # Current statistics database (synced from device)
│   └── data/
│       └── statistics.sqlite3      # Symlink to ../statistics.sqlite3 (KOShelf compatibility)
└── site-output/                    # Generated static website
    ├── index.html                  # Main library page
    ├── books/                      # Individual book pages
    ├── assets/                     # CSS, JS, images
    └── search/                     # Search functionality
```

### Statistics Data Flow
```
KOReader Device Reading Session
    ↓
.sdr/metadata.epub.lua files (highlights, progress)
    ↓
statistics.sqlite3 database (reading statistics, calendar)
    ↓
Syncthing sync to data/books/ and data/koreader-settings/
    ↓
KOShelf reads both sources during site generation
    ↓
Statistics and Calendar pages in generated site
```

### Network Architecture
- **Bridge Network**: `koshelf-network` (172.x.x.x/16 subnet)
- **External Ports**: 8090 (nginx), 8081 (webdav)
- **Custom Domain**: koshelf.books via nginx reverse proxy on port 80
- **Internal Communication**: Container name resolution
- **Security**: No external database ports exposed

### Performance Considerations
- **File Watching**: Dual system (inotify + polling) for minimal CPU overhead with reliability
- **Polling Overhead**: Backup polling every 30 seconds adds minimal resource usage
- **Static Generation**: Full rebuild on any library change (optimized for small-medium libraries)
- **Caching**: nginx serves static files with optimized headers
- **Resource Usage**: ~100MB RAM total for all containers
- **Storage**: Generated sites typically 1-5MB per 100 books
- **macOS Compatibility**: Polling mechanism ensures detection works with Docker bind mounts

## License

This deployment configuration is provided under the same license as KOShelf. See the [original KOShelf repository](https://github.com/paviro/KoShelf) for details.
