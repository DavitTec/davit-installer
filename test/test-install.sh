#!/usr/bin/env bash
# test/test-install.sh
# Version: 0.0.2
# Description: Basic tests for davit-installer setup.
# Alias: Generic

# Test env creation
./scripts/create-env.sh
if [[ -f .env ]]; then
    echo 'PASS: .env created'
else
    echo 'FAIL: .env creation'
    exit 1
fi

# Test manifest creation
./scripts/create-manifest.sh --create
if [[ -f manifest.json && $(jq length manifest.json) -gt 0 ]]; then
    echo 'PASS: manifest.json created with entries'
else
    echo 'FAIL: manifest.json creation'
    exit 1
fi

# Test version bump (patch)
./scripts/create-manifest.sh --bump patch
if git tag | grep -q '^v0.0.2$'; then
    echo 'PASS: Version bumped'
else
    echo 'FAIL: Version bump'
    exit 1
fi

# Test sync (assume SYNC_LEVEL=patch)
if [[ -f /opt/davit/development/manifest.json ]]; then
    echo 'PASS: Master manifest exists (manual verify sync)'
else
    echo 'WARN: Master manifest not found - skip sync test'
fi

# Stub for INSTALL --test
# /opt/davit/bin/INSTALL --test  # Uncomment when INSTALL is ready

echo 'All tests passed!'

# End of test-install.sh