package crafting_interpeters

import "core:fmt"

main :: proc() {
	chunk := Chunk{}
	const := add_constant(&chunk, 1.2)
	write_chunk(&chunk, int(Op_Code.Constant), 123)
	write_chunk(&chunk, const, 123)
	write_chunk(&chunk, int(Op_Code.Return), 124)
	disassemble_chunk(&chunk, "ret")
}

Op_Code :: enum int {
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
		return constant_instruction("Op_Constant", chunk, offset)
	case .Return:
		return simple_instruction("Op_Return", offset)
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
