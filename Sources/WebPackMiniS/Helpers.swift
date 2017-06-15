//
//  Helpers.swift
//  WebPackMiniS
//
//  Created by Helge Hess on 15/06/17.
//  Copyright © 2017 ZeeZide GmbH. All rights reserved.
//

import Foundation

extension Data {
  mutating func add(_ s: String) {
    self.append(contentsOf: s.utf8)
  }
}
