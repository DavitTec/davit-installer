#!/usr/bin/env bash
# Version: 0.0.3
# Description: Tests for davit-installer setup, including env and manifest creation with diffs.
# Alias: Generic

set -euo pipefail
trap 'echo "FAIL: Test script error at line $LINENO"; exit 1' ERR

# Test env creation with samples
echo "Testing .env creation and diffs..."
for i in {1..4}; do
    echo "Running test $i..."
    if [[ -f .env ]]; then mv .env .env.bak; fi
    # Simulate inputs for create-env.sh (adjust based on .env-test$i needs)
    if ./scripts/create-env.sh <<< $'davit\nnode\ndavit-installer\nDavitTec\nDavitTec\ndavit-installer\ninstall+\ngithub\ntrue\ntrue\n\npatch'; then
        if diff -q .env "tests/.env-test$i" > /dev/null 2>&1; then
            echo "PASS: .env matches .env-test$i"
        else
            echo "FAIL: .env differs from .env-test$i"
            diff .env "tests/.env-test$i" || true  # Show diff
            exit 1
        fi
    else
        echo "FAIL: create-env.sh failed for test $i"
        exit 1
    fi
done

# Test manifest creation
echo "Testing manifest.json creation..."
if ./scripts/create-manifest.sh --create; then
    if diff -q manifest.json tests/sample_manifest.json > /dev/null 2>&1; then
        echo "PASS: manifest.json matches sample"
    else
        echo "FAIL: manifest.json differs from sample"
        diff manifest.json tests/sample_manifest.json || true
        exit 1
    fi
else
    echo "FAIL: create-manifest.sh failed"
    exit 1
fi

# ... (keep existing bump and sync tests)

echo "All tests passed!"