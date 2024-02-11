package crafting_interpeters

import "core:fmt"
import "core:reflect"


Op_Code :: enum int {
	Add,
	Subtract,
	Multiply,
	Define_Global,
	Get_Global,
	Set_Global,
	Divide,
	Negate,
	Print,
	Constant,
	Nil,
	True,
	False,
	Pop,
	Not,
	Equality,
	Greater,
	Less,
	Return,
}
Chunk :: struct {
	lines:     [dynamic]int,
	code:      [dynamic]int,
	constants: [dynamic]Value,
}
Nil :: struct {}
NIL :: Nil{}
Value :: union {
	Nil,
	bool,
	f64,
	^Obj,
}


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
	fmt.printf("-- END -- \n")

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
	case .Constant, .Define_Global, .Get_Global, .Set_Global:
		return constant_instruction(reflect.enum_string(cast(Op_Code)instr), chunk, offset)
	case .Negate, .Add, .Subtract, .Multiply, .Divide, .Return, .True, .False, .Nil, .Not, .Equality, .Greater, .Less, .Print, .Pop:
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
	val := chunk.constants[const_index]
	str, is_str := value_to_string(val)
	if is_str {
		fmt.printf("%-16s %4d '%v'\n", name, const_index, str)

	} else {
		fmt.printf("%-16s %4d '%v'\n", name, const_index, val)
	}
	return offset + 2
}
