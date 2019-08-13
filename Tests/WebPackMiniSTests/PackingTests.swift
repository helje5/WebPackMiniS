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

class PackingTests: XCTestCase {
  
  var testDirURL : URL = {
    let env        = ProcessInfo.processInfo.environment
    let fm         = FileManager.default
    let srcroot    = env["APACHE_MODULE_SRCROOT"] ?? fm.currentDirectoryPath
    let srcURL     = URL(fileURLWithPath: srcroot, isDirectory: true)
    return URL(fileURLWithPath: "wpstest", isDirectory: true,
               relativeTo: srcURL)
  }()
  
  let verbose = true
  
  func testTestDirURL() {
    print("dir: \(testDirURL)")
  }
  
  func XXtestWebPackTest2() throws {
    let url = URL(fileURLWithPath: "test2", relativeTo: testDirURL)
    let wps = WebPack(path: url.path)
    
    try wps.regenerate()
  }
  
  func XXtestWebPackTest5Vue() throws {
    let url = URL(fileURLWithPath: "test5", relativeTo: testDirURL)
    let wps = WebPack(path: url.path)
    
    try wps.regenerate()
  }

  static var allTests = [
    ( "testTestDirURL", testTestDirURL )
  ]
}
