package crafting_interpeters
import "core:fmt"
import "core:mem"
import "core:strings"

Obj :: struct {
	type: Obj_Type,
	next: ^Obj,
}
Obj_Type :: enum {
	String,
}

Obj_String :: struct {
	obj:  Obj, // must be in first position
	hash: u32,
	str:  string,
}

allocate_object :: proc($T: typeid) -> ^T {
	obj := transmute(^Obj)reallocate(nil, Obj, 0, size_of(T))
	obj.next = vm.objects
	vm.objects = obj
	return transmute(^T)obj
}

allocate_string :: proc(str: string, s_hash: u32) -> ^Obj_String {
	obj := transmute(^Obj)allocate_object(Obj_String)
	obj.type = Obj_Type.String
	obj_str := transmute(^Obj_String)obj
	obj_str.str = str
	obj_str.hash = s_hash
	push_value(transmute(^Obj)obj_str)
	set(&vm.strings, obj_str.hash, 0)
	pop_value() // WHY???
	return obj_str
}

copy_string :: proc(str: string) -> ^Obj_String {
	hash := hash_string(str)
	interned := find_string(&vm.strings, str, hash)
	if interned != nil {return interned}

	heap_str, err := mem.alloc(size_of(u8) * len(str))
	sb := transmute([]u8)str

	mem.copy(heap_str, &sb[0], len(str))
	new_str := (transmute([^]u8)heap_str)[:len(str)]
	return allocate_string(string(new_str), hash)
}

is_string :: proc(val: Value) -> bool {
	obj, ok := val.(^Obj)
	if !ok do return false
	return obj.type == .String
}
to_obj :: proc(obj: ^$T) -> ^Obj {
	return transmute(^Obj)obj
}

is_obj_type :: proc(val: Value, type: Obj_Type) -> bool {
	o, ok := val.(^Obj)
	return ok && o.type == type
}

print_obj :: proc(obj: ^Obj) {
	switch obj.type {
	case .String:
		os := transmute(^Obj_String)obj
		fmt.printf("%s\n", os.str)
	}
}

concatenate :: proc() {
	b := transmute(^Obj_String)pop_value().(^Obj)
	a := transmute(^Obj_String)pop_value().(^Obj)
	new_str := transmute([^]u8)reallocate_slice(nil, 1, 0, len(a.str) + len(b.str))
	ab := transmute([]u8)a.str
	bb := transmute([]u8)b.str
	mem.copy(&new_str[0], &(ab)[0], len(a.str))
	mem.copy(&new_str[len(a.str)], &(bb)[0], len(b.str))

	result := take_string(string(new_str[:len(a.str) + len(b.str)]))
	pop_value()
	pop_value()

	push_value(transmute(^Obj)result)
}
// FNV-1a
hash_string :: proc(str: string) -> u32 {
	s_hash := u32(2166136261)
	for ch in (transmute([]u8)str) {
		s_hash ~= u32(ch)
		s_hash *= 16777619
	}
	return s_hash
}

take_string :: proc(str: string) -> ^Obj_String {
	s_hash := hash_string(str)
	interned := find_string(&vm.strings, str, s_hash)
	if interned != nil {
		delete(str)
		return interned
	}
	return allocate_string(str, s_hash)
}
