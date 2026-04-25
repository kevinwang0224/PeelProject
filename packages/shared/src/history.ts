import type { HistoryRecord, HistoryRecordSeed } from "./types";

export function createDefaultTitle(date = new Date()): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  const hours = String(date.getHours()).padStart(2, "0");
  const minutes = String(date.getMinutes()).padStart(2, "0");
  const seconds = String(date.getSeconds()).padStart(2, "0");

  return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
}

export function normalizeTitle(
  title: string | undefined,
  fallbackDate = new Date(),
): string {
  const trimmed = title?.trim();
  return trimmed?.length ? trimmed : createDefaultTitle(fallbackDate);
}

export function createHistoryRecord(
  seed: HistoryRecordSeed = {},
): HistoryRecord {
  const now = new Date();
  const isoNow = now.toISOString();

  return {
    id: globalThis.crypto.randomUUID(),
    title: normalizeTitle(seed.title, now),
    content: seed.content ?? "",
    createdAt: isoNow,
    updatedAt: isoNow,
    pinned: false,
  };
}

export function sortHistoryRecords(records: HistoryRecord[]): HistoryRecord[] {
  return [...records].sort((left, right) => {
    if (left.pinned !== right.pinned) {
      return left.pinned ? -1 : 1;
    }

    return right.updatedAt.localeCompare(left.updatedAt);
  });
}

export function upsertHistoryRecord(
  records: HistoryRecord[],
  record: HistoryRecord,
): HistoryRecord[] {
  const nextRecords = records.filter((item) => item.id !== record.id);
  nextRecords.push(record);
  return sortHistoryRecords(nextRecords);
}
