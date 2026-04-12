/// <reference types="vite/client" />

import type { PeelAPI } from '@shared/peel'

declare global {
  interface Window {
    peel: PeelAPI
  }
}
