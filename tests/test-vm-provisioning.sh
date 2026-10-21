#!/usr/bin/env bash
set -euo pipefail
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 -B -m unittest discover -s "$TEST_DIR" -p test_vm_provisioning.py -v
