//
//  JavaScriptParser.swift
//  WebPackS
//
//  Created by Helge Hess on 11/06/17.
//  Copyright © 2017 ZeeZide GmbH. All rights reserved.
//

import struct Foundation.Data
import struct Foundation.URL


// MARK: - Simple Hackish JS Parser

/**
 * Simple Hackish JS Parser
 *
 *
 */
class JavaScriptTokenizer {
  // TODO: make it a Sequence or proper stream :-)
  // TODO: throw errors
  // Note: We generally keep stuff as Data as in our setup we usually want to
  //       write out the stuff again.
  // Proper Grammar:
  //   https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Lexical_grammar
  // TODO: binary and octal numbers. Simple: just use parseHexNumber
  // TODO: tagged template literals (backtick)
  
  static func parseFileAtURL(_ url: URL) -> [ Token ] {
    guard let utf8data = try? Data(contentsOf: url) else {
      print("could not load file:", url)
      return []
    }
    return parseData(utf8data, url: url)
  }
  
  static func parseData(_ data: Data, url: URL? = nil, scriptLine: Int? = 1)
              -> [ Token ]
  {
    let si     = SourceInfo(url: url, scriptLine: scriptLine)
    let parser = JavaScriptTokenizer(data: data, sourceInfo: si)
    parser.parse()
    return parser.tokens
  }
  
  struct SourceInfo {
    let url        : URL?
    let scriptLine : Int?
  }
  
  enum Token : CustomStringConvertible {
    case spaces    (Data)
    case linebreaks(Data)
    case qstring   (quote: UInt8, value: Data) // or template
    case regex     (Data)
    case mlComment (Data)
    case slComment (Data)
    case other     (Data)
    case op        (Data)
    case lparen, rparen, lbrack, rbrack, lbrace, rbrace, semicolon, colon, comma
    case id        (Data)
    case keyword   (Data)
    case number    (Data)
    
    var isRelevantForParsing : Bool {
      // FIXME: this is not entirely correct
      switch self {
        case .mlComment, .slComment, .spaces: return false
        default: return true
      }
    }
    
    var isBinaryOpLeft : Bool {
      // is this token a valid left for a binary operator like '/'?
      switch self {
        case .id, .keyword, .number, .qstring: // use operator
          return true
        // TBD: other
        default:
          return false
      }
    }

    var description : String {
      switch self {
        case .other     (let v): return "<Tok: OTHER \(v.string)>"
        case .regex     (let v): return "<Tok: re \(v.string)>"
        case .qstring   (let q, let v):
          let qs = UnicodeScalar(q)
          return "<Tok: qs \(qs)\(v.string)\(qs)>"
        
        case .spaces    (let v): return "<Tok: spaces #\(v.count)>"
        case .linebreaks(let v): return "<Tok: NL #\(v.count)>"
        case .mlComment (let v): return "<Tok: mlc #\(v.count)>"
        case .slComment (let v): return "<Tok: slc #\(v.count)>"
        case .op        (let v): return "<Tok: op '\(v.string)'>"

        case .id        (let v): return "<Tok: id '\(v.string)'>"
        case .keyword   (let v): return "<Tok: kw '\(v.string)'>"
        case .number    (let v): return "<Tok: \(v.string)>"
        
        case .lparen:    return "<Tok: ( >"
        case .rparen:    return "<Tok: ) >"
        case .lbrack:    return "<Tok: [ >"
        case .rbrack:    return "<Tok: ] >"
        case .lbrace:    return "<Tok: { >"
        case .rbrace:    return "<Tok: } >"
        case .semicolon: return "<Tok: ; >"
        case .colon:     return "<Tok: : >"
        case .comma:     return "<Tok: , >"
      }
    }
  }
  
  let sourceInfo : SourceInfo
  let keywords   : Set<String>
  let data       : Data
  var idx        : Data.Index
  
  var tokens     = [ Token ]()
  
