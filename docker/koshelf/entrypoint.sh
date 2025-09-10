#!/bin/bash
set -e

BOOKS_DIR=${KOSHELF_BOOKS_DIR:-/app/books}
OUTPUT_DIR=${KOSHELF_OUTPUT_DIR:-/app/site-output}
KOREADER_SETTINGS_DIR=${KOSHELF_KOREADER_SETTINGS:-/app/koreader-settings}
STATISTICS_DB=${KOSHELF_STATISTICS_DB:-/app/koreader-settings/data/statistics.sqlite3}
WATCH_INTERVAL=${KOSHELF_WATCH_INTERVAL:-5}
POLL_INTERVAL=${KOSHELF_POLL_INTERVAL:-30}
TITLE=${KOSHELF_TITLE:-"KoShelf Library"}
PORT=${KOSHELF_PORT:-3000}

echo "Starting KoShelf with file watching..."
echo "Books directory: $BOOKS_DIR"
echo "Output directory: $OUTPUT_DIR"
echo "KOReader settings: $KOREADER_SETTINGS_DIR"
echo "Statistics database: $STATISTICS_DB"
echo "Watch interval: ${WATCH_INTERVAL}s"
echo "Poll interval: ${POLL_INTERVAL}s"
echo "Title: $TITLE"

mkdir -p "$BOOKS_DIR" "$OUTPUT_DIR" "$KOREADER_SETTINGS_DIR"

generate_site() {
    echo "Generating site..."
    if [ -f "$STATISTICS_DB" ]; then
        echo "Using statistics database: $STATISTICS_DB"
        koshelf --books-path "$BOOKS_DIR" --statistics-db "$STATISTICS_DB" --output "$OUTPUT_DIR" --title "$TITLE" --include-unread
    else
        echo "Statistics database not found, proceeding without reading stats"
        koshelf --books-path "$BOOKS_DIR" --output "$OUTPUT_DIR" --title "$TITLE" --include-unread
    fi
    echo "Site generated at $(date)"
}

# Function to handle new book detection from .sdr folders
handle_new_book() {
    local sdr_path="$1"
    local book_name=$(basename "$sdr_path" .sdr)
    
    # Add .epub extension if not present
    if [[ "$book_name" != *.epub ]]; then
        book_name="$book_name.epub"
    fi
    
    local epub_path="$BOOKS_DIR/$book_name"
    
    # Check if corresponding EPUB already exists
    if [ -f "$epub_path" ]; then
        echo "EPUB already exists for: $book_name"
        return 0
    fi
    
    echo "📚 New book detected: $book_name"
    echo "🔍 Attempting to find and copy EPUB file..."
    
    # Try to automatically find and copy the EPUB
    if [ -f "/app/scripts/auto-find-book.sh" ]; then
        /app/scripts/auto-find-book.sh "$book_name" "$BOOKS_DIR" "$KOREADER_SETTINGS_DIR"
    else
        echo "⚠️  Auto-find script not available. Manual intervention required."
        echo "   Please copy the EPUB file to: $epub_path"
    fi
}

