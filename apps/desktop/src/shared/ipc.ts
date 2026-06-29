export const IPC_CHANNELS = {
  rendererReady: 'peel:renderer-ready',
  bootstrap: 'peel:bootstrap',
  historyCreate: 'peel:history:create',
  historySave: 'peel:history:save',
  historyRemove: 'peel:history:remove',
  historyRename: 'peel:history:rename',
  historyTogglePin: 'peel:history:toggle-pin',
  settingsSave: 'peel:settings:save',
  filesOpenJson: 'peel:files:open-json',
  filesExportJson: 'peel:files:export-json',
  clipboardReadText: 'peel:clipboard:read-text',
  clipboardWriteText: 'peel:clipboard:write-text',
  menuAction: 'peel:menu-action',
  tempGetInitialContent: 'peel:temp:get-initial-content',
  tempSetDirty: 'peel:temp:set-dirty',
  tempCommit: 'peel:temp:commit',
  snapshotUpdated: 'peel:snapshot-updated'
} as const
