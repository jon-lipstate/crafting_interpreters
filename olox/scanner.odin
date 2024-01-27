package crafting_interpeters

scanner: Scanner

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
		type = match('=') ? .Bang_Equal : .Bang
	case '=':
		type = match('=') ? .Equal_Equal : .Equal
	case '<':
		type = match('=') ? .Less_Equal : .Less
	case '>':
		type = match('=') ? .Greater_Equal : .Greater
	case '"':
		return scan_string()
	}
	if is_alpha(ch) {return scan_ident()}
	if is_digit(ch) {return scan_number()}
	if type != .Invalid {
		return generate_token(type, start)
	}

	return Token{type = .Invalid, text = "Unexpected character", line = scanner.line}
}

scan_string :: proc() -> Token {
	start := scanner.i - 1
	for peek() != '"' && !at_eof() {
		if peek() == '\n' do scanner.line += 1
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
		switch peek() {
		case '\n':
			scanner.line += 1
			fallthrough
		case ' ', '\t', '\r':
			advance_char()
		case '/':
			if peek(1) == '/' {
				for peek() != '\n' && scanner.i < len(scanner.src) {advance_char()}
			}
		case:
			return
		}
	}
}

at_eof :: proc(lookahead: int = 0) -> bool {
	return scanner.i + lookahead < len(scanner.src)
}
advance_char :: proc() -> u8 {
	scanner.i += 1
	return scanner.src[scanner.i - 1]
}
peek :: proc(lookahead := 0) -> u8 {
	if !at_eof(lookahead) do return 0
	return scanner.src[scanner.i + lookahead]
}
match :: proc(expected: u8) -> bool {
	if at_eof() do return false
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
	for is_digit(peek()) do advance_char()
	if peek() == '.' && is_digit(peek(1)) {
		advance_char()
		for is_digit(peek()) do advance_char()
	}
	return generate_token(.Number, start)
}
scan_ident :: proc() -> Token {
	start := scanner.i - 1
	for is_alpha(peek()) || is_digit(peek()) {advance_char()}
	return generate_token(.Identifier, start)
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

identifier_type :: proc() -> Token_Type {
	switch peek() {
	case 'a':
		return check_keyword("and", .And)
	case 'c':
		return check_keyword("class", .Class)
	case 'e':
		return check_keyword("else", .Else)
	case 'f':
		switch peek(1) {
		case 'a':
			return check_keyword("false", .False)
		case 'o':
			return check_keyword("for", .For)
		case 'u':
			return check_keyword("fun", .Fun)
		}
	case 'i':
		return check_keyword("if", .If)
	case 'n':
		return check_keyword("nil", .Nil)
	case 'o':
		return check_keyword("or", .Or)
	case 'p':
		return check_keyword("print", .Print)
	case 'r':
		return check_keyword("return", .Return)
	case 's':
		return check_keyword("super", .Super)
	case 't':
		switch peek(1) {
		case 'h':
			return check_keyword("this", .This)
		case 'r':
			return check_keyword("true", .True)
		}
	case 'v':
		return check_keyword("var", .Var)
	case 'w':
		return check_keyword("while", .While)
	case:
		return .Invalid
	}
	return .Invalid
}
check_keyword :: proc(text: string, type: Token_Type) -> Token_Type {
	if at_eof(len(text)) do return .Invalid
	val := scanner.src[scanner.i:scanner.i + len(text)]
	return val == text ? type : .Invalid
}
