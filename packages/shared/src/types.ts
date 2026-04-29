export type ThemePreference = "system" | "light" | "dark";
export type ExtractionMode = "javascript" | "jsonpath";
export type ExtractionStatus = "idle" | "success" | "empty" | "error";
export type ResultDisplayStyle = "plainText" | "structuredJson";

export type ExtractionQueries = Record<ExtractionMode, string>;

export interface HistoryExtractionState {
  mode: ExtractionMode;
  queries: ExtractionQueries;
}

export type HistoryExtractionSeed = {
  mode?: ExtractionMode;
  queries?: Partial<ExtractionQueries>;
};

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
  extraction: HistoryExtractionState;
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
  extraction?: HistoryExtractionSeed;
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

export const STORAGE_SCHEMA_VERSION = 2;

export const DEFAULT_EXTRACTION_MODE: ExtractionMode = "javascript";

export const DEFAULT_EXTRACTION_QUERIES: ExtractionQueries = {
  javascript: "data",
  jsonpath: "$",
};

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
