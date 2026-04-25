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

export function formatPastedJson(input: string): string {
  const formatted = formatJson(input, "pretty");
  return formatted.ok ? formatted.output : input;
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
