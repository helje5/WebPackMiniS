//
//  Tests.swift
//  Tests
//
//  Created by Helge Hess on 12/06/17.
//  Copyright © 2017 ZeeZide GmbH. All rights reserved.
//

import Foundation
import XCTest
@testable import WebPackMiniS

class JavaScriptTokenizerTests: XCTestCase {
  
  var testDirURL : URL = {
    let env        = ProcessInfo.processInfo.environment
    let fm         = FileManager.default
    let srcroot    = env["APACHE_MODULE_SRCROOT"] ?? fm.currentDirectoryPath
    let srcURL     = URL(fileURLWithPath: srcroot, isDirectory: true)
    return URL(fileURLWithPath: "wpstest", isDirectory: true,
               relativeTo: srcURL)
  }()
  
  let verbose = true
  
  func testJavaScriptParser() {
    let js = "var multiply = require('./multiply');"
    let data = Data(js.utf8)
    let tokens = JavaScriptTokenizer.parseData(data)
    
    if verbose {
      print("JS: \(js)")
      print("TOKENS:-----")
      for token in tokens {
        print("  \(token)")
      }
      print("------------")
    }
    
    let genData = tokens.javaScriptData
    XCTAssertEqual(data, genData)
  }
  
  func testTestDirURL() {
    print("dir: \(testDirURL)")
  }
  
  func XXtestTest2Index() throws {
    let url = URL(fileURLWithPath: "test2/src/index.js", relativeTo: testDirURL)
    let data = try Data(contentsOf: url)
    let tokens = JavaScriptTokenizer.parseData(data)
    
    if verbose {
      print("TOKENS:-----")
      for token in tokens {
        print("  \(token)")
      }
      print("------------")
    }
    
    let genData = tokens.javaScriptData
    XCTAssertEqual(data, genData)
  }
  
  func testRegex3() {
    let js = "var listDelimiter = /;(?![^(]*\\))/g;\nvar"
    let data = Data(js.utf8)
    let tokens = JavaScriptTokenizer.parseData(data)
    
    if verbose {
      print("TOKENS:-----")
      for token in tokens {
        print("  \(token)")
      }
      print("------------")
    }
    var pos = 0
    
    guard case .keyword = tokens[pos] else { XCTAssert(false); return }
    pos += 1
    
    guard case .spaces = tokens[pos] else { XCTAssert(false); return }
    pos += 1
    
    guard case .id = tokens[pos] else { XCTAssert(false); return }
    pos += 1
    
    guard case .spaces = tokens[pos] else { XCTAssert(false); return }
    pos += 1
    
    guard case .op(let v) = tokens[pos], v[0] == 61 /*=*/
     else { XCTAssert(false, "\(tokens[pos])"); return }
    pos += 1
    
    guard case .spaces = tokens[pos] else { XCTAssert(false); return }
    pos += 1
    
    guard case .regex = tokens[pos]
     else { XCTAssert(false, "\(tokens[pos])"); return }
    pos += 1
    
    guard case .semicolon = tokens[pos]
     else { XCTAssert(false, "\(tokens[pos])"); return }
    pos += 1
  }
  
