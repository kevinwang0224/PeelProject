import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { dirname } from 'node:path'

import {
  createHistoryRecord,
  normalizeTitle,
  sortHistoryRecords,
  upsertHistoryRecord
} from '@peel/shared/history'
import {
  DEFAULT_SETTINGS,
  DEFAULT_SNAPSHOT,
  STORAGE_SCHEMA_VERSION,
  type AppSettings,
  type AppSnapshot,
  type CreateHistoryResult,
  type HistoryRecord,
  type HistoryRecordSeed
} from '@desktop/shared/peel'

export class PeelStorage {
  private readonly filePath: string

  private readonly legacyFilePaths: string[]

  private readonly migrationMarkerPath: string

  private snapshot: AppSnapshot | null = null

  private writeQueue = Promise.resolve()

  constructor(filePath: string, legacyFilePaths: string[] = []) {
    this.filePath = filePath
    this.legacyFilePaths = legacyFilePaths.filter((legacyPath) => legacyPath !== filePath)
    this.migrationMarkerPath = `${filePath}.legacy-migration-complete`
  }

  async bootstrap(): Promise<AppSnapshot> {
    return structuredClone(await this.load())
  }

  async createRecord(seed: HistoryRecordSeed = {}): Promise<CreateHistoryResult> {
    const current = await this.load()
    const record = createHistoryRecord(seed)
    const snapshot = await this.persist({
      ...current,
      history: sortHistoryRecords([record, ...current.history])
    })

    return {
      snapshot,
      record
    }
  }

  async saveRecord(record: HistoryRecord): Promise<AppSnapshot> {
    const current = await this.load()
    const snapshot = await this.persist({
      ...current,
      history: upsertHistoryRecord(current.history, {
        ...record,
        title: normalizeTitle(record.title, new Date(record.createdAt)),
        updatedAt: new Date().toISOString()
      })
    })

    return snapshot
  }

  async removeRecord(id: string): Promise<AppSnapshot> {
    const current = await this.load()

    return this.persist({
      ...current,
      history: current.history.filter((record) => record.id !== id)
    })
  }

  async renameRecord(id: string, title: string): Promise<AppSnapshot> {
    const current = await this.load()

    return this.persist({
      ...current,
      history: current.history.map((record) =>
        record.id === id
          ? {
              ...record,
              title: normalizeTitle(title, new Date(record.createdAt))
            }
          : record
      )
    })
  }

  async togglePin(id: string): Promise<AppSnapshot> {
    const current = await this.load()
    const history = current.history.map((record) =>
      record.id === id
        ? {
            ...record,
            pinned: !record.pinned
          }
        : record
    )

    return this.persist({
      ...current,
      history: sortHistoryRecords(history)
    })
  }

  async saveSettings(settings: AppSettings): Promise<AppSnapshot> {
    const current = await this.load()

    return this.persist({
      ...current,
      settings: {
        ...DEFAULT_SETTINGS,
        ...settings
      }
    })
  }

  private async load(): Promise<AppSnapshot> {
    if (this.snapshot) {
      return this.snapshot
    }

    await mkdir(dirname(this.filePath), { recursive: true })

    const currentSnapshot = await readSnapshot(this.filePath)
    const shouldMigrateLegacy = !(await fileExists(this.migrationMarkerPath))
    const legacySnapshots = shouldMigrateLegacy
      ? (
          await Promise.all(this.legacyFilePaths.map((legacyPath) => readSnapshot(legacyPath)))
        ).filter((snapshot): snapshot is AppSnapshot => Boolean(snapshot))
      : []

    const snapshots = [...legacySnapshots, currentSnapshot].filter(
      (snapshot): snapshot is AppSnapshot => Boolean(snapshot)
    )

    this.snapshot = snapshots.length ? mergeSnapshots(snapshots) : DEFAULT_SNAPSHOT

    if (legacySnapshots.length) {
      await this.writeSnapshot(this.snapshot)
      await writeFile(this.migrationMarkerPath, new Date().toISOString(), 'utf8')
    }

    return this.snapshot
  }

  private async persist(snapshot: AppSnapshot): Promise<AppSnapshot> {
    const normalizedSnapshot = coerceSnapshot(snapshot)

    this.snapshot = normalizedSnapshot
    await this.writeSnapshot(normalizedSnapshot)

    return structuredClone(normalizedSnapshot)
  }

  private async writeSnapshot(snapshot: AppSnapshot): Promise<void> {
    const payload = JSON.stringify(snapshot, null, 2)
    this.writeQueue = this.writeQueue.then(() => writeFile(this.filePath, payload, 'utf8'))
    await this.writeQueue
  }
}

async function fileExists(filePath: string): Promise<boolean> {
  try {
    await readFile(filePath, 'utf8')
    return true
  } catch {
    return false
  }
}

async function readSnapshot(filePath: string): Promise<AppSnapshot | null> {
  try {
    const raw = await readFile(filePath, 'utf8')
    return coerceSnapshot(JSON.parse(raw))
  } catch {
    return null
  }
}

function mergeSnapshots(snapshots: AppSnapshot[]): AppSnapshot {
  const historyById = new Map<string, HistoryRecord>()
  const settings = { ...DEFAULT_SETTINGS }

  for (const snapshot of snapshots) {
    for (const record of snapshot.history) {
      historyById.set(record.id, record)
    }

    settings.theme =
      snapshot.settings.theme !== DEFAULT_SETTINGS.theme ||
      settings.theme === DEFAULT_SETTINGS.theme
        ? snapshot.settings.theme
        : settings.theme
    settings.editorFontSize =
      snapshot.settings.editorFontSize !== DEFAULT_SETTINGS.editorFontSize ||
      settings.editorFontSize === DEFAULT_SETTINGS.editorFontSize
        ? snapshot.settings.editorFontSize
        : settings.editorFontSize
    settings.quickPasteShortcut =
      snapshot.settings.quickPasteShortcut !== DEFAULT_SETTINGS.quickPasteShortcut ||
      settings.quickPasteShortcut === DEFAULT_SETTINGS.quickPasteShortcut
        ? snapshot.settings.quickPasteShortcut
        : settings.quickPasteShortcut
  }

  return {
    schemaVersion: STORAGE_SCHEMA_VERSION,
    settings,
    history: sortHistoryRecords([...historyById.values()])
  }
}

function coerceSnapshot(value: unknown): AppSnapshot {
  if (!value || typeof value !== 'object') {
    return DEFAULT_SNAPSHOT
  }

  const input = value as Partial<AppSnapshot>
  const history = Array.isArray(input.history) ? input.history.filter(isHistoryRecord) : []

  return {
    schemaVersion: STORAGE_SCHEMA_VERSION,
    settings: {
      ...DEFAULT_SETTINGS,
      ...(input.settings ?? {})
    },
    history: sortHistoryRecords(history)
  }
}

function isHistoryRecord(value: unknown): value is HistoryRecord {
  if (!value || typeof value !== 'object') {
    return false
  }

  const record = value as Partial<HistoryRecord>

  return (
    typeof record.id === 'string' &&
    typeof record.title === 'string' &&
    typeof record.content === 'string' &&
    typeof record.createdAt === 'string' &&
    typeof record.updatedAt === 'string' &&
    typeof record.pinned === 'boolean'
  )
}
