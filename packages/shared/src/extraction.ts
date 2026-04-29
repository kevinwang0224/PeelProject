import { JSONPath } from "jsonpath-plus";

import { prettyPrintJsonValue } from "./json";
import type { ExtractionRequest, ExtractionResult } from "./types";

export async function runExtraction(
  request: ExtractionRequest,
): Promise<ExtractionResult> {
  const query = request.query.trim();

  if (!query.length) {
    return {
      status: "error",
      title: "Expression Required",
      text: "Enter an expression to run.",
      displayStyle: "plainText",
    };
  }

  try {
    switch (request.mode) {
      case "javascript":
        return renderExtractionValue(
          await runJavaScriptQuery(query, request.data),
        );
      case "jsonpath":
        return renderJsonPathValue(query, request.data);
    }
  } catch (error) {
    return {
      status: "error",
      title: "Extraction Failed",
      text: error instanceof Error ? error.message : "Extraction failed.",
      displayStyle: "plainText",
    };
  }
}

async function runJavaScriptQuery(
  query: string,
  data: unknown,
): Promise<unknown> {
  const immutableData = deepFreeze(structuredClone(data));
  const evaluator = new Function(
    "data",
    '"use strict"; return (' + query + ");",
  );
  const value = evaluator(immutableData);
  return value instanceof Promise ? await value : value;
}

function renderJsonPathValue(query: string, data: unknown): ExtractionResult {
  const matches = JSONPath({
    path: query,
    json: data as string | number | boolean | object | unknown[] | null,
    wrap: true,
  }) as unknown[];

  if (!matches.length) {
    return {
      status: "empty",
      title: "No Result",
      text: "No result",
      displayStyle: "plainText",
    };
  }

  if (matches.length === 1) {
    return renderExtractionValue(matches[0]);
  }

  return renderExtractionValue(matches);
}

function renderExtractionValue(value: unknown): ExtractionResult {
  if (typeof value === "undefined") {
    return {
      status: "empty",
      title: "No Result",
      text: "No result",
      displayStyle: "plainText",
    };
  }

  if (typeof value === "function") {
    return {
      status: "success",
      title: "Result",
      text: `[Function${value.name ? `: ${value.name}` : ""}]`,
      displayStyle: "plainText",
    };
  }

  if (typeof value === "symbol") {
    return {
      status: "success",
      title: "Result",
      text: String(value),
      displayStyle: "plainText",
    };
  }

  if (typeof value === "bigint") {
    return {
      status: "success",
      title: "Result",
      text: `${value.toString()}n`,
      displayStyle: "plainText",
    };
  }

  if (value === null) {
    return {
      status: "success",
      title: "Result",
      text: "null",
      displayStyle: "plainText",
    };
  }

  if (
    typeof value === "string" ||
    typeof value === "number" ||
    typeof value === "boolean"
  ) {
    return {
      status: "success",
      title: "Result",
      text: String(value),
      displayStyle: "plainText",
    };
  }

  return {
    status: "success",
    title: "Result",
    text: prettyPrintJsonValue(value),
    displayStyle: "structuredJson",
  };
}

function deepFreeze<T>(value: T): T {
  if (Array.isArray(value)) {
    value.forEach((item) => deepFreeze(item));
    return Object.freeze(value);
  }

  if (value && typeof value === "object") {
    Object.values(value).forEach((item) => deepFreeze(item));
    return Object.freeze(value);
  }

  return value;
}
