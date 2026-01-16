#!/bin/bash

# --- GestureLink Launcher ---

# Exit on error
set -e

# Cleanup on exit
trap "kill 0" EXIT

echo "----------------------------------------"
echo "🖐️  Starting GestureLink System..."
echo "----------------------------------------"

# Check for swift
if ! command -v swift &> /dev/null; then
    echo "❌ Error: Swift is not installed or not in PATH."
    exit 1
fi

# Build components first to avoid race conditions during run
echo "🔨 Building components..."
(cd GestureListener && swift build -q)
(cd GestureDetector && swift build -q)

# Start Listener
echo "📥 Launching GestureListener (UDP:8080)..."
(cd GestureListener && swift run -q GestureListener) &

# Brief pause for listener setup
sleep 2

# Start Detector
echo "📸 Launching GestureDetector App..."
echo "--- Press Ctrl+C to stop everything ---"
(cd GestureDetector && swift run -q GestureDetector)

wait
