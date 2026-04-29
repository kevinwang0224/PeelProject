import { describe, expect, it } from "vitest";

import {
  createHistoryExtractionState,
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
    expect(record.extraction).toEqual({
      mode: "javascript",
      queries: {
        javascript: "data",
        jsonpath: "$",
      },
    });
    expect(record.updatedAt).toBe(record.createdAt);
  });

  it("keeps extraction queries for each language", () => {
    const record = createHistoryRecord({
      content: '{"items":[{"id":1}]}',
      extraction: {
        mode: "jsonpath",
        queries: {
          javascript: "data.items.map((item) => item.id)",
          jsonpath: "$.items[*].id",
        },
      },
    });

    expect(record.extraction.mode).toBe("jsonpath");
    expect(record.extraction.queries.javascript).toBe(
      "data.items.map((item) => item.id)",
    );
    expect(record.extraction.queries.jsonpath).toBe("$.items[*].id");
  });

  it("fills missing extraction query defaults", () => {
    const extraction = createHistoryExtractionState({
      queries: {
        jsonpath: "$.items[*].id",
      },
    });

    expect(extraction).toEqual({
      mode: "javascript",
      queries: {
        javascript: "data",
        jsonpath: "$.items[*].id",
      },
    });
  });

  it("sorts pinned records first and newer records ahead of older ones", () => {
    const older = {
      id: "older",
      title: "older",
      content: "{}",
      extraction: createHistoryExtractionState(),
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
      extraction: createHistoryExtractionState({
        mode: "jsonpath",
        queries: {
          jsonpath: "$.updated",
        },
      }),
      updatedAt: "2026-04-12T12:00:00.000Z",
    };

    const result = upsertHistoryRecord([base], updated);

    expect(result).toHaveLength(1);
    expect(result[0]?.content).toContain("updated");
    expect(result[0]?.extraction.mode).toBe("jsonpath");
    expect(result[0]?.extraction.queries.jsonpath).toBe("$.updated");
  });
});
