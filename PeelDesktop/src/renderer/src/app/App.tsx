import { AnimatePresence, motion } from 'framer-motion'
import {
  Braces,
  ChevronDown,
  Copy,
  FolderOpen,
  Info,
  Keyboard,
  Minimize2,
  MoreHorizontal,
  Palette,
  PanelLeftClose,
  PanelLeftOpen,
  PanelRightClose,
  PanelRightOpen,
  Pencil,
  Pin,
  PinOff,
  Plus,
  Search,
  Settings,
  Trash2,
  X
} from 'lucide-react'
import {
  startTransition,
  useCallback,
  useDeferredValue,
  useEffect,
  useMemo,
  useRef,
  useState
} from 'react'
import { toast, Toaster } from 'sonner'

import { createDefaultTitle } from '@shared/history'
import {
  DEFAULT_SETTINGS,
  type AppSnapshot,
  type ExtractionMode,
  type ExtractionResult,
  type HistoryRecord,
  type MenuAction
} from '@shared/peel'
import { formatJson, formatPastedJson, summarizeJson, tryParseJson } from '@shared/json'
import {
  MonacoEditorSurface,
  type MonacoSurfaceHandle
} from '@/components/editors/monaco-editor-surface'
import { Button } from '@/components/ui/button'
import {
  ContextMenu,
  ContextMenuContent,
  ContextMenuItem,
  ContextMenuSeparator,
  ContextMenuTrigger
} from '@/components/ui/context-menu'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle
} from '@/components/ui/dialog'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger
} from '@/components/ui/dropdown-menu'
import { Input } from '@/components/ui/input'
import { ScrollArea } from '@/components/ui/scroll-area'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue
} from '@/components/ui/select'
import { Separator } from '@/components/ui/separator'
import { TooltipProvider } from '@/components/ui/tooltip'
import { runExtractionInWorker } from '@/lib/extraction-client'
import { formatRelativeTime } from '@/lib/relative-time'
import { cn } from '@/lib/utils'

const idleExtractionResult: ExtractionResult = {
  status: 'idle',
  title: 'Result',
  text: 'Run an expression to inspect this document.',
  displayStyle: 'plainText'
}

const EMPTY_HISTORY: HistoryRecord[] = []

