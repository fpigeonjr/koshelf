# KOShelf Deployment

A Podman-based deployment setup for [KOShelf](https://github.com/paviro/KoShelf) - a static site generator for ebook libraries with KOReader WebDAV sync integration.

## Features

- 📚 **Auto-generated library site** from your ebook collection
- 🔄 **File watching** - site regenerates when books are added
- 📱 **WebDAV server** for KOReader sync integration  
- 🌐 **Local network access** via nginx reverse proxy
- 📦 **Podman Compose** orchestration for easy deployment
- 💾 **Persistent data storage** for books and sync data

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
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   KOShelf App   │    │   WebDAV Server  │    │  Nginx Proxy    │
│                 │    │                  │    │                 │
│ • File watching │    │ • KOReader sync  │    │ • Static site   │
│ • Site generation│    │ • Authentication │    │ • Local access  │
│ • Auto-rebuild  │    │ • Port 8081      │    │ • Port 3000     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                        │                        │
         └────────────────────────┼────────────────────────┘
                                  │
                        ┌─────────▼─────────┐
                        │  Shared Volumes   │
                        │                   │
                        │ • Books library   │
                        │ • Generated site  │
                        │ • KOReader data   │
                        └───────────────────┘
```

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

### Start/Stop Services
```bash
podman-compose up -d       # Start all services
podman-compose down        # Stop all services
podman-compose logs -f     # View logs
```

### Check Status
```bash
podman-compose ps          # Service status
podman-compose logs koshelf # KOShelf logs
podman-compose logs webdav  # WebDAV logs
```

### Add Books
```bash
# Copy books to trigger auto-regeneration
cp ~/Downloads/books/*.epub ./data/books/

# Or restart to force detection
podman-compose restart koshelf
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

### KOReader Can't Connect
1. **Check network**: Both devices on same WiFi?
2. **Test connectivity**: `ping YOUR_MAC_IP` from KOReader terminal
3. **Verify services**: `podman-compose ps` should show all containers running
4. **Check WebDAV logs**: `podman-compose logs webdav`

### Books Not Appearing
1. **Check file format**: Only `.epub` files supported
2. **Restart KOShelf**: `podman-compose restart koshelf`
3. **Check logs**: `podman-compose logs koshelf`

### WebDAV Sync Issues
1. **Test manually**: `curl -u koreader:koreader123 http://YOUR_IP:8081/`
2. **Check auth**: Verify username/password in KOReader
3. **Network access**: Try accessing `http://YOUR_IP:3000` from Kindle browser

### Rebuild Everything
```bash
podman-compose down
podman-compose build --no-cache
podman-compose up -d
```

## Technical Details

- **KOShelf Version**: v1.0.20 (ARM64 prebuilt binary)
- **WebDAV Server**: bytemark/webdav (Apache-based)
- **Platform**: macOS with Podman
- **Container Runtime**: Podman Compose

## License

This deployment configuration is provided under the same license as KOShelf. See the [original KOShelf repository](https://github.com/paviro/KoShelf) for details.
