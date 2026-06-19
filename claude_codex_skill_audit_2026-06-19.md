# Claude/Codex Skill and Plugin Audit

Date: 2026-06-19

## Executive Summary

- Core local Codex skills under `~/.codex/skills`: 14
- Total plugin-cache skill files under `~/.codex/plugins/cache`: 410
- The large skill surface mainly comes from installed plugin caches and marketplace bundles, including Claude-derived bundles.
- Claude-derived plugins are not only cached; many are actively enabled in `~/.codex/config.toml`.
- No removals have been performed in this audit. This is inventory only.

## Core Local Codex Skills

- `imagegen` -> `/Users/rihan/.codex/skills/.system/imagegen/SKILL.md`
- `openai-docs` -> `/Users/rihan/.codex/skills/.system/openai-docs/SKILL.md`
- `plugin-creator` -> `/Users/rihan/.codex/skills/.system/plugin-creator/SKILL.md`
- `skill-creator` -> `/Users/rihan/.codex/skills/.system/skill-creator/SKILL.md`
- `skill-installer` -> `/Users/rihan/.codex/skills/.system/skill-installer/SKILL.md`
- `codex-configuration` -> `/Users/rihan/.codex/skills/codex-configuration/SKILL.md`
- `doc` -> `/Users/rihan/.codex/skills/doc/SKILL.md`
- `gpt-5-5-prompting` -> `/Users/rihan/.codex/skills/gpt-5-5-prompting/SKILL.md`
- `opensrc` -> `/Users/rihan/.codex/skills/opensrc/SKILL.md`
- `pdf` -> `/Users/rihan/.codex/skills/pdf/SKILL.md`
- `playwright` -> `/Users/rihan/.codex/skills/playwright/SKILL.md`
- `security-best-practices` -> `/Users/rihan/.codex/skills/security-best-practices/SKILL.md`
- `security-threat-model` -> `/Users/rihan/.codex/skills/security-threat-model/SKILL.md`
- `sora` -> `/Users/rihan/.codex/skills/sora/SKILL.md`

## Config-Enabled Custom Skills

- `/Users/rihan/.agents/skills/nextjs-app-ops` enabled=True
- `/Users/rihan/.agents/skills/payments-integration` enabled=True
- `/Users/rihan/.agents/skills/white-label-saas` enabled=True
- `/Users/rihan/.agents/skills/prod-deploy` enabled=True
- `/Users/rihan/.agents/skills/db-migrations` enabled=True
- `/Users/rihan/.agents/skills/api-debugging` enabled=True
- `/Users/rihan/.agents/skills/typescript-quality` enabled=True
- `/Users/rihan/.agents/skills/security-hardening` enabled=True

## Plugin Cache Skill Counts by Namespace

- `caveman-repo`: 4
- `claude-plugins-official`: 26
- `openai-bundled`: 6
- `openai-curated`: 166
- `openai-curated-remote`: 179
- `openai-primary-runtime`: 4
- `personal`: 15
- `thedotmack`: 10

## Live Plugin Registry by Source

### `caveman-repo`

- active: 1
  - `caveman@caveman-repo`
- inactive: 0

### `claude-plugins-official`

- active: 17
  - `agent-sdk-dev@claude-plugins-official`
  - `claude-code-setup@claude-plugins-official`
  - `claude-md-management@claude-plugins-official`
  - `code-review@claude-plugins-official`
  - `code-simplifier@claude-plugins-official`
  - `commit-commands@claude-plugins-official`
  - `context7@claude-plugins-official`
  - `feature-dev@claude-plugins-official`
  - `frontend-design@claude-plugins-official`
  - `greptile@claude-plugins-official`
  - `knowledge-catalog@claude-plugins-official`
  - `playwright@claude-plugins-official`
  - `pr-review-toolkit@claude-plugins-official`
  - `redis-development@claude-plugins-official`
  - `security-guidance@claude-plugins-official`
  - `serena@claude-plugins-official`
  - `superpowers@claude-plugins-official`
- inactive: 2
  - `discord@claude-plugins-official`
  - `github@claude-plugins-official`

### `openai-bundled`

- active: 3
  - `browser@openai-bundled`
  - `chrome@openai-bundled`
  - `computer-use@openai-bundled`
