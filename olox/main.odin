package crafting_interpeters

import "core:fmt"
import "core:os"

main :: proc() {
	if len(os.args) == 1 {
		repl()
	} else if len(os.args) == 2 {
		run_file(os.args[1])
	} else {
		fmt.eprintf("Usage olox [path]\n")
		os.exit(64)
	}
}

Op_Code :: enum int {
	Add,
	Subtract,
	Multiply,
	Divide,
	Negate,
	Constant,
	Return,
}
Chunk :: struct {
	lines:     [dynamic]int,
	code:      [dynamic]int,
	constants: [dynamic]Value,
}
Value :: f64

add_constant :: proc(chunk: ^Chunk, const: Value) -> (index: int) {
	append(&chunk.constants, const)
	return len(chunk.constants) - 1
}

write_chunk :: proc(chunk: ^Chunk, op: int, line: int) {
	append(&chunk.lines, line)
	append(&chunk.code, op)
}

disassemble_chunk :: proc(chunk: ^Chunk, name: string) {
	fmt.printf("-- %s -- \n", name)
	for offset := 0; offset < len(chunk.code); {
		offset = disassemble_instruction(chunk, offset)
	}
}
import "core:reflect"
disassemble_instruction :: proc(chunk: ^Chunk, offset: int) -> int {
	fmt.printf("%04d ", offset)
	if offset > 0 && chunk.lines[offset] == chunk.lines[offset - 1] {
		fmt.printf("   | ")
	} else {
		fmt.printf("%4d ", chunk.lines[offset])
	}
	instr := chunk.code[offset]
	switch cast(Op_Code)instr {
	case .Constant:
		return constant_instruction(reflect.enum_string(cast(Op_Code)instr), chunk, offset)
	case .Negate, .Add, .Subtract, .Multiply, .Divide, .Return:
		return simple_instruction(reflect.enum_string(cast(Op_Code)instr), offset)
	case:
		fmt.printf("Unknown %d\n", instr)
		return offset + 1
	}
}

simple_instruction :: proc(name: string, offset: int) -> int {
	fmt.printf("%s\n", name)
	return offset + 1
}

constant_instruction :: proc(name: string, chunk: ^Chunk, offset: int) -> int {
	const_index := chunk.code[offset + 1]
	fmt.printf("%-16s %4d '%v'\n", name, const_index, chunk.constants[const_index])
	return offset + 2
}
