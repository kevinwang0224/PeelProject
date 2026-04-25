import type { PeelAPI } from '@desktop/shared/peel'

declare global {
  interface Window {
    peel: PeelAPI
  }
}
