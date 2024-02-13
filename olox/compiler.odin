package crafting_interpeters

import "core:fmt"
import "core:strconv"
////
parser: Parser
current: ^Compiler
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
expect_token :: proc(kind: Token_Type) {
	if parser.current.type != kind {
		fmt.panicf("expected %v, got %v", kind, parser.current.type)
	}
	advance_token()
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
		fmt.eprintf(" at '%v'. Reason: %v\n", t.text, msg)
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

grouping :: proc(can_assign: bool = false) {
	expression()
	consume(.Right_Paren, "Expected ')' after expression.")
}

declaration :: proc() {
	if match_token(.Var) {
		var_decl()
	} else {
		statement()
	}
	if parser.panic_mode do synchronize()
}
var_decl :: proc() {
	global := parse_var("Expect variable name.")
	if match_token(.Equal) {
		expression()
	} else {
		emit_byte(int(Op_Code.Nil))
	}
	consume(.Semi_Colon, "expect ; after decl")
	define_var(global)
}
statement :: proc() {
	if match_token(.Print) {
		print_statement()
	} else if match_token(.Left_Brace) {
		begin_scope()
		block()
		end_scope()
	} else {
		expression_statement()
	}
}
expression_statement :: proc() {
	expression()
	consume(.Semi_Colon, "Expect ; after expr.")
	emit_byte(int(Op_Code.Pop))
}
expression :: proc() {
	parse_precedence(.Assign)
}

block :: proc() {
	for parser.current.type != .Right_Brace && parser.current.type != .EOF {
		declaration()
	}
	consume(.Right_Brace, "Expect '}' to close a block.")
}
begin_scope :: proc() {
	current.scope_depth += 1
}
end_scope :: proc() {
	current.scope_depth -= 1
	for current.local_count > 0 &&
	    current.locals[current.local_count - 1].depth > current.scope_depth {
		emit_byte(int(Op_Code.Pop))
		current.local_count -= 1
	}
}

print_statement :: proc() {
	expression()
	expect_token(.Semi_Colon)
	emit_byte(int(Op_Code.Print))
}

synchronize :: proc() {
	parser.panic_mode = false

	for parser.current.type != .EOF {
		if parser.previous.type == .Semi_Colon do return
		#partial switch parser.current.type {
		case .Class, .Fun, .For, .If, .While, .Print, .Return:
			return
		case:
		//nop
		}
		advance_token()
	}
}

number :: proc(can_assign: bool = false) {
	val, ok := strconv.parse_f64(parser.previous.text)
	if !ok {
		error("unable to parse number")
	} else {
		emit_constant(val)
	}
}

