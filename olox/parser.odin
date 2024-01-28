package crafting_interpeters

import "core:fmt"
import "core:strconv"
////
parser: Parser
////
Parser :: struct {
	current:    Token,
	previous:   Token,
	had_error:  bool,
	panic_mode: bool,
}

advance_token :: proc() {
	parser.previous = parser.current
	for {
		parser.current = scan_token()
		if parser.current.type != .Invalid {break}
		error_at_current(parser.current.text)
	}
}
error :: proc(msg: string) {
	error_at(parser.previous, msg)
}
error_at_current :: proc(msg: string) {
	error_at(parser.current, msg)
}
error_at :: proc(t: Token, msg: string) {
	if parser.panic_mode do return
	parser.panic_mode = true
	t := parser.current
	fmt.eprintf("[line %v] Error", t.line)
	if t.type == .EOF {
		fmt.eprintf(" at end")
	} else {
		fmt.eprintf(" at '%v'", t.text)
	}
	parser.had_error = true
}
consume :: proc(t: Token_Type, msg: string) {
	if parser.current.type == t {
		advance_token()
		return
	}
	error_at_current(msg)
}

grouping :: proc() {
	expression()
	consume(.Right_Paren, "Expected ')' after expression.")
}

expression :: proc() {
	parse_precedence(.Assign)
}

number :: proc() {
	val, ok := strconv.parse_f64(parser.previous.text)
	if !ok {
		error("unable to parse number")
	} else {
		emit_constant(val)
	}
}

unary :: proc() {
	op_type := parser.previous.type
	parse_precedence(.Unary)
	#partial switch op_type {
	case .Minus:
		emit_byte(int(Op_Code.Negate))
	case .Bang:
		emit_byte(int(Op_Code.Not))
	case:
		unreachable()
	}
}

binary :: proc() {
	op := parser.previous.type
	rule := get_rule(op)
	parse_precedence(Precedence(int(rule.precedence) + 1))
	#partial switch op {
	case .Plus:
		emit_byte(int(Op_Code.Add))
	case .Minus:
		emit_byte(int(Op_Code.Subtract))
	case .Star:
		emit_byte(int(Op_Code.Multiply))
	case .Slash:
		emit_byte(int(Op_Code.Divide))
	case .Bang_Equal:
		emit_bytes(int(Op_Code.Equality), int(Op_Code.Not))
	case .Equal_Equal:
		emit_byte(int(Op_Code.Equality))
	case .Greater:
		emit_byte(int(Op_Code.Greater))
	case .Greater_Equal:
		emit_bytes(int(Op_Code.Less), int(Op_Code.Not))
	case .Less:
		emit_byte(int(Op_Code.Less))
	case .Less_Equal:
		emit_bytes(int(Op_Code.Greater), int(Op_Code.Not))
	case:
		unreachable()
	}
}
literal :: proc() {
	#partial switch parser.previous.type {
	case .False:
		emit_byte(int(Op_Code.False))
	case .True:
		emit_byte(int(Op_Code.True))
	case .Nil:
		emit_byte(int(Op_Code.Nil))
	case:
		unreachable()
	}
}

parse_precedence :: proc(prec: Precedence) {
	advance_token()
	prefix_rule := get_rule(parser.previous.type).prefix
	if prefix_rule == nil {
		error("Expected Expression")
		return
	}
	prefix_rule()

	for prec <= get_rule(parser.current.type).precedence {
		advance_token()
		infix_rule := get_rule(parser.previous.type).infix
		infix_rule()
	}
}
get_rule :: proc(t: Token_Type) -> ^Parse_Rule {
	return &RULES[t]
}
Precedence :: enum {
	None,
	Assign,
	Or,
	And,
	Equality,
	Comparison,
	Term,
	Factor,
	Unary,
	Call,
	Primary,
	Equal,
	Greater,
	Less,
}
Parse_Rule :: struct {
	prefix:     Parse_Fn,
	infix:      Parse_Fn,
	precedence: Precedence,
}

Parse_Fn :: #type proc()

RULES := #partial [Token_Type]Parse_Rule {
	.Left_Paren = {grouping, nil, .None},
	// .Right_Paren = {nil, nil, .None},
	// .Left_Brace = {nil, nil, .None},
	// .Right_Brace = {nil, nil, .None},
	// .Comma = {nil, nil, .None},
	// .Dot = {nil, nil, .None},
	.Minus = {unary, binary, .Term},
	.Plus = {nil, binary, .Term},
	// .Semi_Colon = {nil, nil, .None},
	.Slash = {nil, binary, .Factor},
	.Star = {nil, binary, .Factor},
	.Bang = {unary, nil, .None},
	.Bang_Equal = {nil, binary, .Equality},
	// .Equal = {nil, nil, .None},
	.Equal_Equal = {nil, binary, .Equality},
	.Greater = {nil, binary, .Comparison},
	.Greater_Equal = {nil, binary, .Comparison},
	.Less = {nil, binary, .Comparison},
	.Less_Equal = {nil, binary, .Comparison},
	// .Identifier = {nil, nil, .None},
	// .String = {nil, nil, .None},
	.Number = {number, nil, .None},
	// .And = {nil, nil, .None},
	// .Class = {nil, nil, .None},
	// .Else = {nil, nil, .None},
	.False = {literal, nil, .None},
	// .For = {nil, nil, .None},
	// .Fun = {nil, nil, .None},
	// .If = {nil, nil, .None},
	.Nil = {literal, nil, .None},
	// .Or = {nil, nil, .None},
	// .Print = {nil, nil, .None},
	// .Return = {nil, nil, .None},
	// .Super = {nil, nil, .None},
	// .This = {nil, nil, .None},
	.True = {literal, nil, .None},
	// .Var = {nil, nil, .None},
	// .While = {nil, nil, .None},
	// .Invalid = {nil, nil, .None},
	// .EOF = {nil, nil, .None},
}
