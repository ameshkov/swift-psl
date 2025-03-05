#!/bin/bash
set -e

# Directory for temporary files
TMP_DIR="/tmp/swift-psl"
mkdir -p "$TMP_DIR"

# Path to the current PSL file on the server
PSL_URL="https://publicsuffix.org/list/public_suffix_list.dat"

# Path to download the new PSL file
NEW_PSL_FILE="$TMP_DIR/public_suffix_list.dat"

# Path to store the version information
VERSION_FILE="$TMP_DIR/psl_version.txt"
CURRENT_VERSION_FILE="Sources/PublicSuffixList/Resources/version.txt"

# Download the latest PSL file
echo "Downloading the latest Public Suffix List..."
curl -s -o "$NEW_PSL_FILE" "$PSL_URL"

# Extract VERSION from the downloaded file
NEW_VERSION=$(grep -m 1 "VERSION:" "$NEW_PSL_FILE" | sed 's/\/\/ VERSION: //')

# If version file doesn't exist yet, create it
if [ ! -f "$CURRENT_VERSION_FILE" ]; then
    echo "Creating version file for the first time..."
    mkdir -p "$(dirname "$CURRENT_VERSION_FILE")"
    echo "NONE" >"$CURRENT_VERSION_FILE"
fi

# Read the current version
CURRENT_VERSION=$(cat "$CURRENT_VERSION_FILE")

echo "Current version: $CURRENT_VERSION"
echo "New version: $NEW_VERSION"

# Compare versions
if [ "$CURRENT_VERSION" != "$NEW_VERSION" ]; then
    echo "New version found. Updating resources..."

    # Run ResourceBuilder to update bin files
    echo "Running ResourceBuilder..."
    swift run ResourceBuilder "$NEW_PSL_FILE" \
        "Sources/PublicSuffixList/Resources/common.bin" \
        "Sources/PublicSuffixList/Resources/negated.bin" \
        "Sources/PublicSuffixList/Resources/asterisk.bin"

    # Update the version file
    echo "$NEW_VERSION" >"$CURRENT_VERSION_FILE"

    # Run tests to verify the new PSL data is valid
    echo "Running tests to validate the updated PSL data..."
    if swift test; then
        echo "Tests passed! New PSL data is valid."
        echo "Resources have been updated to version $NEW_VERSION"
    else
        echo "Tests failed, check what went wrong!"
    fi
else
    echo "No update needed. Current version is already up to date."
fi

# Cleanup
rm -f "$NEW_PSL_FILE"

echo "Done!"
