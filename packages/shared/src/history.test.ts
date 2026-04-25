import { describe, expect, it } from "vitest";

import {
  createHistoryRecord,
  normalizeTitle,
  sortHistoryRecords,
  upsertHistoryRecord,
} from "./history";

describe("history helpers", () => {
  it("creates a fallback title when input is blank", () => {
    const title = normalizeTitle("   ", new Date(2026, 3, 12, 8, 0, 0));

    expect(title).toBe("2026-04-12 08:00:00");
  });

  it("creates complete records with ids and timestamps", () => {
    const record = createHistoryRecord({ content: '{"name":"peel"}' });

    expect(record.id).toBeTruthy();
    expect(record.title).toBeTruthy();
    expect(record.content).toContain("peel");
    expect(record.updatedAt).toBe(record.createdAt);
  });

  it("sorts pinned records first and newer records ahead of older ones", () => {
    const older = {
      id: "older",
      title: "older",
      content: "{}",
      createdAt: "2026-04-11T09:00:00.000Z",
      updatedAt: "2026-04-11T09:00:00.000Z",
      pinned: false,
    };

    const pinned = {
      ...older,
      id: "pinned",
      pinned: true,
    };

    const newer = {
      ...older,
      id: "newer",
      updatedAt: "2026-04-12T09:00:00.000Z",
    };

    expect(
      sortHistoryRecords([older, newer, pinned]).map((record) => record.id),
    ).toEqual(["pinned", "newer", "older"]);
  });

  it("upserts records by id", () => {
    const base = createHistoryRecord({ title: "base", content: "{}" });
    const updated = {
      ...base,
      content: '{"updated":true}',
      updatedAt: "2026-04-12T12:00:00.000Z",
    };

    const result = upsertHistoryRecord([base], updated);

    expect(result).toHaveLength(1);
    expect(result[0]?.content).toContain("updated");
  });
});
