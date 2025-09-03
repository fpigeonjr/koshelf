#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_DIR/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

cd "$PROJECT_DIR"

echo "📦 Creating backup for KOShelf deployment..."

mkdir -p "$BACKUP_DIR"

BACKUP_FILE="$BACKUP_DIR/koshelf_backup_$TIMESTAMP.tar.gz"

echo "🗂️  Backing up data and configuration..."
tar -czf "$BACKUP_FILE" \
    --exclude='data/site-output' \
    data/ \
    .env \
    docker-compose.yml

echo "📊 Backup created: $BACKUP_FILE"
echo "📏 Size: $(du -h "$BACKUP_FILE" | cut -f1)"

echo "🧹 Cleaning up old backups (keeping last 5)..."
ls -t "$BACKUP_DIR"/koshelf_backup_*.tar.gz | tail -n +6 | xargs rm -f 2>/dev/null || true

echo "✅ Backup complete!"
echo ""
echo "📁 Backup contents:"
echo "   • Books library (data/books/)"
echo "   • KOReader settings (data/koreader-settings/)"
echo "   • Environment configuration (.env)"
echo "   • Docker Compose configuration"
echo ""
echo "🔄 To restore: tar -xzf $BACKUP_FILE"