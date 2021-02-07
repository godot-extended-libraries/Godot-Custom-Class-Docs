## An object that contains documentation data about a class.
## @contribute https://placeholder_contribute.com
tool
extends DocItem
class_name ClassDocItem

var base := "" ## The base class this class extends from.
var brief := "" ## A brief description of the class.
var description := "" ## A full description of the class.

var methods := [] ## A list of method documents.
var properties := [] ## A list of property documents.
var signals := [] ## A list of signal documents.
var constants := [] ## A list of constant documents, including enumerators.

var tutorials := [] ## A list of tutorials that helps to understand this class.

var contriute_url := "" ## A link to where the user can contribute to the class' documentation.

func _init(args := {}) -> void:
	for arg in args:
		set(arg, args[arg])

## @params name
## @returns MethodDocItem
## Gets a method document called [code]name[/code].
func get_method_doc(name: String) -> MethodDocItem:
	for doc in methods:
		if doc.name == name:
			return doc
	return null

## @params name
## @returns PropertyDocItem
## Gets a signal document called [code]name[/code].
func get_property_doc(name: String) -> PropertyDocItem:
	for doc in properties:
		if doc.name == name:
			return doc
	return null

## @params name
## @returns SignalDocItem
## Gets a signal document called [code]name[/code].
func get_signal_doc(name: String) -> SignalDocItem:
	for doc in signals:
		if doc.name == name:
			return doc
	return null

## @params name
## @returns ConstantlDocItem
## Gets a signal document called [code]name[/code].
func get_constant_doc(name: String) -> ConstantDocItem:
	for doc in constants:
		if doc.name == name:
			return doc
	return null
