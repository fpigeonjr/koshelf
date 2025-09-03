#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "🚀 Setting up KOShelf deployment..."

if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "✅ Created .env file - please review and update credentials if needed"
fi

echo "🐳 Building Docker images..."
podman-compose build

echo "📁 Creating necessary directories..."
mkdir -p data/books data/koreader-settings data/site-output

echo "🔐 Setting up permissions..."
chmod 755 data/books data/koreader-settings data/site-output

echo "🎯 Starting services..."
podman-compose up -d

echo "⏳ Waiting for services to start..."
sleep 10

echo "🔍 Checking service status..."
podman-compose ps

echo "🎉 Setup complete!"
echo ""
echo "📚 Your KOShelf deployment is ready:"
echo "   Web interface: http://localhost:3000"
echo "   WebDAV (books): http://localhost:8081/books/"
echo "   WebDAV (settings): http://localhost:8081/koreader-settings/"
echo ""
echo "📖 WebDAV credentials (from .env):"
echo "   Username: $(grep WEBDAV_USERNAME .env | cut -d= -f2)"
echo "   Password: $(grep WEBDAV_PASSWORD .env | cut -d= -f2)"
echo ""
echo "📁 To add books: Place them in ./data/books/"
echo "🔄 The site will auto-regenerate when books change"