- inactive: 0

### `openai-curated`

- active: 20
  - `build-ios-apps@openai-curated`
  - `build-macos-apps@openai-curated`
  - `build-web-apps@openai-curated`
  - `build-web-data-visualization@openai-curated`
  - `coderabbit@openai-curated`
  - `codex-security@openai-curated`
  - `fyxer@openai-curated`
  - `github@openai-curated`
  - `gmail@openai-curated`
  - `hostinger@openai-curated`
  - `hugging-face@openai-curated`
  - `intercom@openai-curated`
  - `mem@openai-curated`
  - `openai-developers@openai-curated`
  - `outlook-email@openai-curated`
  - `render@openai-curated`
  - `sentry@openai-curated`
  - `shutterstock@openai-curated`
  - `superpowers@openai-curated`
  - `vercel@openai-curated`
- inactive: 0

### `openai-primary-runtime`

- active: 3
  - `documents@openai-primary-runtime`
  - `presentations@openai-primary-runtime`
  - `spreadsheets@openai-primary-runtime`
- inactive: 0

### `personal`

- active: 1
  - `claude-mem@personal`
- inactive: 0

### `thedotmack`

- active: 0
- inactive: 1
  - `claude-mem@thedotmack`

## Claude Marketplace Cache Directories in Codex

- `/Users/rihan/.codex/plugins/cache/claude-plugins-official/agent-sdk-dev` skill_files=0
- `/Users/rihan/.codex/plugins/cache/claude-plugins-official/claude-code-setup` skill_files=1
- `/Users/rihan/.codex/plugins/cache/claude-plugins-official/claude-md-management` skill_files=1
- `/Users/rihan/.codex/plugins/cache/claude-plugins-official/code-review` skill_files=0
- `/Users/rihan/.codex/plugins/cache/claude-plugins-official/code-simplifier` skill_files=0
- `/Users/rihan/.codex/plugins/cache/claude-plugins-official/commit-commands` skill_files=0
- `/Users/rihan/.codex/plugins/cache/claude-plugins-official/context7` skill_files=0
- `/Users/rihan/.codex/plugins/cache/claude-plugins-official/discord` skill_files=2
- `/Users/rihan/.codex/plugins/cache/claude-plugins-official/feature-dev` skill_files=0
- `/Users/rihan/.codex/plugins/cache/claude-plugins-official/frontend-design` skill_files=1
- `/Users/rihan/.codex/plugins/cache/claude-plugins-official/github` skill_files=0
- `/Users/rihan/.codex/plugins/cache/claude-plugins-official/greptile` skill_files=0
- `/Users/rihan/.codex/plugins/cache/claude-plugins-official/knowledge-catalog` skill_files=1
- `/Users/rihan/.codex/plugins/cache/claude-plugins-official/playwright` skill_files=0
- `/Users/rihan/.codex/plugins/cache/claude-plugins-official/pr-review-toolkit` skill_files=0
- `/Users/rihan/.codex/plugins/cache/claude-plugins-official/redis-development` skill_files=0
- `/Users/rihan/.codex/plugins/cache/claude-plugins-official/security-guidance` skill_files=0
- `/Users/rihan/.codex/plugins/cache/claude-plugins-official/serena` skill_files=0
- `/Users/rihan/.codex/plugins/cache/claude-plugins-official/slack` skill_files=6
- `/Users/rihan/.codex/plugins/cache/claude-plugins-official/superpowers` skill_files=14

## Claude Marketplace Clones Under `~/.claude`

- `/Users/rihan/.claude/plugins/marketplaces/anthropics-claude-code `
- `/Users/rihan/.claude/plugins/marketplaces/caveman`
- `/Users/rihan/.claude/plugins/marketplaces/claude-plugins-official`
- `/Users/rihan/.claude/plugins/marketplaces/neon`
- `/Users/rihan/.claude/plugins/marketplaces/thedotmack`
- `/Users/rihan/.claude/plugins/marketplaces/thedotmack.bak`

## Handoff and Summary Files Under `~/.claude`

