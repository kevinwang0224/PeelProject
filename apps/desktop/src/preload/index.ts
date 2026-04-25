import { contextBridge, ipcRenderer } from 'electron'

import { IPC_CHANNELS } from '@desktop/shared/ipc'
import type { PeelAPI, MenuAction } from '@desktop/shared/peel'

const menuListeners = new Set<(action: MenuAction) => void>()

ipcRenderer.on(IPC_CHANNELS.menuAction, (_event, action: MenuAction) => {
  menuListeners.forEach((listener) => listener(action))
})

const peelApi: PeelAPI = {
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
  menu: {
    onAction: (listener) => {
      menuListeners.add(listener)

      return () => {
        menuListeners.delete(listener)
      }
    }
  }
}

contextBridge.exposeInMainWorld('peel', peelApi)
