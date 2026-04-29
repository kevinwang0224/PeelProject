import type { AppSettings, AppSnapshot, HistoryRecord, HistoryRecordSeed } from '@peel/shared/types'

export { DEFAULT_SETTINGS, DEFAULT_SNAPSHOT, STORAGE_SCHEMA_VERSION } from '@peel/shared/types'
export type {
  AppSettings,
  AppSnapshot,
  ExtractionMode,
  ExtractionRequest,
  ExtractionResult,
  ExtractionStatus,
  HistoryRecord,
  HistoryRecordSeed,
  JsonValidationIssue,
  ResultDisplayStyle,
  ThemePreference
} from '@peel/shared/types'

export type MenuAction =
  | 'new-json'
  | 'new-json-from-clipboard'
  | 'open-json'
  | 'export-json'
  | 'format-json'
  | 'compact-json'
  | 'find'

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

export interface PeelAPI {
  rendererReady: () => void
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
