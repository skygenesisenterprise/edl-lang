## Bootstrap-dialect tokenizer for the migrator.
##
## Deliberately small: it tokenises the *bootstrap dialect* (ADR-0001), the
## subset EDL's own toolchain is written in, and nothing else. It does not need
## to understand the full lexical grammar of the bootstrap source because the
## migrator refuses, and reports, anything outside that dialect.
##
## Comments are dropped, but `#[ ]#` and `#` are recognised so that commented-out
## code cannot leak into the translation. Indentation is not tokenised: every
## token carries its line and column, and the translator derives blocks from
## those.
##
## Bootstrap dialect: see specs/decisions/ADR-0001.

type
  SourceTokKind* = enum
    skEof
    skIdent
    skKeyword
    skNumber
    skString
    skChar
    skOperator
    skPunct
    skBad

  SourceTok* = object
    kind*: SourceTokKind
    text*: string
    line*: int     ## 1-based
    col*: int      ## 1-based

const bootstrapKeywords = @[
  "addr", "and", "as", "asm", "bind", "block", "break", "case", "cast",
  "concept", "const", "continue", "converter", "defer", "discard", "distinct",
  "div", "do", "elif", "else", "end", "enum", "except", "export", "finally",
  "for", "from", "func", "if", "import", "in", "include", "interface", "is",
  "isnot", "iterator", "let", "macro", "method", "mixin", "mod", "nil", "not",
  "notin", "object", "of", "or", "out", "proc", "ptr", "raise", "ref", "return",
  "shl", "shr", "static", "template", "try", "tuple", "type", "using", "var",
  "when", "while", "xor", "yield"
]

proc isKeywordWord*(word: string): bool =
  for keyword in bootstrapKeywords:
    if keyword == word:
      return true
  result = false

