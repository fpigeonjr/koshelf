#!/bin/bash
set -e

BOOKS_DIR=${KOSHELF_BOOKS_DIR:-/app/books}
OUTPUT_DIR=${KOSHELF_OUTPUT_DIR:-/app/site-output}
WATCH_INTERVAL=${KOSHELF_WATCH_INTERVAL:-5}
TITLE=${KOSHELF_TITLE:-"KoShelf Library"}
PORT=${KOSHELF_PORT:-3000}

echo "Starting KoShelf with file watching..."
echo "Books directory: $BOOKS_DIR"
echo "Output directory: $OUTPUT_DIR"
echo "Watch interval: ${WATCH_INTERVAL}s"
echo "Title: $TITLE"

mkdir -p "$BOOKS_DIR" "$OUTPUT_DIR"

generate_site() {
    echo "Generating site..."
    koshelf --books-path "$BOOKS_DIR" --output "$OUTPUT_DIR" --title "$TITLE" --include-unread
    echo "Site generated at $(date)"
}

if [ "${KOSHELF_WATCH_MODE:-true}" = "true" ]; then
    echo "Starting in watch mode..."
    
    # Generate initial site
    generate_site
    
    # Start file watcher
    inotifywait -m -r -e create,delete,modify,move --format '%w%f %e' "$BOOKS_DIR" 2>/dev/null | while read file event; do
        echo "File change detected: $file ($event)"
        sleep "$WATCH_INTERVAL"
        generate_site
    done &
    
    WATCHER_PID=$!
    
    # Start simple HTTP server for the generated site
    echo "Starting HTTP server on port $PORT..."
    cd "$OUTPUT_DIR"
    python3 -m http.server "$PORT" &
    SERVER_PID=$!
    
    trap "kill $WATCHER_PID $SERVER_PID 2>/dev/null || true; exit" SIGTERM SIGINT
    
    echo "KoShelf is ready!"
    echo "File watcher PID: $WATCHER_PID"
    echo "HTTP server PID: $SERVER_PID"
    echo "Access your library at: http://localhost:$PORT"
    
    wait $WATCHER_PID $SERVER_PID
else
    echo "Watch mode disabled. Generating site once..."
    generate_site
fi