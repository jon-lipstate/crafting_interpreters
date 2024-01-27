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
