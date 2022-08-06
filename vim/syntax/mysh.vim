if exists("b:current_syntax")
	finish
endif

let b:current_syntax = "mysh"

syn keyword myshTypes var

syn keyword myshConditional if else while for in

syn keyword myshBoolean true false

syn keyword myshStatement return fn

syn keyword Todo TODO contained

" single chars + assignment counterpart
syn match myshOperator /[-+*/%<>=!]=\?/

" single chars without assignment

syn match myshOperator /|/

" double chars
syn match myshOperator /&&\|||/

" first identifier of the line is a call
syn match myshFnCall "^\s*[A-z0-9_]\+" contains=myshBuiltins

" first identifer after pipe is a call
" syn match myshFnCall "[A-z0-9_]\+" contained
syn match myshFnCall "[A-Za-z_][A-Za-z0-9_]*" contained

syn match myshFnCallPipe "|\s*[A-Za-z0-9_]\+" contains=myshBuiltins,myshOperator,Numberm,myshFnCall

" first identifier after left parens is a call
syn match myshFnCallParens "(\s*[A-Za-z0-9_]\+" contains=myshBuiltins,myshFnCall

" first identifier after assignment is a call
syn match myshFnCallAssign "=\s*[A-Za-z0-9_]\+" contains=myshBuiltins,myshFnCall,myshOperator,Number

" builtins have specific highlighting
syn keyword myshBuiltins print filter len append contained

syn region String start='"' end='"'

syn match Identifier "\$[A-Za-z0-9_]\+"

syn match Number "\<[0-9]\+"

syn region Comment start="#" end="$" contains=Todo

hi def link myshTypes Type
hi def link myshConditional Conditional
hi def link myshBoolean Boolean
hi def link myshStatement Statement
hi def link myshOperator Operator
hi def link myshFnCall Type
hi def link myshBuiltins Boolean
