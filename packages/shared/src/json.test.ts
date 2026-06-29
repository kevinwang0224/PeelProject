import { describe, expect, it } from "vitest";

import {
  formatJson,
  formatJsonInput,
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

  it("formats normal valid json on paste", () => {
    const result = formatPastedJson('{"name":"Peel","items":[1,2]}');

    expect(result).toContain("\n");
    expect(result).toContain('"name"');
  });

  it("unwraps a string-wrapped json object on paste", () => {
    const result = formatPastedJson('"{\\"name\\":\\"Peel\\"}"');

    expect(result).toBe('{\n  "name": "Peel"\n}');
  });

  it("unwraps backslash-escaped json without outer quotes on paste", () => {
    const result = formatPastedJson('{\\"name\\":\\"Peel\\"}');

    expect(result).toBe('{\n  "name": "Peel"\n}');
  });

  it("unwraps a string-wrapped json array on paste", () => {
    const result = formatPastedJson('"[{\\"id\\":1}]"');

    expect(result).toBe('[\n  {\n    "id": 1\n  }\n]');
  });

  it("does not unwrap a plain json string", () => {
    expect(formatPastedJson('"hello"')).toBe('"hello"');
  });

  it("formatJsonInput unescapes then applies compact style", () => {
    const result = formatJsonInput('"{\\"name\\":\\"Peel\\"}"', "compact");

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.output).toBe('{"name":"Peel"}');
    }
  });

  it("formatJsonInput reports issues for invalid json", () => {
    const result = formatJsonInput("{oops", "pretty");

    expect(result.ok).toBe(false);
  });
});
