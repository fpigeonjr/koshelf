#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "☁️  Preparing KOShelf for Cloudflare Pages migration..."

if [ ! -d "data/site-output" ]; then
    echo "❌ No site output found. Please run the deployment first."
    exit 1
fi

echo "📊 Current site statistics:"
echo "   Files: $(find data/site-output -type f | wc -l)"
echo "   Size: $(du -sh data/site-output | cut -f1)"

echo ""
echo "🚀 Migration steps for Cloudflare Pages:"
echo ""
echo "1. 📁 Site files are ready in: ./data/site-output/"
echo "2. 🔧 Create a new GitHub repository for the static site"
echo "3. 📋 Copy the site files to your new repository"
echo "4. 🔗 Connect the repository to Cloudflare Pages"
echo "5. ⚙️  Configure build settings:"
echo "   • Build command: (none - pre-built)"
echo "   • Output directory: /"
echo "   • Root directory: /"
echo ""
echo "🤖 Optional: Set up GitHub Actions for automated deployment"
echo ""
echo "Example GitHub Actions workflow:"
echo "---"
cat << 'EOF'
name: Deploy to Cloudflare Pages
on:
  schedule:
    - cron: '0 6 * * *'  # Daily at 6 AM
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Deploy to Cloudflare Pages
        uses: cloudflare/pages-action@v1
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          projectName: koshelf
          directory: ./
EOF
echo "---"
echo ""
echo "🔑 You'll need to set up Cloudflare API credentials in GitHub Secrets"
echo "✅ Migration preparation complete!"