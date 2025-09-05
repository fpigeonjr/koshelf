#!/bin/bash
set -e

BOOKS_DIR=${KOSHELF_BOOKS_DIR:-/app/books}
OUTPUT_DIR=${KOSHELF_OUTPUT_DIR:-/app/site-output}
KOREADER_SETTINGS_DIR=${KOSHELF_KOREADER_SETTINGS:-/app/koreader-settings}
STATISTICS_DB=${KOSHELF_STATISTICS_DB:-/app/koreader-settings/data/statistics.sqlite3}
WATCH_INTERVAL=${KOSHELF_WATCH_INTERVAL:-5}
TITLE=${KOSHELF_TITLE:-"KoShelf Library"}
PORT=${KOSHELF_PORT:-3000}

echo "Starting KoShelf with file watching..."
echo "Books directory: $BOOKS_DIR"
echo "Output directory: $OUTPUT_DIR"
echo "KOReader settings: $KOREADER_SETTINGS_DIR"
echo "Statistics database: $STATISTICS_DB"
echo "Watch interval: ${WATCH_INTERVAL}s"
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
    
    # Start file watcher for books directory
    echo "Starting file watcher for books directory..."
    inotifywait -m -r -e create,delete,modify,move --format '%w%f %e' "$BOOKS_DIR" 2>/dev/null | while read file event; do
        echo "Book file change detected: $file ($event)"
        sleep "$WATCH_INTERVAL"
        generate_site
    done &
    BOOKS_WATCHER_PID=$!
    
    # Start watcher for KOReader settings directory (new book detection)
    echo "Starting watcher for KOReader settings directory..."
    inotifywait -m -r -e create --format '%w%f %e' "$KOREADER_SETTINGS_DIR" 2>/dev/null | while read file event; do
        # Check if this is a new .sdr directory creation
        if [[ "$file" == *.sdr ]] && [ "$event" = "CREATE" ]; then
            echo "New .sdr directory detected: $file"
            handle_new_book "$file"
            # Give it a moment for the .sdr to be fully created, then regenerate
            sleep "$WATCH_INTERVAL"
            generate_site
        fi
    done &
    KOREADER_WATCHER_PID=$!
    
    # Start watcher for statistics database (reading progress sync)
    echo "Starting watcher for statistics database..."
    if [ -f "$STATISTICS_DB" ] || [ -d "$(dirname "$STATISTICS_DB")" ]; then
        inotifywait -m -e modify,create --format '%w%f %e' "$STATISTICS_DB" 2>/dev/null | while read file event; do
            echo "Statistics database updated: $file ($event)"
            sleep "$WATCH_INTERVAL"
            generate_site
        done &
        STATS_WATCHER_PID=$!
    else
        echo "Statistics database path not accessible, skipping stats watcher"
        STATS_WATCHER_PID=""
    fi
    
    # Start simple HTTP server for the generated site
    echo "Starting HTTP server on port $PORT..."
    cd "$OUTPUT_DIR"
    python3 -m http.server "$PORT" &
    SERVER_PID=$!
    
    trap "kill $BOOKS_WATCHER_PID $KOREADER_WATCHER_PID ${STATS_WATCHER_PID:-} $SERVER_PID 2>/dev/null || true; exit" SIGTERM SIGINT
    
    echo "KoShelf is ready!"
    echo "Books watcher PID: $BOOKS_WATCHER_PID"
    echo "KOReader watcher PID: $KOREADER_WATCHER_PID"
    echo "Statistics watcher PID: ${STATS_WATCHER_PID:-disabled}"
    echo "HTTP server PID: $SERVER_PID"
    echo "Access your library at: http://localhost:$PORT"
    
    if [ -n "$STATS_WATCHER_PID" ]; then
        wait $BOOKS_WATCHER_PID $KOREADER_WATCHER_PID $STATS_WATCHER_PID $SERVER_PID
    else
        wait $BOOKS_WATCHER_PID $KOREADER_WATCHER_PID $SERVER_PID
    fi
else
    echo "Watch mode disabled. Generating site once..."
    generate_site
fi