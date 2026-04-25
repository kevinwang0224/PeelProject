import type { ExtractionRequest, ExtractionResult } from '@peel/shared/types'

const EXTRACTION_TIMEOUT_MS = 1200

export function runExtractionInWorker(request: ExtractionRequest): Promise<ExtractionResult> {
  return new Promise((resolve, reject) => {
    const worker = new Worker(new URL('../workers/extraction.worker.ts', import.meta.url), {
      type: 'module'
    })

    const timeout = window.setTimeout(() => {
      worker.terminate()
      reject(new Error('Extraction timed out.'))
    }, EXTRACTION_TIMEOUT_MS)

    worker.onmessage = (event: MessageEvent<ExtractionResult>) => {
      window.clearTimeout(timeout)
      worker.terminate()
      resolve(event.data)
    }

    worker.onerror = (event) => {
      window.clearTimeout(timeout)
      worker.terminate()
      reject(new Error(event.message || 'Extraction failed.'))
    }

    worker.postMessage(request)
  })
}
