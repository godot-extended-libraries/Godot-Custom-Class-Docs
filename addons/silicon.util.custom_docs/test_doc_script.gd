## Some brief description.
##
## A longer description. You can use most bbcode stuff in the docs.
## You can [b]bold[/b], [i]italicize[/i], [s]strikethrough[/s],
## [codeblock]
## var code = "block"
## [/codeblock]
## And so on.
class_name CustomControlThing
extends Control

## A custom signal that's never emitted 'cause it's just an example.
signal some_signal(param_a, param_b)

enum Enumerators {
	ENUM_A,
	ENUM_B,
	ENUM_C
}

## This is a constant.
const A_CONST = 10

## This is foo.
var foo: Spatial

var bar: int ## This is bar.

## @params a, b, c
## A method.
func method_a(a, b: int, c: Spatial) -> void:
	pass

## Another method.
func method_b() -> int:
	return 0

## @virtual
## A virtual method to be overwriiten.
func _virtual_func() -> void:
	pass
