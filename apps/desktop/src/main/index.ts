import {
  app,
  BrowserWindow,
  clipboard,
  dialog,
  globalShortcut,
  ipcMain,
  Menu,
  nativeImage,
  shell,
  Tray
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

interface TempWindowState {
  initialContent: string
  dirty: boolean
}

/** 临时窗口运行态：key 为 webContents.id，记录预填内容与是否有未保存改动 */
const tempWindowStates = new Map<number, TempWindowState>()

/** 菜单栏/系统托盘图标；用模块级引用避免被 GC */
let tray: Tray | null = null
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

function createTempWindow(initialContent: string): BrowserWindow {
  const tempWindow = new BrowserWindow({
    width: 820,
    height: 620,
    minWidth: 480,
    minHeight: 360,
    show: false,
    title: 'Peel — Temporary',
    titleBarStyle: process.platform === 'darwin' ? 'hiddenInset' : 'default',
    backgroundColor: '#f0ede8',
    ...(process.platform === 'linux' ? { icon } : {}),
    webPreferences: {
      preload: join(__dirname, '../preload/index.js'),
      contextIsolation: true,
      sandbox: true
    }
  })

  // 缓存 id：'closed' 事件触发时 webContents 已销毁，再读取 .id 会抛 "Object has been destroyed"
  const tempWindowId = tempWindow.webContents.id
  tempWindowStates.set(tempWindowId, { initialContent, dirty: false })

  tempWindow.on('ready-to-show', () => {
    tempWindow.show()
    tempWindow.focus()
  })

  tempWindow.webContents.setWindowOpenHandler((details) => {
    void shell.openExternal(details.url)
    return { action: 'deny' }
  })

  tempWindow.webContents.setZoomFactor(1)
  if (typeof tempWindow.webContents.setVisualZoomLevelLimits === 'function') {
    void tempWindow.webContents.setVisualZoomLevelLimits(1, 1).catch((error) => {
      console.warn('Failed to lock visual zoom limits:', error)
    })
  }

  if (is.dev && process.env.ELECTRON_RENDERER_URL) {
    void tempWindow.loadURL(`${process.env.ELECTRON_RENDERER_URL}#temp`)
  } else {
    void tempWindow.loadFile(join(__dirname, '../renderer/index.html'), { hash: 'temp' })
  }

  tempWindow.on('close', (event) => {
    const state = tempWindowStates.get(tempWindowId)

    if (!state || !state.dirty) {
      return
    }

    event.preventDefault()

    const choice = dialog.showMessageBoxSync(tempWindow, {
      type: 'warning',
      buttons: ['Discard', 'Cancel'],
      defaultId: 1,
      cancelId: 1,
      title: 'Discard changes?',
      message: 'Discard changes?',
      detail: 'This temporary window has unsaved content. Closing it will discard the data.'
    })

    if (choice === 0) {
      // 先从 map 删除，避免 'closed' 处理器或重复 close 再次操作已销毁窗口
      tempWindowStates.delete(tempWindowId)
      tempWindow.destroy()
    }
  })

  tempWindow.on('closed', () => {
    tempWindowStates.delete(tempWindowId)
  })

  return tempWindow
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
  ipcMain.handle(IPC_CHANNELS.tempGetInitialContent, (event) => {
    return tempWindowStates.get(event.sender.id)?.initialContent ?? ''
  })
  ipcMain.on(IPC_CHANNELS.tempSetDirty, (event, dirty: boolean) => {
    const state = tempWindowStates.get(event.sender.id)
    if (state) {
      state.dirty = dirty
    }
  })
  ipcMain.handle(IPC_CHANNELS.tempCommit, async (event, seed: HistoryRecordSeed) => {
    const { snapshot } = await storage.createRecord(seed)

    if (peelMainBrowserWindow && !peelMainBrowserWindow.isDestroyed()) {
      peelMainBrowserWindow.webContents.send(IPC_CHANNELS.snapshotUpdated, snapshot)
    }

    const senderWindow = BrowserWindow.fromWebContents(event.sender)
    if (senderWindow) {
      // 先删除状态，destroy() 触发的 'closed' 处理器便不会再操作已销毁窗口
      tempWindowStates.delete(event.sender.id)
      senderWindow.destroy()
    }
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
  createTray()
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

function handleQuickPasteTrigger(): void {
  createTempWindow(clipboard.readText())
}

function openMainWindow(): void {
  const mainWindow =
    peelMainBrowserWindow && !peelMainBrowserWindow.isDestroyed()
      ? peelMainBrowserWindow
      : createWindow()

  if (mainWindow.isMinimized()) {
    mainWindow.restore()
  }

  mainWindow.show()
  mainWindow.focus()
}

function createTray(): void {
  if (tray) {
    return
  }

  const trayImage = nativeImage.createFromPath(icon).resize({ width: 18, height: 18 })
  if (process.platform === 'darwin') {
    trayImage.setTemplateImage(true)
  }

  tray = new Tray(trayImage)
  tray.setToolTip('Peel')

  const contextMenu = Menu.buildFromTemplate([
    {
      label: 'Open Main Window',
      click: () => openMainWindow()
    },
    {
      label: 'New Temporary Window',
      click: () => handleQuickPasteTrigger()
    },
    { type: 'separator' },
    {
      label: 'Quit Peel',
      click: () => app.quit()
    }
  ])

  tray.setContextMenu(contextMenu)

  // 非 macOS 下左键单击直接打开主窗口（macOS 单击默认弹出菜单）
  if (process.platform !== 'darwin') {
    tray.on('click', () => openMainWindow())
  }
}

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
    const registered = globalShortcut.register(normalized, handleQuickPasteTrigger)

    if (registered) {
      registeredQuickPasteShortcut = normalized
      return true
    }

    if (previousShortcut) {
      const rollbackRegistered = globalShortcut.register(previousShortcut, handleQuickPasteTrigger)

      if (rollbackRegistered) {
        registeredQuickPasteShortcut = previousShortcut
      }
    }
  } catch (error) {
    console.error('Failed to register quick paste shortcut:', error)

    if (previousShortcut) {
      const rollbackRegistered = globalShortcut.register(previousShortcut, handleQuickPasteTrigger)

      if (rollbackRegistered) {
        registeredQuickPasteShortcut = previousShortcut
      }
    }
  }

  return false
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
