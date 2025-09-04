# Agent Guidelines for KOShelf

## Build/Test Commands
- `podman-compose up -d` - Start all services (koshelf, webdav, nginx)
- `podman-compose down` - Stop all services
- `podman-compose build --no-cache` - Rebuild containers
- `podman-compose logs -f` - View all logs
- `podman-compose logs koshelf` - View KOShelf app logs
- `podman-compose restart koshelf` - Restart KOShelf to trigger rebuild

## Project Structure
This is a deployment repository using Docker/Podman containers with the prebuilt KOShelf binary (v1.0.20 ARM64). Core components:
- `docker/koshelf/` - KOShelf app container with file watching
- `docker/webdav/` - WebDAV server for KOReader sync
- `docker/nginx/` - Static site proxy
- `data/` - Persistent volumes (books, site output, KOReader settings)

## Code Style Guidelines
- Shell scripts: Use bash with `set -e`, proper quoting, descriptive variable names
- Docker: Multi-stage builds, minimal base images, proper COPY ordering for cache efficiency
- Environment variables: Use `${VAR:-default}` pattern for defaults
- File structure: Keep related configs together in `docker/` subdirs
- Comments: Document complex logic and environment variable purposes

## Testing
No automated tests - verify manually by checking container logs and accessing http://localhost:3000