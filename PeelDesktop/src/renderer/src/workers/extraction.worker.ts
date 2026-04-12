import { runExtraction } from '@shared/extraction'
import type { ExtractionRequest, ExtractionResult } from '@shared/peel'

self.onmessage = async (event: MessageEvent<ExtractionRequest>) => {
  const result: ExtractionResult = await runExtraction(event.data)
  self.postMessage(result)
}
