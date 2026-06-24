# WarpClone Beta Testing

## Install

1. Download the latest `WarpClone-1.0.0-beta.dmg` from GitHub Releases.
2. Open the DMG and drag `WarpClone.app` into `/Applications`.
3. Launch WarpClone. If Gatekeeper warns on an unsigned local build, right-click the app and choose Open.

For source builds:

```bash
git clone https://github.com/rihanaws/wrap-macos-app.git
cd wrap-macos-app
swift build
./script/build_and_run.sh
```

## Test Checklist

- Run terminal commands: `ls`, `git status`, `cat`, `grep`.
- Try interactive programs such as `vim`, `nano`, and `htop`.
- Split panes with `Cmd+D` and `Cmd+Shift+D`.
- Switch working directories and confirm new commands run in the active directory.
- Type `# hello` in AI mode and confirm tokens stream into a terminal block and the AI Inspector.
- Attach images up to the configured limit and submit an AI request.
- Stop a streaming response midway.
- Open the Code Review tab, select changed files, and verify green/red diff rendering.
- Add a review comment and submit it to AI.
- Verify risky shell commands trigger security prompts or blocks.
- Confirm MCP servers require approval before starting.

## Bug Reports

Report issues at `https://github.com/rihanaws/wrap-macos-app/issues` with:

- macOS version and hardware.
- WarpClone version or commit SHA.
- Reproduction steps.
- Screenshots for UI issues.
- Crash logs from Console.app when available.

## Known Limitations

- Public distribution requires a Developer ID certificate and notarization.
- Hunk-level diff actions currently show confirmation stubs.
- AI review responses are streamed to terminal blocks; applying returned patches is not automatic.