  func testRegex2() {
    // contains a slash in the group
    let js = "var match = file.match(/([^/\\\\]+)\\.vue$/);"
    
    let data = Data(js.utf8)
    let tokens = JavaScriptTokenizer.parseData(data)
    
    if verbose {
      print("TOKENS:-----")
      for token in tokens {
        print("  \(token)")
      }
      print("------------")
    }
    var pos = 0
    
    guard case .keyword = tokens[pos] else { XCTAssert(false); return }
    pos += 1
    
    guard case .spaces = tokens[pos] else { XCTAssert(false); return }
    pos += 1
    
    guard case .id = tokens[pos] else { XCTAssert(false); return }
    pos += 1
    
    guard case .spaces = tokens[pos] else { XCTAssert(false); return }
    pos += 1
    
    guard case .op(let v) = tokens[pos], v[0] == 61 /*=*/
     else { XCTAssert(false, "\(tokens[pos])"); return }
    pos += 1
    
    guard case .spaces = tokens[pos] else { XCTAssert(false); return }
    pos += 1
    
    guard case .id = tokens[pos] else { XCTAssert(false); return }
    pos += 1
    
    guard case .op(let v2) = tokens[pos], v2[0] == 46 /*.*/
     else { XCTAssert(false, "\(tokens[pos])"); return }
    pos += 1
    
    guard case .id = tokens[pos] else { XCTAssert(false); return }
    pos += 1
    
    guard case .lparen = tokens[pos] else { XCTAssert(false); return }
    pos += 1
    
    guard case .regex = tokens[pos]
     else { XCTAssert(false, "\(tokens[pos])"); return }
    pos += 1
    
    guard case .rparen = tokens[pos]
     else { XCTAssert(false, "\(tokens[pos])"); return }
    pos += 1
    
    guard case .semicolon = tokens[pos]
     else { XCTAssert(false, "\(tokens[pos])"); return }
    pos += 1
  }
  
  func testTokenizeMainJS() {
    let js = "import Vue from 'vue'\n" +
             "import App from './App.vue'\n" +
             "\n"
    let data = Data(js.utf8)
    let tokens = JavaScriptTokenizer.parseData(data)
    
    if verbose {
      print("TOKENS:-----")
      for token in tokens {
        print("  \(token)")
      }
      print("------------")
    }
  }
  
  func testRegex() {
    let js   = "var camelizeRE = /-(\\w)/g;\nvar camelize = "
    let data = Data(js.utf8)
    let tokens = JavaScriptTokenizer.parseData(data)
    
    if verbose {
      print("TOKENS:-----")
      for token in tokens {
        print("  \(token)")
      }
      print("------------")
    }
    var pos = 0
    
    guard case .keyword = tokens[pos] else { XCTAssert(false); return }
    pos += 1
    
    guard case .spaces = tokens[pos] else { XCTAssert(false); return }
    pos += 1
    
    guard case .id = tokens[pos] else { XCTAssert(false); return }
    pos += 1
    
    guard case .spaces = tokens[pos] else { XCTAssert(false); return }
    pos += 1
    
    guard case .op(let v) = tokens[pos], v[0] == 61 /*=*/
     else { XCTAssert(false, "\(tokens[pos])"); return }
    pos += 1
    
    guard case .spaces = tokens[pos] else { XCTAssert(false); return }
    pos += 1
    
    guard case .regex = tokens[pos]
     else { XCTAssert(false, "\(tokens[pos])"); return }
    pos += 1
    
    guard case .semicolon = tokens[pos]
     else { XCTAssert(false, "\(tokens[pos])"); return }
    pos += 1
    
    guard case .linebreaks = tokens[pos] else { XCTAssert(false); return }
    pos += 1
    
    guard case .keyword = tokens[pos] else { XCTAssert(false); return }
    pos += 1
    
    guard case .spaces = tokens[pos] else { XCTAssert(false); return }
    pos += 1
    
    guard case .id = tokens[pos] else { XCTAssert(false); return }
    pos += 1
  }

  func XXtestTokenizeVue() throws {
    let url = URL(fileURLWithPath: "test5/node_modules/vue/dist/vue.js",
                  relativeTo: testDirURL)
    let data = try Data(contentsOf: url)
    let tokens = JavaScriptTokenizer.parseData(data)
    
    if verbose {
      print("TOKENS:-----")
      for token in tokens {
        print("  \(token)")
      }
      print("------------")
    }
    
    let genData = tokens.javaScriptData
    XCTAssertEqual(data, genData)
  }
  
  static var allTests = [
    ( "testJavaScriptParser", testJavaScriptParser ),
    ( "testTestDirURL",       testTestDirURL       ),
    ( "testRegex3",           testRegex3           ),
    ( "testRegex2",           testRegex2           ),
    ( "testTokenizeMainJS",   testTokenizeMainJS   ),
    ( "testRegex",            testRegex            ),
  ]
}
