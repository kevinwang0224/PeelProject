import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises'
import { join } from 'node:path'
import { tmpdir } from 'node:os'

import { describe, expect, it } from 'vitest'

import { STORAGE_SCHEMA_VERSION } from '@desktop/shared/peel'
import { PeelStorage } from './storage'

describe('PeelStorage', () => {
  it('keeps legacy records without extraction and upgrades them on disk', async () => {
    const dir = await mkdtemp(join(tmpdir(), 'peel-storage-'))
    const filePath = join(dir, 'peel-data.json')

    try {
      await writeFile(
        filePath,
        JSON.stringify({
          schemaVersion: 1,
          settings: {
            theme: 'system',
            editorFontSize: 14,
            quickPasteShortcut: ''
          },
          history: [
            {
              id: 'legacy-record',
              title: 'Legacy',
              content: '{"kept":true}',
              createdAt: '2026-04-29T00:00:00.000Z',
              updatedAt: '2026-04-29T00:00:00.000Z',
              pinned: false
            }
          ]
        }),
        'utf8'
      )

      const storage = new PeelStorage(filePath)
      const snapshot = await storage.bootstrap()
      const record = snapshot.history[0]

      expect(snapshot.schemaVersion).toBe(STORAGE_SCHEMA_VERSION)
      expect(record?.content).toBe('{"kept":true}')
      expect(record?.extraction).toEqual({
        mode: 'javascript',
        queries: {
          javascript: 'data',
          jsonpath: '$'
        }
      })

      const persisted = JSON.parse(await readFile(filePath, 'utf8'))
      expect(persisted.schemaVersion).toBe(STORAGE_SCHEMA_VERSION)
      expect(persisted.history[0].content).toBe('{"kept":true}')
      expect(persisted.history[0].extraction.queries.javascript).toBe('data')
    } finally {
      await rm(dir, { recursive: true, force: true })
    }
  })

  it('restores legacy snapshots when current storage is empty even after migration marker exists', async () => {
    const dir = await mkdtemp(join(tmpdir(), 'peel-storage-'))
    const filePath = join(dir, 'peel-data.json')
    const legacyPath = join(dir, 'legacy-data.json')

    try {
      await writeFile(
        filePath,
        JSON.stringify({
          schemaVersion: 1,
          settings: {
            theme: 'system',
            editorFontSize: 14,
            quickPasteShortcut: ''
          },
          history: []
        }),
        'utf8'
      )
      await writeFile(`${filePath}.legacy-migration-complete`, new Date().toISOString(), 'utf8')
      await writeFile(
        legacyPath,
        JSON.stringify({
          schemaVersion: 1,
          settings: {
            theme: 'system',
            editorFontSize: 14,
            quickPasteShortcut: ''
          },
          history: [
            {
              id: 'legacy-record',
              title: 'Legacy',
              content: '{"restored":true}',
              createdAt: '2026-04-29T00:00:00.000Z',
              updatedAt: '2026-04-29T00:00:00.000Z',
              pinned: false
            }
          ]
        }),
        'utf8'
      )

      const storage = new PeelStorage(filePath, [legacyPath])
      const snapshot = await storage.bootstrap()

      expect(snapshot.history).toHaveLength(1)
      expect(snapshot.history[0]?.content).toBe('{"restored":true}')
    } finally {
      await rm(dir, { recursive: true, force: true })
    }
  })
})