  init(data: Data, sourceInfo: SourceInfo) {
    self.sourceInfo = sourceInfo
    self.data       = data
    self.idx        = self.data.startIndex
    
    let kw = Set<String>(JavaScriptTokenizer.keywords)
    keywords = kw.union(JavaScriptTokenizer.keywordsES5_added)
  }
  
  
  // MARK: - Parsing
  
  func parse() {
    var lastParseToken : Token? = nil
    
    while !eof {
      // yeah, lame, I know I know ...
      let c0 = la(0)
      
      var token : Token? = nil
      
      if token == nil {
        switch c0 {
          case c.lparen:    token = .lparen;    idx += 1
          case c.rparen:    token = .rparen;    idx += 1
          case c.lbrack:    token = .lbrack;    idx += 1
          case c.rbrack:    token = .rbrack;    idx += 1
          case c.lbrace:    token = .lbrace;    idx += 1
          case c.rbrace:    token = .rbrace;    idx += 1
          case c.semicolon: token = .semicolon; idx += 1
          case c.colon:     token = .colon;     idx += 1
          case c.comma:     token = .comma;     idx += 1
          
          case c.squot, c.dquot, c.backtick: // backtick is template
            token = parseQuotedString()
          
          default: token = nil
        }
      }
      
      if token == nil {
        if c0 == c.nl || (c0 == c.cr && la(1) == c.nl) {
          token = parseLineBreaks()
        }
      }
      
      if token == nil {
        if c0 == c.slash {
          let c1 = la(1)
          if c1 == c.slash {
            // Note: This doesn't clash w/ regex. The empty "//" is not a valid
            //       regex literal.
            token = parseSingleLineComment()
          }
          else if c1 == c.star {
            token = parseMultilineLineComment()
          }
          else {
            // Regex. Regex competes w/ the binary '/' operator.
            if !(lastParseToken?.isBinaryOpLeft ?? false) {
              token = parseRegex()
            }
          }
        }
      }
      
      if token == nil {
        let c1 = la(1)
        if c0 == 48 /* 0 */ && isNumTypeChar(c1) &&
           c.isdigit(la(2))
        {
          token = parseHexNumber()
        }
        else if c.isdigit(c0) || c0 == c.minus && c.isdigit(c1) {
          token = parseNumber()
        }
      }
      
      if token == nil {
        if c.isspace(c0) {
          token = parseSpaces()
        }
        else if isOpChar(c0) {
          // FIXME: special support for regex, e.g.: /([^\s"'<>/=]+)/
          // need to distinguish unary/binary?
          token = parseOp()
        }
        else if isIdStartChar(c0) {
          token = parseIdentifier()
        }
      }

      if token == nil {
        token = parseOther()
      }
      
      assert(token != nil, "could not parse token?!")
      if let token = token {
        tokens.append(token)
        if token.isRelevantForParsing {
          lastParseToken = token
        }
      }
    }
  }
  
  func parseIdentifier() -> Token? {
    guard let p = consumeWhile({ isIdChar($0) }) else { return nil }
    let s = p.string
    return keywords.contains(s) ? .keyword(p) : .id(p)
  }
  
  func parseOp() -> Token? {
    // just parse all opchars, doesn't matter how many :-)
    guard let p = consumeWhile({ isOpChar($0) }) else { return nil }
    return .op(p)
  }
  
  func parseOther() -> Token? {
    guard let p = consumeWhile({ !isTokStartChar($0) }) else { return nil }
    return .other(p)
  }
  
  func parseSpaces() -> Token? {
    guard let p = consumeWhile({ c.isspace($0) }) else { return nil }
    return .spaces(p)
  }
  
  func parseLineBreaks() -> Token? {
    guard let p = consumeWhile({ $0 == c.nl || $0 == c.cr }) else { return nil }
    return .linebreaks(p)
  }
  
  func parseSingleLineComment() -> Token? {
    guard let p = consumeWhile({ $0 != c.nl }) else { return nil }
    if la(0) == c.nl {
      idx += 1
    }
    return .slComment(p)
  }
  
