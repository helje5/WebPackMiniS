//
//  WebPackS.swift
//  ApacheExpressAdmin
//
//  Created by Helge Hess on 11/06/17.
//  Copyright © 2017 ZeeZide GmbH. All rights reserved.
//

import class  Foundation.FileManager
import struct Foundation.URL
import struct Foundation.Data

public class WebPack : LoaderContext {
  
  let config : Configuration
  
  var resources = [ String : Data ]()
  var modules   = [ Data ]()
  var modulePathToIndex = [ String : Int ]()
  
  struct FileProcessingInfo {
    let url : URL
  }
  
  public enum Error : Swift.Error {
    case CouldNotLoadFile     (URL)
    case DidNotFindLoader     (URL)
    case FailedToLoad         (URL, Swift.Error)
    case CouldNotLoadDirectory(URL)
    case DidNotFindModule     (String)
  }
  
  var        processFileStack = [ FileProcessingInfo ]()
  public var currentFileURL   : URL? { return processFileStack.last?.url }
  
  // MARK: - Generate
  
  func regenerate() throws {
    resources.removeAll()
    modules.removeAll()
    modulePathToIndex.removeAll()
    
    let entryId = try processFile(config.entry)
    let script  = assembleModuleScript(entryId: entryId)
    resources[config.output.filename] = script
  }
  
  func assembleModuleScript(entryId: Int) -> Data {
    var script = Data()
    script.reserveCapacity(2048)
    
    // this is similar to what the real WebPack generates
    script.add("(function(modules) { // webpack bootstrap\n")
    script.append(bootstrapBody)
    script.add("  __webpack_require__.s = \(entryId);\n")
    script.add("  return __webpack_require__(__webpack_require__.s);\n")
    script.add("})")
    script.add("([\n")
    do {
      for i in 0..<modules.count {
        // TBD: should the wrapper be done in the jsloader?
        script.add("/* \(i) */\n")
        script.add("(function(module, exports, __webpack_require__) {\n")
        script.append(modules[i])
        script.add("}),\n") // are trailing commas allowed in JS?
      }
    }
    script.add("])\n")
    
    return script
  }
  
  func processFile(_ url: URL) throws -> Int {
    let fpi = FileProcessingInfo(url: url)
    processFileStack.append(fpi)
    defer { processFileStack.removeLast() }
    
    if let idx = modulePathToIndex[url.path] { // already processed
      return idx
    }
    
    guard let loader = loaderForURL(url), !loader.isEmpty
     else { throw Error.CouldNotLoadFile(url) }
    
    guard var data = try? Data(contentsOf: url)
     else { throw Error.CouldNotLoadFile(url) }
    
    modules.append(Data()) // just reserve the slot
    let idx = (modules.count - 1)
    modulePathToIndex[url.path] = idx
    
    for loader in loader.reversed() {
      do {
        data = try loader.load(data, in: self)
      }
      catch {
        throw Error.FailedToLoad(url, error)
      }
    }
    
    //log.trace("LOADED:-----\n" + data.string + "\n-----")
    
    modules[idx] = data
    return idx
  }
  
  func loaderForURL(_ url: URL) -> [ WebPackLoader ]? {
    for rule in config.moduleRules {
      guard rule.matchesURL(url) else { continue }
      
      return rule.loader.map { $0.init(options: rule.options) }
    }
    return nil
  }
  
  func lookupModule(_ module: String, relativeTo url: URL?) throws -> URL {
    let fm = FileManager.default
    
    if module.hasPrefix(".") {
      let fileURL = URL(fileURLWithPath: module, relativeTo: url)
      if fm.fileExists(atPath: module) { return fileURL }
      
      let dirURL = fileURL.deletingLastPathComponent()
      let fn     = fileURL.lastPathComponent
      
      guard let ls = try? fm.contentsOfDirectory(atPath: dirURL.path)
       else { throw Error.CouldNotLoadDirectory(dirURL) }
      
      let matches = ls.filter { $0.hasPrefix(fn) }
      guard !matches.isEmpty else { throw Error.DidNotFindModule(module) }
      
      #if false
      if matches.count > 1 {
        log.warn("multiple matches for module:", module, "in:", dirURL.path)
      }
      #endif
      return URL(fileURLWithPath: matches[0], relativeTo: url)
    }
    
    // ./node_modules/vue/dist/vue.js
    let nodeModuleDir = URL(fileURLWithPath: "node_modules",
                            relativeTo: config.baseURL)
    let pkgDir = nodeModuleDir
                   .appendingPathComponent(module)
                   .appendingPathComponent("dist")
    
    guard let ls = try? fm.contentsOfDirectory(atPath: pkgDir.path)
     else { throw Error.CouldNotLoadDirectory(pkgDir) }
    
    let matches = ls.filter { $0.hasPrefix(module + ".") }
    // console.log("MATCHES:", matches, pkgDir, module)
    guard !matches.isEmpty else { throw Error.DidNotFindModule(module) }
    
    #if false
    if matches.count > 1 {
      log.trace("multiple matches for module:", module, "in:", pkgDir.path,
                matches.joined(separator: ","))
    }
    #endif
    
    let choice : String
    if matches.contains(module + ".js") {
      choice = module + ".js"
    }
    else {
      choice = matches[0]
    }
    
    return URL(fileURLWithPath: choice, relativeTo: pkgDir)
  }
  
