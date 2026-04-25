import { runExtraction } from '@peel/shared/extraction'
import type { ExtractionRequest, ExtractionResult } from '@peel/shared/types'

self.onmessage = async (event: MessageEvent<ExtractionRequest>) => {
  const result: ExtractionResult = await runExtraction(event.data)
  self.postMessage(result)
}
