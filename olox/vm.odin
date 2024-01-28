package crafting_interpeters

import "core:fmt"
import "core:os"
import "core:reflect"

/// GLOBALS
DEBUG_TRACE :: true
DEBUG_PRINT_CODE :: true
//
compiling_chunk: ^Chunk
vm := Virtual_Machine{}

////
Virtual_Machine :: struct {
	chunk:   ^Chunk,
	ip:      int,
	stack:   [256]Value,
	top:     int,
	objects: ^Obj,
}
reset_stack :: proc() {
	vm.top = 0
}

Interpret_Result :: enum {
	Ok,
	Compile_Error,
	Runtime_Error,
}

repl :: proc() {
	buf: [1024]u8
	for {
		fmt.printf("> ")
		n, ok := os.read_full(os.stdin, buf[:])
		if n == 0 {
			fmt.printf("\n")
			break
		}
		interpret(buf[:n])
	}
}

run_file :: proc(path: string) {
	src, ok := os.read_entire_file_from_filename(path)
	if !ok {
		fmt.eprintln("Failed to open the file.")
		os.exit(74)
	}
	res := interpret(src)
	if res == .Compile_Error do os.exit(65)
	if res == .Runtime_Error do os.exit(70)
	if ok {
		delete(src) // FIXME - this is segfaulting on linux??
	}
}

compile :: proc(src: []u8, chunk: ^Chunk) -> bool {
	init_scanner(src)
	compiling_chunk = chunk
	advance_token()
	expression()
	consume(.EOF, "Expected EOF")
	end_compiler()
	return !parser.had_error
}

current_chunk :: proc() -> ^Chunk {
	return compiling_chunk
}
destroy_chunk :: proc(chunk: ^Chunk) {
	delete(chunk.code)
	delete(chunk.constants)
	delete(chunk.lines)
	delete(scanner.src)
	vm.chunk = nil
}

interpret :: proc(src: []u8) -> Interpret_Result {
	chunk := &Chunk{}
	ok := compile(src, chunk)
	result := run()
	destroy_chunk(chunk)
	return result
}

run :: proc() -> Interpret_Result {
	vm.chunk = current_chunk()
	read_next :: proc() -> int {
		instr := vm.chunk.code[vm.ip] // technically ptr deref faster
		vm.ip += 1
		return instr
	}
	loop: for {
		when DEBUG_TRACE {
			for v, i in vm.stack {
				fmt.printf("          [ %v ]\n", vm.stack[i])
				if i >= vm.top do break
			}
			disassemble_instruction(vm.chunk, vm.ip)
		}
		instr := read_next()
		switch cast(Op_Code)instr {
		case .Negate:
			switch v in pop_value() {
			case (Nil):
				runtime_error("'nil' cannot be negated")
				return .Runtime_Error
			case (bool):
				runtime_error("'bool' cannot be negated")
				return .Runtime_Error
			case (^Obj):
				runtime_error("'string' cannot be negated")
				return .Runtime_Error
			case (f64):
				push_value(-v)
			}
		case .Not:
			push_value(is_falsey(pop_value()))
		case .Constant:
			const := vm.chunk.constants[read_next()]
			push_value(const)
		case .Add:
			if is_string(peek_value()) && is_string(peek_value(1)) {
				concatenate()
			} else if is_number(peek_value()) && is_number(peek_value(1)) {
				b := pop_value().(f64)
				a := pop_value().(f64)
			} else {
				runtime_error("'+' is for two strings or two numbers\n")
				return .Runtime_Error
			}
		case .Subtract:
			b, a_ok := pop_value().(f64)
			a, b_ok := pop_value().(f64)
			if !a_ok || !b_ok {
				runtime_error("'-' is for numbers\n")
				return .Runtime_Error
			}
			push_value(a - b)
		case .Multiply:
			b, a_ok := pop_value().(f64)
			a, b_ok := pop_value().(f64)
			if !a_ok || !b_ok {
				runtime_error("'*' is for numbers\n")
				return .Runtime_Error
			}
			push_value(a * b)
		case .Divide:
			b, a_ok := pop_value().(f64)
			a, b_ok := pop_value().(f64)
			if !a_ok || !b_ok {
				runtime_error("'/' is for numbers\n")
				return .Runtime_Error
			}
			push_value(a / b)
		case .True:
			push_value(true)
		case .False:
			push_value(false)
		case .Nil:
			push_value(NIL)
		case .Equality:
			a := pop_value()
			b := pop_value()
			push_value(values_are_equal(a, b))
		case .Greater:
			b, a_ok := pop_value().(f64)
			a, b_ok := pop_value().(f64)
			if !a_ok || !b_ok {
				runtime_error("'>' is for numbers\n")
				return .Runtime_Error
			}
			push_value(a > b)
		case .Less:
			b, a_ok := pop_value().(f64)
			a, b_ok := pop_value().(f64)
			if !a_ok || !b_ok {
				runtime_error("'<' is for numbers\n")
				return .Runtime_Error
			}
			push_value(a < b)
		case .Return:
			fmt.printf("%v", pop_value())
			return .Ok
		case:
			return .Compile_Error
		}
	}
}

