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

See [docs/implementation-notes.md](/Users/kevin/dev/myprojects/PeelProject/PeelDesktop/docs/implementation-notes.md).

## Commands

```bash
cd /Users/kevin/dev/myprojects/PeelProject/PeelDesktop
npm install
npm run dev
npm run test
npm run build
```

## Scope

- History sidebar with search, pin, rename, delete
- Raw JSON editing with Monaco
- Automatic paste formatting for valid JSON
- JavaScript and JSONPath extraction
- Local settings and history storage
- Native dialogs for open and export
- System/light/dark theme support
