#!/usr/bin/env bash
# Run OpenTofu commands with the macOS TLS workaround.
# Required when the OS user doesn't exist in the local Directory Service,
# which prevents Go's CGO TLS stack from accessing the macOS Keychain.
set -euo pipefail
export GODEBUG=x509usefallback=1
exec tofu "$@"
