package crafting_interpeters
import "core:mem"
import "core:fmt"
import "core:strings"
Obj :: struct {
	type: Obj_Type,
	next: ^Obj,
}
Obj_Type :: enum {
	String,
}

Obj_String :: struct {
	obj: Obj, // must be in first position
	str: string,
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
copy_string :: proc(s: string) -> ^Obj_String {
	os := new(Obj_String)
	os.str = strings.clone(s)
	os.obj.type = .String
	// allocate_object
	os.obj.next = vm.objects
	vm.objects = transmute(^Obj)os
	return os
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
	conc := strings.concatenate({a.str, b.str})
}
