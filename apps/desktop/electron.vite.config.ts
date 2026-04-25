import { resolve } from 'node:path'
import { defineConfig, externalizeDepsPlugin } from 'electron-vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  main: {
    plugins: [externalizeDepsPlugin()],
    resolve: {
      alias: {
        '@main': resolve('src/main'),
        '@desktop/shared': resolve('src/shared'),
        '@peel/shared': resolve('../../packages/shared/src')
      }
    }
  },
  preload: {
    plugins: [externalizeDepsPlugin()],
    resolve: {
      alias: {
        '@desktop/shared': resolve('src/shared'),
        '@peel/shared': resolve('../../packages/shared/src')
      }
    }
  },
  renderer: {
    resolve: {
      alias: {
        '@': resolve('src/renderer/src'),
        '@renderer': resolve('src/renderer/src'),
        '@desktop/shared': resolve('src/shared'),
        '@peel/shared': resolve('../../packages/shared/src')
      }
    },
    plugins: [react(), tailwindcss()]
  }
})
