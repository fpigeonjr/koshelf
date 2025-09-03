#!/bin/sh
set -e

USERNAME=${WEBDAV_USERNAME:-koreader}
PASSWORD=${WEBDAV_PASSWORD:-koreader123}

echo "Setting up WebDAV authentication for user: $USERNAME"
htpasswd -cb /etc/nginx/.htpasswd "$USERNAME" "$PASSWORD"

echo "Starting nginx..."
exec "$@"