- `/Users/rihan/.claude/PR2-HANDOFF.md`
- `/Users/rihan/.claude/PR3-HANDOFF.md`
- `/Users/rihan/.claude/PR4-HANDOFF.md`
- `/Users/rihan/.claude/PR8-HANDOFF.md`
- `/Users/rihan/.claude/SESSION-HANDOFF-PHASE4.md`
- `/Users/rihan/.claude/SESSION-HANDOFF.md`
- `/Users/rihan/.claude/cache/IMPLEMENTATION_SUMMARY.md`

## Codex Rollout Summary Files

- total: 91
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-03T23-33-35-Id6X-pendrive_macos_read_only_disk9_troubleshooting.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-03T23-35-22-YArz-san_disk_pendrive_read_only_macos_diagnosis.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-35-12-8upt-cursor_rule_caveman_activate_frontmatter_fix.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-35-20-IGCP-autocsr_welcome_email_shipped_on_main.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-35-23-CGQl-welcome_email_claude_update_commit_push.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-35-27-hR8N-autocsr_welcome_email_first_sign_in.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-35-32-l3OQ-autocsr_week4_welcome_email_status_update.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-35-40-7GWi-autocsr_welcome_email_first_signin.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-35-47-uMFq-add_react_email_preview_script_autocsr_web.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-35-51-7BU4-autocsr_welcome_email_resend_nextauth.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-35-56-1QJc-autocsr_onboarding_email_auth_inspection.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-36-02-ZWT1-polar_billing_webhook_security_review.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-36-13-CnOP-security_review_polar_billing_webhook_pii_log.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-36-18-Z5r2-polar_sandbox_billing_end_to_end.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-36-22-kzF4-polar_sandbox_billing_ngrok_webhook_commit.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-36-27-exV8-autocsr_memory_index_polar_billing_update.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-36-31-KGzu-polar_sandbox_billing_status_update.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-36-40-e44x-polar_sandbox_billing_wiring_autocsr.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-36-42-L3Uj-polar_sandbox_billing_wired_and_documented.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-36-45-SmBf-polar_sandbox_billing_claude_md_update.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-36-48-pxFD-autocsr_project_status_loaded_polar_sandbox_pending.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-36-51-JQB6-autocsr_repo_claude_docs_week4_status.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-36-54-ia6T-polar_sandbox_billing_end_to_end.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-36-58-2Zk6-polar_sandbox_billing_webhook_and_tier_verification.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-37-14-0vjr-polar_sandbox_billing_webhook_update.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-37-18-v5OC-polar_sandbox_webhook_delivery_diagnostics.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-37-23-4c57-neon_db_connectivity_schema_enumeration.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-37-27-ZplK-web_prisma_migration_state_check.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-37-29-Yo7V-observe_web_db_env_and_schema.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-37-33-Ksml-polar_sandbox_billing_ngrok_checkout_validation.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-37-39-3n5J-polar_sandbox_billing_ngrok_setup.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-37-42-XApN-ngrok_config_location_and_token_migration.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-37-47-0ok6-polar_sandbox_billing_end_to_end.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-37-55-DMsq-polar_sandbox_billing_checkout_redirect.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-38-02-2ryz-polar_pat_set_in_web_env.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-38-06-nSKo-polar_sandbox_billing_end_to_end.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-38-14-TLWO-polar_sandbox_billing_wiring.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-38-19-mzLG-polar_sandbox_billing_end_to_end.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-38-24-WGj3-polar_sandbox_billing_setup_checkout_url_shape.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-38-29-abbE-polar_checkout_create_typing_inspection.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-38-32-qbvO-polar_sandbox_billing_sdk_checkout_inspection.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-38-36-uFFh-polar_sandbox_billing_setup_env_and_sdk.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T14-38-40-J31L-polar_sandbox_webhook_setup.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T20-23-54-py15-autocsr_full_repo_review_priority_issues_and_verification.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-07T21-44-38-IKJV-omlx_8005_mcp_and_ui_management.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T04-00-06-m7rz-login_config_error_missing_prisma_client.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T04-00-10-llcI-autocsr_web_codebase_recon.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T04-00-12-8Jmq-techsci_agency_platform_memory_pipeline_review.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T12-31-27-D6ST-codex_worktree_setup_syntax_check.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T12-31-30-LiOK-codex_worktree_setup_script_added.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T12-31-33-Y47n-codex_local_environments_doc_lookup.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T12-31-37-JH3C-codex_local_environments_worktree_setup.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T12-31-40-5mfL-codex_app_worktree_config_discovery.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T12-31-43-7Frw-codex_host_setup_mcp_agents_execpolicy.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T12-31-47-JnoT-techsci_agency_platform_site_wide_refresh_tests_pass.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T12-31-52-5lGI-autocsr_dashboard_review_training_discovery.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T12-31-56-oLL4-techsci_agency_platform_repo_discovery.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T12-31-59-jWwd-knowledge_upload_and_agents_dashboard_inspection.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T12-32-01-XT3h-techsci_agency_platform_codebase_review_core_integrations.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T12-32-04-OaW3-autocsr_web_schema_dashboard_layout.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T12-32-07-TEkg-autocsr_auth_env_discovery.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T12-32-11-Fmm9-techsci_agency_platform_codebase_review_architecture.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T12-32-13-GDrh-autocsr_web_codebase_orientation_and_global_styling_discover.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T12-32-18-oG9X-techsci_agency_platform_recon.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T12-32-21-Ehx3-repo_inventory_and_skill_discovery.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T12-32-24-viAe-claude_mem_mcp_auth_failure.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T12-32-29-W4p8-knowledge_document_schema_inspection.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T12-32-33-ngBq-block_9_knowledge_base_end_to_end_neon_schema_discovery.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T12-32-44-R342-login_error_missing_prisma_client_generate.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T12-32-48-NKB2-tenant_isolation_bypass_semantic_cache_filter_injection.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T12-32-51-obVu-knowledge_base_end_to_end_validation.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T12-32-54-6YTd-knowledge_base_end_to_end_validation.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T12-32-57-DahH-inference_embed_smoke_test_port_8000_conflict.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T12-33-00-wbbQ-block_9_knowledge_base_validation.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T12-33-03-vSso-manual_knowledge_chunk_embed.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T12-33-06-zpku-knowledge_base_dashboard_real_counts.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T12-33-10-1Hwl-knowledge_context_onboarding_agent.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T12-33-14-lQ97-knowledge_base_agent_retrieval_withdrawal_verification.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T12-33-17-CUMO-knowledge_base_agent_context_wiring.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-10T15-01-19-dk6l-nightly_ci_report_ci_failure_baseline.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-12T10-46-50-r4CI-nightly_ci_report_github_actions_deploy_failures.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-12T10-58-47-loeV-bankguard_ai_phase1_hardening_git_push_prisma_migration.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-12T15-02-01-BZSJ-nightly_ci_report_green_window.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-13T07-06-31-gBVF-gpt_55_prompting_skill_created.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-13T07-18-08-Oyfw-split_gpt55_prompting_and_codex_configuration_skills.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-13T07-38-26-jtMV-install_and_validate_opensrc_skill.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-15T01-51-34-47nd-gpt_55_prompting_skill_creation.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-15T02-09-21-FcpC-gpt_5_5_prompting_skill_first.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-15T14-03-51-ABuC-multi_ide_config_duplication_audit.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-15T14-52-35-Avj4-ide_mcp_secret_and_plugin_cleanup_phase_work.md`
- `/Users/rihan/.codex/memories/rollout_summaries/2026-06-18T18-46-42-Am5v-codex_ui_config_diagnostic_headroom_down_cloud_disabled.md`

## Preliminary Classification

### Keep Permanently

- `~/.codex/skills/*` core local skills
- `~/.agents/skills/*` skills explicitly enabled in `~/.codex/config.toml`
- OpenAI runtime/curated plugins you actually use for daily work

### Claude-Derived and Likely Optional

- `~/.codex/plugins/cache/claude-plugins-official/*`
- `~/.claude/plugins/marketplaces/claude-plugins-official/*`
- `~/.claude/plugins/marketplaces/anthropics-claude-code` and related marketplace clones if you are not using Claude Code locally
- Claude handoff/history artifacts under `~/.claude/*HANDOFF*.md` and `~/.claude/cache/IMPLEMENTATION_SUMMARY.md`

### Important Constraint Before Deletion

- Many Claude-derived plugins are still enabled in `~/.codex/config.toml`. Removing cache directories alone would leave broken references. Cleanup must update config first, then remove bundles, then validate.

