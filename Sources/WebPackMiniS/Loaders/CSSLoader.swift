//
//  CSSLoader.swift
//  WebPackS
//
//  Created by Helge Hess on 13.06.17.
//  Copyright © 2017 ZeeZide GmbH. All rights reserved.
//

import Foundation

open class CSSLoader : WebPackLoader {
  // TODO: process @import statements in CSS
  // e.g.: @import url("../node_modules/semantic-ui-css/semantic.min.css");
  
  public init() {
  }
  
  public required convenience init(options: [ String : Any ]) {
    self.init()
  }
  
  open func load(_ data: Data, in context: LoaderContext) throws -> Data {
    // no-op for now
    return data
  }
}

open class StyleLoader : WebPackLoader {
  
  public init() {
  }
  
  public required convenience init(options: [ String : Any ]) {
    self.init()
  }
  
  open func load(_ data: Data, in context: LoaderContext) throws -> Data {
    // convert to JavaScript which loads the CSS
    
    var js = Data()
    js.reserveCapacity(data.count + 512)
    js.add("var css = '")
    for b in data { // FIXME: urks, slow. Or is it?
      switch b {
        case 92 /* \ */, 39 /* ' */:
          js.append(92) /* \ */
          js.append(b)
        case 10:
          js.add("\\n")
        case 13:
          js.add("\\r")
        default:
          js.append(b)
      }
    }
    js.add("';\n")
    js.add("var h = document.head || document.getElementsByTagName('head')[0];")
    js.add("\nvar s = document.createElement('style');")
    js.add("\ns.type = 'text/css';")
    js.add("\nif (s.stylesheet) { ")
    js.add("s.styleSheet.cssText = css;")
    js.add(" } else { ")
    js.add("s.appendChild(document.createTextNode(css));")
    js.add(" }")
    js.add("\nh.appendChild(s);")
    
    return js
  }
}
