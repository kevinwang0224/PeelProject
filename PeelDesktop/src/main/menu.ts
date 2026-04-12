import { app, BrowserWindow, Menu, shell } from 'electron'

import { IPC_CHANNELS } from '@shared/ipc'
import type { MenuAction } from '@shared/peel'

export function buildAppMenu(getWindow: () => BrowserWindow | null, isDev: boolean): Menu {
  const sendAction = (action: MenuAction): void => {
    getWindow()?.webContents.send(IPC_CHANNELS.menuAction, action)
  }

  const appMenu: Electron.MenuItemConstructorOptions[] =
    process.platform === 'darwin'
      ? [
          {
            label: app.name,
            submenu: [
              { role: 'about' },
              { type: 'separator' },
              { role: 'services' },
              { type: 'separator' },
              { role: 'hide' },
              { role: 'hideOthers' },
              { role: 'unhide' },
              { type: 'separator' },
              { role: 'quit' }
            ]
          }
        ]
      : []

  const fileMenu: Electron.MenuItemConstructorOptions = {
    label: 'File',
    submenu: [
      {
        label: 'New JSON',
        accelerator: 'CmdOrCtrl+N',
        click: () => sendAction('new-json')
      },
      {
        label: 'Open JSON…',
        accelerator: 'CmdOrCtrl+O',
        click: () => sendAction('open-json')
      },
      {
        label: 'Export JSON…',
        accelerator: 'CmdOrCtrl+Shift+S',
        click: () => sendAction('export-json')
      },
      { type: 'separator' },
      process.platform === 'darwin' ? { role: 'close' } : { role: 'quit' }
    ]
  }

  const editMenu: Electron.MenuItemConstructorOptions = {
    label: 'Edit',
    submenu: [
      {
        label: 'Format JSON',
        accelerator: 'Shift+Alt+F',
        click: () => sendAction('format-json')
      },
      {
        label: 'Compact JSON',
        accelerator: 'Shift+Alt+M',
        click: () => sendAction('compact-json')
      },
      { type: 'separator' },
      {
        label: 'Copy',
        accelerator: 'CmdOrCtrl+C',
        click: () => sendAction('copy')
      },
      {
        label: 'Paste',
        accelerator: 'CmdOrCtrl+V',
        click: () => sendAction('paste')
      },
      {
        label: 'Find',
        accelerator: 'CmdOrCtrl+F',
        click: () => sendAction('find')
      },
      {
        label: 'Select All',
        accelerator: 'CmdOrCtrl+A',
        click: () => sendAction('select-all')
      }
    ]
  }

  const viewSubmenu: Electron.MenuItemConstructorOptions[] = [
    { role: 'togglefullscreen' },
    ...(isDev
      ? ([
          { role: 'reload' },
          { role: 'toggleDevTools' }
        ] satisfies Electron.MenuItemConstructorOptions[])
      : []),
    {
      label: 'Peel Website',
      click: () => {
        void shell.openExternal('https://github.com')
      }
    }
  ]

  const template: Electron.MenuItemConstructorOptions[] = [
    ...appMenu,
    fileMenu,
    editMenu,
    {
      label: 'View',
      submenu: viewSubmenu
    },
    {
      label: 'Window',
      submenu: [{ role: 'minimize' }, { role: 'zoom' }]
    }
  ]

  return Menu.buildFromTemplate(template)
}