  public func slotForModule(_ module: String, relativeTo relurl: URL?)
                throws -> Int
  {
    // TBD: this is really a 'require'?
    let url = try lookupModule(module, relativeTo: relurl)
    
    let idx = try processFile(url)
    return idx
  }
  
  public func slotForScript(_ script: Data) -> Int? {
    modules.append(script)
    let idx = (modules.count - 1)
    return idx
  }
  
  // MARK: - Deliver
  
  func dataForFile(_ path: String) throws -> Data? { // TODO: directly stream
    try regenerate()
    return resources[path]
  }
  
  
  // MARK: - Init
  
  public init(configuration: Configuration) {
    self.config = configuration
  }
  
  public convenience init(path  : String =
                                    FileManager.default.currentDirectoryPath,
                          entry : String = "./src/index.js")
  {
    let pathURL = URL(fileURLWithPath: path, isDirectory: true)
    
    let config = Configuration(
      baseURL :   pathURL,
      entry   :   URL(fileURLWithPath: entry, relativeTo: pathURL),
      output  :   Output(path: pathURL.appendingPathComponent("dist").path,
                         publicPath: "dist/",
                         filename: "bundle.js"),
      moduleRules: [
        LoadRule(pathExtensions: ["vue"],
                 loader:  [ VueLoader.self ],
                 options: [:]),
        LoadRule(pathExtensions: ["js"],
                 loader:  [ JSLoader.self ],
                 options: [ "exclude": "/node_modules/" ]),
        LoadRule(pathExtensions: [ "png", "jpg", "gif", "svg", "eot", "ttf",
                                   "woff", "woff2" ],
                 loader:  [ FileLoader.self ],
                 options: [ "name": "[name].[ext]?[hash]" ]),
        LoadRule(pathExtensions: ["css"],
                 loader:  [ StyleLoader.self, CSSLoader.self ],
                 options: [:])
      ],
      resolvePathExtensionAliases: [
        "vue": "vue/dist/vue.esm.js"
      ],
      devServer: DevServerConfig()
    )
    
    self.init(configuration: config)
  }
  
  
  // MARK: - Configuration
  
  public struct Configuration {
    
    var baseURL        : URL
    var entry          : URL
    var output         : Output
    
    var moduleRules    : [ LoadRule ] = []
    
    var resolvePathExtensionAliases : [ String : String ] = [:]
    
    var devServer      = DevServerConfig()
    
    // performance: { hints: false }
    // devtool:     '#eval-source-map'
  }
  
  public struct Output {
    var path       : String
    var publicPath : String = "dist/"
    var filename   : String = "build.js"
  }
  
  public struct LoadRule {
    var pathExtensions : [ String ] // in place of 'test' which takes a regex
    var loader         : [ WebPackLoader.Type ]
    var options        : [ String : Any ] = [ : ]
    
    func matchesURL(_ url: URL) -> Bool {
      return pathExtensions.contains(url.pathExtension)
    }
  }
  
  public struct ResolveAlias {
    var pathExtension  : String = "vue" //
  }
  
  public struct DevServerConfig {
    let historyApiFallback = true
    let noInfo             = true
  }
  
}


// MARK: - Scripts

fileprivate let bootstrapBody : Data = {
  var script = Data()
  script.reserveCapacity(404)
  script.add("  var installedModules = {};\n")
  script.add("  function __webpack_require__(moduleId) {\n")
  script.add("    if (installedModules[moduleId]) {\n")
  script.add("      return installedModules[moduleId].exports;\n")
  script.add("    }\n")
  script.add("    var module = installedModules[moduleId] = {\n")
  script.add("      i: moduleId, l: false, exports: {}\n")
  script.add("    }\n")
  script.add("    modules[moduleId].call(module.exports,\n") // this
  script.add("      module, module.exports, __webpack_require__\n")
  script.add("    );\n")
  script.add("    module.l = true;")
  script.add("    return module.exports;")
  script.add("  }\n")
  script.add("  __webpack_require__.m = modules;\n")
  script.add("  __webpack_require__.c = installedModules;\n")
  return script
}()
