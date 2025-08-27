#!/bin/bash
# test-install.sh

# Test env creation
./scripts/create-env.sh
if [[ -f .env ]]; then echo 'PASS: .env created'; else echo 'FAIL'; fi

# More tests...
