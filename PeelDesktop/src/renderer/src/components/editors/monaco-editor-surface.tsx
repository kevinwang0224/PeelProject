import Editor, { type OnMount } from '@monaco-editor/react'
import type * as Monaco from 'monaco-editor'
import { useEffect, useRef } from 'react'

import type { JsonValidationIssue } from '@shared/peel'
import { cn } from '@/lib/utils'

export interface MonacoSurfaceHandle {
  focus: () => void
  getTextForCopy: () => string
  pasteText: (text: string) => void
  selectAll: () => void
  showFind: () => void
}

interface MonacoEditorSurfaceProps {
  value: string
  onChange?: (value: string) => void
  language: 'json' | 'javascript' | 'plaintext'
  path: string
  theme: 'peel-light' | 'peel-dark'
  placeholder?: string
  readOnly?: boolean
  fontSize: number
  validationIssue?: JsonValidationIssue | null
  revealIssueToken?: number
  onRun?: () => void
  onBlur?: () => void
  onFocus?: (handle: MonacoSurfaceHandle | null) => void
  handleRef?: React.MutableRefObject<MonacoSurfaceHandle | null>
  transformPaste?: (text: string) => string
}

export function MonacoEditorSurface({
  value,
  onChange,
  language,
  path,
  theme,
  placeholder,
  readOnly = false,
  fontSize,
  validationIssue,
  revealIssueToken,
  onRun,
  onBlur,
  onFocus,
  handleRef,
  transformPaste
}: MonacoEditorSurfaceProps): React.JSX.Element {
  const editorRef = useRef<Monaco.editor.IStandaloneCodeEditor | null>(null)
  const monacoRef = useRef<typeof Monaco | null>(null)
  const lastRevealTokenRef = useRef<number>(0)

  const stableHandleRef = useRef<MonacoSurfaceHandle>({
    focus: () => {
      editorRef.current?.focus()
    },
    getTextForCopy: () => {
      const editor = editorRef.current
      const model = editor?.getModel()

      if (!editor || !model) {
        return ''
      }

      const selection = editor.getSelection()
      const selectedText = selection ? model.getValueInRange(selection) : ''

      return selectedText.length ? selectedText : model.getValue()
    },
    pasteText: (rawText: string) => {
      const editor = editorRef.current
      const model = editor?.getModel()

      if (!editor || !model || readOnly) {
        return
      }

      const selection = editor.getSelection() ?? model.getFullModelRange()
      const nextText = transformPaste ? transformPaste(rawText) : rawText
      editor.executeEdits('peel-manual-paste', [
        { range: selection, text: nextText, forceMoveMarkers: true }
      ])
      editor.focus()
    },
    selectAll: () => {
      void editorRef.current?.getAction('editor.action.selectAll')?.run()
    },
    showFind: () => {
      void editorRef.current?.getAction('actions.find')?.run()
    }
  })

  useEffect(() => {
    if (!handleRef) {
      return
    }

    handleRef.current = stableHandleRef.current
    return () => {
      handleRef.current = null
    }
  }, [handleRef])

  useEffect(() => {
    const editor = editorRef.current
    const monaco = monacoRef.current
    const model = editor?.getModel()

    if (!editor || !monaco || !model) {
      return
    }

    if (!validationIssue) {
      monaco.editor.setModelMarkers(model, 'peel', [])
      return
    }

    const start = model.getPositionAt(validationIssue.offset)
    const end = model.getPositionAt(validationIssue.offset + Math.max(validationIssue.length, 1))

    monaco.editor.setModelMarkers(model, 'peel', [
      {
        message: validationIssue.message,
        severity: monaco.MarkerSeverity.Error,
        startLineNumber: start.lineNumber,
        startColumn: start.column,
        endLineNumber: end.lineNumber,
        endColumn: end.column
      }
    ])
  }, [validationIssue])

  useEffect(() => {
    const editor = editorRef.current
    const model = editor?.getModel()

    if (!editor || !model || !validationIssue || !revealIssueToken) {
      return
    }

    if (lastRevealTokenRef.current === revealIssueToken) {
      return
    }

    lastRevealTokenRef.current = revealIssueToken
    const position = model.getPositionAt(validationIssue.offset)
    editor.revealLineInCenter(position.lineNumber)
    editor.setPosition(position)
  }, [revealIssueToken, validationIssue])

  const handleMount: OnMount = (editor, monaco) => {
    editorRef.current = editor
    monacoRef.current = monaco

    if (onRun) {
      editor.addCommand(monaco.KeyMod.CtrlCmd | monaco.KeyCode.Enter, () => {
        onRun()
      })
    }

    editor.onDidFocusEditorWidget(() => {
      onFocus?.(stableHandleRef.current)
    })

    editor.onDidBlurEditorWidget(() => {
      onFocus?.(null)
      onBlur?.()
    })

    const domNode = editor.getDomNode()

    const handlePaste = (event: ClipboardEvent): void => {
      if (!transformPaste || readOnly) {
        return
      }

      const pastedText = event.clipboardData?.getData('text/plain')

      if (typeof pastedText !== 'string' || !pastedText.length) {
        return
      }

      event.preventDefault()
      stableHandleRef.current.pasteText(pastedText)
    }

    domNode?.addEventListener('paste', handlePaste, true)

    editor.onDidDispose(() => {
      domNode?.removeEventListener('paste', handlePaste, true)
    })
  }

  return (
    <div className="peel-monaco-shell size-full">
      {!value.length && placeholder ? (
        <div className="peel-monaco-placeholder">{placeholder}</div>
      ) : null}
      <Editor
        path={path}
        value={value}
        language={language}
        theme={theme}
        onChange={(nextValue) => onChange?.(nextValue ?? '')}
        onMount={handleMount}
        options={{
          readOnly,
          automaticLayout: true,
          minimap: { enabled: false },
          scrollBeyondLastLine: false,
          lineNumbers: readOnly && language === 'plaintext' ? 'off' : 'on',
          renderLineHighlight: 'none',
          wordWrap: 'on',
          glyphMargin: false,
          folding: language !== 'plaintext',
          contextmenu: true,
          mouseWheelZoom: false,
          fontSize,
          fontFamily: 'IBM Plex Mono',
          padding: { top: 16, bottom: 16 },
          smoothScrolling: true,
          overviewRulerBorder: false,
          scrollbar: {
            verticalScrollbarSize: 10,
            horizontalScrollbarSize: 10
          }
        }}
        className={cn('size-full')}
      />
    </div>
  )
}