export default function App(): React.JSX.Element {
  const [snapshot, setSnapshot] = useState<AppSnapshot | null>(null)
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [editorText, setEditorText] = useState('')
  const [searchText, setSearchText] = useState('')
  const [settingsOpen, setSettingsOpen] = useState(false)
  const [settingsSection, setSettingsSection] = useState<'appearance' | 'shortcuts' | 'about'>(
    'appearance'
  )
  const [quickPasteShortcutDraft, setQuickPasteShortcutDraft] = useState('')
  const [isCapturingShortcut, setIsCapturingShortcut] = useState(false)
  const [renameTarget, setRenameTarget] = useState<HistoryRecord | null>(null)
  const [renameValue, setRenameValue] = useState('')
  const [resultCollapsed, setResultCollapsed] = useState(true)
  const [resultVisible, setResultVisible] = useState(false)
  const [splitRatio, setSplitRatio] = useState(0.55)
  const [isEditingTitle, setIsEditingTitle] = useState(false)
  const [titleDraft, setTitleDraft] = useState('')
  const [extractionMode, setExtractionMode] = useState<ExtractionMode>('javascript')
  const [extractionQuery, setExtractionQuery] = useState('data')
  const [extractionResult, setExtractionResult] = useState<ExtractionResult>(idleExtractionResult)
  const [errorRevealToken, setErrorRevealToken] = useState(0)
  const [systemTheme, setSystemTheme] = useState<'light' | 'dark'>('light')

  const deferredSearch = useDeferredValue(searchText)
  const rawEditorHandleRef = useRef<MonacoSurfaceHandle | null>(null)
  const expressionEditorHandleRef = useRef<MonacoSurfaceHandle | null>(null)
  const resultEditorHandleRef = useRef<MonacoSurfaceHandle | null>(null)
  const activeEditorHandleRef = useRef<MonacoSurfaceHandle | null>(null)
  const splitContainerRef = useRef<HTMLDivElement>(null)
  const [newMenuOpen, setNewMenuOpen] = useState(false)
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false)
  const newMenuTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const focusRawEditorSoon = useCallback(() => {
    window.setTimeout(() => {
      rawEditorHandleRef.current?.focus()
      activeEditorHandleRef.current = rawEditorHandleRef.current
    }, 0)
  }, [])

  const records = snapshot?.history ?? EMPTY_HISTORY
  const settings = snapshot?.settings ?? DEFAULT_SETTINGS
  const selectedRecord = records.find((record) => record.id === selectedId) ?? null
  const titleForWidth = isEditingTitle ? titleDraft : (selectedRecord?.title ?? 'Untitled')
  const titleWidthCh = Math.min(Math.max(titleForWidth.length, 12), 28)
  const summary = summarizeJson(editorText)
  const resolvedTheme = settings.theme === 'system' ? systemTheme : settings.theme
  const monacoTheme = resolvedTheme === 'dark' ? 'peel-dark' : 'peel-light'
  const visibleExtractionResult = extractionQuery.trim().length
    ? extractionResult
    : idleExtractionResult

  const filteredRecords = useMemo(() => {
    const query = deferredSearch.trim().toLowerCase()

    if (!query.length) {
      return records
    }

    return records.filter((record) => {
      return (
        record.title.toLowerCase().includes(query) || record.content.toLowerCase().includes(query)
      )
    })
  }, [deferredSearch, records])

  const pinnedRecords = filteredRecords.filter((record) => record.pinned)
  const regularRecords = filteredRecords.filter((record) => !record.pinned)

  useEffect(() => {
    const media = window.matchMedia('(prefers-color-scheme: dark)')
    const sync = (): void => setSystemTheme(media.matches ? 'dark' : 'light')

    sync()
    media.addEventListener('change', sync)

    return () => {
      media.removeEventListener('change', sync)
    }
  }, [])

  useEffect(() => {
    document.documentElement.classList.toggle('dark', resolvedTheme === 'dark')
  }, [resolvedTheme])

  useEffect(() => {
    let mounted = true

    void window.peel.bootstrap().then((nextSnapshot) => {
      if (!mounted) {
        return
      }

      const initialRecord = nextSnapshot.history[0] ?? null

      startTransition(() => {
        setSnapshot(nextSnapshot)
        setSelectedId(initialRecord?.id ?? null)
        setEditorText(initialRecord?.content ?? '')
      })
    })

    return () => {
      mounted = false
    }
  }, [])

  const applySnapshot = useCallback((nextSnapshot: AppSnapshot): void => {
    startTransition(() => {
      setSnapshot(nextSnapshot)
    })
  }, [])

  const persistCurrentEditor = useCallback(async (): Promise<AppSnapshot | null> => {
    if (!snapshot) {
      return null
    }

    if (!selectedId && !editorText.trim().length) {
      return snapshot
    }

    if (!selectedId) {
      const created = await window.peel.history.create({
        title: createDefaultTitle(),
        content: editorText
      })

      applySnapshot(created.snapshot)

      startTransition(() => {
        setSelectedId(created.record.id)
      })

      return created.snapshot
    }

    const currentRecord = snapshot.history.find((record) => record.id === selectedId)

    if (!currentRecord || currentRecord.content === editorText) {
      return snapshot
    }

    const nextSnapshot = await window.peel.history.save({
      ...currentRecord,
      content: editorText
    })

    applySnapshot(nextSnapshot)
    return nextSnapshot
  }, [applySnapshot, editorText, selectedId, snapshot])

  useEffect(() => {
    if (!snapshot) {
      return
    }

    if (!editorText.trim().length && !selectedId) {
      return
    }

    if (selectedId) {
      const currentRecord = snapshot.history.find((record) => record.id === selectedId)

      if (currentRecord?.content === editorText) {
        return
      }
    }

    const timer = window.setTimeout(() => {
      void persistCurrentEditor()
    }, 320)

    return () => {
      window.clearTimeout(timer)
    }
  }, [editorText, persistCurrentEditor, selectedId, snapshot])

  const openResult = useCallback(() => {
    setResultCollapsed(false)
    setResultVisible(true)
  }, [])

  const closeResult = useCallback(() => {
    setResultVisible(false)
    setResultCollapsed(true)
  }, [])

  const handleDragStart = useCallback((e: React.MouseEvent) => {
    e.preventDefault()
    const container = splitContainerRef.current
    if (!container) return

    const containerRect = container.getBoundingClientRect()

    const onMove = (ev: MouseEvent): void => {
      const ratio = (ev.clientX - containerRect.left) / containerRect.width
      setSplitRatio(Math.max(0.25, Math.min(0.78, ratio)))
    }

    const onUp = (): void => {
      document.removeEventListener('mousemove', onMove)
      document.removeEventListener('mouseup', onUp)
    }

    document.addEventListener('mousemove', onMove)
    document.addEventListener('mouseup', onUp)
  }, [])

  const handleTitleCommit = useCallback(async (): Promise<void> => {
    if (!selectedId) {
      setIsEditingTitle(false)
      return
    }

    const trimmed = titleDraft.trim()
    if (!trimmed) {
      setIsEditingTitle(false)
      return
    }

    const currentTitle = records.find((record) => record.id === selectedId)?.title
    if (currentTitle === trimmed) {
      setIsEditingTitle(false)
      return
    }

    try {
      const nextSnapshot = await window.peel.history.rename(selectedId, trimmed)
      // 不用 startTransition：否则 snapshot 晚一帧才更新，会先退出编辑态并闪一下旧标题
      setSnapshot(nextSnapshot)
    } finally {
      setIsEditingTitle(false)
    }
  }, [records, selectedId, titleDraft])

  const runExtraction = useCallback(
    async (expand = false): Promise<void> => {
      if (!extractionQuery.trim().length) {
        setExtractionResult(idleExtractionResult)
        return
      }

      const parsed = tryParseJson(editorText)

      if (parsed.issue || parsed.value === null) {
        setExtractionResult({
          status: 'error',
          title: 'Invalid JSON',
          text: 'Current content is not valid JSON.',
          displayStyle: 'plainText'
        })
        if (expand) {
          openResult()
        }
        return
      }

      try {
        const result = await runExtractionInWorker({
          mode: extractionMode,
          query: extractionQuery,
          data: parsed.value
        })

        setExtractionResult(result)
        if (expand || result.status !== 'idle') {
          openResult()
        }
      } catch (error) {
        setExtractionResult({
          status: 'error',
          title: 'Extraction Failed',
          text: error instanceof Error ? error.message : 'Extraction failed.',
          displayStyle: 'plainText'
        })
      }
    },
    [editorText, extractionMode, extractionQuery, openResult]
  )

  useEffect(() => {
    if (!extractionQuery.trim().length) {
      return
    }

    startTransition(openResult)

    const timer = window.setTimeout(() => {
      void runExtraction()
    }, 260)

    return () => {
      window.clearTimeout(timer)
    }
  }, [editorText, extractionMode, extractionQuery, runExtraction, openResult])

  const handleCreateRecord = useCallback(
    async (initialContent: string): Promise<void> => {
      await persistCurrentEditor()
      const created = await window.peel.history.create({
        title: createDefaultTitle(),
        content: initialContent
      })

      applySnapshot(created.snapshot)
      startTransition(() => {
        setSelectedId(created.record.id)
        setEditorText(created.record.content)
        setExtractionResult(idleExtractionResult)
      })

      focusRawEditorSoon()
    },
    [applySnapshot, focusRawEditorSoon, persistCurrentEditor]
  )

  const handleOpenJson = useCallback(async (): Promise<void> => {
    const opened = await window.peel.files.openJson()

    if (!opened) {
      return
    }

    const nextContent = formatPastedJson(opened.content)
    const created = await window.peel.history.create({
      title: opened.title,
      content: nextContent
    })

    applySnapshot(created.snapshot)
    startTransition(() => {
      setSelectedId(created.record.id)
      setEditorText(created.record.content)
    })

    toast.success('Opened as a new record.')
  }, [applySnapshot])

  const handleExportJson = useCallback(async (): Promise<void> => {
    if (!editorText.trim().length) {
      toast.message('There is nothing to export yet.')
      return
    }

    const didExport = await window.peel.files.exportJson({
      suggestedName: `${(selectedRecord?.title || 'Peel Export').replaceAll('/', '-')}.json`,
      content: editorText
    })

    if (didExport) {
      toast.success('JSON exported.')
    }
  }, [editorText, selectedRecord])

  const handleSelectRecord = useCallback(
    async (record: HistoryRecord): Promise<void> => {
      if (record.id === selectedId) {
        return
      }

      const nextSnapshot = (await persistCurrentEditor()) ?? snapshot
      const nextRecord = nextSnapshot?.history.find((item) => item.id === record.id) ?? record

      startTransition(() => {
        setSelectedId(nextRecord.id)
        setEditorText(nextRecord.content)
        setExtractionResult(idleExtractionResult)
      })
    },
    [persistCurrentEditor, selectedId, snapshot]
  )

  const handleDeleteRecord = useCallback(
    async (record: HistoryRecord): Promise<void> => {
      const nextSnapshot = await window.peel.history.remove(record.id)
      applySnapshot(nextSnapshot)

      const fallback = nextSnapshot.history[0] ?? null
      startTransition(() => {
        if (record.id === selectedId) {
          setSelectedId(fallback?.id ?? null)
          setEditorText(fallback?.content ?? '')
        }
      })

      toast.success('Record deleted.')
    },
    [applySnapshot, selectedId]
  )

  const handleTogglePin = useCallback(
    async (record: HistoryRecord): Promise<void> => {
      const nextSnapshot = await window.peel.history.togglePin(record.id)
      applySnapshot(nextSnapshot)
    },
    [applySnapshot]
  )

  const handleRenameSubmit = useCallback(async (): Promise<void> => {
    if (!renameTarget) {
      return
    }

    const nextSnapshot = await window.peel.history.rename(renameTarget.id, renameValue)
    applySnapshot(nextSnapshot)
    setRenameTarget(null)
    toast.success('Title updated.')
  }, [applySnapshot, renameTarget, renameValue])

  const handleFormat = useCallback(
    (style: 'pretty' | 'compact'): void => {
      const result = formatJson(editorText, style)

      if (!result.ok) {
        setErrorRevealToken((value) => value + 1)
        toast.error(result.issue.message)
        return
      }

      setEditorText(result.output)
      toast.success(style === 'pretty' ? 'JSON formatted.' : 'JSON compacted.')
    },
    [editorText]
  )

  const handleCopyCurrent = useCallback(async (): Promise<void> => {
    const result = formatJson(editorText, 'pretty')
    const textToCopy = result.ok ? result.output : editorText
    await window.peel.clipboard.writeText(textToCopy)
    toast.success('Copied.')
  }, [editorText])

  const handleCopyExtraction = useCallback(async (): Promise<void> => {
    if (visibleExtractionResult.status !== 'success') {
      return
    }

    await window.peel.clipboard.writeText(visibleExtractionResult.text)
    toast.success('Result copied.')
  }, [visibleExtractionResult])

  const handleFormatResult = useCallback(
    (style: 'pretty' | 'compact'): void => {
      if (extractionResult.displayStyle !== 'structuredJson') return
      const result = formatJson(extractionResult.text, style)
      if (!result.ok) return
      setExtractionResult((prev) => ({ ...prev, text: result.output }))
    },
    [extractionResult]
  )

  const persistSettings = useCallback(
    async (nextSettings: AppSnapshot['settings']): Promise<void> => {
      const nextSnapshot = await window.peel.settings.save(nextSettings)
      applySnapshot(nextSnapshot)
    },
    [applySnapshot]
  )

  const handleMenuAction = useCallback(
    async (action: MenuAction): Promise<void> => {
      switch (action) {
        case 'new-json':
          await handleCreateRecord('{}')
          break
        case 'new-json-from-clipboard': {
          const clipboardText = await window.peel.clipboard.readText()
          await handleCreateRecord(formatPastedJson(clipboardText))
          break
        }
        case 'open-json':
          await handleOpenJson()
          break
        case 'export-json':
          await handleExportJson()
          break
        case 'format-json':
          handleFormat('pretty')
          break
        case 'compact-json':
          handleFormat('compact')
          break
        case 'find':
          activeEditorHandleRef.current?.showFind()
          break
      }
    },
    [handleCreateRecord, handleExportJson, handleFormat, handleOpenJson]
  )

  useEffect(() => {
    return window.peel.menu.onAction((action) => {
      void handleMenuAction(action)
    })
  }, [handleMenuAction])

  if (!snapshot) {
    return <LoadingSplash />
  }

  return (
    <TooltipProvider delayDuration={180}>
      <div className="peel-shell">
        {/* ── Row 1: full-width header bar (sidebar controls | title toolbar) ── */}
        {/* ── Row 2: sidebar content | main editor ── */}
        <div
          className="grid h-full grid-rows-[auto_minmax(0,1fr)] gap-x-px [will-change:grid-template-columns]"
          style={{
            gridTemplateColumns: sidebarCollapsed ? '160px minmax(0,1fr)' : '260px minmax(0,1fr)',
            transition: 'grid-template-columns 320ms cubic-bezier(0.32, 0.72, 0, 1)'
          }}
        >
          {/* ── Row 1, Col 1: Sidebar header (sibling of main header → same row height) ── */}
          <div
            className="peel-window-drag flex items-center gap-0.5 border-b border-r border-[var(--border)] bg-[var(--panel)]"
            style={{
              paddingLeft: sidebarCollapsed ? 88 : undefined,
              paddingRight: sidebarCollapsed ? 8 : 8,
              justifyContent: sidebarCollapsed ? 'flex-start' : 'flex-end'
            }}
          >
            {/* Toggle: collapse ↔ expand */}
            <button
              onClick={() => setSidebarCollapsed((v) => !v)}
              title={sidebarCollapsed ? 'Expand Sidebar' : 'Collapse Sidebar'}
              className="flex size-7 items-center justify-center rounded-md text-[var(--muted)] transition-colors hover:bg-[color-mix(in_srgb,var(--foreground)_5%,transparent)] hover:text-[var(--foreground)]"
            >
              {sidebarCollapsed ? <PanelLeftOpen size={18} /> : <PanelLeftClose size={18} />}
            </button>

            {/* + button with hover dropdown */}
            <div
              className="relative"
              onMouseEnter={() => {
                if (newMenuTimerRef.current) clearTimeout(newMenuTimerRef.current)
                setNewMenuOpen(true)
              }}
              onMouseLeave={() => {
                newMenuTimerRef.current = setTimeout(() => setNewMenuOpen(false), 120)
              }}
            >
              <button
                onClick={() => void handleCreateRecord('{}')}
                className="flex size-7 items-center justify-center gap-0.5 rounded-md pl-0.5 pr-1 text-[var(--muted)] transition-colors hover:bg-[color-mix(in_srgb,var(--foreground)_5%,transparent)] hover:text-[var(--foreground)]"
              >
                <Plus size={18} />
                <ChevronDown size={10} className="opacity-50" />
              </button>

              <AnimatePresence>
                {newMenuOpen && (
                  <motion.div
                    className="peel-window-no-drag absolute left-0 top-full z-50 mt-1 min-w-[148px] overflow-hidden rounded-md border border-[var(--border)] bg-[var(--panel)] py-1 shadow-lg"
                    initial={{ opacity: 0, y: -4 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, y: -4 }}
                    transition={{ duration: 0.1 }}
                  >
                    <button
                      className="flex w-full items-center gap-2 px-3 py-1.5 text-xs text-[var(--foreground)] hover:bg-[color-mix(in_srgb,var(--foreground)_6%,transparent)]"
                      onClick={() => {
                        setNewMenuOpen(false)
                        void handleCreateRecord('{}')
                      }}
                    >
                      <Plus className="size-3.5 text-[var(--muted)]" />
                      New JSON
                    </button>
                    <button
                      className="flex w-full items-center gap-2 px-3 py-1.5 text-xs text-[var(--foreground)] hover:bg-[color-mix(in_srgb,var(--foreground)_6%,transparent)]"
                      onClick={() => {
                        setNewMenuOpen(false)
                        void handleOpenJson()
                      }}
                    >
                      <FolderOpen className="size-3.5 text-[var(--muted)]" />
                      Open File
                    </button>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          </div>

          {/* ── Row 1, Col 2: Main header / title toolbar ── */}
          <header className="peel-window-drag flex h-9 shrink-0 items-center border-b border-[var(--border)] bg-[var(--panel)] px-4">
            <div
              className="peel-doc-title-shell cursor-text"
              style={{ width: `${titleWidthCh}ch`, maxWidth: '280px' }}
              role={isEditingTitle ? undefined : 'button'}
              tabIndex={isEditingTitle ? -1 : 0}
              title={isEditingTitle ? undefined : 'Click to rename'}
              onClick={
                isEditingTitle
                  ? undefined
                  : () => {
                      if (!selectedRecord) return
                      setTitleDraft(selectedRecord.title)
                      setIsEditingTitle(true)
                    }
              }
              onKeyDown={
                isEditingTitle
                  ? undefined
                  : (e) => {
                      if (e.key === 'Enter' || e.key === ' ') {
                        e.preventDefault()
                        if (!selectedRecord) return
                        setTitleDraft(selectedRecord.title)
                        setIsEditingTitle(true)
                      }
                    }
              }
            >
              {isEditingTitle ? (
                <input
                  autoFocus
                  type="text"
                  value={titleDraft}
                  onChange={(e) => setTitleDraft(e.target.value)}
                  onBlur={() => void handleTitleCommit()}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') void handleTitleCommit()
                    if (e.key === 'Escape') setIsEditingTitle(false)
                  }}
                  className="peel-doc-title-text peel-doc-title-field min-w-0 flex-1 text-left"
                  onClick={(e) => e.stopPropagation()}
                />
              ) : (
                <span className="peel-doc-title-text block min-w-0 truncate text-left">
                  {selectedRecord?.title ?? 'Untitled'}
                </span>
              )}
            </div>
          </header>

          {/* ── Row 2, Col 1: Sidebar content ── */}
          <aside
            className="flex min-h-0 flex-col overflow-hidden border-r border-[var(--border)] bg-[var(--panel)]"
            style={{ display: sidebarCollapsed ? 'none' : undefined }}
          >
            {!sidebarCollapsed && (
              <>
                <div className="px-3 pb-2 pt-2">
                  <div className="relative">
                    <Search className="pointer-events-none absolute left-2.5 top-1/2 size-3.5 -translate-y-1/2 text-[var(--muted-foreground)]" />
                    <Input
                      className="pl-8"
                      placeholder="Search"
                      value={searchText}
                      onChange={(event) => setSearchText(event.target.value)}
                    />
                  </div>
                </div>

                <ScrollArea className="min-h-0 flex-1 px-2 pb-2">
                  <div className="space-y-1">
                    {pinnedRecords.length ? (
                      <HistorySection
                        title="Pinned"
                        records={pinnedRecords}
                        selectedId={selectedId}
                        onSelect={handleSelectRecord}
                        onRename={(record) => {
                          setRenameTarget(record)
                          setRenameValue(record.title)
                        }}
                        onDelete={handleDeleteRecord}
                        onTogglePin={handleTogglePin}
                      />
                    ) : null}

                    <HistorySection
                      title={pinnedRecords.length ? 'Recent' : 'History'}
                      records={regularRecords}
                      selectedId={selectedId}
                      onSelect={handleSelectRecord}
                      onRename={(record) => {
                        setRenameTarget(record)
                        setRenameValue(record.title)
                      }}
                      onDelete={handleDeleteRecord}
                      onTogglePin={handleTogglePin}
                    />

                    {!filteredRecords.length ? (
                      <div className="rounded-md border border-dashed border-[var(--border-strong)] px-4 py-6 text-center">
                        <p className="text-sm text-[var(--muted)]">
                          {searchText.length ? 'No matches found.' : 'No records yet.'}
                        </p>
                      </div>
                    ) : null}
                  </div>
                </ScrollArea>

                <div className="flex h-9 items-center border-t border-[var(--border)] bg-[var(--panel)] px-2.5">
                  <button
                    className="flex h-7 w-full items-center gap-2 rounded-md px-2 text-sm text-[var(--muted)] transition hover:bg-[color-mix(in_srgb,var(--foreground)_4%,transparent)] hover:text-[var(--foreground)]"
                    onClick={() => setSettingsOpen(true)}
                  >
                    <Settings className="size-3.5" />
                    Settings
                  </button>
                </div>
              </>
            )}
          </aside>

          {/* ── Row 2, Col 2: Main Editor Area — 宽度由父级 grid-template-columns 过渡；不要用 Framer layout(transform)，否则 Monaco 选区/光标会错位 */}
          <main
            className="grid min-h-0 grid-rows-[minmax(0,1fr)_minmax(160px,220px)_36px] gap-px bg-[color-mix(in_srgb,var(--foreground)_6%,transparent)]"
            style={{ gridColumn: sidebarCollapsed ? '1 / -1' : undefined }}
          >
            {/* Top row: JSON (left) + drag handle + Result (right) */}
            <div
              ref={splitContainerRef}
              className="grid min-h-0"
              style={{
                gridTemplateColumns: resultCollapsed
                  ? '1fr'
                  : `minmax(0, ${splitRatio}fr) 5px minmax(200px, ${1 - splitRatio}fr)`
              }}
            >
              {/* JSON Panel */}
              <PanelFrame
                title="JSON"
                status={summary.issue ? `Line ${summary.issue.line}: ${summary.issue.message}` : ''}
                statusTone={summary.issue ? 'danger' : summary.isValid ? 'success' : 'muted'}
                actions={
                  <div className="flex items-center gap-1">
                    <Button
                      variant="ghost"
                      size="sm"
                      title="Format (Shift+Alt+F)"
                      onClick={() => handleFormat('pretty')}
                    >
                      <Braces className="size-3.5" />
                      Format
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      title="Compact (Shift+Alt+M)"
                      onClick={() => handleFormat('compact')}
                    >
                      <Minimize2 className="size-3.5" />
                      Compact
                    </Button>
                    <Button variant="ghost" size="sm" onClick={() => void handleCopyCurrent()}>
                      <Copy className="size-3.5" />
                      Copy
                    </Button>
                  </div>
                }
              >
                <MonacoEditorSurface
                  path={selectedId ? `peel://record-${selectedId}.json` : 'peel://new.json'}
                  theme={monacoTheme}
                  language="json"
                  fontSize={settings.editorFontSize}
                  value={editorText}
                  onChange={setEditorText}
                  validationIssue={summary.issue}
                  revealIssueToken={errorRevealToken}
                  onFocus={(handle) => {
                    activeEditorHandleRef.current = handle
                  }}
                  handleRef={rawEditorHandleRef}
                  transformPaste={formatPastedJson}
                />
              </PanelFrame>

              {/* Drag handle — only between panels when result is open */}
              {!resultCollapsed && (
                <div
                  className="cursor-col-resize bg-[color-mix(in_srgb,var(--foreground)_6%,transparent)] transition-colors duration-150 select-none hover:bg-[color-mix(in_srgb,var(--foreground)_10%,transparent)]"
                  onMouseDown={handleDragStart}
                />
              )}

              {/* Result Panel：不用 framer 包一层，避免 opacity 动画带来的合成层与 Monaco 错位 */}
              {resultVisible ? (
                <section className="grid min-h-0 grid-rows-[36px_minmax(0,1fr)] bg-[var(--panel)]">
                    <header className="flex items-center justify-between border-b border-[var(--border)] pl-6 pr-4">
                      <div className="flex min-w-0 flex-1 items-center gap-2 overflow-hidden text-xs">
                        <span className="shrink-0 font-medium">Result</span>
                        <span
                          className="peel-status-dot shrink-0"
                          data-tone={toneForResult(visibleExtractionResult.status)}
                        />
                        <span
                          className="truncate"
                          style={{
                            color:
                              toneForResult(visibleExtractionResult.status) === 'success'
                                ? 'var(--success)'
                                : toneForResult(visibleExtractionResult.status) === 'danger'
                                  ? 'var(--danger)'
                                  : 'var(--muted)'
                          }}
                        >
                          {statusLabel(visibleExtractionResult.status)}
                        </span>
                      </div>
                      <div className="flex shrink-0 items-center gap-1">
                        <Button
                          variant="ghost"
                          size="sm"
                          disabled={visibleExtractionResult.displayStyle !== 'structuredJson'}
                          onClick={() => handleFormatResult('pretty')}
                        >
                          <Braces className="size-3.5" />
                          Format
                        </Button>
                        <Button
                          variant="ghost"
                          size="sm"
                          disabled={visibleExtractionResult.displayStyle !== 'structuredJson'}
                          onClick={() => handleFormatResult('compact')}
                        >
                          <Minimize2 className="size-3.5" />
                          Compact
                        </Button>
                        <Button
                          variant="ghost"
                          size="sm"
                          disabled={visibleExtractionResult.status !== 'success'}
                          onClick={() => void handleCopyExtraction()}
                        >
                          <Copy className="size-3.5" />
                          Copy
                        </Button>
                        <Button variant="ghost" size="sm" className="px-2" onClick={closeResult}>
                          <X className="size-4" />
                        </Button>
                      </div>
                    </header>
                    <div className="min-h-0 h-full overflow-hidden">
                      {visibleExtractionResult.displayStyle === 'structuredJson' ? (
                        <MonacoEditorSurface
                          path="peel://result.json"
                          theme={monacoTheme}
                          language="json"
                          fontSize={settings.editorFontSize}
                          value={visibleExtractionResult.text}
                          readOnly
                          onFocus={(handle) => {
                            activeEditorHandleRef.current = handle
                          }}
                          handleRef={resultEditorHandleRef}
                        />
                      ) : (
                        <ScrollArea className="size-full px-4 py-3">
                          <pre className="whitespace-pre-wrap font-mono text-[0.8125rem] leading-6 text-[var(--foreground)]">
                            {visibleExtractionResult.text}
                          </pre>
                        </ScrollArea>
                      )}
                    </div>
                </section>
              ) : null}
            </div>

            {/* Bottom row: Expression Panel — always visible */}
            <section className="grid min-h-0 grid-rows-[36px_minmax(0,1fr)] bg-[var(--panel)]">
              <header className="flex items-center justify-between border-b border-[var(--border)] pl-6 pr-3">
                <div className="flex items-center gap-2">
                  <Select
                    value={extractionMode}
                    onValueChange={(value: ExtractionMode) => setExtractionMode(value)}
                  >
                    <SelectTrigger className="h-7 w-[120px] text-xs">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="javascript">JavaScript</SelectItem>
                      <SelectItem value="jsonpath">JSONPath</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <div className="flex shrink-0 items-center gap-1">
                  <Button
                    variant="ghost"
                    size="sm"
                    className="px-2"
                    onClick={() => (resultCollapsed ? openResult() : closeResult())}
                    title={resultCollapsed ? 'Show Result' : 'Hide Result'}
                  >
                    {resultCollapsed ? (
                      <PanelRightOpen className="size-4" />
                    ) : (
                      <PanelRightClose className="size-4" />
                    )}
                  </Button>
                </div>
              </header>
              <div className="min-h-0 h-full overflow-hidden">
                <MonacoEditorSurface
                  path="peel://expression.ts"
                  theme={monacoTheme}
                  language={extractionMode === 'javascript' ? 'javascript' : 'plaintext'}
                  fontSize={settings.editorFontSize}
                  value={extractionQuery}
                  onChange={setExtractionQuery}
                  placeholderOffsetPx={extractionMode === 'jsonpath' ? 8 : 0}
                  placeholder={
                    extractionMode === 'javascript'
                      ? 'data.items.map((item) => item.id)'
                      : '$.items[*].id'
                  }
                  onRun={() => {
                    void runExtraction(true)
                  }}
                  onFocus={(handle) => {
                    activeEditorHandleRef.current = handle
                  }}
                  handleRef={expressionEditorHandleRef}
                />
              </div>
            </section>

            {/* Status Bar — below expression panel */}
            <footer className="flex items-center justify-between border-t border-[var(--border)] bg-[var(--panel)] px-4 text-xs text-[var(--muted)]">
              <div className="flex items-center gap-4">
                <StatusItem
                  label="Validation"
                  value={summary.issue ? 'Invalid' : summary.isValid ? 'Valid' : 'Empty'}
                  tone={summary.issue ? 'danger' : summary.isValid ? 'success' : 'muted'}
                />
                <StatusItem label="Type" value={summary.rootType} />
                <StatusItem label="Keys" value={String(summary.keyCount)} />
                <StatusItem label="Bytes" value={String(summary.byteSize)} />
              </div>
              <div className="flex items-center gap-3">
                <span>{settings.theme === 'system' ? 'System' : capitalize(settings.theme)}</span>
                <span>{settings.editorFontSize}px</span>
              </div>
            </footer>
          </main>
        </div>

        {/* Settings Dialog */}
        <Dialog
          open={settingsOpen}
          onOpenChange={(open) => {
            setSettingsOpen(open)
            if (open) {
              setSettingsSection('appearance')
              setQuickPasteShortcutDraft(toDisplayShortcut(settings.quickPasteShortcut))
            }
          }}
        >
          <DialogContent className="w-[min(96vw,780px)]">
            <DialogHeader>
              <DialogTitle>Settings</DialogTitle>
              <DialogDescription>
                Tune app look, keyboard shortcuts, and app info.
              </DialogDescription>
            </DialogHeader>

            <div className="mt-4 grid min-h-[340px] grid-cols-[168px_minmax(0,1fr)] gap-4">
              <nav className="flex flex-col gap-1 rounded-md border border-[var(--border)] bg-[var(--panel)] p-1">
                <SettingsNavItem
                  label="Appearance"
                  icon={<Palette />}
                  active={settingsSection === 'appearance'}
                  onClick={() => setSettingsSection('appearance')}
                />
                <SettingsNavItem
                  label="Shortcuts"
                  icon={<Keyboard />}
                  active={settingsSection === 'shortcuts'}
                  onClick={() => setSettingsSection('shortcuts')}
                />
                <SettingsNavItem
                  label="About"
                  icon={<Info />}
                  active={settingsSection === 'about'}
                  onClick={() => setSettingsSection('about')}
                />
              </nav>

              <section className="flex min-w-0 flex-col gap-3 rounded-md border border-[var(--border)] bg-[var(--panel)] p-4">
                {settingsSection === 'appearance' ? (
                  <>
                    <PreferenceRow label="Theme">
                      <Select
                        value={settings.theme}
                        onValueChange={(value: AppSnapshot['settings']['theme']) => {
                          void persistSettings({
                            ...settings,
                            theme: value
                          })
                        }}
                      >
                        <SelectTrigger className="w-[140px]">
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="system">System</SelectItem>
                          <SelectItem value="light">Light</SelectItem>
                          <SelectItem value="dark">Dark</SelectItem>
                        </SelectContent>
                      </Select>
                    </PreferenceRow>

                    <PreferenceRow label="Font Size">
                      <Select
                        value={String(settings.editorFontSize)}
                        onValueChange={(value) => {
                          void persistSettings({
                            ...settings,
                            editorFontSize: Number(value)
                          })
                        }}
                      >
                        <SelectTrigger className="w-[140px]">
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          {[12, 13, 14, 15, 16, 18].map((size) => (
                            <SelectItem key={size} value={String(size)}>
                              {size}px
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </PreferenceRow>
                  </>
                ) : null}

                {settingsSection === 'shortcuts' ? (
                  <>
                    <div className="flex flex-col gap-2">
                      <p className="text-sm font-medium text-[var(--foreground)]">
                        Global Shortcut
                      </p>
                      <p className="text-sm text-[var(--muted)]">
                        Press this shortcut anywhere to open Peel, create a new JSON, and paste
                        clipboard content.
                      </p>
                    </div>
                    <Separator />
                    <PreferenceRow label="Shortcut">
                      <Input
                        value={quickPasteShortcutDraft}
                        placeholder={isCapturingShortcut ? 'Press keys...' : 'Not set'}
                        readOnly
                        onFocus={() => setIsCapturingShortcut(true)}
                        onBlur={() => setIsCapturingShortcut(false)}
                        onKeyDown={(event) => {
                          event.preventDefault()
                          event.stopPropagation()

                          if (event.key === 'Escape') {
                            setIsCapturingShortcut(false)
                            ;(event.currentTarget as HTMLInputElement).blur()
                            return
                          }

                          if (
                            (event.key === 'Backspace' || event.key === 'Delete') &&
                            !event.metaKey &&
                            !event.ctrlKey &&
                            !event.altKey &&
                            !event.shiftKey
                          ) {
                            setQuickPasteShortcutDraft('')
                            return
                          }

                          const nextShortcut = buildShortcutFromEvent(event)

                          if (!nextShortcut) {
                            return
                          }

                          setQuickPasteShortcutDraft(nextShortcut)
                          setIsCapturingShortcut(false)
                          ;(event.currentTarget as HTMLInputElement).blur()
                        }}
                        className="w-[220px]"
                      />
                    </PreferenceRow>
                    <p className="text-xs text-[var(--muted)]">
                      Click input then press keys. Use Backspace to clear, Esc to cancel capture.
                    </p>
                    <div className="flex items-center justify-end gap-2">
                      <Button
                        variant="outline"
                        onClick={async () => {
                          setQuickPasteShortcutDraft('')
                          try {
                            await persistSettings({
                              ...settings,
                              quickPasteShortcut: ''
                            })
                            toast.success('Global shortcut cleared.')
                          } catch (error) {
                            toast.error(
                              error instanceof Error ? error.message : 'Failed to clear shortcut.'
                            )
                          }
                        }}
                      >
                        Clear
                      </Button>
                      <Button
                        variant="accent"
                        onClick={async () => {
                          const accelerator = toAcceleratorShortcut(quickPasteShortcutDraft.trim())
                          try {
                            await persistSettings({
                              ...settings,
                              quickPasteShortcut: accelerator
                            })
                            toast.success(
                              quickPasteShortcutDraft.trim().length
                                ? 'Global shortcut saved.'
                                : 'Global shortcut cleared.'
                            )
                          } catch (error) {
                            toast.error(
                              error instanceof Error
                                ? error.message
                                : 'Failed to save global shortcut.'
                            )
                          }
                        }}
                      >
                        Save
                      </Button>
                    </div>
                  </>
                ) : null}

                {settingsSection === 'about' ? (
                  <div className="flex flex-col gap-2 text-sm">
                    <p className="font-medium text-[var(--foreground)]">Peel Desktop</p>
                    <p className="text-[var(--muted)]">
                      A fast JSON formatter and extractor built for macOS.
                    </p>
                    <Separator />
                    <PreferenceRow label="Renderer">
                      <span className="text-[var(--muted)]">Electron + React + Monaco</span>
                    </PreferenceRow>
                    <PreferenceRow label="Current Theme">
                      <span className="text-[var(--muted)]">
                        {settings.theme === 'system' ? 'System' : capitalize(settings.theme)}
                      </span>
                    </PreferenceRow>
                  </div>
                ) : null}
              </section>
            </div>

            <DialogFooter>
              <Button variant="outline" onClick={() => setSettingsOpen(false)}>
                Done
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>

        {/* Rename Dialog */}
        <Dialog open={!!renameTarget} onOpenChange={(open) => !open && setRenameTarget(null)}>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Rename</DialogTitle>
              <DialogDescription>Give this record a new name.</DialogDescription>
            </DialogHeader>
            <div className="mt-4">
              <Input value={renameValue} onChange={(event) => setRenameValue(event.target.value)} />
            </div>
            <DialogFooter>
              <Button variant="outline" onClick={() => setRenameTarget(null)}>
                Cancel
              </Button>
              <Button variant="accent" onClick={() => void handleRenameSubmit()}>
                Save
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>
      <Toaster theme={resolvedTheme} position="top-right" closeButton richColors />
    </TooltipProvider>
  )
}

function LoadingSplash(): React.JSX.Element {
  return (
    <div className="flex h-full items-center justify-center bg-[var(--background)]">
      <div className="text-center">
        <h1 className="text-xl font-semibold tracking-tight">Peel</h1>
        <p className="mt-2 text-sm text-[var(--muted)]">Loading…</p>
      </div>
    </div>
  )
}

function HistorySection({
  title,
  records,
  selectedId,
  onSelect,
  onRename,
  onDelete,
  onTogglePin
}: {
  title: string
  records: HistoryRecord[]
  selectedId: string | null
  onSelect: (record: HistoryRecord) => Promise<void>
  onRename: (record: HistoryRecord) => void
  onDelete: (record: HistoryRecord) => Promise<void>
  onTogglePin: (record: HistoryRecord) => Promise<void>
}): React.JSX.Element {
  return (
    <section>
      <div className="mb-1 px-2 pt-2">
        <span className="text-[11px] font-medium uppercase tracking-wider text-[var(--muted-foreground)]">
          {title}
        </span>
      </div>
      <div className="space-y-px">
        {records.map((record) => (
          <div key={record.id} className="peel-sidebar-row">
            <ContextMenu>
              <ContextMenuTrigger asChild>
                <button
                  className={cn(
                    'group w-full rounded-md px-2.5 py-2 text-left transition-colors',
                    record.id === selectedId
                      ? 'bg-[color-mix(in_srgb,var(--accent)_12%,transparent)] text-[var(--foreground)]'
                      : 'text-[var(--foreground)] hover:bg-[color-mix(in_srgb,var(--foreground)_4%,transparent)]'
                  )}
                  onClick={() => void onSelect(record)}
                >
                  <div className="flex items-start justify-between gap-1">
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center gap-1.5">
                        <span className="truncate text-[13px] font-medium">{record.title}</span>
                        {record.pinned ? (
                          <Pin className="size-3 shrink-0 text-[var(--accent)]" />
                        ) : null}
                      </div>
                      <p className="mt-0.5 truncate text-[11px] text-[var(--muted)]">
                        {record.content.trim().length
                          ? record.content.replace(/\s+/g, ' ').slice(0, 60)
                          : 'Empty'}
                      </p>
                    </div>
                    <DropdownMenu>
                      <DropdownMenuTrigger asChild>
                        <button
                          className="rounded-md p-1 text-[var(--muted)] opacity-0 transition hover:text-[var(--foreground)] group-hover:opacity-100"
                          onClick={(event) => event.stopPropagation()}
                        >
                          <MoreHorizontal className="size-3.5" />
                        </button>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent align="end">
                        <DropdownMenuItem
                          onClick={(event) => {
                            event.stopPropagation()
                            onRename(record)
                          }}
                        >
                          <Pencil className="size-4" />
                          Rename
                        </DropdownMenuItem>
                        <DropdownMenuItem
                          onClick={(event) => {
                            event.stopPropagation()
                            void onTogglePin(record)
                          }}
                        >
                          {record.pinned ? (
                            <PinOff className="size-4" />
                          ) : (
                            <Pin className="size-4" />
                          )}
                          {record.pinned ? 'Unpin' : 'Pin'}
                        </DropdownMenuItem>
                        <DropdownMenuSeparator />
                        <DropdownMenuItem
                          onClick={(event) => {
                            event.stopPropagation()
                            void onDelete(record)
                          }}
                        >
                          <Trash2 className="size-4" />
                          Delete
                        </DropdownMenuItem>
                      </DropdownMenuContent>
                    </DropdownMenu>
                  </div>
                  <div className="mt-1 text-[10px] text-[var(--muted-foreground)]">
                    {formatRelativeTime(record.updatedAt)}
                  </div>
                </button>
              </ContextMenuTrigger>
              <ContextMenuContent>
                <ContextMenuItem onSelect={() => onRename(record)}>
                  <Pencil className="size-4" />
                  Rename
                </ContextMenuItem>
                <ContextMenuItem onSelect={() => void onTogglePin(record)}>
                  {record.pinned ? <PinOff className="size-4" /> : <Pin className="size-4" />}
                  {record.pinned ? 'Unpin' : 'Pin'}
                </ContextMenuItem>
                <ContextMenuSeparator />
                <ContextMenuItem
                  onSelect={() => void onDelete(record)}
                  className="text-[var(--danger)] focus:bg-[var(--danger)] focus:text-white"
                >
                  <Trash2 className="size-4" />
                  Delete
                </ContextMenuItem>
              </ContextMenuContent>
            </ContextMenu>
          </div>
        ))}
      </div>
    </section>
  )
}

function PanelFrame({
  title,
  status,
  statusTone,
  actions,
  children
}: {
  title: string
  status: string
  statusTone: 'success' | 'danger' | 'muted'
  actions?: React.ReactNode
  children: React.ReactNode
}): React.JSX.Element {
  return (
    <section className="grid min-h-0 grid-rows-[36px_minmax(0,1fr)] bg-[var(--panel)]">
      <header className="flex items-center justify-between border-b border-[var(--border)] pl-6 pr-4">
        <div className="flex min-w-0 flex-1 items-center gap-2 overflow-hidden text-xs">
          <span className="shrink-0 font-medium">{title}</span>
          <span className="peel-status-dot shrink-0" data-tone={statusTone} />
          <span
            className="truncate"
            style={{
              color:
                statusTone === 'success'
                  ? 'var(--success)'
                  : statusTone === 'danger'
                    ? 'var(--danger)'
                    : 'var(--muted)'
            }}
          >
            {status}
          </span>
        </div>
        <div className="shrink-0">{actions}</div>
      </header>
      <div className="min-h-0 h-full overflow-hidden">{children}</div>
    </section>
  )
}

function StatusItem({
  label,
  value,
  tone
}: {
  label: string
  value: string
  tone?: 'success' | 'danger' | 'muted'
}): React.JSX.Element {
  return (
    <div className="flex items-center gap-1.5">
      {tone ? <span className="peel-status-dot peel-status-dot--static" data-tone={tone} /> : null}
      <span className="text-[var(--muted-foreground)]">{label}:</span>
      <span>{value}</span>
    </div>
  )
}

function PreferenceRow({
  label,
  children
}: {
  label: string
  children: React.ReactNode
}): React.JSX.Element {
  return (
    <div className="flex items-center justify-between gap-4">
      <span className="text-sm font-medium">{label}</span>
      <div>{children}</div>
    </div>
  )
}

function SettingsNavItem({
  label,
  icon,
  active,
  onClick
}: {
  label: string
  icon: React.ReactNode
  active: boolean
  onClick: () => void
}): React.JSX.Element {
  return (
    <button
      className={cn(
        'flex h-8 items-center gap-2 rounded-md px-2 text-sm transition-colors',
        active
          ? 'bg-[color-mix(in_srgb,var(--accent)_12%,transparent)] text-[var(--foreground)]'
          : 'text-[var(--muted)] hover:bg-[color-mix(in_srgb,var(--foreground)_4%,transparent)] hover:text-[var(--foreground)]'
      )}
      onClick={onClick}
    >
      {icon}
      <span>{label}</span>
    </button>
  )
}

function statusLabel(status: ExtractionResult['status']): string {
  switch (status) {
    case 'success':
      return ''
    case 'empty':
      return 'No result'
    case 'error':
      return 'Error'
    case 'idle':
      return 'Idle'
  }
}

function toneForResult(status: ExtractionResult['status']): 'success' | 'danger' | 'muted' {
  switch (status) {
    case 'success':
      return 'success'
    case 'error':
      return 'danger'
    default:
      return 'muted'
  }
}

function capitalize(value: string): string {
  return value.charAt(0).toUpperCase() + value.slice(1)
}

function buildShortcutFromEvent(event: React.KeyboardEvent<HTMLInputElement>): string | null {
  const modifiers: string[] = []
  const isMac = navigator.platform.toLowerCase().includes('mac')

  if (event.metaKey) modifiers.push('Command')
  if (event.ctrlKey) modifiers.push('Control')
  if (event.altKey) modifiers.push(isMac ? 'Option' : 'Alt')
  if (event.shiftKey) modifiers.push('Shift')

  const key = normalizeShortcutKey(event)
  if (!key) {
    return null
  }

  if (!modifiers.length) {
    return null
  }

  return [...modifiers, key].join('+')
}

function normalizeShortcutKey(event: React.KeyboardEvent<HTMLInputElement>): string | null {
  const { key, code } = event

  if (code === 'Space') {
    return 'Space'
  }

  if (key === 'Meta' || key === 'Control' || key === 'Alt' || key === 'Shift') {
    return null
  }

  if (key.length === 1 && /^[a-z0-9]$/i.test(key)) {
    return key.toUpperCase()
  }

  if (/^F\d{1,2}$/i.test(key)) {
    return key.toUpperCase()
  }

  const keyMap: Record<string, string> = {
    ArrowUp: 'Up',
    ArrowDown: 'Down',
    ArrowLeft: 'Left',
    ArrowRight: 'Right',
    ' ': 'Space',
    Spacebar: 'Space',
    Enter: 'Enter',
    Tab: 'Tab',
    Backspace: 'Backspace',
    Delete: 'Delete',
    Home: 'Home',
    End: 'End',
    PageUp: 'PageUp',
    PageDown: 'PageDown',
    Insert: 'Insert'
  }

  return keyMap[key] ?? null
}

function toAcceleratorShortcut(shortcut: string): string {
  return shortcut.replaceAll('Option', 'Alt')
}

function toDisplayShortcut(shortcut: string): string {
  const isMac = navigator.platform.toLowerCase().includes('mac')
  if (!isMac) {
    return shortcut
  }

  return shortcut.replaceAll('Alt', 'Option')
}
