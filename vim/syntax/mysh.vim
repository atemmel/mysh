if exists("b:current_syntax")
	finish
endif

let b:current_syntax = "mysh"

syn keyword Keyword var

syn keyword Conditional if else

syn keyword Keyword true false

syn region String start='"' end='"'

syn match Identifier "$[a-zA-Z0-9_]\+"

syn region Comment start="#" end="$"
