package crafting_interpeters

import "core:fmt"
import "core:mem"
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
	strings: Table,
	globals: Table,
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
		// delete(src) // FIXME - this is segfaulting on linux??
	}
}

compile :: proc(src: []u8, chunk: ^Chunk) -> bool {
	init_scanner(src)
	compiling_chunk = chunk
	current = new(Compiler)
	advance_token()
	for !match_token(.EOF) {
		declaration()
	}
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
				push_value(a + b)
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
		case .Pop:
			pop_value()
		case .Define_Global:
			os := read_string()
			fmt.println("------> DEFINE", os.str)
			val := pop_value() // <-- this is the defined value of the global
			fmt.println("defined::", value_to_string(val))
			set(&vm.globals, os.hash, val)

		case .Get_Global:
			os := read_string()
			val, found := get(&vm.globals, os.hash)
			str, is_str := value_to_string(val)

			fmt.println("------> Try-Get", os.str, found, str)
			fmt.println("------> GET", str)

			if !found {
				runtime_error("undefined variable '%v'", os.str)
				return .Runtime_Error
			}
			push_value(val)

		case .Set_Global:
			os := read_string()
			is_new := set(&vm.globals, os.hash, peek_value())
			if is_new {
				remove(&vm.globals, os.hash)
				runtime_error("Undefined Variable '%v'", os.str)
				return .Runtime_Error
			}

		case .Get_Local:
			slot := read_next()
			push_value(vm.stack[slot])

		case .Set_Local:
			slot := read_next()
			vm.stack[slot] = peek_value()

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
		case .Print:
			print_value(pop_value())
			fmt.printf("\n")

		case .Jump:
			offset := read_next()
			vm.ip += offset
		case .Jump_If_False:
			offset := read_next()
			if offset > 32 {
				fmt.println(offset)
				panic("eex")
			}
			if is_falsey(peek_value()) {
				vm.ip += offset
			}
		case .Loop:
			offset := read_next()
			vm.ip -= offset
		case .Return:
			// fmt.printf("return :: ")
			// print_value(pop_value())
			return .Ok
		case:
			return .Compile_Error
		}
	}
}
print_value :: proc(value: Value) {
	switch v in value {
	case (bool):
		fmt.println(v)
	case (f64):
		fmt.println(v)
	case (Nil):
		fmt.println("nil")
	case (^Obj):
		print_obj(v)
	}
}
push_value :: proc(v: Value) {
	when false {
		fmt.print("push", vm.top + 1, " ")
		print_value(v)
		fmt.println()
	}

	vm.stack[vm.top] = v
	vm.top += 1
}
pop_value :: proc() -> Value {
	vm.top -= 1
	if vm.top < 0 {runtime_error("!!! stack pointer went negative\n");return nil}
	when false {
		fmt.print("pop", vm.top, " ")
		print_value(vm.stack[vm.top])
		fmt.println()
	}
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
emit_jump :: proc(instr: int) -> int {
	emit_byte(instr)
	emit_byte(0xff)
	return len(current_chunk().code) - 1
}
emit_loop :: proc(start: int) {
	emit_byte(int(Op_Code.Loop))
	offset := len(current_chunk().code) - start + 1
	if offset > 65000 {error("loop too large")}
	emit_byte(offset)
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
patch_jump :: proc(offset: int) {
	jump := len(current_chunk().code) - offset - 1
	if jump > 65000 {
		error("jump is too far")
	}
	current_chunk().code[offset] = jump //>> 8 & 0xff
	// current_chunk().code[offset+1] = jump & 0xff
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
free_vm :: proc() {
	delete(vm.strings.entries)
	delete(vm.globals.entries)
	free_objects()
}
free_objects :: proc() {
	obj := vm.objects
	for obj != nil {
		switch obj.type {
		case Obj_Type.String:
			os := transmute(^Obj_String)obj
			ob := transmute([]u8)os.str
			reallocate_slice(&(ob)[0], 1, len(os.str), 0)
			reallocate(os, Obj_String, 0, 0)
		}
		obj = obj.next
	}
}

reallocate_slice :: proc(ptr: rawptr, size: int, current_size: int, new_len: int) -> rawptr {
	if new_len == 0 {
		free(ptr)
		return nil
	} else if ptr == nil {
		p, ok := mem.alloc(size * new_len)
		assert(ok == .None)
		return p
	} else {
		unimplemented()
	}
}


reallocate :: proc(ptr: rawptr, $T: typeid, current_size: int, new_size: int) -> rawptr {
	if new_size == 0 {
		free(ptr)
		return nil
	} else if ptr == nil {
		p, ok := mem.alloc(size_of(T) * new_size)
		assert(ok == .None)
		return p
	} else {
		unimplemented()
	}
}


match_token :: proc(t: Token_Type) -> bool {
	if parser.current.type != t do return false
	advance_token()
	return true
}
read_next :: proc() -> int {
	instr := vm.chunk.code[vm.ip] // technically ptr deref faster
	vm.ip += 1
	return instr
}

read_string :: proc() -> ^Obj_String {
	idx := read_next()
	val := vm.chunk.constants[idx]
	obj := val.(^Obj)
	os := transmute(^Obj_String)obj
	return os
}