push_value :: proc(v: Value) {
	vm.stack[vm.top] = v
	vm.top += 1
}
pop_value :: proc() -> Value {
	vm.top -= 1
	if vm.top < 0 {runtime_error("stack pointer went negative\n");return nil}
	return vm.stack[vm.top]
}
peek_value :: proc(lookahead := 0) -> Value {
	return vm.stack[(vm.top - 1) - lookahead]
}
is_falsey :: proc(value: Value) -> bool {
	switch v in value {
	case (Nil):
		return true
	case (bool):
		return !v
	case (f64):
		return false
	case (^Obj):
		return false // todo: verify
	}
	unreachable()
}
is_number :: proc(value: Value) -> bool {
	_, is_number := value.(f64)
	return is_number
}
values_are_equal :: proc(a, b: Value) -> bool {
	if reflect.get_union_variant_raw_tag(a) != reflect.get_union_variant_raw_tag(b) {return false}
	// i think can just cmp the unions...
	switch av in a {
	case (bool):
		bv := b.(bool)
		return av == bv
	case (f64):
		bv := b.(f64)
		return av == bv
	case (Nil):
		return true
	case (^Obj):
		as := (transmute(^Obj_String)(a.(^Obj))).str
		bs := (transmute(^Obj_String)(b.(^Obj))).str
		return as == bs
	}
	unreachable()
}
runtime_error :: proc(format: string, args: ..any) {
	line := vm.chunk.lines[vm.ip]
	fmt.eprintf("[line %d] in script ", line)
	fmt.printf(format, ..args)
	reset_stack()
}

emit_byte :: proc(v: int) {
	write_chunk(current_chunk(), v, parser.previous.line)
}
emit_bytes :: proc(a, b: int) {
	emit_byte(a)
	emit_byte(b)
}
end_compiler :: proc() {
	emit_byte(int(Op_Code.Return))
	if DEBUG_PRINT_CODE {
		if !parser.had_error {
			disassemble_chunk(current_chunk(), "code")
		}
	}
}
emit_constant :: proc(v: Value) {
	emit_bytes(int(Op_Code.Constant), set_constant(v))
}
// TODO: fixme, he uses a u8 buf, need to write [8]u8 for f64
set_constant :: proc(v: Value) -> int {
	idx := add_constant(current_chunk(), v)
	if idx > 255 {
		error("too many constants in a chunk")
		return 0
	}
	return idx
}

free_objects :: proc() {
	obj := vm.objects
	for obj != nil {
		switch obj.type {
		case .String:
			os := transmute(^Obj_String)obj
			reallocate_slice(transmute([]u8)os.str, 0)
			reallocate(os, size_of(Obj_String), 0)
		}
		obj = obj.next
	}
}

reallocate_slice :: proc(slice: []$T, new_len: int) {
	if new_len == 0 {
		delete(slice)
	} else {
		unimplemented()
	}
}


reallocate :: proc(ptr: rawptr, current_size: int, new_size: int) {
	if new_size == 0 {
		free(ptr)
	} else {
		unimplemented()
	}
}
