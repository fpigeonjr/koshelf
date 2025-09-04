#!/bin/bash

# Auto Book Finder Script
# Attempts to automatically find and copy EPUB files when new .sdr folders are detected

set -e

BOOK_NAME="$1"
BOOKS_DIR="$2"
KOREADER_SETTINGS_DIR="$3"

if [ -z "$BOOK_NAME" ] || [ -z "$BOOKS_DIR" ]; then
    echo "Usage: $0 <book_name> <books_dir> [koreader_settings_dir]"
    exit 1
fi

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Auto Book Finder: Looking for '$BOOK_NAME'${NC}"

# Function to search for EPUB in common locations
find_epub_file() {
    local search_name="$1"
    local found_file=""
    
    # Search locations in order of preference
    local search_paths=(
        "/Volumes/Kindle/documents"           # Kindle via USB
        "/Volumes/*/documents"                # Other e-readers via USB  
        "/mnt/*/documents"                    # Linux mount points
        "/media/*/documents"                  # Alternative Linux mounts
        "$HOME/Downloads"                     # Common download location
        "$HOME/Documents"                     # Documents folder
        "/tmp/calibre_downloads"              # Calibre temp downloads
    )
    
    echo -e "${YELLOW}Searching for EPUB file...${NC}"
    
    for search_path in "${search_paths[@]}"; do
        if [ -d "$search_path" ] 2>/dev/null; then
            echo "  Checking: $search_path"
            
            # Try exact match first
            found_file=$(find "$search_path" -name "$search_name" -type f 2>/dev/null | head -1)
            if [ -n "$found_file" ]; then
                echo "$found_file"
                return 0
            fi
            
            # Try case-insensitive match
            found_file=$(find "$search_path" -iname "$search_name" -type f 2>/dev/null | head -1)
            if [ -n "$found_file" ]; then
                echo "$found_file"
                return 0
            fi
            
            # Try partial match (without .epub extension)
            local name_without_ext="${search_name%.epub}"
            found_file=$(find "$search_path" -iname "*${name_without_ext}*.epub" -type f 2>/dev/null | head -1)
            if [ -n "$found_file" ]; then
                echo "$found_file"
                return 0
            fi
        fi
    done
    
    return 1
}

# Try to find the EPUB file
epub_file=$(find_epub_file "$BOOK_NAME")

if [ -n "$epub_file" ]; then
    echo -e "${GREEN}Found EPUB: $epub_file${NC}"
    
    # Copy to books directory
    dest_path="$BOOKS_DIR/$BOOK_NAME"
    echo -e "${BLUE}Copying to: $dest_path${NC}"
    
    cp "$epub_file" "$dest_path"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Successfully copied '$BOOK_NAME' to books directory!${NC}"
        echo -e "${GREEN}📚 Book will appear in your KOShelf library shortly.${NC}"
        exit 0
    else
        echo -e "${RED}❌ Failed to copy file${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  EPUB file not found automatically.${NC}"
    echo -e "${YELLOW}📝 To add this book to your library:${NC}"
    echo -e "   1. Locate '$BOOK_NAME' on your device or computer"
    echo -e "   2. Copy it to: $BOOKS_DIR/$BOOK_NAME"
    echo -e "   3. The book will automatically appear in your KOShelf library"
    echo
    echo -e "${BLUE}💡 Tip: Connect your e-reader via USB and run:${NC}"
    echo -e "   ./scripts/sync-kindle-books.sh"
    exit 1
fi