import { app, BrowserWindow, clipboard, dialog, ipcMain, Menu, shell } from 'electron'
import { readFile, writeFile } from 'node:fs/promises'
import { basename, extname, join } from 'node:path'

import { electronApp, is } from '@electron-toolkit/utils'
import icon from '../../resources/icon.png?asset'
import { IPC_CHANNELS } from '@shared/ipc'
import type { AppSettings, ExportJsonPayload, HistoryRecord, HistoryRecordSeed } from '@shared/peel'
import { buildAppMenu } from './menu'
import { PeelStorage } from './storage'

const storage = new PeelStorage(join(app.getPath('userData'), 'peel-data.json'))

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

  mainWindow.on('ready-to-show', () => {
    mainWindow.show()
  })

  mainWindow.webContents.setWindowOpenHandler((details) => {
    void shell.openExternal(details.url)
    return { action: 'deny' }
  })

  if (is.dev && process.env.ELECTRON_RENDERER_URL) {
    void mainWindow.loadURL(process.env.ELECTRON_RENDERER_URL)
  } else {
    void mainWindow.loadFile(join(__dirname, '../renderer/index.html'))
  }

  return mainWindow
}

function registerIpcHandlers(): void {
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
  ipcMain.handle(IPC_CHANNELS.settingsSave, (_event, settings: AppSettings) =>
    storage.saveSettings(settings)
  )
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

  const getFocusedWindow = (): BrowserWindow | null => BrowserWindow.getFocusedWindow()
  Menu.setApplicationMenu(buildAppMenu(getFocusedWindow, is.dev))

  createWindow()

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
