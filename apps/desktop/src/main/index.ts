import {
  app,
  BrowserWindow,
  clipboard,
  dialog,
  globalShortcut,
  ipcMain,
  Menu,
  shell
} from 'electron'
import { readFile, writeFile } from 'node:fs/promises'
import { basename, extname, join } from 'node:path'

import { electronApp, is } from '@electron-toolkit/utils'
import icon from '../../resources/icon.png?asset'
import { IPC_CHANNELS } from '@desktop/shared/ipc'
import type {
  AppSettings,
  ExportJsonPayload,
  HistoryRecord,
  HistoryRecordSeed
} from '@desktop/shared/peel'
import { buildAppMenu } from './menu'
import { PeelStorage } from './storage'

/** 若选区/光标与文字错位，可设 `PEEL_DISABLE_GPU=1` 启动以排查是否为 GPU 合成问题（须在 ready 之前调用） */
if (process.env.PEEL_DISABLE_GPU === '1') {
  app.disableHardwareAcceleration()
}

const PEEL_DATA_FILE = 'peel-data.json'
const legacyUserDataDirs = ['peeldesktop', '@peel/desktop']

app.setName('Peel')
app.setPath('userData', join(app.getPath('appData'), 'Peel'))

const storage = new PeelStorage(
  join(app.getPath('userData'), PEEL_DATA_FILE),
  legacyUserDataDirs.map((dirName) => join(app.getPath('appData'), dirName, PEEL_DATA_FILE))
)
let registeredQuickPasteShortcut = ''
/** 应用菜单的 IPC 目标：hiddenInset 等场景下 getFocusedWindow() 可能为 null，需回退到主窗 */
let peelMainBrowserWindow: BrowserWindow | null = null
const windowReadiness = new WeakMap<
  BrowserWindow,
  {
    readyToShow: boolean
    rendererReady: boolean
    fallbackTimer: ReturnType<typeof setTimeout> | null
  }
>()

function showWindowWhenReady(window: BrowserWindow): void {
  const readiness = windowReadiness.get(window)

  if (!readiness || !readiness.readyToShow || !readiness.rendererReady || window.isVisible()) {
    return
  }

  if (readiness.fallbackTimer) {
    clearTimeout(readiness.fallbackTimer)
    readiness.fallbackTimer = null
  }

  window.show()
}

function createWindow(): BrowserWindow {
  const mainWindow = new BrowserWindow({
    width: 1440,
    height: 920,
    minWidth: 1180,
    minHeight: 760,
    show: false,
    title: 'Peel',
    titleBarStyle: process.platform === 'darwin' ? 'hiddenInset' : 'default',
    backgroundColor: '#f0ede8',
    ...(process.platform === 'linux' ? { icon } : {}),
    webPreferences: {
      preload: join(__dirname, '../preload/index.js'),
      contextIsolation: true,
      sandbox: true
    }
  })

  const readiness = {
    readyToShow: false,
    rendererReady: false,
    fallbackTimer: null as ReturnType<typeof setTimeout> | null
  }

  windowReadiness.set(mainWindow, readiness)

  mainWindow.on('ready-to-show', () => {
    readiness.readyToShow = true
    readiness.fallbackTimer = setTimeout(() => {
      if (!mainWindow.isDestroyed() && !mainWindow.isVisible()) {
        mainWindow.show()
      }
    }, 2000)
    showWindowWhenReady(mainWindow)
  })

  mainWindow.webContents.setWindowOpenHandler((details) => {
    void shell.openExternal(details.url)
    return { action: 'deny' }
  })

  // Keep Chromium zoom fixed at 100% to avoid Monaco caret/selection layer drift.
  mainWindow.webContents.setZoomFactor(1)
  if (typeof mainWindow.webContents.setVisualZoomLevelLimits === 'function') {
    void mainWindow.webContents.setVisualZoomLevelLimits(1, 1).catch((error) => {
      console.warn('Failed to lock visual zoom limits:', error)
    })
  }

  if (is.dev && process.env.ELECTRON_RENDERER_URL) {
    void mainWindow.loadURL(process.env.ELECTRON_RENDERER_URL)
  } else {
    void mainWindow.loadFile(join(__dirname, '../renderer/index.html'))
  }

  peelMainBrowserWindow = mainWindow
  mainWindow.on('closed', () => {
    if (readiness.fallbackTimer) {
      clearTimeout(readiness.fallbackTimer)
      readiness.fallbackTimer = null
    }

    if (peelMainBrowserWindow === mainWindow) {
      peelMainBrowserWindow = null
    }
  })

  return mainWindow
}

