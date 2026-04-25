export type ThemePreference = "system" | "light" | "dark";
export type ExtractionMode = "javascript" | "jsonpath";
export type ExtractionStatus = "idle" | "success" | "empty" | "error";
export type ResultDisplayStyle = "plainText" | "structuredJson";

export interface JsonValidationIssue {
  message: string;
  line: number;
  column: number;
  offset: number;
  length: number;
}

export interface HistoryRecord {
  id: string;
  title: string;
  content: string;
  createdAt: string;
  updatedAt: string;
  pinned: boolean;
}

export interface AppSettings {
  theme: ThemePreference;
  editorFontSize: number;
  quickPasteShortcut: string;
}

export interface AppSnapshot {
  schemaVersion: number;
  settings: AppSettings;
  history: HistoryRecord[];
}

export interface HistoryRecordSeed {
  title?: string;
  content?: string;
}

export interface ExtractionResult {
  status: ExtractionStatus;
  title: string;
  text: string;
  displayStyle: ResultDisplayStyle;
}

export interface ExtractionRequest {
  mode: ExtractionMode;
  query: string;
  data: unknown;
}

export const STORAGE_SCHEMA_VERSION = 1;

export const DEFAULT_SETTINGS: AppSettings = {
  theme: "system",
  editorFontSize: 14,
  quickPasteShortcut: "",
};

export const DEFAULT_SNAPSHOT: AppSnapshot = {
  schemaVersion: STORAGE_SCHEMA_VERSION,
  settings: DEFAULT_SETTINGS,
  history: [],
};