if [ "${KOSHELF_WATCH_MODE:-true}" = "true" ]; then
    echo "Starting in watch mode..."
    
    # Generate initial site
    generate_site
    
    # Start file watcher for books directory (exclude hidden/temp files and output directory)
    echo "Starting file watcher for books directory..."
    inotifywait -m -r -e create,delete,modify,move --exclude '/\.|\.tmp$|\.temp$' --format '%w%f %e' "$BOOKS_DIR" 2>/dev/null | while read file event; do
        # Skip if the event is in the output directory or involves temporary files
        if [[ "$file" == *"$OUTPUT_DIR"* ]] || [[ "$file" == *".tmp"* ]] || [[ "$file" == *".temp"* ]] || [[ "$file" == */.*/* ]]; then
            continue
        fi
        echo "Book file change detected: $file ($event)"
        sleep "$WATCH_INTERVAL"
        generate_site
    done &
    BOOKS_WATCHER_PID=$!
    
    # Start watcher for KOReader settings directory (new book detection)
    echo "Starting watcher for KOReader settings directory..."
    inotifywait -m -r -e create,modify --exclude '/\.|\.tmp$|\.temp$' --format '%w%f %e' "$KOREADER_SETTINGS_DIR" 2>/dev/null | while read file event; do
        # Skip temporary/hidden files and output directory
        if [[ "$file" == *"$OUTPUT_DIR"* ]] || [[ "$file" == *".tmp"* ]] || [[ "$file" == *".temp"* ]] || [[ "$file" == */.*/* ]]; then
            continue
        fi
        # Check if this is a new .sdr directory creation or important file modification
        if [[ "$file" == *.sdr ]] && [ "$event" = "CREATE" ]; then
            echo "New .sdr directory detected: $file"
            handle_new_book "$file"
            # Give it a moment for the .sdr to be fully created, then regenerate
            sleep "$WATCH_INTERVAL"
            generate_site
        elif [[ "$file" == *.lua ]] || [[ "$file" == *.sqlite3 ]]; then
            echo "KOReader data change detected: $file ($event)"
            sleep "$WATCH_INTERVAL"
            generate_site
        fi
    done &
    KOREADER_WATCHER_PID=$!
    
    # Start watcher for statistics database (reading progress sync)
    echo "Starting watcher for statistics database..."
    # Watch the directory containing the database instead of the symlinked file
    STATS_DIR="$(dirname "$STATISTICS_DB")"
    if [ -d "$KOREADER_SETTINGS_DIR" ]; then
        # Watch both the settings directory and the data subdirectory for database changes
        inotifywait -m -e modify,create,move --format '%w%f %e' "$KOREADER_SETTINGS_DIR" "$STATS_DIR" 2>/dev/null | while read file event; do
            # Only trigger on actual database changes, not temporary files
            if [[ "$file" == *"statistics.sqlite3"* ]] && [[ "$file" != *".tmp"* ]] && [[ "$file" != *".temp"* ]] && [[ "$file" != *"-shm"* ]] && [[ "$file" != *"-wal"* ]]; then
                echo "Statistics database change detected: $file ($event)"
                sleep "$WATCH_INTERVAL"
                generate_site
            fi
        done &
        STATS_WATCHER_PID=$!
    else
        echo "KOReader settings directory not accessible, skipping stats watcher"
        STATS_WATCHER_PID=""
    fi
    
    # Start backup polling mechanism (for macOS Docker bind mount issues)
    echo "Starting backup polling mechanism (every ${POLL_INTERVAL}s)..."
    (
        # Initialize baseline values after initial generation to avoid false positives
        sleep 2
        LAST_BOOKS_COUNT=$(find "$BOOKS_DIR" -name "*.epub" 2>/dev/null | wc -l)
        LAST_SDR_COUNT=$(find "$BOOKS_DIR" -name "*.sdr" -type d 2>/dev/null | wc -l)
        # Initialize statistics database tracking for both symlink and real file
        if [ -f "$STATISTICS_DB" ]; then
            LAST_STATS_MTIME=$(stat -c %Y "$STATISTICS_DB" 2>/dev/null || echo 0)
        else
            LAST_STATS_MTIME=0
        fi
        
        REAL_STATS_DB="$KOREADER_SETTINGS_DIR/statistics.sqlite3"
        if [ -f "$REAL_STATS_DB" ]; then
            LAST_REAL_STATS_MTIME=$(stat -c %Y "$REAL_STATS_DB" 2>/dev/null || echo 0)
        else
            LAST_REAL_STATS_MTIME=0
        fi
        
        echo "Polling baseline initialized: $LAST_BOOKS_COUNT books, $LAST_SDR_COUNT .sdr dirs"
        echo "Statistics database tracking: symlink mtime=$LAST_STATS_MTIME, real file mtime=$LAST_REAL_STATS_MTIME"
        
        while true; do
            sleep "$POLL_INTERVAL"
            
            # Check for new books (EPUB files)
            CURRENT_BOOKS_COUNT=$(find "$BOOKS_DIR" -name "*.epub" 2>/dev/null | wc -l)
            if [ "$CURRENT_BOOKS_COUNT" -ne "$LAST_BOOKS_COUNT" ]; then
                echo "Polling detected book count change: $LAST_BOOKS_COUNT -> $CURRENT_BOOKS_COUNT"
                LAST_BOOKS_COUNT=$CURRENT_BOOKS_COUNT
                generate_site
                continue
            fi
            
            # Check for new .sdr directories
            CURRENT_SDR_COUNT=$(find "$BOOKS_DIR" -name "*.sdr" -type d 2>/dev/null | wc -l)
            if [ "$CURRENT_SDR_COUNT" -ne "$LAST_SDR_COUNT" ]; then
                echo "Polling detected .sdr directory change: $LAST_SDR_COUNT -> $CURRENT_SDR_COUNT"
                LAST_SDR_COUNT=$CURRENT_SDR_COUNT
                generate_site
                continue
            fi
            
            # Check for .sdr directory changes (simplified approach)
            # Method 1: Check if any .sdr directory was modified recently
            RECENT_SDR_CHANGES=$(find "$BOOKS_DIR" -name "*.sdr" -type d -newermt "$POLL_INTERVAL seconds ago" 2>/dev/null | wc -l)
            if [ "$RECENT_SDR_CHANGES" -gt 0 ]; then
                echo "Polling detected recent .sdr changes ($RECENT_SDR_CHANGES directories modified)"
                generate_site
                continue
            fi
            
            # Check for statistics database changes (watch both symlink target and link itself)
            STATS_CHANGED=false
            if [ -f "$STATISTICS_DB" ]; then
                CURRENT_STATS_MTIME=$(stat -c %Y "$STATISTICS_DB" 2>/dev/null || echo 0)
                if [ "$CURRENT_STATS_MTIME" -gt "$LAST_STATS_MTIME" ]; then
                    echo "Polling detected statistics database change (symlink target)"
                    LAST_STATS_MTIME=$CURRENT_STATS_MTIME
                    STATS_CHANGED=true
                fi
            fi
            
            # Also check the actual database file in case symlink doesn't update properly
            REAL_STATS_DB="$KOREADER_SETTINGS_DIR/statistics.sqlite3"
            if [ -f "$REAL_STATS_DB" ]; then
                CURRENT_REAL_STATS_MTIME=$(stat -c %Y "$REAL_STATS_DB" 2>/dev/null || echo 0)
                if [ -z "$LAST_REAL_STATS_MTIME" ]; then
                    LAST_REAL_STATS_MTIME=$CURRENT_REAL_STATS_MTIME
                elif [ "$CURRENT_REAL_STATS_MTIME" -gt "$LAST_REAL_STATS_MTIME" ]; then
                    echo "Polling detected statistics database change (real file)"
                    LAST_REAL_STATS_MTIME=$CURRENT_REAL_STATS_MTIME
                    STATS_CHANGED=true
                fi
            fi
            
            if [ "$STATS_CHANGED" = true ]; then
                generate_site
            fi
        done
    ) &
    POLLING_PID=$!
    
    # Start simple HTTP server for the generated site
    echo "Starting HTTP server on port $PORT..."
    cd "$OUTPUT_DIR"
    python3 -m http.server "$PORT" &
    SERVER_PID=$!
    
    trap "kill $BOOKS_WATCHER_PID $KOREADER_WATCHER_PID ${STATS_WATCHER_PID:-} $POLLING_PID $SERVER_PID 2>/dev/null || true; exit" SIGTERM SIGINT
    
    echo "KoShelf is ready!"
    echo "Books watcher PID: $BOOKS_WATCHER_PID"
    echo "KOReader watcher PID: $KOREADER_WATCHER_PID"
    echo "Statistics watcher PID: ${STATS_WATCHER_PID:-disabled}"
    echo "Backup polling PID: $POLLING_PID"
    echo "HTTP server PID: $SERVER_PID"
    echo "Access your library at: http://localhost:$PORT"
    
    if [ -n "$STATS_WATCHER_PID" ]; then
        wait $BOOKS_WATCHER_PID $KOREADER_WATCHER_PID $STATS_WATCHER_PID $POLLING_PID $SERVER_PID
    else
        wait $BOOKS_WATCHER_PID $KOREADER_WATCHER_PID $POLLING_PID $SERVER_PID
    fi
else
    echo "Watch mode disabled. Generating site once..."
    generate_site
fi