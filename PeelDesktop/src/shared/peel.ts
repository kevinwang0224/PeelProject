export type ThemePreference = 'system' | 'light' | 'dark'
export type ExtractionMode = 'javascript' | 'jsonpath'
export type ExtractionStatus = 'idle' | 'success' | 'empty' | 'error'
export type ResultDisplayStyle = 'plainText' | 'structuredJson'
export type MenuAction =
  | 'new-json'
  | 'open-json'
  | 'export-json'
  | 'format-json'
  | 'compact-json'
  | 'copy'
  | 'paste'
  | 'find'
  | 'select-all'

export interface JsonValidationIssue {
  message: string
  line: number
  column: number
  offset: number
  length: number
}

export interface HistoryRecord {
  id: string
  title: string
  content: string
  createdAt: string
  updatedAt: string
  pinned: boolean
}

export interface AppSettings {
  theme: ThemePreference
  editorFontSize: number
}

export interface AppSnapshot {
  schemaVersion: number
  settings: AppSettings
  history: HistoryRecord[]
}

export interface HistoryRecordSeed {
  title?: string
  content?: string
}

export interface CreateHistoryResult {
  snapshot: AppSnapshot
  record: HistoryRecord
}

export interface OpenJsonResult {
  path: string
  title: string
  content: string
}

export interface ExportJsonPayload {
  suggestedName: string
  content: string
}

export interface ExtractionResult {
  status: ExtractionStatus
  title: string
  text: string
  displayStyle: ResultDisplayStyle
}

export interface ExtractionRequest {
  mode: ExtractionMode
  query: string
  data: unknown
}

export interface PeelAPI {
  bootstrap: () => Promise<AppSnapshot>
  history: {
    create: (seed?: HistoryRecordSeed) => Promise<CreateHistoryResult>
    save: (record: HistoryRecord) => Promise<AppSnapshot>
    remove: (id: string) => Promise<AppSnapshot>
    rename: (id: string, title: string) => Promise<AppSnapshot>
    togglePin: (id: string) => Promise<AppSnapshot>
  }
  settings: {
    save: (settings: AppSettings) => Promise<AppSnapshot>
  }
  files: {
    openJson: () => Promise<OpenJsonResult | null>
    exportJson: (payload: ExportJsonPayload) => Promise<boolean>
  }
  clipboard: {
    readText: () => Promise<string>
    writeText: (text: string) => Promise<void>
  }
  menu: {
    onAction: (listener: (action: MenuAction) => void) => () => void
  }
}

export const STORAGE_SCHEMA_VERSION = 1

export const DEFAULT_SETTINGS: AppSettings = {
  theme: 'system',
  editorFontSize: 14
}

export const DEFAULT_SNAPSHOT: AppSnapshot = {
  schemaVersion: STORAGE_SCHEMA_VERSION,
  settings: DEFAULT_SETTINGS,
  history: []
}
