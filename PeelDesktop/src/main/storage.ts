import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { dirname } from 'node:path'

import {
  createHistoryRecord,
  normalizeTitle,
  sortHistoryRecords,
  upsertHistoryRecord
} from '@shared/history'
import {
  DEFAULT_SETTINGS,
  DEFAULT_SNAPSHOT,
  STORAGE_SCHEMA_VERSION,
  type AppSettings,
  type AppSnapshot,
  type CreateHistoryResult,
  type HistoryRecord,
  type HistoryRecordSeed
} from '@shared/peel'

export class PeelStorage {
  private readonly filePath: string

  private snapshot: AppSnapshot | null = null

  private writeQueue = Promise.resolve()

  constructor(filePath: string) {
    this.filePath = filePath
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

    try {
      const raw = await readFile(this.filePath, 'utf8')
      const parsed = JSON.parse(raw)
      this.snapshot = coerceSnapshot(parsed)
    } catch {
      this.snapshot = DEFAULT_SNAPSHOT
    }

    return this.snapshot
  }

  private async persist(snapshot: AppSnapshot): Promise<AppSnapshot> {
    const normalizedSnapshot = coerceSnapshot(snapshot)
    const payload = JSON.stringify(normalizedSnapshot, null, 2)

    this.snapshot = normalizedSnapshot
    this.writeQueue = this.writeQueue.then(() => writeFile(this.filePath, payload, 'utf8'))
    await this.writeQueue

    return structuredClone(normalizedSnapshot)
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
