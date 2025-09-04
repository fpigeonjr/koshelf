#!/bin/bash

# KOShelf Kindle Book Sync Script
# Automatically syncs EPUB books from mounted Kindle to KOShelf books directory

set -e

# Configuration
KINDLE_MOUNT_PATH="/Volumes/Kindle"
KINDLE_BOOKS_PATH="${KINDLE_MOUNT_PATH}/documents"
KOSHELF_BOOKS_PATH="$(dirname "$0")/../data/books"
LOG_FILE="$(dirname "$0")/../kindle-sync.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${LOG_FILE}"
}

# Check if Kindle is mounted
check_kindle_mounted() {
    if [ ! -d "${KINDLE_MOUNT_PATH}" ]; then
        echo -e "${RED}Error: Kindle not found at ${KINDLE_MOUNT_PATH}${NC}"
        echo "Please ensure your Kindle is connected and mounted."
        exit 1
    fi
    
    if [ ! -d "${KINDLE_BOOKS_PATH}" ]; then
        echo -e "${RED}Error: Kindle documents directory not found at ${KINDLE_BOOKS_PATH}${NC}"
        exit 1
    fi
}

# Create books directory if it doesn't exist
ensure_books_directory() {
    if [ ! -d "${KOSHELF_BOOKS_PATH}" ]; then
        log "Creating KOShelf books directory: ${KOSHELF_BOOKS_PATH}"
        mkdir -p "${KOSHELF_BOOKS_PATH}"
    fi
}

# Sync books function
sync_books() {
    local books_found=0
    local books_copied=0
    local books_updated=0
    
    echo -e "${BLUE}Scanning for EPUB books on Kindle...${NC}"
    echo -e "${YELLOW}Note: KOShelf only supports EPUB format. KFX and other formats will be ignored.${NC}"
    
    # Count total EPUB books on Kindle (KOShelf only supports EPUB format)
    books_found=$(find "${KINDLE_BOOKS_PATH}" -name "*.epub" -o -name "*.EPUB" -o -name "*.Epub" | wc -l | tr -d ' ')
    
    if [ "${books_found}" -eq 0 ]; then
        echo -e "${YELLOW}No EPUB books found on Kindle.${NC}"
        log "No EPUB books found on Kindle"
        return 0
    fi
    
    echo -e "${GREEN}Found ${books_found} EPUB books on Kindle${NC}"
    log "Found ${books_found} EPUB books on Kindle"
    
    # Sync each EPUB file (handle both lowercase and uppercase extensions)
    while IFS= read -r -d '' book_path; do
        book_name=$(basename "${book_path}")
        # Normalize extension to lowercase for consistency
        normalized_name=$(echo "${book_name}" | sed 's/\.EPUB$/.epub/i' | sed 's/\.Epub$/.epub/i')
        dest_path="${KOSHELF_BOOKS_PATH}/${normalized_name}"
        
        if [ -f "${dest_path}" ]; then
            # Check if source is newer than destination
            if [ "${book_path}" -nt "${dest_path}" ]; then
                echo -e "${YELLOW}Updating: ${normalized_name}${NC}"
                cp "${book_path}" "${dest_path}"
                ((books_updated++))
                log "Updated book: ${normalized_name}"
            else
                echo -e "${BLUE}Skipping (up to date): ${normalized_name}${NC}"
            fi
        else
            echo -e "${GREEN}Copying: ${normalized_name}${NC}"
            cp "${book_path}" "${dest_path}"
            ((books_copied++))
            log "Copied new book: ${normalized_name}"
        fi
    done < <(find "${KINDLE_BOOKS_PATH}" -name "*.epub" -o -name "*.EPUB" -o -name "*.Epub" -print0)
    
    echo
    echo -e "${GREEN}Sync completed!${NC}"
    echo -e "Books copied: ${GREEN}${books_copied}${NC}"
    echo -e "Books updated: ${YELLOW}${books_updated}${NC}"
    echo -e "Total books in library: ${BLUE}$(find "${KOSHELF_BOOKS_PATH}" -name "*.epub" | wc -l | tr -d ' ')${NC}"
    
    log "Sync completed - Copied: ${books_copied}, Updated: ${books_updated}"
}

# Restart KOShelf to detect new books
restart_koshelf() {
    if command -v podman-compose >/dev/null 2>&1; then
        echo -e "${BLUE}Restarting KOShelf to detect new books...${NC}"
        log "Restarting KOShelf container"
        
        # Change to the directory containing docker-compose.yml
        cd "$(dirname "$0")/.."
        
        podman-compose restart koshelf
        echo -e "${GREEN}KOShelf restarted successfully!${NC}"
        log "KOShelf restarted successfully"
        
        echo -e "${GREEN}Your library should now be available at: http://localhost:3000${NC}"
    else
        echo -e "${YELLOW}podman-compose not found. Please manually restart KOShelf with:${NC}"
        echo "podman-compose restart koshelf"
        log "Manual restart required - podman-compose not found"
    fi
}

# Main execution
main() {
    echo -e "${BLUE}KOShelf Kindle Book Sync${NC}"
    echo -e "${BLUE}========================${NC}"
    echo
    
    log "Starting Kindle book sync"
    
    check_kindle_mounted
    ensure_books_directory
    sync_books
    
    # Ask user if they want to restart KOShelf
    echo
    read -p "Restart KOShelf now to detect new books? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        restart_koshelf
    else
        echo -e "${YELLOW}Remember to restart KOShelf manually to see new books:${NC}"
        echo "podman-compose restart koshelf"
        log "User chose not to restart KOShelf automatically"
    fi
    
    log "Kindle book sync completed"
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "KOShelf Kindle Book Sync Script"
        echo
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --dry-run      Show what would be synced without copying files"
        echo "  --force        Force restart KOShelf without prompting"
        echo "  --quiet        Reduce output verbosity"
        echo
        echo "This script syncs EPUB books from a mounted Kindle device"
        echo "to the KOShelf books directory and optionally restarts KOShelf."
        exit 0
        ;;
    --dry-run)
        echo -e "${YELLOW}DRY RUN MODE - No files will be copied${NC}"
        # TODO: Implement dry-run mode
        ;;
    *)
        main
        ;;
esac