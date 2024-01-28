package crafting_interpeters

Obj :: struct {
	type: Obj_Type,
}
Obj_Type :: enum {
	String,
}

Obj_String :: struct {
	obj: Obj, // must be in first position
	str: string,
}
is_string :: proc(obj: ^Obj) -> bool {
	return obj.type == .String
}
to_obj :: proc(obj: ^$T) -> ^Obj {
	return transmute(^Obj)obj
}

is_obj_type :: proc(val: Value, type: Obj_Type) -> bool {
	o, ok := val.(^Obj)
	return ok && o.type == type
}