function registerIpcHandlers(): void {
  ipcMain.on(IPC_CHANNELS.rendererReady, (event) => {
    const window = BrowserWindow.fromWebContents(event.sender)

    if (!window) {
      return
    }

    const readiness = windowReadiness.get(window)
    if (!readiness) {
      return
    }

    readiness.rendererReady = true
    showWindowWhenReady(window)
  })

  ipcMain.handle(IPC_CHANNELS.bootstrap, () => storage.bootstrap())
  ipcMain.handle(IPC_CHANNELS.historyCreate, (_event, seed?: HistoryRecordSeed) =>
    storage.createRecord(seed)
  )
  ipcMain.handle(IPC_CHANNELS.historySave, (_event, record: HistoryRecord) =>
    storage.saveRecord(record)
  )
  ipcMain.handle(IPC_CHANNELS.historyRemove, (_event, id: string) => storage.removeRecord(id))
  ipcMain.handle(IPC_CHANNELS.historyRename, (_event, id: string, title: string) =>
    storage.renameRecord(id, title)
  )
  ipcMain.handle(IPC_CHANNELS.historyTogglePin, (_event, id: string) => storage.togglePin(id))
  ipcMain.handle(IPC_CHANNELS.settingsSave, async (_event, settings: AppSettings) => {
    const current = await storage.bootstrap()
    const nextShortcut = settings.quickPasteShortcut.trim()
    const currentShortcut = current.settings.quickPasteShortcut.trim()

    if (nextShortcut !== currentShortcut) {
      const registered = registerQuickPasteShortcut(nextShortcut)
      if (!registered && nextShortcut.length) {
        throw new Error('Global shortcut is unavailable or already in use.')
      }
    }

    const snapshot = await storage.saveSettings({
      ...settings,
      quickPasteShortcut: nextShortcut
    })
    return snapshot
  })
  ipcMain.handle(IPC_CHANNELS.filesOpenJson, openJsonFile)
  ipcMain.handle(IPC_CHANNELS.filesExportJson, (_event, payload: ExportJsonPayload) =>
    exportJsonFile(payload)
  )
  ipcMain.handle(IPC_CHANNELS.clipboardReadText, () => clipboard.readText())
  ipcMain.handle(IPC_CHANNELS.clipboardWriteText, (_event, text: string) => {
    clipboard.writeText(text)
  })
}

app.whenReady().then(() => {
  electronApp.setAppUserModelId('com.peel.desktop')

  if (process.platform === 'darwin') {
    app.dock?.setIcon(icon)
  }

  registerIpcHandlers()

  const getMenuTargetWindow = (): BrowserWindow | null =>
    BrowserWindow.getFocusedWindow() ??
    peelMainBrowserWindow ??
    BrowserWindow.getAllWindows()[0] ??
    null

  createWindow()
  Menu.setApplicationMenu(buildAppMenu(getMenuTargetWindow, is.dev))
  void storage.bootstrap().then((snapshot) => {
    registerQuickPasteShortcut(snapshot.settings.quickPasteShortcut)
  })

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow()
    }
  })
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit()
  }
})

app.on('will-quit', () => {
  globalShortcut.unregisterAll()
})

