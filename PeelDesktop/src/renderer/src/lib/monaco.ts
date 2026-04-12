import { loader } from '@monaco-editor/react'
import * as monaco from 'monaco-editor'
import editorWorker from 'monaco-editor/esm/vs/editor/editor.worker?worker'
import jsonWorker from 'monaco-editor/esm/vs/language/json/json.worker?worker'
import tsWorker from 'monaco-editor/esm/vs/language/typescript/ts.worker?worker'

let configured = false

export function configureMonaco(): void {
  if (configured) {
    return
  }

  ;(
    self as typeof globalThis & {
      MonacoEnvironment?: {
        getWorker: (_workerId: string, label: string) => Worker
      }
    }
  ).MonacoEnvironment = {
    getWorker(_workerId, label) {
      if (label === 'json') {
        return new jsonWorker()
      }

      if (label === 'typescript' || label === 'javascript') {
        return new tsWorker()
      }

      return new editorWorker()
    }
  }

  loader.config({ monaco })

  monaco.languages.typescript.javascriptDefaults.addExtraLib(
    'declare const data: any;',
    'ts:peel/data.d.ts'
  )

  monaco.languages.typescript.javascriptDefaults.setDiagnosticsOptions({
    noSemanticValidation: false,
    noSyntaxValidation: false
  })

  monaco.editor.defineTheme('peel-light', {
    base: 'vs',
    inherit: true,
    rules: [
      { token: 'delimiter', foreground: '636366' },
      { token: 'string', foreground: 'c41a16' },
      { token: 'number', foreground: '1c00cf' },
      { token: 'keyword', foreground: '9b2393', fontStyle: 'bold' }
    ],
    colors: {
      'editor.background': '#00000000',
      'editor.lineHighlightBackground': '#00000000',
      'editorLineNumber.foreground': '#aeaeb2',
      'editorLineNumber.activeForeground': '#636366',
      'editor.selectionBackground': '#b4d8fd',
      'editor.inactiveSelectionBackground': '#d4e4f7',
      'editorCursor.foreground': '#007aff',
      'editorIndentGuide.background1': '#00000008',
      'editorIndentGuide.activeBackground1': '#00000018',
      'editor.wordHighlightBackground': '#007aff18',
      'editor.wordHighlightStrongBackground': '#007aff28',
      'editor.findMatchBackground': '#007aff40',
      'editor.findMatchHighlightBackground': '#007aff20',
      'editor.hoverHighlightBackground': '#007aff10'
    }
  })

  monaco.editor.defineTheme('peel-dark', {
    base: 'vs-dark',
    inherit: true,
    rules: [
      { token: 'delimiter', foreground: '98989d' },
      { token: 'string', foreground: 'fc6d6b' },
      { token: 'number', foreground: 'd0bf69' },
      { token: 'keyword', foreground: 'fc5fa3', fontStyle: 'bold' }
    ],
    colors: {
      'editor.background': '#00000000',
      'editor.lineHighlightBackground': '#ffffff06',
      'editorLineNumber.foreground': '#636366',
      'editorLineNumber.activeForeground': '#aeaeb2',
      'editor.selectionBackground': '#3f638b',
      'editor.inactiveSelectionBackground': '#2d4a6b',
      'editorCursor.foreground': '#0a84ff',
      'editorIndentGuide.background1': '#ffffff0a',
      'editorIndentGuide.activeBackground1': '#ffffff1a',
      'editor.wordHighlightBackground': '#0a84ff20',
      'editor.wordHighlightStrongBackground': '#0a84ff35',
      'editor.findMatchBackground': '#0a84ff50',
      'editor.findMatchHighlightBackground': '#0a84ff28',
      'editor.hoverHighlightBackground': '#0a84ff15'
    }
  })

  configured = true
}