unary :: proc(can_assign: bool = false) {
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

binary :: proc(can_assign: bool = false) {
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
literal :: proc(can_assign: bool = false) {
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
_string :: proc(can_assign: bool = false) {str := parser.previous.text[1:len(
		parser.previous.text,
	) -
	1]
	obj: ^Obj = transmute(^Obj)copy_string(str)
	emit_constant(obj)
}
variable :: proc(can_assign: bool = false) {
	named_variable(&parser.previous, can_assign)
}
named_variable :: proc(token: ^Token, can_assign: bool) {
	get_op, set_op: Op_Code
	arg := resolve_local(current, token.text)
	if arg != -1 {
		get_op = .Get_Local
		set_op = .Set_Local
	} else {
		arg = identifier_constant(token)
		get_op = .Get_Global
		set_op = .Set_Global
	}

	if can_assign && match_token(.Equal) {
		expression()
		emit_bytes(int(set_op), arg)
	} else {
		emit_bytes(int(get_op), arg)
	}
}
parse_precedence :: proc(prec: Precedence) {
	advance_token()
	prefix_rule := get_rule(parser.previous.type).prefix
	if prefix_rule == nil {
		error("Expected Expression")
		return
	}
	can_assign := prec <= Precedence.Assign
	prefix_rule(can_assign)

	for prec <= get_rule(parser.current.type).precedence {
		advance_token()
		infix_rule := get_rule(parser.previous.type).infix
		infix_rule()
		if can_assign && match_token(.Equal) {
			error("invalid assignment target.")
		}
	}
}

identifier_constant :: proc(t: ^Token) -> int {
	obj := transmute(^Obj)copy_string(t.text)
	index := set_constant(obj)
	return index
}
parse_var :: proc(err_msg: string) -> int {
	consume(.Identifier, err_msg)
	declare_var()
	if current.scope_depth > 0 do return 0 // we're in a local scope -> exit 

	return identifier_constant(&parser.previous)
}

define_var :: proc(global: int) {
	if current.scope_depth > 0 {
		mark_initialized()
		return
	}
	emit_bytes(int(Op_Code.Define_Global), global)
}
mark_initialized :: proc() {
	current.locals[current.local_count - 1].depth = current.scope_depth
}
declare_var :: proc() {
	if current.scope_depth == 0 do return
	name := parser.previous.text
	for i := current.local_count - 1; i >= 0; i -= 1 {
		local := &current.locals[i]
		if local.depth != -1 && local.depth < current.scope_depth {
			break
		}
		if local.name == name {
			error("repeated declaration of variable in this scope")
		}
	}
	add_local(name)
}
add_local :: proc(name: string) {
	if current.local_count == 255 {
		error("too many locals in function")
		return
	}
	local := &current.locals[current.local_count]
	current.local_count += 1
	local.name = name
	local.depth = -1
}
resolve_local :: proc(compiler: ^Compiler, name: string) -> int {
	for i := compiler.local_count - 1; i >= 0; i -= 1 {
		local := &compiler.locals[i]
		// because we walk backwards, inner values correctly shadow outers
		if local.name == name {
			if local.depth == -1 {
				error("cant read local var in its own initializer")
			}
			return i // this index is the same as stack-slot
		}
	}
	return -1
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

Compiler :: struct {
	locals:      [255]Local,
	local_count: int,
	scope_depth: int,
}
Local :: struct {
	name:  string,
	depth: int,
}
Parse_Fn :: #type proc(can_assign: bool = false)

RULES := #partial [Token_Type]Parse_Rule {
	.Left_Paren    = {grouping, nil, .None},
	// .Right_Paren = {nil, nil, .None},
	// .Left_Brace = {nil, nil, .None},
	// .Right_Brace = {nil, nil, .None},
	// .Comma = {nil, nil, .None},
	// .Dot = {nil, nil, .None},
	.Minus         = {unary, binary, .Term},
	.Plus          = {nil, binary, .Term},
	// .Semi_Colon = {nil, nil, .None},
	.Slash         = {nil, binary, .Factor},
	.Star          = {nil, binary, .Factor},
	.Bang          = {unary, nil, .None},
	.Bang_Equal    = {nil, binary, .Equality},
	// .Equal = {nil, nil, .None},
	.Equal_Equal   = {nil, binary, .Equality},
	.Greater       = {nil, binary, .Comparison},
	.Greater_Equal = {nil, binary, .Comparison},
	.Less          = {nil, binary, .Comparison},
	.Less_Equal    = {nil, binary, .Comparison},
	.Identifier    = {variable, nil, .None},
	.String        = {_string, nil, .None},
	.Number        = {number, nil, .None},
	// .And = {nil, nil, .None},
	// .Class = {nil, nil, .None},
	// .Else = {nil, nil, .None},
	.False         = {literal, nil, .None},
	// .For = {nil, nil, .None},
	// .Fun = {nil, nil, .None},
	// .If = {nil, nil, .None},
	.Nil           = {literal, nil, .None},
	// .Or = {nil, nil, .None},
	// .Print = {nil, nil, .None},
	// .Return = {nil, nil, .None},
	// .Super = {nil, nil, .None},
	// .This = {nil, nil, .None},
	.True          = {literal, nil, .None},
	// .Var = {nil, nil, .None},
	// .While = {nil, nil, .None},
	// .Invalid = {nil, nil, .None},
	// .EOF = {nil, nil, .None},
}

value_to_string :: proc(val: Value) -> (str: string, is_string: bool) {
	obj, is := val.(^Obj)
	if !is do return "", false
	os := transmute(^Obj_String)obj
	return os.str, true
}
