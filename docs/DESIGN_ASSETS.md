# WarpClone Design Assets

## App Icon

Use a 1024x1024 PNG source and generate macOS icon assets with:

```bash
./script/generate_icons.sh path/to/icon_1024.png
```

The generated files are written to:

```text
Sources/WarpClone/Resources/Assets.xcassets/AppIcon.appiconset
```

Recommended visual direction:

- macOS rounded-square silhouette.
- Dark terminal surface with a bright command cursor.
- Subtle AI accent, avoiding busy gradients.
- Legible at 16x16 and 32x32.

## Screenshots

Capture the main app window with:

```bash
./script/screenshot.sh
```

Recommended screenshot set:

- Main terminal with command blocks.
- AI Inspector streaming a response.
- Code Review diff with file sidebar and hunk actions.
- Settings/Security panel showing provider and permission controls.

## Release Copy

Short description:

> WarpClone is a native macOS terminal workspace with command blocks, AI streaming, code review diffs, MCP inspection, and explicit security guardrails.

Long description:

> WarpClone brings terminal sessions, AI assistance, Git review, and tool approval into a single SwiftUI macOS workspace. Commands render as durable blocks, AI answers stream into both the terminal and inspector, uncommitted changes can be reviewed in a diff surface, and potentially risky commands or MCP servers pass through explicit security checks.
