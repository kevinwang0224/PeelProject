import {
  getLocation,
  parse,
  printParseErrorCode,
  type ParseError,
} from "jsonc-parser";

import type { JsonValidationIssue } from "./types";

export type JsonFormatStyle = "pretty" | "compact";
export type JsonRootType =
  | "Empty"
  | "Object"
  | "Array"
  | "String"
  | "Number"
  | "Boolean"
  | "Null"
  | "Invalid";

export interface JsonSummary {
  isValid: boolean;
  issue: JsonValidationIssue | null;
  rootType: JsonRootType;
  keyCount: number;
  byteSize: number;
}

export function validateJson(input: string): JsonValidationIssue | null {
  if (!input.trim().length) {
    return null;
  }

  const errors: ParseError[] = [];
  parse(input, errors, {
    allowTrailingComma: false,
    disallowComments: true,
  });

  if (!errors.length) {
    return null;
  }

  const firstError = errors[0];
  const location = getLineColumn(input, firstError.offset);

  return {
    message: humanizeParseError(firstError),
    line: location.line,
    column: location.column,
    offset: firstError.offset,
    length: Math.max(firstError.length, 1),
  };
}

export function tryParseJson(input: string): {
  value: unknown | null;
  issue: JsonValidationIssue | null;
} {
  const issue = validateJson(input);

  if (issue) {
    return { value: null, issue };
  }

  if (!input.trim().length) {
    return { value: null, issue: null };
  }

  return {
    value: JSON.parse(input),
    issue: null,
  };
}

export function formatJson(
  input: string,
  style: JsonFormatStyle,
): { ok: true; output: string } | { ok: false; issue: JsonValidationIssue } {
  const { value, issue } = tryParseJson(input);

  if (issue || value === null) {
    return issue
      ? { ok: false, issue }
      : {
          ok: true,
          output: "",
        };
  }

  return {
    ok: true,
    output: JSON.stringify(value, null, style === "pretty" ? 2 : 0),
  };
}

export function prettyPrintJsonValue(value: unknown): string {
  return JSON.stringify(value, null, 2);
}

export function summarizeJson(input: string): JsonSummary {
  const issue = validateJson(input);

  if (issue) {
    return {
      isValid: false,
      issue,
      rootType: "Invalid",
      keyCount: 0,
      byteSize: byteSizeOf(input),
    };
  }

  if (!input.trim().length) {
    return {
      isValid: false,
      issue: null,
      rootType: "Empty",
      keyCount: 0,
      byteSize: 0,
    };
  }

  const value = JSON.parse(input);

  return {
    isValid: true,
    issue: null,
    rootType: detectRootType(value),
    keyCount: countKeys(value),
    byteSize: byteSizeOf(input),
  };
}

export function formatJsonInput(
  input: string,
  style: JsonFormatStyle,
): { ok: true; output: string } | { ok: false; issue: JsonValidationIssue } {
  const embedded = extractEmbeddedJson(input);
  return formatJson(embedded ?? input, style);
}

export function formatPastedJson(input: string): string {
  const embedded = extractEmbeddedJson(input);
  const formatted = formatJson(embedded ?? input, "pretty");
  return formatted.ok ? formatted.output : input;
}

/**
 * 检测被字符串化或反斜杠转义的 JSON 文本，并返回内层 JSON 源串。
 * 仅在能可靠还原为对象/数组时才返回，避免误伤普通字符串。
 */
function extractEmbeddedJson(input: string): string | null {
  const trimmed = input.trim();

  if (!trimmed.length) {
    return null;
  }

  const parsed = tryParseJson(trimmed);

  if (!parsed.issue) {
    // 形如 "{\"a\":1}" 的 JSON 字符串字面量，其内容本身是对象/数组。
    if (typeof parsed.value === "string") {
      const inner = tryParseJson(parsed.value.trim());

      if (!inner.issue && isObjectOrArray(inner.value)) {
        return JSON.stringify(inner.value);
      }
    }

    return null;
  }

  // 形如 {\"a\":1} 的转义文本（缺少外层引号），尝试按字符串内容解码。
  if (trimmed.includes('\\"')) {
    const decoded = decodeJsonStringBody(trimmed);

    if (decoded !== null) {
      const inner = tryParseJson(decoded.trim());

      if (!inner.issue && isObjectOrArray(inner.value)) {
        return JSON.stringify(inner.value);
      }
    }
  }

  return null;
}

function decodeJsonStringBody(body: string): string | null {
  try {
    const decoded = JSON.parse(`"${body}"`);
    return typeof decoded === "string" ? decoded : null;
  } catch {
    return null;
  }
}

function isObjectOrArray(value: unknown): boolean {
  return typeof value === "object" && value !== null;
}

function detectRootType(value: unknown): JsonRootType {
  if (Array.isArray(value)) {
    return "Array";
  }

  if (value === null) {
    return "Null";
  }

  switch (typeof value) {
    case "object":
      return "Object";
    case "string":
      return "String";
    case "number":
      return "Number";
    case "boolean":
      return "Boolean";
    default:
      return "Invalid";
  }
}

function countKeys(value: unknown): number {
  if (Array.isArray(value)) {
    return value.reduce<number>((total, item) => total + countKeys(item), 0);
  }

  if (value && typeof value === "object") {
    const entries = Object.values(value as Record<string, unknown>);
    return (
      Object.keys(value as Record<string, unknown>).length +
      entries.reduce<number>((total, item) => total + countKeys(item), 0)
    );
  }

  return 0;
}

function byteSizeOf(input: string): number {
  return new TextEncoder().encode(input).length;
}

function humanizeParseError(error: ParseError): string {
  const label = printParseErrorCode(
    error.error as Parameters<typeof printParseErrorCode>[0],
  );

  switch (label) {
    case "InvalidSymbol":
      return "Unexpected character";
    case "PropertyNameExpected":
      return "Property name expected";
    case "ValueExpected":
      return "Value expected";
    case "CommaExpected":
      return "Comma expected";
    case "ColonExpected":
      return "Colon expected";
    case "CloseBraceExpected":
      return "Closing brace expected";
    case "CloseBracketExpected":
      return "Closing bracket expected";
    case "EndOfFileExpected":
      return "Unexpected trailing content";
    default:
      return label.replace(/([a-z])([A-Z])/g, "$1 $2");
  }
}

function getLineColumn(
  input: string,
  offset: number,
): { line: number; column: number } {
  getLocation(input, offset);

  const content = input.slice(0, offset);
  const lines = content.split("\n");

  return {
    line: lines.length,
    column: (lines.at(-1)?.length ?? 0) + 1,
  };
}
