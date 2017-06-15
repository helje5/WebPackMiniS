//
//  JSLoader.swift
//  WebPackS
//
//  Created by Helge Hess on 11/06/17.
//  Copyright © 2017 ZeeZide GmbH. All rights reserved.
//

import Foundation

/**
 * Replace 'require' statements, wrap in JS module.
 *
 * Maybe do some basic babeling.
 */
open class JSLoader : WebPackLoader {
  
  public struct Configuration {
    let excludeFilenames : [ String ]
    let stripComments    = true
    let compactSpaces    = true
  }
  
  let config : Configuration
  
  public init(configuration: Configuration) {
    self.config = configuration
  }
  
  public required convenience init(options: [ String : Any ]) {
    // TODO: parse options
    let config =  Configuration(excludeFilenames: [ "node_modules" ])
    self.init(configuration: config)
  }
  
  open func load(_ data: Data, in context: LoaderContext) throws -> Data {
    let url    = context.currentFileURL
    var tokens = JavaScriptTokenizer.parseData(data, url: url)
    
    var modCount = 0
    
    if config.stripComments {
      tokens = tokens
        .filter {
          if case .mlComment = $0 { modCount += 1; return false }
          return true
        }
        .map {
          guard case .slComment = $0 else { return $0 }
          modCount += 1
          return .linebreaks(Data([10]))
        }
    }
    if config.compactSpaces {
      for i in 0..<tokens.count {
        guard case .spaces(let spaces) = tokens[i] else { continue }
        guard spaces.count > 1                     else { continue }
        tokens[i] = .spaces(oneSpace)
        modCount += 1
      }
    }
    
    var i = 0
    while i < tokens.count {
      if let require = tokens.matchRequireCall(i) {
        // require ( qstring ) => __webpack_require__ ( qstring )
        i = require.nextIndex
        guard !require.module.isEmpty else { continue }
        
        // TODO: WebPack also supports some expressions
        //         ("templates" + name + ".jade") will load all *.jade
        guard let slot =
                    try? context.slotForModule(require.module, relativeTo: url)
         else { continue }
        
        tokens[require.idRequire] = .id(idWebpackRequire)
        tokens[require.qsModule]  = .number(Data("\(slot)".utf8))
        modCount += 1
      }
      else if let impstmt = tokens.matchImportCall(i) {
        i = impstmt.nextIndex
        guard !impstmt.module.isEmpty else { continue }
        
        guard let slot =
                    try? context.slotForModule(impstmt.module, relativeTo: url)
         else { continue }
        
        if let _ = impstmt.idVariable, let from = impstmt.kwFrom {
          // import <id> from qstring => var <id> = __webpack_require__ ( qstring )
          tokens[impstmt.kwImport]   = .keyword(Data("var".utf8))
          tokens[from]               = .op(opAssign)
          tokens[impstmt.qsModule]   = // hack
                               .other(Data("__webpack_require__(\(slot))".utf8))
        }
        else {
          // import qstring => __webpack_require__ ( qstring )
          tokens[impstmt.kwImport]   = .id(idWebpackRequire)
          tokens[impstmt.qsModule]   = .other(Data("(\(slot))".utf8)) // hack
        }
          
        modCount += 1
      }
      else if let expstmt = tokens.matchExport(i) {
        // export default sum => module.exports = sum
        // export default { ... tons of stuff ... } => module.exports = {...}
        i = expstmt.nextIndex
        
        tokens[expstmt.kwExport]  = .other(Data("module.exports".utf8)) // hack
        tokens[expstmt.kwDefault] = .op(opAssign)
        
        modCount += 1
      }
      else {
        i += 1
      }
    }
    
    // strip leading/trailing spaces
    if tokens.count > 0 {
      if case .linebreaks = tokens[0] {
        tokens.removeFirst()
        modCount += 1
      }
    }
    if tokens.count > 0 {
      if case .linebreaks = tokens[tokens.count - 1] {
        tokens.removeLast()
        modCount += 1
      }
    }
    
    // generate
    
    let newJS = tokens.javaScriptData
    // log.trace("JS:-----\n" + newJS.string + "\n-----")
    
    return newJS
  }
}

fileprivate let oneSpace         = Data([ 32 ])
fileprivate let opAssign         = Data("=".utf8)
fileprivate let idRequire        = Data("require".utf8)
fileprivate let idWebpackRequire = Data("__webpack_require__".utf8)
fileprivate let kwImport         = Data("import".utf8)
fileprivate let kwExport         = Data("export".utf8)
fileprivate let kwDefault        = Data("default".utf8)
fileprivate let kwFrom           = Data("from".utf8)

fileprivate struct RequireMatch<Index> {
  let idRequire   : Index
  let qsModule    : Index
  let module      : String
  let nextIndex   : Index
}