  func parseMultilineLineComment() -> Token? {
    guard la(0) == c.slash && la(1) == c.star else { return nil }
    
    let start = idx
    idx += 2
    while !eof {
      if la(0) == c.star && la(1) == c.slash { break }
      idx += 1
    }
    
    if la(0) == c.star {
      idx += 1
      if la(0) == c.slash {
        idx += 1
      }
    }
    
    guard start < idx else { return nil }
    return .mlComment(data.subdata(in: start..<self.idx))
  }
  
  func consumeRegexGroup() -> Bool {
    guard !eof              else { return false }
    guard la(0) == c.lparen else { return false }
    
    idx += 1 // (
    while !eof && la(0) != c.rparen {
      guard consumeRegexPattern() else { break }
    }
    
    if la(0) == c.rparen {
      idx += 1 // )
    }
    
    return true
  }
  
  func consumeRegexCharClass() -> Bool {
    guard !eof              else { return false }
    guard la(0) == c.lbrack else { return false }
    
    idx += 1 // (
    while !eof && la(0) != c.rbrack {
      if la(0) == c.backslash && la(1) != 0 {
        idx += 1
      }
      idx += 1
    }
    
    if la(0) == c.rbrack {
      idx += 1 // )
    }
    
    return true
  }
  
  func consumeRegexPattern(stopAtSlash: Bool = false) -> Bool {
    guard !eof else { return false }
    
    if stopAtSlash && la(0) == c.slash { // end of regex pattern
      return true
    }
    
    // escaped char
    if la(0) == c.backslash && la(1) != 0 {
      idx += 2
      return true
    }
    
    if la(0) == c.lparen { return consumeRegexGroup()     }
    if la(0) == c.lbrack { return consumeRegexCharClass() }
    
    // consume as char
    idx += 1
    return true
  }
      
  func parseRegex() -> Token? {
    guard !eof else { return nil }
    guard la(0) == c.slash else { return nil }
    
    let start = idx
    idx += 1 // skip slash
    while !eof && la(0) != c.slash {
      // Note: we are supposed to actually understand and parse the regex
      //       syntax inline. E.g. a regex can contain a slash w/o escaping:
      //         /([^/\\]+)\.vue$/
      guard consumeRegexPattern(stopAtSlash: true) else { break }
    }
    
    // did we get a slash?
    if la(0) != c.slash {
      idx = start // reverse walking
      return nil
    }
    
    idx += 1 // consume slash
    
    // parse modifiers /abc/g
    while !eof && isRegexFlag(la(0)) {
      idx += 1
    }
    
    guard start < idx else { return nil }
    return .regex(data.subdata(in: start..<idx))
  }
  
  func parseQuotedString() -> Token? {
    guard !eof else { return nil }
    
    let qc = data[idx]
    idx += 1
    let start = idx
    
    while !eof && la(0) != qc {
      if la(0) == c.backslash && la(1) != 0 {
        idx += 1
      }
      
      idx += 1
    }

    let end = idx
    if la(0) == qc {
      idx += 1
    }
    
    guard start < idx else { return nil }
    return .qstring(quote: qc, value: data.subdata(in: start..<end))
  }
  
  func parseHexNumber() -> Token? {
    guard la(0) == 48 && isNumTypeChar(la(1)) else { return nil }
    
    let start  = idx
    idx += 2 // 0x
    while c.isdigit(la(0)) {
      idx += 1
    }
    guard start < idx else { return nil }
    return .number(data.subdata(in: start..<self.idx))
  }
  
