## The base class for every document exporter.
## @contribute https://placeholder_contribute.com
tool
extends Reference
class_name DocExporter

## @virtual
## @params doc
## @param-types ClassDocItem
## This function gets called to generate a document string from a [ClassDocItem].
func _generate(doc: ClassDocItem) -> String:
	return ""
