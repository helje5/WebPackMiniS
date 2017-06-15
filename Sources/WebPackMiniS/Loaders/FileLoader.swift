//
//  FileLoader.swift
//  WebPackS
//
//  Created by Helge Hess on 11/06/17.
//  Copyright © 2017 ZeeZide GmbH. All rights reserved.
//

import Foundation

/**
 * A file loader pushes the file into the external files section of the pack,
 * instead of embedding the file.
 */
open class FileLoader : WebPackLoader {
  
  public struct Configuration {
    let name : String
  }
  
  let config : Configuration
  
  public init(configuration: Configuration) {
    self.config = configuration
  }
  
  public required convenience init(options: [ String : Any ]) {
    // TODO: parse options
    let config =  Configuration(name: "[name].[ext]?[hash]")
    self.init(configuration: config)
  }
  
  open func load(_ data: Data, in context: LoaderContext) throws -> Data {
    throw LoaderError.TODO(#function)
  }
}