  func parseNumber() -> Token? {
    let c0 = la(0), c1 = la(1)
    guard c.isdigit(c0) || (c0 == c.minus && c.isdigit(c1)) else { return nil }
    
    let start  = idx
    
    if c0 == c.minus {
      idx += 1
    }
    
    var hadDot = false, hadE = false
    
    while !eof {
      let c0 = la(0)
      if !c.isdigit(c0) {
        if c0 == c.dot {
          guard !hadDot else { break }
          hadDot = true
        }
        else if c0 == 101 /* e */ {
          guard !hadE else { break }
          
          let c1 = la(1)
          guard c.isdigit(c1) || (c1 == c.minus && c.isdigit(la(2)))
           else { break }

          hadE = true
          if c1 == c.minus { idx += 1}
        }
        else {
          break // NaN
        }
      }
      
      idx += 1
    }
    
    guard start < idx else { return nil }
    return .number(data.subdata(in: start..<self.idx))
  }
  
  final var eof : Bool { return idx >= data.endIndex }
  
  final func la(_ i : Int = 0) -> UInt8 {
    guard (idx + i) < data.endIndex else { return 0 }
    return data[idx + i]
  }
  
  final func consumeWhile(_ cb: (UInt8) -> Bool) -> Data? {
    let start = idx
    while !eof && cb(la(0)) {
      idx += 1
    }
    guard start < idx else { return nil }
    return data.subdata(in: start..<self.idx)
  }
  
  // MARK: - Constants

  final func isTokStartChar(_ c0: UInt8) -> Bool {
    guard c0 != 0 else { return false }
    
    switch c0 {
      case c.lparen, c.rparen, c.lbrack, c.rbrack, c.lbrace, c.rbrace:
        return true
    
      case c.squot, c.dquot:
        return true
      
      default: break
    }
    
    if c.isspace(c0)     { return true }
    if isOpChar(c0)      { return true }
    if isIdStartChar(c0) { return true }
    return false
  }
  
  final func isRegexFlag(_ c0: UInt8) -> Bool {
    switch c0 {
      case 103 /* g */, 105 /* i */, 109 /* m */, 117 /* u */, 121 /* y */:
        return true
      default: return false
    }
  }
  
  final func isNumTypeChar(_ c0: UInt8) -> Bool {
    // 0x18282, 0X181, 0b2882, 0o2828
    switch c0 {
      case 120 /*x*/, 88 /*X*/: return true
      // TODO: binary, octal
      default: return false
    }
  }
  
  final func isOpChar(_ c0: UInt8) -> Bool {
    switch c0 {
      case c.excl      : return true
      case c.percent   : return true
      case c.amp       : return true
      case c.star      : return true
      case c.plus      : return true
      case c.minus     : return true
      case c.dot       : return true
      case c.slash     : return true
      case c.colon     : return true
      case c.lt        : return true
      case c.eq        : return true
      case c.gt        : return true
      case c.qmark     : return true
      case c.lbrack    : return true
      case c.backslash : return true
      case c.rbrack    : return true
      case c.or        : return true
      case c.pipe      : return true
      case c.tilde     : return true
      default          : return false
    }
  }
  
  final func isIdStartChar(_ c0: UInt8) -> Bool {
    guard !c.isdigit(c0) else { return false }
    return isIdChar(c0)
  }
  final func isIdChar(_ c0: UInt8) -> Bool {
    switch c0 {
      case c.dollar, c.underline: return true
      case 48...57:  return true // 0-9
      case 65...90:  return true // A-Z
      case 97...122: return true // a-z
      default:       return false
    }
  }
  
  static let keywordsES5_added = [
    "await",
    "class",
    "enum",
    "export",
    "extends",
    "import",
    "let",
    "super"
  ]
  static let keywordsES5_removed = [
    "abstract",
    "boolean",
    "byte",
    "char",
    "double",
    "final",
    "float",
    "goto",
    "int",
    "long",
    "native",
    "short",
    "synchronized",
    "throws",
    "transient",
    "volatile"
  ]
  static let keywords = [
    "abstract",
    "arguments",
    "boolean",
    "break",
    "byte",
    "case",
    "catch",
    "char",
    "const",
    "continue",
    "debugger",
    "default",
    "delete",
    "do",
    "double",
    "else",
    "eval",
    "false",
    "final",
    "finally",
    "float",
    "for",
    "function",
    "goto",
    "if",
    "implements",
    "in",
    "instanceof",
    "int",
    "interface",
    "long",
    "native",
    "new",
    "null",
    "package",
    "private",
    "protected",
    "public",
    "return",
    "short",
    "static",
    "switch",
    "synchronized",
    "this",
    "throw",
    "throws",
    "transient",
    "true",
    "try",
    "typeof",
    "var",
    "void",
    "volatile",
    "while",
    "with",
    "yield"
  ]
}

