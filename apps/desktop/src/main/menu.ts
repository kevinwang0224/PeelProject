import { app, BaseWindow, BrowserWindow, Menu, shell, type WebContents } from 'electron'

import { IPC_CHANNELS } from '@desktop/shared/ipc'
import type { MenuAction } from '@desktop/shared/peel'

type EditingCommand = 'cut' | 'copy' | 'paste' | 'selectAll'

function webContentsIfAlive(
  win: BaseWindow | BrowserWindow | null | undefined
): WebContents | null {
  if (!win || win.isDestroyed()) {
    return null
  }

  if (win instanceof BrowserWindow) {
    return win.webContents
  }

  if ('webContents' in win && win.webContents) {
    return win.webContents as WebContents
  }

  return null
}

function resolveTargetWebContents(
  menuWindow: BaseWindow | undefined,
  getPreferredWindow: () => BrowserWindow | null
): WebContents | null {
  const chain: Array<BaseWindow | BrowserWindow | null | undefined> = [
    menuWindow,
    getPreferredWindow(),
    BrowserWindow.getFocusedWindow(),
    BrowserWindow.getAllWindows()[0]
  ]

  for (const candidate of chain) {
    const wc = webContentsIfAlive(candidate ?? undefined)
    if (wc) {
      return wc
    }
  }

  return null
}

function dispatchEditingCommand(
  command: EditingCommand,
  menuWindow: BaseWindow | undefined,
  getPreferredWindow: () => BrowserWindow | null
): void {
  const webContents = resolveTargetWebContents(menuWindow, getPreferredWindow)
  if (!webContents) {
    return
  }

  switch (command) {
    case 'cut':
      webContents.cut()
      break
    case 'copy':
      webContents.copy()
      break
    case 'paste':
      webContents.paste()
      break
    case 'selectAll':
      webContents.selectAll()
      break
  }
}

export function buildAppMenu(getWindow: () => BrowserWindow | null, isDev: boolean): Menu {
  const sendAction = (action: MenuAction, menuWindow?: BaseWindow): void => {
    const webContents = resolveTargetWebContents(menuWindow, getWindow)
    webContents?.send(IPC_CHANNELS.menuAction, action)
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
        click: (_item, bw) => sendAction('new-json', bw)
      },
      {
        label: 'Open JSON…',
        accelerator: 'CmdOrCtrl+O',
        click: (_item, bw) => sendAction('open-json', bw)
      },
      {
        label: 'Export JSON…',
        accelerator: 'CmdOrCtrl+Shift+S',
        click: (_item, bw) => sendAction('export-json', bw)
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
        click: (_item, bw) => sendAction('format-json', bw)
      },
      {
        label: 'Compact JSON',
        accelerator: 'Shift+Alt+M',
        click: (_item, bw) => sendAction('compact-json', bw)
      },
      { type: 'separator' },
      /*
       * 显式调用 webContents.cut/copy/paste/selectAll：焦点落在页内任意可编辑控件时行为与系统一致；
       * 若用 renderer 里读剪贴板再写死到 JSON 编辑器，会在设置/搜索框等场景误粘贴。
       * 不用 role：部分 Electron + 无边框标题栏组合下 role 快捷键可能不触发。
       */
      {
        label: 'Cut',
        accelerator: 'CmdOrCtrl+X',
        click: (_item, bw) => dispatchEditingCommand('cut', bw, getWindow)
      },
      {
        label: 'Copy',
        accelerator: 'CmdOrCtrl+C',
        click: (_item, bw) => dispatchEditingCommand('copy', bw, getWindow)
      },
      {
        label: 'Paste',
        accelerator: 'CmdOrCtrl+V',
        click: (_item, bw) => dispatchEditingCommand('paste', bw, getWindow)
      },
      { type: 'separator' },
      {
        label: 'Find',
        accelerator: 'CmdOrCtrl+F',
        click: (_item, bw) => sendAction('find', bw)
      },
      {
        label: 'Select All',
        accelerator: 'CmdOrCtrl+A',
        click: (_item, bw) => dispatchEditingCommand('selectAll', bw, getWindow)
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