function registerQuickPasteShortcut(accelerator: string): boolean {
  const normalized = accelerator.trim()
  const previousShortcut = registeredQuickPasteShortcut

  if (previousShortcut) {
    globalShortcut.unregister(previousShortcut)
    registeredQuickPasteShortcut = ''
  }

  if (!normalized.length) {
    return true
  }

  try {
    const registered = globalShortcut.register(normalized, () => {
      const mainWindow = ensureMainWindow()

      if (mainWindow.isMinimized()) {
        mainWindow.restore()
      }

      mainWindow.show()
      mainWindow.focus()
      sendMenuAction(mainWindow, 'new-json-from-clipboard')
    })

    if (registered) {
      registeredQuickPasteShortcut = normalized
      return true
    }

    if (previousShortcut) {
      const rollbackRegistered = globalShortcut.register(previousShortcut, () => {
        const mainWindow = ensureMainWindow()

        if (mainWindow.isMinimized()) {
          mainWindow.restore()
        }

        mainWindow.show()
        mainWindow.focus()
        sendMenuAction(mainWindow, 'new-json-from-clipboard')
      })

      if (rollbackRegistered) {
        registeredQuickPasteShortcut = previousShortcut
      }
    }
  } catch (error) {
    console.error('Failed to register quick paste shortcut:', error)

    if (previousShortcut) {
      const rollbackRegistered = globalShortcut.register(previousShortcut, () => {
        const mainWindow = ensureMainWindow()

        if (mainWindow.isMinimized()) {
          mainWindow.restore()
        }

        mainWindow.show()
        mainWindow.focus()
        sendMenuAction(mainWindow, 'new-json-from-clipboard')
      })

      if (rollbackRegistered) {
        registeredQuickPasteShortcut = previousShortcut
      }
    }
  }

  return false
}

function ensureMainWindow(): BrowserWindow {
  const existingWindow = BrowserWindow.getAllWindows()[0]

  if (existingWindow) {
    return existingWindow
  }

  return createWindow()
}

function sendMenuAction(window: BrowserWindow, action: 'new-json-from-clipboard'): void {
  if (window.webContents.isLoadingMainFrame()) {
    window.webContents.once('did-finish-load', () => {
      window.webContents.send(IPC_CHANNELS.menuAction, action)
    })
    return
  }

  window.webContents.send(IPC_CHANNELS.menuAction, action)
}

async function openJsonFile(): Promise<{ path: string; title: string; content: string } | null> {
  const browserWindow = BrowserWindow.getFocusedWindow()
  const result = browserWindow
    ? await dialog.showOpenDialog(browserWindow, {
        title: 'Open JSON',
        properties: ['openFile'],
        filters: [
          { name: 'JSON', extensions: ['json'] },
          { name: 'All Files', extensions: ['*'] }
        ]
      })
    : await dialog.showOpenDialog({
        title: 'Open JSON',
        properties: ['openFile'],
        filters: [
          { name: 'JSON', extensions: ['json'] },
          { name: 'All Files', extensions: ['*'] }
        ]
      })

  if (result.canceled || !result.filePaths[0]) {
    return null
  }

  const filePath = result.filePaths[0]
  const content = await readFile(filePath, 'utf8')

  return {
    path: filePath,
    title: basename(filePath, extname(filePath)),
    content
  }
}

async function exportJsonFile(payload: ExportJsonPayload): Promise<boolean> {
  const browserWindow = BrowserWindow.getFocusedWindow()
  const result = browserWindow
    ? await dialog.showSaveDialog(browserWindow, {
        title: 'Export JSON',
        defaultPath: payload.suggestedName,
        filters: [{ name: 'JSON', extensions: ['json'] }]
      })
    : await dialog.showSaveDialog({
        title: 'Export JSON',
        defaultPath: payload.suggestedName,
        filters: [{ name: 'JSON', extensions: ['json'] }]
      })

  if (result.canceled || !result.filePath) {
    return false
  }

  await writeFile(result.filePath, payload.content, 'utf8')
  return true
}
