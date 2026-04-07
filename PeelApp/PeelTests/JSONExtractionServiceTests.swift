import XCTest
@testable import Peel

final class JSONExtractionServiceTests: XCTestCase {
    func testJavaScriptExtractionReturnsPrimitiveResult() {
        let input = """
        {
          "user": {
            "name": "Peel"
          }
        }
        """

        let result = JSONExtractionService.run(
            input: input,
            query: "data.user.name",
            mode: .javaScript
        )

        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.text, "Peel")
    }

    func testJavaScriptExtractionReportsExecutionError() {
        let input = """
        {
          "items": [1, 2, 3]
        }
        """

        let result = JSONExtractionService.run(
            input: input,
            query: "data.missing.call()",
            mode: .javaScript
        )

        XCTAssertEqual(result.status, .error)
    }

    func testJSONPathExtractionReturnsPrettyJSONArrayForMultipleMatches() {
        let input = """
        {
          "items": [
            { "id": 1 },
            { "id": 2 }
          ]
        }
        """

        let result = JSONExtractionService.run(
            input: input,
            query: "$.items[*].id",
            mode: .jsonPath
        )

        XCTAssertEqual(result.status, .success)
        XCTAssertTrue(result.text.contains("1"))
        XCTAssertTrue(result.text.contains("2"))
    }

    func testJSONPathExtractionSupportsRecursiveLookup() {
        let input = """
        {
          "user": {
            "name": "Peel"
          },
          "items": [
            {
              "name": "Formatter"
            }
          ]
        }
        """

        let result = JSONExtractionService.run(
            input: input,
            query: "$..name",
            mode: .jsonPath
        )

        XCTAssertEqual(result.status, .success)
        XCTAssertTrue(result.text.contains("Peel"))
        XCTAssertTrue(result.text.contains("Formatter"))
    }

    func testJSONPathExtractionReturnsNoResultWhenNothingMatches() {
        let input = """
        {
          "user": {
            "name": "Peel"
          }
        }
        """

        let result = JSONExtractionService.run(
            input: input,
            query: "$.user.age",
            mode: .jsonPath
        )

        XCTAssertEqual(result.status, .empty)
        XCTAssertEqual(result.text, "无结果")
    }

    func testPreparedInputCanBeReusedForJavaScriptExtraction() throws {
        let input = """
        {
          "user": {
            "name": "Peel",
            "age": 3
          }
        }
        """

        let preparedInput = try JSONExtractionService.prepare(input: input)
        let result = JSONExtractionService.run(
            preparedInput: preparedInput,
            query: "data.user.age",
            mode: .javaScript
        )

        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.text, "3")
        XCTAssertEqual(result.displayStyle, .plainText)
    }

    func testStructuredResultMarksStructuredDisplayStyle() {
        let input = """
        {
          "items": [
            { "id": 1 },
            { "id": 2 }
          ]
        }
        """

        let result = JSONExtractionService.run(
            input: input,
            query: "$.items[*]",
            mode: .jsonPath
        )

        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.displayStyle, .structuredJSON)
    }
}
