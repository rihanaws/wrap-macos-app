# Privacy Policy

Last updated: 2026-06-24

WarpClone is an open-source macOS terminal application. Data is local-first unless you explicitly use an external provider.

## Local Terminal Data

Terminal sessions, command blocks, configuration, and audit logs are stored on your Mac. WarpClone does not operate a hosted service for terminal history.

## AI Provider Data

When you submit an AI request, the prompt, selected attachments, and relevant request metadata are sent to the provider you configure, such as OpenRouter, OpenAI, Anthropic, or Google. WarpClone does not sell this data and does not proxy it through a WarpClone-operated server.

Provider handling is governed by the provider's own privacy and retention policy.

## Credentials

API keys are stored in macOS Keychain when supported by the configured workflow. Do not put secrets in prompts, docs, scripts, or committed files.

## Audit Logs

Permission decisions, blocked commands, and MCP approval events can be logged locally under `~/.warp/audit.log`. These logs are intended for local security review.

## MCP Servers

MCP servers run locally after approval. WarpClone restricts their launch environment and does not intentionally pass token, secret, or API-key environment variables to child processes.

## Telemetry

WarpClone does not include product analytics or background telemetry in the current beta. If crash reporting or telemetry is added later, it should be opt-in and documented before release.

## Deletion

You can remove local WarpClone state by deleting `~/.warp/` and any app-specific Keychain items you created for AI providers.

## Contact

Use the project issue tracker for privacy questions until a dedicated support address is configured.
