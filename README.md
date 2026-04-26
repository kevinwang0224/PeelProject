# Peel

[中文说明](README_zh.md)

**Peel** is a lightweight JSON formatter and editor. The goal is a fast, minimal app with a clean interface: edit raw JSON in Monaco, run extractions with JavaScript or JSONPath, and keep a searchable history of documents—all with local storage.

## Features

- **Monaco-based editing** with syntax highlighting, validation, and familiar shortcuts  
- **Automatic paste formatting** for valid JSON; non-JSON text is kept as-is  
- **Extraction** via embedded JavaScript or **JSONPath** (work runs off the main thread)  
- **History sidebar**: create, search, pin, rename, and delete records; edits persist automatically  
- **Import / export**: open JSON files and export; clipboard read/write through the app shell  
- **Theme**: system preference, light, or dark  
- **Desktop**: native file dialogs and application menu integration (Electron)

## Repository layout

| Path | Description |
|------|-------------|
| [`apps/desktop/`](apps/desktop/) | Current **Electron** desktop app (React, TypeScript, Vite, Tailwind, shadcn/ui, Monaco) |
| [`packages/shared/`](packages/shared/) | **Platform-agnostic** JSON utilities, extraction logic, types, and history helpers (`@peel/shared`) |
| `apps/extension/` | Reserved for a future **browser extension** (reuses `@peel/shared` only) |

The renderer talks to the system only through a small **`window.peel`** API exposed in preload; it does not call Node or Electron directly from the UI.

## Prerequisites

- **Node.js** 20+ recommended (align with current Electron / Vite tooling)  
- **npm** (workspaces are used at the repo root)

## Getting started

```bash
git clone <your-fork-or-remote-url> peel
cd peel
npm install
```

### Run the desktop app (development)

```bash
npm run dev:desktop
```

This runs the `@peel/desktop` workspace with electron-vite.

### Other common scripts

| Command | Purpose |
|--------|---------|
| `npm run build:shared` | Build the `@peel/shared` package |
| `npm run lint` | Lint all workspaces that define a `lint` script |
| `npm run test` | Run tests in all workspaces |
| `npm run typecheck` | Typecheck all workspaces |
| `npm run build` | Build all workspaces (where implemented) |

### Desktop-only

From the repo root, or with `cd apps/desktop` and workspace-aware npm:

```bash
npm run test -w @peel/desktop
npm run build -w @peel/desktop
```

`@peel/desktop` `build` also builds `@peel/shared`, runs typecheck and tests, then packages the Electron app.

**macOS distributables** (see `apps/desktop/package.json`):

```bash
npm run build:mac -w @peel/desktop
```

Produces DMG and ZIP via electron-builder (configure in `apps/desktop/electron-builder.yml`).

More desktop-oriented notes: [`apps/desktop/README.md`](apps/desktop/README.md).

## Technologies (desktop)

- [Electron](https://www.electronjs.org/) — desktop shell  
- [React](https://react.dev/) + [TypeScript](https://www.typescriptlang.org/)  
- [Vite](https://vitejs.dev/) + [electron-vite](https://electron-vite.org/)  
- [Tailwind CSS](https://tailwindcss.com/) + [shadcn/ui](https://ui.shadcn.com/) (Radix primitives)  
- [Monaco Editor](https://github.com/microsoft/monaco-editor)  
- Shared parsing/helpers: [jsonc-parser](https://github.com/microsoft/node-jsonc-parser), [jsonpath-plus](https://github.com/JSONPath-Plus/JSONPath-Plus)

---

*Product name in installers: **Peel** (`appId`: `com.peel.desktop`).*