proc isIdentStart(c: char): bool =
  result = (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_'

proc isIdentPart(c: char): bool =
  result = isIdentStart(c) or (c >= '0' and c <= '9')

proc isDigit(c: char): bool =
  result = c >= '0' and c <= '9'

proc isOperatorChar(c: char): bool =
  case c
  of '+', '-', '*', '/', '\\', '<', '>', '=', '!', '@', '$', '~', '&', '|',
     '%', '^', '?':
    result = true
  else:
    result = false

type
  ScanningState = ref object
    src: string
    pos: int
    line: int
    col: int

proc peek(s: ScanningState, ahead: int): char =
  let i = s.pos + ahead
  if i < 0 or i >= s.src.len:
    result = '\0'
  else:
    result = s.src[i]

proc advance(s: ScanningState): char =
  result = s.peek(0)
  if result == '\n':
    inc s.line
    s.col = 1
  else:
    inc s.col
  inc s.pos

proc skipLineComment(s: ScanningState) =
  while s.peek(0) != '\n' and s.peek(0) != '\0':
    discard s.advance()

proc skipBlockComment(s: ScanningState) =
  ## The bootstrap dialect's `#[ ... ]#`, which nests.
  discard s.advance()
  discard s.advance()
  var depth = 1
  while depth > 0 and s.peek(0) != '\0':
    if s.peek(0) == '#' and s.peek(1) == '[':
      inc depth
      discard s.advance()
      discard s.advance()
    elif s.peek(0) == ']' and s.peek(1) == '#':
      dec depth
      discard s.advance()
      discard s.advance()
    else:
      discard s.advance()

proc skipTrivia(s: ScanningState) =
  var again = true
  while again:
    again = false
    while s.peek(0) == ' ' or s.peek(0) == '\t' or s.peek(0) == '\r' or
          s.peek(0) == '\n':
      discard s.advance()
    if s.peek(0) == '#':
      if s.peek(1) == '[':
        skipBlockComment(s)
      else:
        skipLineComment(s)
      again = true

proc scanString(s: ScanningState): SourceTok =
  ## `s.pos` is on the opening quote. Triple-quoted strings are marked invalid,
  ## since EDL has no equivalent.
  let startLine = s.line
  let startCol = s.col
  if s.peek(1) == '"' and s.peek(2) == '"':
    result = SourceTok(kind: skBad, text: "\"\"\"", line: startLine, col: startCol)
    discard s.advance()
    discard s.advance()
    discard s.advance()
    return
  discard s.advance()
  var value = "\""
  while s.peek(0) != '"' and s.peek(0) != '\n' and s.peek(0) != '\0':
    let ch = s.advance()
    if ch == '\\':
      value.add('\\')
      if s.peek(0) != '\0' and s.peek(0) != '\n':
        value.add(s.advance())
    else:
      value.add(ch)
  if s.peek(0) == '"':
    discard s.advance()
  value.add('"')
  result = SourceTok(kind: skString, text: value, line: startLine, col: startCol)

proc scanNumber(s: ScanningState): SourceTok =
  ## Also consumes the bootstrap dialect's type suffix (`0'i64`, `1'u8`,
  ## `2.0'f32`). Leaving it to
  ## the character-literal scanner would swallow the rest of the line, closing
  ## brackets included.
  let startLine = s.line
  let startCol = s.col
  var text = ""
  while isDigit(s.peek(0)) or s.peek(0) == '_':
    text.add(s.advance())
  if s.peek(0) == '.' and isDigit(s.peek(1)):
    text.add(s.advance())
    while isDigit(s.peek(0)) or s.peek(0) == '_':
      text.add(s.advance())
  if s.peek(0) == 'e' or s.peek(0) == 'E':
    text.add(s.advance())
    if s.peek(0) == '+' or s.peek(0) == '-':
      text.add(s.advance())
    while isDigit(s.peek(0)):
      text.add(s.advance())
  if s.peek(0) == '\'' and isIdentStart(s.peek(1)):
    text.add(s.advance())
    while isIdentPart(s.peek(0)):
      text.add(s.advance())
  result = SourceTok(kind: skNumber, text: text, line: startLine, col: startCol)

proc scanChar(s: ScanningState): SourceTok =
  ## An unterminated literal is marked invalid rather than run to the end of the
  ## line: a bad token must never silently hide the code after it.
  let startLine = s.line
  let startCol = s.col
  var text = "'"
  discard s.advance()
  while s.peek(0) != '\'' and s.peek(0) != '\n' and s.peek(0) != '\0':
    let ch = s.advance()
    text.add(ch)
    if ch == '\\' and s.peek(0) != '\0' and s.peek(0) != '\n':
      text.add(s.advance())
  if s.peek(0) != '\'':
    return SourceTok(kind: skBad, text: text, line: startLine, col: startCol)
  discard s.advance()
  text.add("'")
  result = SourceTok(kind: skChar, text: text, line: startLine, col: startCol)

proc scanIdent(s: ScanningState): SourceTok =
  let startLine = s.line
  let startCol = s.col
  var text = ""
  while isIdentPart(s.peek(0)):
    text.add(s.advance())
  var kind = skIdent
  if isKeywordWord(text):
    kind = skKeyword
  result = SourceTok(kind: kind, text: text, line: startLine, col: startCol)

proc scanOperator(s: ScanningState): SourceTok =
  let startLine = s.line
  let startCol = s.col
  var text = ""
  while isOperatorChar(s.peek(0)):
    text.add(s.advance())
  result = SourceTok(kind: skOperator, text: text, line: startLine, col: startCol)

proc tokenizeBootstrap*(src: string): seq[SourceTok] =
  ## Tokenizes `src`. Comments and whitespace are dropped; every token keeps its
  ## source position so the translator can reconstruct block structure.
  let s = ScanningState(src: src, pos: 0, line: 1, col: 1)
  result = @[]
  while true:
    skipTrivia(s)
    if s.pos >= s.src.len:
      result.add(SourceTok(kind: skEof, text: "", line: s.line, col: s.col))
      break
    let startLine = s.line
    let startCol = s.col
    let ch = s.peek(0)
    if isIdentStart(ch):
      result.add(scanIdent(s))
    elif isDigit(ch):
      result.add(scanNumber(s))
    elif ch == '"':
      result.add(scanString(s))
    elif ch == '\'':
      result.add(scanChar(s))
    elif isOperatorChar(ch):
      result.add(scanOperator(s))
    elif ch == '.' and s.peek(1) == '.':
      # `..` and `..<` are operators, not two field accesses.
      discard s.advance()
      discard s.advance()
      var text = ".."
      if s.peek(0) == '<':
        text.add(s.advance())
      result.add(SourceTok(kind: skOperator, text: text, line: startLine, col: startCol))
    elif ch == '(' or ch == ')' or ch == '[' or ch == ']' or ch == '{' or
         ch == '}' or ch == ',' or ch == ';' or ch == '.' or ch == ':' or
         ch == '`':
      discard s.advance()
      result.add(SourceTok(kind: skPunct, text: $ch, line: startLine, col: startCol))
    else:
      discard s.advance()
      result.add(SourceTok(kind: skBad, text: $ch, line: startLine, col: startCol))
