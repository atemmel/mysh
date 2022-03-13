if exists("b:current_syntax")
	finish
endif

let b:current_syntax = "mysh"

syn keyword Keyword var if else

syn keyword Keyword true false

syn region String start='"' end='"'

syn region Comment start="#" end="$"