fileprivate struct ImportMatch<Index> {
  let kwImport    : Index
  let idVariable  : Index?
  let id          : String?
  let kwFrom      : Index?
  let qsModule    : Index
  let module      : String
  let nextIndex   : Index
}

fileprivate struct ExportMatch<Index> {
  
  let kwExport    : Index
  let kwDefault   : Index
  let idVariable  : Index?
  let id          : String?
  
  let nextIndex   : Index
}

fileprivate extension Collection
                        where Iterator.Element == JavaScriptTokenizer.Token
{
  func matchExport(_ idx: Index) -> ExportMatch<Index>? {
    // https://developer.mozilla.org/de/docs/Web/JavaScript/Reference/Statements/export
    // export default sum;
    // export default { ... tons of stuff ... };
    guard idx < endIndex                                  else { return nil }
    
    var pos = idx
    guard case .keyword(let v) = self[pos], v == kwExport else { return nil }
    
    let kwExportIdx = pos
    pos = index(after: pos) // skip export
    
    pos = skipSpacesAndComments(pos)
    guard case .keyword(let v2) = self[pos], v2 == kwDefault else { return nil }
    let kwDefaultIdx = pos
    pos = index(after: pos) // skip export
    
    pos = skipSpacesAndComments(pos)
    
    var idVariable : Index?  = nil
    var id         : String? = nil
    if case .id(let idv) = self[pos] {
      idVariable = pos
      id         = idv.string
      pos = index(after: pos)
    }
    else if case .lbrace = self[pos] {
      // - I think we just need to count/balance the { braces }
      pos = index(after: pos)
      var braceCount = 1
      while braceCount > 0 && pos < endIndex {
        if      case .lbrace = self[pos] { braceCount += 1}
        else if case .rbrace = self[pos] { braceCount -= 1}
        pos = index(after: pos)
      }
      if braceCount > 0 {
        //console.warn("unbalanced braces ...")
        return nil
      }
    }
    // TODO: else: export default function bar() {}
    else {
      //console.warn("unexpected export token:", self[pos])
      return nil
    }
    
    return ExportMatch(kwExport   : kwExportIdx,
                       kwDefault  : kwDefaultIdx,
                       idVariable : idVariable,
                       id         : id,
                       nextIndex  : pos)
  }
  
  // match: import <id> from qstring
  func matchImportCall(_ idx: Index) -> ImportMatch<Index>? {
    guard idx < endIndex                                  else { return nil }
    
    var pos = idx
    guard case .keyword(let v) = self[pos], v == kwImport else { return nil }
    let kwImportIdx = pos
    pos = index(after: pos) // skip import
    
    var idVariable : Index?  = nil
    var id         : String? = nil
    var kwFromIdx  : Index?  = nil
    
    pos = skipSpacesAndComments(pos)
    if case .id(let idv) = self[pos] {
      idVariable = pos
      id = idv.string
      pos = index(after: pos)
      
      // Not a reserved word, hm
      pos = skipSpacesAndComments(pos)
      guard case .id(let v2) = self[pos], v2 == kwFrom else { return nil }
      kwFromIdx = pos
      pos = index(after: pos)
    }
    
    pos = skipSpacesAndComments(pos)
    guard case .qstring(_, let module) = self[pos] else { return nil }
    let qsModule = pos
    pos = index(after: pos)
    
    return ImportMatch(kwImport   : kwImportIdx,
                       idVariable : idVariable,
                       id         : id,
                       kwFrom     : kwFromIdx,
                       qsModule   : qsModule,
                       module     : module.string,
                       nextIndex  : pos)
  }
  
  // match: require ( qstring )
  func matchRequireCall(_ idx: Index) -> RequireMatch<Index>? {
    guard idx < endIndex               else { return nil }
    guard case .id(let id) = self[idx] else { return nil }
    guard id == idRequire              else { return nil }
    
    let rqidx = idx
    var pos   = idx
    
    pos = index(after: pos) // skip require
    
    pos = skipSpacesAndComments(pos)
    guard case .lparen = self[pos] else { return nil }
    pos = index(after: pos)
    
    pos = skipSpacesAndComments(pos)
    guard case .qstring(_, let value) = self[pos] else { return nil }
    let sidx = pos
    pos = index(after: pos)
    
    pos = skipSpacesAndComments(pos)
    guard case .rparen = self[pos] else { return nil }
    pos = index(after: pos)
    
    return RequireMatch(idRequire: rqidx, qsModule: sidx, module: value.string,
                        nextIndex: pos)
  }
  
  func skipSpacesAndComments(_ posa: Index) -> Index {
    var pos = posa
    while pos < endIndex {
      switch self[pos] {
        case .mlComment, .slComment, .spaces, .linebreaks:
          break
        default:
          return pos
      }
      
      pos = index(after: pos)
    }
    return pos
  }
  
}
