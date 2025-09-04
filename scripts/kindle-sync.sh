#!/bin/bash

# Quick Kindle sync command
# Usage: ./kindle-sync.sh

cd "$(dirname "$0")"
./scripts/sync-kindle-books.sh "$@"