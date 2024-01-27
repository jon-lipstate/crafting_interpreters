package crafting_interpeters

import "core:fmt"
import "core:os"
DEBUG_TRACE :: true
DEBUG_PRINT_CODE :: true
Virtual_Machine :: struct {
	chunk: ^Chunk,
	ip:    int,
	stack: [256]Value,
	top:   int,
}
vm := Virtual_Machine{}

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
	src, ok := os.read_entire_file_from_filename(path);defer if ok do delete(src)
	if !ok {
		fmt.eprintln("Failed to open the file.")
		os.exit(74)
	}
	res := interpret(src)
	if res == .Compile_Error do os.exit(65)
	if res == .Runtime_Error do os.exit(70)
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
			push(-pop())
		case .Constant:
			const := vm.chunk.constants[read_next()]
			push(const)
		case .Add:
			b := pop()
			a := pop()
			push(a + b)
		case .Subtract:
			b := pop()
			a := pop()
			push(a - b)
		case .Multiply:
			b := pop()
			a := pop()
			push(a * b)
		case .Divide:
			b := pop()
			a := pop()
			push(a / b)
		case .Return:
			fmt.printf("%v", pop())
			return .Ok
		case:
			return .Compile_Error
		}
	}
}

push :: proc(v: Value) {
	vm.stack[vm.top] = v
	vm.top += 1
}
pop :: proc() -> Value {
	vm.top -= 1
	return vm.stack[vm.top]
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
