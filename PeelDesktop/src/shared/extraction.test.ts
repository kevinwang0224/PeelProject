import { describe, expect, it } from 'vitest'

import { runExtraction } from './extraction'

describe('extraction helpers', () => {
  const data = {
    user: { name: 'Peel', age: 3 },
    items: [{ id: 1 }, { id: 2 }]
  }

  it('returns primitive values from javascript queries', async () => {
    const result = await runExtraction({
      mode: 'javascript',
      query: 'data.user.name',
      data
    })

    expect(result.status).toBe('success')
    expect(result.text).toBe('Peel')
  })

  it('returns structured json from jsonpath queries', async () => {
    const result = await runExtraction({
      mode: 'jsonpath',
      query: '$.items[*]',
      data
    })

    expect(result.status).toBe('success')
    expect(result.displayStyle).toBe('structuredJson')
    expect(result.text).toContain('"id": 1')
  })

  it('returns empty when nothing matches', async () => {
    const result = await runExtraction({
      mode: 'jsonpath',
      query: '$.missing',
      data
    })

    expect(result.status).toBe('empty')
  })
})
