#!/bin/bash
#
#  install.sh
#  Onit
#
#  Created by Kévin Naudin on 2026-01-23.
#
#  Run this script once to configure git hooks for this repository.
#  Usage: ./.githooks/install.sh
#

set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

echo "Setting up git hooks..."

# Configure git to use the shared hooks directory
git config core.hooksPath .githooks

# Create Secrets.xcconfig from sample if it doesn't exist
SECRETS_FILE="macos/OnitQuickEdit/Secrets.xcconfig"
SECRETS_SAMPLE="macos/OnitQuickEdit/Secrets.xcconfig.sample"

if [ ! -f "$SECRETS_FILE" ] && [ -f "$SECRETS_SAMPLE" ]; then
    cp "$SECRETS_SAMPLE" "$SECRETS_FILE"
    echo "✓ Created Secrets.xcconfig from sample"
    echo "  → Please edit $SECRETS_FILE with your API keys"
fi

# Create backup if Secrets exists but backup doesn't
SECRETS_BACKUP="macos/OnitQuickEdit/Secrets.xcconfig.backup"
if [ -f "$SECRETS_FILE" ] && [ ! -f "$SECRETS_BACKUP" ]; then
    cp "$SECRETS_FILE" "$SECRETS_BACKUP"
    echo "✓ Created Secrets.xcconfig.backup"
fi

echo ""
echo "✓ Git hooks installed successfully!"
echo ""
echo "What this does:"
echo "  • post-checkout: Restores Secrets.xcconfig + updates submodules + cleans SPM cache"
echo "  • post-merge: Updates submodules after pull + cleans SPM cache"
echo "  • pre-commit: Prevents accidentally committing secrets"
