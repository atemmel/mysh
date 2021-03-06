if exists("b:current_syntax")
	finish
endif

let b:current_syntax = "mysh"

syn keyword Keyword var fn

syn keyword Conditional if else while for in

syn keyword Keyword true false return

syn region String start='"' end='"'

syn match Identifier "$[a-zA-Z0-9_]\+"

syn match Number "[0-9]\+"

syn region Comment start="#" end="$"
