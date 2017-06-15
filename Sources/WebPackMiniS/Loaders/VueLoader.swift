//
//  VueLoader.swift
//  WebPackS
//
//  Created by Helge Hess on 11/06/17.
//  Copyright © 2017 ZeeZide GmbH. All rights reserved.
//

import Foundation

// Use libxml2/XMLDocument to load the HTML?
open class VueLoader : WebPackLoader {
  
  public init() {
  }
  
  public required convenience init(options: [ String : Any ]) {
    self.init()
  }
  
  open func load(_ data: Data, in context: LoaderContext) throws -> Data {
    guard let s = String(data: data, encoding: .utf8) else { return data }
    
    // TODO: reserve slot for URL to avoid cycles?
    
    let template = s.extractContentInTag("<template>")
    let script   = s.extractContentInTag("<script>")
    let style    = s.extractContentInTag("<style>")
    
    let NL         = "" // use "\n" for debugging
    var scriptSlot : Int? = nil
    var styleSlot  : Int? = nil
    
    if let script = script, !script.isEmpty {
      // TODO: lookup the loader somehow
      let loader = JSLoader(options: [:])
      let data   = try loader.load(Data(script.utf8), in: context)
      scriptSlot = context.slotForScript(data)
    }
    
    if let style = style, !style.isEmpty {
      let loader = StyleLoader()
      let data   = try loader.load(Data(style.utf8), in: context)
      styleSlot = context.slotForScript(data)
    }
    
    var data = Data()
    data.reserveCapacity(512)
    
    if let style = styleSlot {
      data.add("__webpack_require__(\(style));" + NL)
    }
    
    if let script = scriptSlot {
      data.add("module.exports = __webpack_require__(\(script));" + NL)
    }
    else {
      data.add("module.exports = {};\n")
    }
    
    if let template = template {
      var tesc = template.replacingOccurrences(of: "'", with: "\\'")
      tesc = tesc.replacingOccurrences(of: "\n", with: "\\n")
      data.add("module.exports.template = '");
      data.add(tesc)
      data.add("';" + NL)
    }
    
    return data
  }
}

extension String {
  
  func extractContentInTag(_ tag: String) -> String? {
    let etag = tag.replacingOccurrences(of: "<", with: "</")
    
    guard let sr = self.range(of: tag), let er = self.range(of: etag)
     else { return nil }
    
    guard sr.upperBound < er.lowerBound else { return nil }
    
    var sidx = sr.upperBound
    while sidx < er.lowerBound && (self[sidx] == " " || self[sidx] == "\n") {
      sidx = self.index(after: sidx)
    }
    
    return self.substring(with: sidx..<er.lowerBound)
  }
  
}
