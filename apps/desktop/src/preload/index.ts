import { contextBridge, ipcRenderer } from 'electron'

import { IPC_CHANNELS } from '@desktop/shared/ipc'
import type { AppSnapshot, PeelAPI, MenuAction } from '@desktop/shared/peel'

const menuListeners = new Set<(action: MenuAction) => void>()

ipcRenderer.on(IPC_CHANNELS.menuAction, (_event, action: MenuAction) => {
  menuListeners.forEach((listener) => listener(action))
})

const snapshotListeners = new Set<(snapshot: AppSnapshot) => void>()

ipcRenderer.on(IPC_CHANNELS.snapshotUpdated, (_event, snapshot: AppSnapshot) => {
  snapshotListeners.forEach((listener) => listener(snapshot))
})

const peelApi: PeelAPI = {
  rendererReady: () => ipcRenderer.send(IPC_CHANNELS.rendererReady),
  bootstrap: () => ipcRenderer.invoke(IPC_CHANNELS.bootstrap),
  history: {
    create: (seed) => ipcRenderer.invoke(IPC_CHANNELS.historyCreate, seed),
    save: (record) => ipcRenderer.invoke(IPC_CHANNELS.historySave, record),
    remove: (id) => ipcRenderer.invoke(IPC_CHANNELS.historyRemove, id),
    rename: (id, title) => ipcRenderer.invoke(IPC_CHANNELS.historyRename, id, title),
    togglePin: (id) => ipcRenderer.invoke(IPC_CHANNELS.historyTogglePin, id)
  },
  settings: {
    save: (settings) => ipcRenderer.invoke(IPC_CHANNELS.settingsSave, settings)
  },
  files: {
    openJson: () => ipcRenderer.invoke(IPC_CHANNELS.filesOpenJson),
    exportJson: (payload) => ipcRenderer.invoke(IPC_CHANNELS.filesExportJson, payload)
  },
  clipboard: {
    readText: () => ipcRenderer.invoke(IPC_CHANNELS.clipboardReadText),
    writeText: (text) => ipcRenderer.invoke(IPC_CHANNELS.clipboardWriteText, text)
  },
  temp: {
    getInitialContent: () => ipcRenderer.invoke(IPC_CHANNELS.tempGetInitialContent),
    setDirty: (dirty) => ipcRenderer.send(IPC_CHANNELS.tempSetDirty, dirty),
    commit: (seed) => ipcRenderer.invoke(IPC_CHANNELS.tempCommit, seed)
  },
  menu: {
    onAction: (listener) => {
      menuListeners.add(listener)

      return () => {
        menuListeners.delete(listener)
      }
    }
  },
  onSnapshotUpdated: (listener) => {
    snapshotListeners.add(listener)

    return () => {
      snapshotListeners.delete(listener)
    }
  }
}

contextBridge.exposeInMainWorld('peel', peelApi)
