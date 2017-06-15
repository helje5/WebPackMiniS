//
//  WebPackLoader.swift
//  WebPackMiniS
//
//  Created by Helge Hess on 15/06/17.
//  Copyright © 2017 ZeeZide GmbH. All rights reserved.
//

import Foundation

// MARK: - Loaders

public protocol LoaderContext {
  
  var  currentFileURL : URL? { get }
  
  func slotForModule(_ module: String, relativeTo url: URL?) throws -> Int
  func slotForScript(_ script: Data) -> Int?
  
}

public protocol WebPackLoader {
  
  init(options: [ String : Any ])
  
  func load(_ data: Data, in context: LoaderContext) throws -> Data
  
}

public enum LoaderError : Swift.Error {
  case TODO(String)
}
