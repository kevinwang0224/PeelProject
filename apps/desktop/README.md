# PeelDesktop

Electron-based desktop rewrite of Peel.

## Stack

- Electron
- React + TypeScript
- Vite
- Tailwind CSS
- shadcn/ui primitives
- Monaco editor

## Design Notes

See [docs/implementation-notes.md](/Users/kevin/dev/myprojects/PeelProject/apps/desktop/docs/implementation-notes.md).

## Commands

```bash
cd /Users/kevin/dev/myprojects/PeelProject
npm install
npm run dev:desktop
npm run test -w @peel/desktop
npm run build -w @peel/desktop
```

Shared JSON helpers are imported from `@peel/shared` and live in `../../packages/shared`.

## Scope

- History sidebar with search, pin, rename, delete
- Raw JSON editing with Monaco
- Automatic paste formatting for valid JSON
- JavaScript and JSONPath extraction
- Local settings and history storage
- Native dialogs for open and export
- System/light/dark theme support

