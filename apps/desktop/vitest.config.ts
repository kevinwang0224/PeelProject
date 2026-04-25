import { resolve } from 'node:path'
import { defineConfig } from 'vitest/config'

export default defineConfig({
  resolve: {
    alias: {
      '@': resolve('src/renderer/src'),
      '@renderer': resolve('src/renderer/src'),
      '@desktop/shared': resolve('src/shared'),
      '@peel/shared': resolve('../../packages/shared/src')
    }
  },
  test: {
    environment: 'node',
    include: ['src/**/*.test.ts', 'src/**/*.test.tsx']
  }
})
