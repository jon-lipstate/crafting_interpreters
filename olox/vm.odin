package crafting_interpeters

import "core:fmt"
DEBUG_TRACE :: true

Virtual_Machine :: struct {
	chunk: ^Chunk,
	ip:    int,
	stack: [256]Value,
	top:   int,
}

Interpret_Result :: enum {
	Ok,
	Compile_Error,
	Runtime_Error,
}
interpret :: proc(vm: ^Virtual_Machine, chunk: ^Chunk) -> Interpret_Result {
	vm.chunk = chunk
	return run(vm)
}

run :: proc(vm: ^Virtual_Machine) -> Interpret_Result {
	read_next :: proc(vm: ^Virtual_Machine) -> int {
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
		instr := read_next(vm)
		switch cast(Op_Code)instr {
		case .Negate:
			push(vm, -pop(vm))
		case .Constant:
			const := vm.chunk.constants[read_next(vm)]
			push(vm, const)
		case .Add:
			b := pop(vm)
			a := pop(vm)
			push(vm, a + b)
		case .Subtract:
			b := pop(vm)
			a := pop(vm)
			push(vm, a - b)
		case .Multiply:
			b := pop(vm)
			a := pop(vm)
			push(vm, a * b)
		case .Divide:
			b := pop(vm)
			a := pop(vm)
			push(vm, a / b)
		case .Return:
			fmt.printf("%v", pop(vm))
			return .Ok
		case:
			return .Compile_Error
		}
	}
}

push :: proc(vm: ^Virtual_Machine, v: Value) {
	vm.stack[vm.top] = v
	vm.top += 1
}
pop :: proc(vm: ^Virtual_Machine) -> Value {
	vm.top -= 1
	return vm.stack[vm.top]
}
