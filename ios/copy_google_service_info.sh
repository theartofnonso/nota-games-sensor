#!/bin/bash

# Script to copy the correct GoogleService-Info.plist based on build configuration

CONFIGURATION="${CONFIGURATION}"
RUNNER_DIR="${SRCROOT}/Runner"
SOURCE_FILE=""
DEST_FILE="${RUNNER_DIR}/GoogleService-Info.plist"

# Determine which file to copy based on configuration
if [[ "$CONFIGURATION" == *"coach"* ]]; then
    SOURCE_FILE="${RUNNER_DIR}/GoogleService-Info-coach.plist"
elif [[ "$CONFIGURATION" == *"client"* ]]; then
    SOURCE_FILE="${RUNNER_DIR}/GoogleService-Info-client.plist"
else
    # Default to client for Debug, Profile, Release (non-flavor builds)
    SOURCE_FILE="${RUNNER_DIR}/GoogleService-Info-client.plist"
fi

# Copy the file
if [ -f "$SOURCE_FILE" ]; then
    cp "$SOURCE_FILE" "$DEST_FILE"
    echo "Copied $SOURCE_FILE to $DEST_FILE for configuration: $CONFIGURATION"
else
    echo "Error: Source file $SOURCE_FILE not found!"
    exit 1
fi
