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
    // Note: using `Data` for this in 3.0.2 was extremely slow

    let count = data.count
    
    var capacity = count + 12
    var dest = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
    var pos  = 0
    
    // print("generate data #\(count) \(Date())")
    
    func realloc(_ p: UnsafeMutablePointer<UInt8>,
                 oldCapacity: Int, newCapacity: Int)
         -> UnsafeMutablePointer<UInt8>
    {
      assert(oldCapacity < newCapacity)
      var newDest = UnsafeMutablePointer<UInt8>.allocate(capacity: newCapacity)
      newDest.initialize(from: p, count: oldCapacity)
      p.deallocate(capacity: oldCapacity)
      return newDest
    }
    
    for c in "var css = '".utf8 {
      dest[pos] = c
      pos += 1
    }
    
    
    // still super-slow, maybe it is the add
    data.withUnsafeBytes { (p : UnsafePointer<UInt8>) -> Void in
      var ptr = p
      for _ in 0..<count {
        if (pos + 2) >= capacity {
          let newCapacity = capacity + 512
          dest = realloc(dest, oldCapacity: capacity, newCapacity: newCapacity)
          capacity = newCapacity
        }
        
        switch ptr.pointee {
          case 92 /* \ */, 39 /* ' */:
            dest[pos] = 92;          pos += 1 /* \ */
            dest[pos] = ptr.pointee; pos += 1
          case 10:
            dest[pos] = 92;          pos += 1 /* \ */
            dest[pos] = 110;         pos += 1 /* n */
          case 13:
            dest[pos] = 92;          pos += 1 /* \ */
            dest[pos] = 114;         pos += 1 /* r */
          default:
            dest[pos] = ptr.pointee; pos += 1
        }
        ptr += 1
      }
    }
    // print("generated data \(Date()).")
    
    // TODO: copies, keep the stuff
    var js = Data(buffer: UnsafeBufferPointer(start: dest, count: pos))
    dest.deallocate(capacity: capacity)
    
    // TODO: add to buffer to avoid reallocs
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
