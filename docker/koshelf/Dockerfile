FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    inotify-tools \
    curl \
    ca-certificates \
    python3 \
    unzip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Download and extract prebuilt KoShelf binary for ARM64 Linux
RUN curl -L https://github.com/paviro/KoShelf/releases/download/v1.0.20/linux-gnu-aarch64.zip -o koshelf.zip \
    && unzip koshelf.zip \
    && mv koshelf /usr/local/bin/koshelf \
    && chmod +x /usr/local/bin/koshelf \
    && rm koshelf.zip

COPY docker/koshelf/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create scripts directory and copy auto-find script  
RUN mkdir -p /app/scripts
COPY scripts/auto-find-book.sh /app/scripts/auto-find-book.sh
RUN chmod +x /app/scripts/auto-find-book.sh

VOLUME ["/app/books", "/app/site-output", "/app/koreader-settings"]

EXPOSE 3000

ENTRYPOINT ["/entrypoint.sh"]