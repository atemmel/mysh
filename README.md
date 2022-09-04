# mysh

### todo:

* astgen
  * indexing + slicing

* interpreter
  * type system
    * float
    * ~~struct/table/dict~~
		* nested tables
  * proper error messages
  * indexing + slicing
  * refcounting instead of copying everything all the time

### to have:
 * type conversions `(newtype $variable)`(?)
 * repl highlighting

### to maybe have:
 * null/nil/none-esque(?)
 * `fn` type: `var func = $print`(?)
 * type annotations
 * (some) semantic analysis

### tofix:
 * repl symtable
 * better repl reader (history, search)

### ideas:

redirection syntax (to not conflict with logical operators)

```sh
ls |> myfile.txt
```

pipe assign operator

```sh
$numbers |= append 6

# is equivalent to

$numbers = $numbers | append 6
```
