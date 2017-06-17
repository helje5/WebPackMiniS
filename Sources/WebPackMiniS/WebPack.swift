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
  
  public let config : Configuration
  
  public var resources = [ String : Data ]()
  var        modules   = [ Data ]()
  var        modulePathToIndex = [ String : Int ]()
  
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
      let fileURL = URL.resolve(fileURL: url, filePath: module)
      if fm.fileExists(atPath: fileURL.path) { return fileURL }
      
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
      return URL.resolve(fileURL: url, filePath: matches[0])
    }
    
    
    // TODO: I think we need to read package.json to determine the proper loc
    //   ./node_modules/vue/dist/vue.js
    // vs
    //   ./node_modules/moment/moment.js
    let nodeModuleDir = URL.resolve(fileURL: config.baseURL,
                                    filePath: "node_modules/")
    var pkgDir = nodeModuleDir
                   .appendingPathComponent(module)
                   .appendingPathComponent("dist")
    if !fm.fileExists(atPath: pkgDir.path) { // HACK
      pkgDir = nodeModuleDir.appendingPathComponent(module)
    }
    
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

    return URL.resolve(fileURL: pkgDir, filePath: choice)
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
  
  public func dataForFile(_ path: String) throws -> Data? {
    // TODO: directly stream
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
      entry   :   URL.resolve(fileURL: pathURL, filePath: entry),
      output  :   Output(path: pathURL.appendingPathComponent("dist").path,
                         publicPath: "dist/",
                         filename: "bundle.js"),
      moduleRules: [
        LoadRule(pathExtensions: ["vue"],
                 loader:  [ VueLoader.self ]),
        LoadRule(pathExtensions: ["js"],
                 loader:  [ JSLoader.self ],
                 options: [ "exclude": "/node_modules/" ]),
        LoadRule(pathExtensions: [ "png", "jpg", "gif", "svg", "eot", "ttf",
                                   "woff", "woff2" ],
                 loader:  [ FileLoader.self ],
                 options: [ "name": "[name].[ext]?[hash]" ]),
        LoadRule(pathExtensions: ["css"],
                 loader:  [ StyleLoader.self, CSSLoader.self ])
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
    
    public var baseURL     : URL
    public var entry       : URL
    public var output      : Output
    
    public var moduleRules : [ LoadRule ]
    
    public var resolvePathExtensionAliases : [ String : String ]
    
    public var devServer   : DevServerConfig
    
    // performance: { hints: false }
    // devtool:     '#eval-source-map'
    
    public init(baseURL     : URL,
                entry       : URL,
                output      : Output,
                moduleRules : [ LoadRule ] = [],
                resolvePathExtensionAliases : [ String : String ] = [:],
                devServer   : DevServerConfig = DevServerConfig())
    {
      self.baseURL     = baseURL
      self.entry       = entry
      self.output      = output
      self.moduleRules = moduleRules
      self.resolvePathExtensionAliases = resolvePathExtensionAliases
      self.devServer   = devServer
    }
  }
  
  public struct Output {
    public var path       : String
    public var publicPath : String
    public var filename   : String
    
    public init(path       : String,
                publicPath : String = "dist/",
                filename   : String = "build.js")
    {
      self.path       = path
      self.publicPath = publicPath
      self.filename   = filename
    }
  }
  
  public struct LoadRule {
    public var pathExtensions : [ String ]
                                   // in place of 'test' which takes a regex
    public var loader         : [ WebPackLoader.Type ]
    public var options        : [ String : Any ] = [ : ]
    
    public init(pathExtensions : [ String ],
                loader         : [ WebPackLoader.Type ],
                options        : [ String : Any ] = [ : ])
    {
      self.pathExtensions = pathExtensions
      self.loader         = loader
      self.options        = options
    }
    
    func matchesURL(_ url: URL) -> Bool {
      return pathExtensions.contains(url.pathExtension)
    }
  }
  
  public struct ResolveAlias {
    public var pathExtension : String
    
    public init(pathExtension: String = "vue") {
      self.pathExtension = pathExtension
    }
  }
  
  public struct DevServerConfig {
    public var historyApiFallback : Bool
    public var noInfo             : Bool
    
    public init(historyApiFallback: Bool = true, noInfo: Bool = true) {
      self.historyApiFallback = historyApiFallback
      self.noInfo             = noInfo
    }
  }
  
}


// MARK: - Compat

extension URL {
  static func resolve(fileURL url: URL?, filePath path: String) -> URL {
    #if swift(>=3.1) // This is really a `if #available(macOS 10.11, *)`
      return URL(fileURLWithPath: path, relativeTo: url)
    #else // Swift 3.0.2
      guard var url = url, !url.path.isEmpty, !path.hasPrefix("/")
       else { return URL(fileURLWithPath: path) }
      guard !path.isEmpty else { return url }
      
      // print("resolve \(path) against \(url.path as Optional)")
      
      // file:///abc/def/main.js
      // ./Vue
      
      // Funny: Even if the url ends in /, the path may not contain it
      if !url.absoluteString.hasSuffix("/") { // this is actually what happens
        // FIXME: should we check isDir in filesystem?
        url = url.deletingLastPathComponent()
      }
      
      var processedPath = path
      while processedPath.hasPrefix("../") {
        let idx = processedPath.index(processedPath.startIndex, offsetBy: 3)
        processedPath = processedPath.substring(from: idx)
        url = url.deletingLastPathComponent()
      }
      
      if processedPath.hasPrefix("./") {
        let idx = processedPath.index(processedPath.startIndex, offsetBy: 2)
        processedPath = processedPath.substring(from: idx)
      }
      
      let result = url.appendingPathComponent(processedPath)
      // print("  got: \(processedPath) \(result)")
      return result
    #endif
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