fileprivate enum c {
  
  static func isspace(_ c: UInt8) -> Bool {
    guard c != 0 else { return false }
    return c < 33
  }
  static func isdigit(_ c: UInt8) -> Bool {
    return c >= 48 /* 0 */ && c <= 57 /* 9 */
  }
  
  static let none      : UInt8 = 0
  
  static let tab       : UInt8 = 9
  static let nl        : UInt8 = 10
  static let cr        : UInt8 = 13
  static let space     : UInt8 = 32
  
  static let excl      : UInt8 = 33 // !
  static let dquot     : UInt8 = 34 // "
  static let hash      : UInt8 = 35 // #
  static let dollar    : UInt8 = 36 // $ (regular id char in JS)
  static let percent   : UInt8 = 37 // %
  static let amp       : UInt8 = 38 // &
  static let squot     : UInt8 = 39 // '
  static let lparen    : UInt8 = 40 // (
  static let rparen    : UInt8 = 41 // )
  static let star      : UInt8 = 42 // *
  static let plus      : UInt8 = 43 // +
  static let comma     : UInt8 = 44 // ,
  static let minus     : UInt8 = 45 // -
  static let dot       : UInt8 = 46 // .
  static let slash     : UInt8 = 47 // /
  static let colon     : UInt8 = 58 // :
  static let semicolon : UInt8 = 59 // ;
  static let lt        : UInt8 = 60 // <
  static let eq        : UInt8 = 61 // =
  static let gt        : UInt8 = 62 // >
  static let qmark     : UInt8 = 63 // ?
  
  static let lbrack    : UInt8 = 91 // [
  static let backslash : UInt8 = 92 // \
  static let rbrack    : UInt8 = 93 // ]
  static let or        : UInt8 = 94 // ^
  static let underline : UInt8 = 95 // _
  static let backtick  : UInt8 = 96 // `
  
  static let lbrace    : UInt8 = 123 // {
  static let pipe      : UInt8 = 124 // |
  static let rbrace    : UInt8 = 125 // }
  static let tilde     : UInt8 = 126 // ~
}

extension Sequence where Iterator.Element == JavaScriptTokenizer.Token {
  
  var javaScriptData : Data {
    var data = Data()
    var iter = makeIterator()
    while let token = iter.next() {
      switch token {
        case .other     (let v): data.append(v)
        
        case .qstring   (let q, let v):
          data.append(q)
          data.append(v)
          data.append(q)
          
        case .spaces    (let v): data.append(v)
        case .linebreaks(let v): data.append(v)
        
        case .mlComment (let v): data.append(v)
        case .slComment (let v):
          data.append(v)
          data.append(c.nl)
        
        case .op        (let v): data.append(v)
          
        case .id        (let v): data.append(v)
        case .keyword   (let v): data.append(v)
        case .number    (let v): data.append(v)
        case .regex     (let v): data.append(v)
        
        case .lparen:            data.append(c.lparen)
        case .rparen:            data.append(c.rparen)
        case .lbrack:            data.append(c.lbrack)
        case .rbrack:            data.append(c.rbrack)
        case .lbrace:            data.append(c.lbrace)
        case .rbrace:            data.append(c.rbrace)
        case .semicolon:         data.append(c.semicolon)
        case .colon:             data.append(c.colon)
        case .comma:             data.append(c.comma)
      }
    }
    return data
  }
  
}

extension Data {
  
  var string : String {
    return String(data: self, encoding: .utf8) ?? ""
  }
  
}
