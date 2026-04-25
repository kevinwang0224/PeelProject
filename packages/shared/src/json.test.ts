import { describe, expect, it } from "vitest";

import {
  formatJson,
  formatPastedJson,
  summarizeJson,
  validateJson,
} from "./json";

describe("json helpers", () => {
  it("formats valid json in pretty mode", () => {
    const result = formatJson('{"name":"Peel","items":[1,2]}', "pretty");

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.output).toContain("\n");
      expect(result.output).toContain('"name"');
    }
  });

  it("reports validation issues with location", () => {
    const issue = validateJson('{\n  "name": "Peel"\n  "broken": true\n}');

    expect(issue?.line).toBe(3);
    expect(issue?.message).toContain("Comma");
  });

  it("summarizes valid json accurately", () => {
    const summary = summarizeJson(
      '{"user":{"name":"Peel"},"items":[{"id":1}]}',
    );

    expect(summary.isValid).toBe(true);
    expect(summary.rootType).toBe("Object");
    expect(summary.keyCount).toBe(4);
  });

  it("keeps invalid pasted content unchanged", () => {
    expect(formatPastedJson("{oops")).toBe("{oops");
  });
});
