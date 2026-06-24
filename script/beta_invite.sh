#!/usr/bin/env bash
set -euo pipefail

BETA_URL="${BETA_URL:-https://github.com/rihanaws/wrap-macos-app/releases/tag/v1.0.0-beta}"
ISSUES_URL="${ISSUES_URL:-https://github.com/rihanaws/wrap-macos-app/issues}"

cat <<EOF
Subject: WarpClone beta is ready

Hi,

WarpClone is ready for beta testing. It is a native macOS terminal with command blocks, AI streaming, code review diffs, MCP inspection, and explicit security guardrails.

Download:
${BETA_URL}

Please test:
- Normal terminal commands and interactive programs
- Split panes and session switching
- AI mode with streaming responses
- Code Review diff rendering and review comments
- Security prompts for risky commands and MCP servers

Report issues here:
${ISSUES_URL}

Please include macOS version, WarpClone version, reproduction steps, screenshots for UI issues, and any crash logs from Console.app.

Thanks,
WarpClone
EOF
