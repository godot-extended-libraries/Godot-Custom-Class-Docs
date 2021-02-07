tool
extends Reference

const _GD_TYPES = [
	"", "bool", "int", "float",
	"String", "Vector2", "Rect2", "Vector3",
	"Transform2D", "Plane", "Quat", "AABB",
	"Basis", "Transform", "Color", "NodePath",
	"RID", "Object", "Dictionary", "Array",
	"PoolByteArray", "PoolIntArray", "PoolRealArray", "PoolStringArray",
	"PoolVector2Array", "PoolVector3Array", "PoolColorArray"
]


func generate(name: String, base: String, script_path: String) -> ClassDocItem:
	var script: GDScript = load(script_path)
	var code_lines := script.source_code.split("\n")
	var doc := ClassDocItem.new({
		name = name,
		base = base
	})
	
	for method in script.get_script_method_list():
		if method.name.begins_with("_"):
			continue
		doc.methods.append(_create_method_doc(method.name, script, method))
	
	for property in script.get_script_property_list():
		if property.name.begins_with("_"):
			continue
		doc.properties.append(_create_property_doc(property.name, script, property))
	
	for _signal in script.get_script_signal_list():
		var signal_doc := SignalDocItem.new({
			"name": _signal.name
		})
		doc.signals.append(signal_doc)
		
		for arg in _signal.args:
			signal_doc.args.append(ArgumentDocItem.new({
				"name": arg.name,
				"type": _type_string(
					arg.type, 
					arg["class_name"]
				) if arg.type != TYPE_NIL else "Variant"
			}))
	
	for constant in script.get_script_constant_map():
		doc.constants.append(ConstantDocItem.new({
			"name": constant,
			"value": script.get_script_constant_map()[constant]
		}))
	
	var comment_block := ""
	var annotations := {}
	var reading_block := false
	for line in code_lines:
		var indented: bool = line.begins_with(" ") or line.begins_with("\t")
		if line.begins_with("##"):
			reading_block = true
		else:
			reading_block = false
			comment_block = comment_block.trim_suffix("\n")
		
		if line.find("##") != -1 and not reading_block:
			comment_block = line.right(line.find("##") + 2)
		
		if reading_block:
			if line.begins_with("## "):
				line = line.trim_prefix("## ")
			else:
				line = line.trim_prefix("##")
			if line.begins_with("@"):
				var annote: Array = line.split(" ", true, 1)
				annotations[annote[0]] = null if annote.size() == 1 else annote[1]
			else:
				comment_block += line + "\n"
			
		elif not comment_block.empty():
			if line.begins_with("extends") or line.begins_with("tool") or line.begins_with("class_name"):
				if annotations.has("@doc-ignore"):
					return null
				var doc_split = comment_block.split("\n", true, 1)
				doc.brief = doc_split[0]
				if doc_split.size() == 2:
					doc.description = doc_split[1]
				
			elif line.find("func ") != -1 and not indented:
				var regex := RegEx.new()
				regex.compile("func ([a-zA-Z0-9_]+)")
				var method := regex.search(line).get_string(1)
				var method_doc := doc.get_method_doc(method)
				
				if not method_doc and method:
					method_doc = _create_method_doc(method, script)
					doc.methods.append(method_doc)
				
				if method_doc:
					if annotations.has("@params"):
						var params = annotations["@params"].split(",")
						for i in min(params.size(), method_doc.args.size()):
							method_doc.args[i].name = params[i]
					if annotations.has("@param-types"):
						var params = annotations["@param-types"].split(",")
						for i in min(params.size(), method_doc.args.size()):
							method_doc.args[i].type = params[i]
					if annotations.has("@returns"):
						method_doc.return_type = annotations["@returns"]
					method_doc.is_virtual = annotations.has("@virtual")
					method_doc.description = comment_block
				
			elif line.find("var ") != -1 and not indented:
				var regex := RegEx.new()
				regex.compile("var ([a-zA-Z0-9_]+)")
				var prop := regex.search(line).get_string(1)
				var prop_doc := doc.get_property_doc(prop)
				
				if not prop_doc and prop:
					prop_doc = _create_property_doc(prop, script)
					doc.properties.append(prop_doc)
				
				if prop_doc:
					if annotations.has("@setter"):
						prop_doc.setter = annotations["@setter"]
					if annotations.has("@getter"):
						prop_doc.getter = annotations["@getter"]
					prop_doc.description = comment_block
				
			elif line.find("signal") != -1 and not indented:
				var regex := RegEx.new()
				regex.compile("signal ([a-zA-Z0-9_]+)")
				var signl := regex.search(line).get_string(1)
				var signal_doc := doc.get_signal_doc(signl)
				if signal_doc:
					signal_doc.description = comment_block
				
			elif line.find("const") != -1 and not indented:
				var regex := RegEx.new()
				regex.compile("const ([a-zA-Z0-9_]+)")
				var constant := regex.search(line).get_string(1)
				var const_doc := doc.get_constant_doc(constant)
				if const_doc:
					const_doc.description = comment_block
			
			
			
			comment_block = ""
			annotations.clear()
	
	return doc


func _create_method_doc(name: String, script: Script = null, method := {}) -> MethodDocItem:
	if method.empty():
		var methods := script.get_script_method_list()
		for m in methods:
			if m.name == name:
				method = m
				break
	
	var method_doc := MethodDocItem.new({
		"name": method.name,
		"return_type": _type_string(
			method["return"]["type"],
			method["return"]["class_name"]
		) if method["return"]["type"] != TYPE_NIL else "void",
	})
	for arg in method.args:
		method_doc.args.append(ArgumentDocItem.new({
			"name": arg.name,
			"type": _type_string(
				arg.type, 
				arg["class_name"]
			) if arg.type != TYPE_NIL else "Variant"
		}))
	return method_doc


func _create_property_doc(name: String, script: Script = null, property := {}) -> PropertyDocItem:
	if property.empty():
		var properties := script.get_script_property_list()
		for p in properties:
			if p.name == name:
				property = p
				break
	
	var property_doc := PropertyDocItem.new({
		"name": property.name,
		"type": _type_string(
			property.type,
			property["class_name"]
		) if property.type != TYPE_NIL else "Variant"
	})
	return property_doc


func _type_string(type: int, _class_name: String) -> String:
	if type == TYPE_OBJECT:
		return _class_name
	else:
		return _GD_TYPES[type]
