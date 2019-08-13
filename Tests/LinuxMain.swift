import XCTest

@testable import WebPackMiniSTests

let tests = [
  testCase(JavaScriptTokenizerTests.allTests),
  testCase(PackingTests.allTests),
]

XCTMain(tests)
