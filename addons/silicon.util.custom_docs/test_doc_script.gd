##
# Some brief description.
# 
# A longer description. You can use most bbcode stuff in the docs.
# You can [b]bold[/b], [i]italicize[/i], [s]strikethrough[/s],
# [codeblock]
# var code = "block"
# [/codeblock]
# And so on.
extends ParallaxBackground
class_name CustomClass

signal some_signal

const A_CONST = 10

##
# This is foo.
var foo: Spatial

var bar: int ## This is bar.

##
# A method.
func method_a(a, b: int, c: Spatial) -> void:
	pass

##
# Another method.
func method_b() -> int:
	return 0
