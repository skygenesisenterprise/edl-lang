## Lexer tests.
##
## Positive cases check the token stream (kinds, values, positions). Negative
## cases check that a specific diagnostic code is produced -- error reporting is
## a language feature, so it is tested like one.

import edl/source
import edl/tokens
import edl/lexer
import edl/diagnostics

import ../framework

type
  LexRun = object
    tokens: seq[Token]
    diags: Diagnostics

proc lexFull(src: string): LexRun =
  let file = newSourceFile("test.edl", src)
  var diags = newDiagnostics()
  result.tokens = tokenize(file, diags)
  result.diags = diags

proc lex(src: string): seq[Token] =
  result = lexFull(src).tokens

proc run*() =
  beginSuite("lexer")

  # ---- keywords, identifiers, end of file ----
  block:
    let t = lex("fn let struct if else while for in return import")
    check(t[0].kind == tkKwFn, "'fn' lexes as a keyword")
    check(t[1].kind == tkKwLet, "'let' lexes as a keyword")
    check(t[2].kind == tkKwStruct, "'struct' lexes as a keyword")
    check(t[3].kind == tkKwIf, "'if' lexes as a keyword")
    check(t[4].kind == tkKwElse, "'else' lexes as a keyword")
    check(t[5].kind == tkKwWhile, "'while' lexes as a keyword")
    check(t[6].kind == tkKwFor, "'for' lexes as a keyword")
    check(t[7].kind == tkKwIn, "'in' lexes as a keyword")
    check(t[8].kind == tkKwReturn, "'return' lexes as a keyword")
    check(t[9].kind == tkKwImport, "'import' lexes as a keyword")
    check(t[10].kind == tkEof, "input ends with an eof token")

  block:
    let t = lex("greet name_1 _private")
    check(t[0].kind == tkIdent, "plain identifier")
    checkEqStr(t[0].text, "greet", "identifier text is kept")
    check(t[1].kind == tkIdent, "identifier with digits")
    check(t[2].kind == tkIdent, "identifier starting with underscore")

  # ---- numbers ----
  block:
    let t = lex("42 0x1F 0b1010 1_000_000")
    checkEqInt64(t[0].intVal, 42'i64, "decimal integer")
    checkEqInt64(t[1].intVal, 31'i64, "hexadecimal integer")
    checkEqInt64(t[2].intVal, 10'i64, "binary integer")
    checkEqInt64(t[3].intVal, 1000000'i64, "underscores are separators, not digits")

  block:
    let t = lex("1.5 2e3 1.5e-3")
    check(t[0].kind == tkFloatLit, "float with fraction")
    check(t[1].kind == tkFloatLit, "float with exponent")
    check(t[2].kind == tkFloatLit, "float with negative exponent")
    check(t[1].floatVal == 2000.0, "exponent is applied")

  # ---- strings and chars ----
  block:
    let t = lex("\"hello\" \"a\\nb\" \"\"")
    checkEqStr(t[0].strVal, "hello", "plain string value")
    checkEqStr(t[1].strVal, "a\nb", "escape sequences are decoded")
    checkEqStr(t[2].strVal, "", "empty string is valid")

  block:
    let t = lex("'a' '\\n'")
    checkEqStr(t[0].strVal, "a", "char literal value")
    checkEqStr(t[1].strVal, "\n", "escaped char literal")

  # ---- operators and punctuation ----
  block:
    let t = lex("-> == != <= >= = < > + - * / % . , : ; ? ( ) { } [ ]")
    check(t[0].kind == tkArrow, "'->'")
    check(t[1].kind == tkEq, "'=='")
    check(t[2].kind == tkNe, "'!='")
    check(t[3].kind == tkLe, "'<='")
    check(t[4].kind == tkGe, "'>='")
    check(t[5].kind == tkAssign, "'=' alone is assignment")
    check(t[6].kind == tkLt, "'<' alone is comparison")
    check(t[7].kind == tkGt, "'>' alone is comparison")

  # ---- comments ----
  block:
    let t = lex("let x = 1 // trailing comment\nlet y = 2")
    check(t[0].kind == tkKwLet, "line comment is skipped")
    checkEqStr(t[5].text, "y", "lexing resumes on the next line")

  block:
    let t = lex("/* outer /* nested */ still a comment */ 1")
    check(t[0].kind == tkIntLit, "block comments nest")

  # ---- positions ----
  block:
    let r = lexFull("fn main() {\n  let x = 1\n}")
    checkEqInt(r.tokens[0].span.start.line, 1, "first token is on line 1")
    checkEqInt(r.tokens[5].span.start.line, 2, "token after a newline is on line 2")
    checkEqInt(r.tokens[5].span.start.col, 3, "column counts from 1")
    checkEqStr(r.tokens[5].text, "let", "the token on line 2 is 'let'")

  # ---- negative cases ----
  block:
    let r = lexFull("\"unterminated")
    check(r.diags.hasCode(edlLexUnterminatedString), "unterminated string is reported")

  block:
    let r = lexFull("/* never closed")
    check(r.diags.hasCode(edlLexUnterminatedComment), "unterminated block comment is reported")

  block:
    let r = lexFull("let x = @")
    check(r.diags.hasCode(edlLexUnexpectedChar), "unexpected character is reported")

  block:
    let r = lexFull("\"bad \\q escape\"")
    check(r.diags.hasCode(edlLexInvalidEscape), "invalid escape is reported")

  block:
    let r = lexFull("'ab'")
    check(r.diags.hasCode(edlLexInvalidChar), "over-long char literal is reported")

  block:
    let r = lexFull("let x = 1")
    check(not r.diags.hasErrors(), "valid input produces no errors")
