# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
cd PeelApp

# Generate Xcode project from project.yml (also builds)
./generate_project.sh

# Just regenerate the project
xcodegen generate

# Run tests (always prefer test over build-only)
xcodebuild -project Peel.xcodeproj -scheme Peel -configuration Debug -derivedDataPath build test

# Build only
xcodebuild -project Peel.xcodeproj -scheme Peel -configuration Debug -derivedDataPath build build
```

**Prerequisites**: Xcode 15+, macOS 14.0+, XcodeGen (`brew install xcodegen`)

## Project Overview

Peel is a native macOS JSON formatter and editor. Zero third-party dependencies — only Apple frameworks (SwiftUI, SwiftData, Foundation, JavaScriptCore, WebKit/AppKit).

Active code lives in `PeelApp/`. The old `Peel/` directory is deprecated.

## Architecture

**Entry point**: `PeelApp/Peel/App/PeelApp.swift` — app setup, menu, global shortcuts

**State management**: `JSONWorkspace` (marked `@Observable`) is the single source of truth for editor content, formatting state, and extraction results. All views bind to it.

**Key flow**:
```
ContentView (NavigationSplitView)
├── SidebarView — history list with search, pin, rename
│   └── HistoryRowView
└── EditorContainerView — right panel
    ├── RawJSONEditorPanel — JSON text editor (NSTextView-based with syntax highlighting)
    ├── ExtractionResultPanel — shows JS/JSONPath extraction output
    └── ExpressionEditorPanel — expression input (Cmd+Return to run)
```

**Services** (in `Peel/Services/`):
- `JSONFormatterService` — all JSON processing (pretty-print, compact, sort, validate)
- `JSONExtractionService` — JavaScript and JSONPath extraction from JSON
- `SyntaxHighlighter` — NSTextView-based syntax coloring with error line highlighting
- `QuickPasteController` — global hotkey clipboard import

**Models** (in `Peel/Models/`):
- `HistoryItem` — SwiftData model for persisted history entries
- `JSONDocument` — in-memory document representation
- `EditorLayoutSettings` — layout preferences (stacked vs side-by-side)

**Persistence**: SwiftData. Edits auto-save to the current `HistoryItem`. Empty records are auto-deleted on navigation.

## Key Conventions

- **Project config changes** → edit `PeelApp/project.yml`, then regenerate (never edit `.xcodeproj` directly)
- **JSON processing** → always route through `JSONFormatterService`, never use `JSONSerialization` directly in views
- **Extraction** → always route through `JSONExtractionService`
- **No third-party deps** — use system frameworks only
- **Do not commit**: `build/`, `DerivedData/`, `xcuserdata/`, `.xcuserstate`
- After functional or config changes, run `xcodebuild test` — not just build

## Language

The AGENTS.md file and user preferences are in Chinese (中文). Respond in Chinese when the user writes in Chinese.
