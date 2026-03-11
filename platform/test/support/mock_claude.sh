#!/bin/bash
set -euo pipefail

# Mock Claude CLI for testing the Platform.Agent Port pipeline.
# Reads prompt from stdin, returns a valid JSON response.

prompt=$(cat)

cat <<'EOF'
{"messages":[{"role":"assistant","content":[{"type":"text","text":"Mock response for task"}]}]}
EOF
