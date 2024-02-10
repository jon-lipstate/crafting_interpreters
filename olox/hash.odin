package crafting_interpeters
import "core:intrinsics"

MAX_TABLE_LOAD :: 0.75


Table :: struct {
	entries: []Entry,
	count:   int,
}

Entry :: struct {
	key:   u32,
	value: Value,
}

set :: proc(table: ^Table, key: u32, value: Value) -> (is_new: bool) {
	assert(key != 0, "Zero is a reserved Key")
	if table.count + 1 > int(f32(len(table.entries)) * MAX_TABLE_LOAD) {
		adjust_capacity(table, grow_capacity(len(table.entries)))
	}
	entry := find_entry(table.entries, key)
	is_new = entry == nil // FIXME - need check for K = 0??
	if is_new && entry.value == nil {table.count += 1}
	entry.key = key
	entry.value = value

	return
}

get :: proc(table: ^Table, key: u32) -> (value: Value, found: bool) {
	if table.count == 0 do return
	entry := find_entry(table.entries, key)
	if entry.key == 0 do return

	return entry.value, true
}

remove :: proc(table: ^Table, key: u32) -> (deleted: bool) {
	if table.count == 0 do return false
	entry := find_entry(table.entries, key)
	if entry.key == 0 do return false
	entry.value = true // Tombstone - this is not extensible as Value contains bool, $V may not in other use cases
	entry.key = 0
	return true
}

add_all :: proc(src, dest: ^Table) {
	for e in src.entries {
		if e.key == 0 do continue
		set(dest, e.key, e.value)
	}
}

find_entry :: proc(entries: []Entry, key: u32) -> ^Entry {
	index := key % u32(len(entries))
	tombstone: ^Entry
	for {
		entry := &entries[index]
		if entry.key == key {
			return entry
		} else {
			if entry.value == nil {
				return tombstone != nil ? tombstone : entry
			} else {
				tombstone = entry
			}
		}
		index = (index + 1) % u32(len(entries))
	}
}

adjust_capacity :: proc(table: ^Table, capacity: int) {
	entries := make([]Entry, capacity)
	table.count = 0
	if table.entries != nil {
		for entry in table.entries {
			if entry.key == 0 do continue
			dest := find_entry(entries, entry.key)
			dest.value = entry.value
			table.count += 1
		}
		delete(table.entries)
	}
	table.entries = entries
}

grow_capacity :: proc(current: int) -> int {
	return current * 2
}

find_string :: proc(tbl: ^Table, s: string, hash: u32) -> ^Obj_String {
	unimplemented()
}
