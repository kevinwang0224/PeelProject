/// <reference types="vite/client" />

import type { PeelAPI } from '@desktop/shared/peel'

declare global {
  interface Window {
    peel: PeelAPI
  }
}
