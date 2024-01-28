package crafting_interpeters
////
scanner: Scanner

////
Scanner :: struct {
	src:     string,
	i:       int,
	line:    int,
	current: u8,
}

init_scanner :: proc(src: []u8) {
	scanner.src = string(src)
	scanner.line = 1
}

scan_token :: proc() -> Token {
	skip_whitespace()
	if scanner.i >= len(scanner.src) {
		return Token{type = .EOF, line = scanner.line}
	}
	start := scanner.i
	ch := advance_char()
	lit: string
	type: Token_Type
	line := scanner.line
	switch ch {
	case '(':
		type = .Left_Paren
	case ')':
		type = .Right_Paren
	case '{':
		type = .Left_Brace
	case '}':
		type = .Right_Brace
	case ';':
		type = .Semi_Colon
	case ',':
		type = .Comma
	case '.':
		type = .Dot
	case '-':
		type = .Minus
	case '+':
		type = .Plus
	case '/':
		type = .Slash
	case '*':
		type = .Star
	case '!':
		type = match_char('=') ? .Bang_Equal : .Bang
	case '=':
		type = match_char('=') ? .Equal_Equal : .Equal
	case '<':
		type = match_char('=') ? .Less_Equal : .Less
	case '>':
		type = match_char('=') ? .Greater_Equal : .Greater
	case '"':
		return scan_string()
	}

	if type == .Invalid {
		if is_alpha(ch) {
			return scan_ident()
		}
		if is_digit(ch) {
			return scan_number()
		}
		return(
			Token {
				type = .Invalid,
				text = fmt.tprintf("Unexpected character <%v>\n", rune(ch)),
				line = scanner.line,
			} \
		)

	}
	return generate_token(type, start)

}

scan_string :: proc() -> Token {
	start := scanner.i - 1
	for peek_char() != '"' && !at_eof() {
		if peek_char() == '\n' do scanner.line += 1
		advance_char()
	}
	if at_eof() {
		return Token{type = .Invalid, text = "Unterminated String", line = scanner.line}
	}
	advance_char() // closing "
	return generate_token(.String, start)
}

skip_whitespace :: proc() {
	for {
		ch := peek_char()
		switch ch {
		case '\n':
			scanner.line += 1
			fallthrough
		case ' ', '\t', '\r':
			advance_char()
		case '/':
			if peek_char(1) == '/' {
				for peek_char() != '\n' && scanner.i < len(scanner.src) {advance_char()}
			}
		case:
			return
		}
	}
}

at_eof :: proc(lookahead: int = 0) -> bool {
	i := scanner.i + lookahead
	eof := len(scanner.src)
	return i >= eof
}
advance_char :: proc() -> u8 {
	scanner.i += 1
	return scanner.src[scanner.i - 1]
}
peek_char :: proc(lookahead := 0) -> u8 {
	if at_eof(lookahead) do return 0
	ch := scanner.src[scanner.i + lookahead]
	return ch
}
match_char :: proc(expected: u8) -> bool {
	if at_eof() {return false}
	if scanner.src[scanner.i] != expected do return false
	scanner.i += 1
	return true
}

is_digit :: proc(ch: u8) -> bool {
	return '0' <= ch && ch <= '9'
}
is_alpha :: proc(ch: u8) -> bool {
	return 'a' <= ch && ch <= 'z' || 'A' <= ch && ch <= 'Z' || '_' == ch
}
scan_number :: proc() -> Token {
	start := scanner.i - 1
	for is_digit(peek_char()) do advance_char()
	if peek_char() == '.' && is_digit(peek_char(1)) {
		advance_char()
		for is_digit(peek_char()) do advance_char()
	}
	return generate_token(.Number, start)
}
scan_ident :: proc() -> Token {
	start := scanner.i - 1
	for is_alpha(peek_char()) || is_digit(peek_char()) {advance_char()}
	type := identifier_type(scanner.src[start:scanner.i])
	return generate_token(type, start)
}

import "core:fmt"
generate_token :: proc(type: Token_Type, start: int) -> Token {
	token := Token {
		type = type,
		text = scanner.src[start:scanner.i],
		line = scanner.line,
	}
	fmt.println(token)
	return token
}

identifier_type :: proc(text: string) -> Token_Type {
	switch text {
	case "and":
		return .And
	case "class":
		return .Class
	case "else":
		return .Else
	case "false":
		return .False
	case "for":
		return .For
	case "fun":
		return .Fun
	case "if":
		return .If
	case "nil":
		return .Nil
	case "or":
		return .Or
	case "print":
		return .Print
	case "return":
		return .Return
	case "super":
		return .Super
	case "this":
		return .This
	case "true":
		return .True
	case "var":
		return .Var
	case "while":
		return .While
	case:
		return .Identifier
	}
	return .Identifier
}
