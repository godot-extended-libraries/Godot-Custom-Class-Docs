tool
extends Reference

const GD_TYPES = [
	"", "bool", "int", "float",
	"string", "Vector2", "Rect2", "Vector3",
	"Transform2D", "Plane", "Quat", "AABB",
	"Basis", "Transform", "Color", "NodePath",
	"RID", "Object", "Dictionary", "Array",
	"PoolByteArray", "PoolIntArray", "PoolRealArray", "PoolStringArray",
	"PoolVector2Array", "PoolVector3Array", "PoolColorArray"
]

var editor_settings: EditorSettings
var theme: Theme
var class_list: Array

var title_color: Color
var text_color: Color
var headline_color: Color
var base_type_color: Color
var comment_color: Color
var symbol_color: Color
var value_color: Color
var qualifier_color: Color
var type_color: Color


func update_colors() -> void:
	title_color = theme.get_color("accent_color", "Editor")
	text_color = theme.get_color("default_color", "RichTextLabel")
	headline_color = theme.get_color("headline_color", "EditorHelp")
	base_type_color = title_color.linear_interpolate(text_color, 0.5)
	comment_color = text_color * Color(1, 1, 1, 0.6)
	symbol_color = comment_color
	value_color = text_color * Color(1, 1, 1, 0.6)
	qualifier_color = text_color * Color(1, 1, 1, 0.8)
	type_color = theme.get_color("accent_color", "Editor").linear_interpolate(text_color, 0.5)


func generate(name: String, base: String, script_path: String) -> Dictionary:
	var script: GDScript = load(script_path)
	var code_lines := script.source_code.split("\n")
	var doc := {
		name = name,
		base = base,
		brief = "Placeholder brief description.",
		description = """A full description. This is also just placeholder.""",
		methods = [],
		properties = [],
		constants = [],
		signals = [],
		enums = [],
		tutorials = []
	}
	
	for method in script.get_script_method_list():
		if method.name.begins_with("_"):
			continue
		
		var method_doc := {
			"name": method.name,
			"return_type": type_string(
				method["return"]["type"],
				method["return"]["class_name"]
			) if method["return"]["type"] != TYPE_NIL else "void",
			"return_enum": "",
			"args": [],
			"qualifiers": "",
			"description": ""
		}
		doc.methods.append(method_doc)
		
		for arg in method.args:
			method_doc.args.append({
				"name": arg.name,
				"default": "",
				"enumeration": "",
				"type": type_string(
					arg.type, 
					arg["class_name"]
				)
			})
	
	for property in script.get_script_property_list():
		if property.name.begins_with("_"):
			continue
		
		var property_doc := {
			"name": property.name,
			"default": property.name, # FIXME: Actual default
			"enumeration": "",
			"setter": "",
			"getter": "",
			"type": type_string(
				property.type,
				property["class_name"]
			),
			"description": ""
		}
		doc.properties.append(property_doc)
	
	for _signal in script.get_script_signal_list():
		if _signal.name.begins_with("_"):
			continue
		
		var signal_doc := {
			"name": _signal.name,
			"args": [],
			"description": ""
		}
		doc.signals.append(signal_doc)
		
		for arg in _signal.args:
			signal_doc.args.append({
				"name": arg.name,
				"type": type_string(
					arg.type, 
					arg["class_name"]
				)
			})
	
#	var comment_block := ""
#	var reading_block := false
#	for line in code_lines:
#		line = line.strip_edges()
#		if line.begins_with("##"):
#			reading_block = true
	
	return doc


func type_string(type: int, _class_name: String) -> String:
	if type == TYPE_OBJECT:
		return _class_name
	else:
		return GD_TYPES[type]


func add_type(p_type: String, p_enum: String, label: RichTextLabel):
	var t := p_type
	if t.empty():
		t = "void"
	var can_ref := (t != "void") or not p_enum.empty()
	
	if not p_enum.empty():
		if p_enum.split(".").size() > 1:
			t = p_enum.split(".")[1]
		else:
			t = p_enum.split(".")[0]
	
	var text_color := label.get_color("default_color", "RichTextLabel")
	var type_color := label.get_color("accent_color", "Editor").linear_interpolate(text_color, 0.5)
	label.push_color(type_color)
	if can_ref:
		if p_enum.empty():
			label.push_meta("#" + t) #class
		else:
			label.push_meta("$" + p_enum) #class
	label.add_text(t)
	if can_ref:
		label.pop()
	label.pop()


func add_method(method: Dictionary, overview: bool, label: RichTextLabel) -> void:
#	method_line[method.name] = label.get_line_count() - 2 #gets overridden if description
	var is_vararg: bool = method.qualifiers.find("vararg") != -1
	if overview:
		label.push_cell()
		label.push_align(RichTextLabel.ALIGN_RIGHT)
	
	add_type(method.return_type, method.return_enum, label)
	
	if overview:
		label.pop() #align
		label.pop() #cell
		label.push_cell()
	else:
		label.add_text(" ")
	
	if overview and method.description != "":
		label.push_meta("@method " + method.name)
	
	label.push_color(headline_color)
	add_text(method.name, label)
	label.pop()
	
	if overview and method.description != "":
		label.pop() #meta
	
	label.push_color(symbol_color)
	label.add_text("(")
	label.pop()
	
	for j in method.args.size():
		label.push_color(text_color)
		if j > 0:
			label.add_text(", ")
		
		add_text(method.args[j].name, label)
		label.add_text(": ")
		add_type(method.args[j].type, method.args[j].enumeration, label)
		if method.args[j].default != "":
			label.push_color(symbol_color)
			label.add_text(" = ")
			label.pop()
			label.push_color(value_color)
			add_text(method.args[j].default, label)
			label.pop()
		label.pop()
	
	if is_vararg:
		label.push_color(text_color)
		if method.args.size():
			label.add_text(", ")
		label.push_color(symbol_color)
		label.add_text("...")
		label.pop()
		label.pop()
	
	label.push_color(symbol_color)
	label.add_text(")")
	label.pop()
	if method.qualifiers != "":
		label.push_color(qualifier_color)
		label.add_text(" ")
		add_text(method.qualifiers, label)
		label.pop()
	
	if overview:
		label.pop() #cell


func add_text(bbcode: String, label: RichTextLabel) -> void:
	var base_path: String
	
	var doc_font := label.get_font("doc", "EditorFonts")
	var doc_bold_font := label.get_font("doc_bold", "EditorFonts")
	var doc_code_font := label.get_font("doc_source", "EditorFonts")
	var doc_kbd_font := label.get_font("doc_keyboard", "EditorFonts")
	
	var headline_color := label.get_color("headline_color", "EditorHelp")
	var accent_color := label.get_color("accent_color", "Editor")
	var property_color := label.get_color("property_color", "Editor")
	var link_color := accent_color.linear_interpolate(headline_color, 0.8)
	var code_color := accent_color.linear_interpolate(headline_color, 0.6)
	var kbd_color := accent_color.linear_interpolate(property_color, 0.6)
	
	bbcode = bbcode.dedent().replace("\t", "").replace("\r", "").strip_edges()
	
	bbcode = bbcode.replace("[csharp]", "[b]C#:[/b]\n[codeblock]")
	bbcode = bbcode.replace("[gdscript]", "[b]GDScript:[/b]\n[codeblock]")
	bbcode = bbcode.replace("[/csharp]", "[/codeblock]")
	bbcode = bbcode.replace("[/gdscript]", "[/codeblock]")
	
	# Remove codeblocks (they would be printed otherwise)
	bbcode = bbcode.replace("[codeblocks]\n", "")
	bbcode = bbcode.replace("\n[/codeblocks]", "")
	bbcode = bbcode.replace("[codeblocks]", "")
	bbcode = bbcode.replace("[/codeblocks]", "")
	
	# remove extra new lines around code blocks
	bbcode = bbcode.replace("[codeblock]\n", "[codeblock]")
	bbcode = bbcode.replace("\n[/codeblock]", "[/codeblock]")
	
	var tag_stack := []
	var code_tag := false

	var pos := 0
	while pos < bbcode.length():
		var brk_pos := bbcode.find("[", pos)
		if brk_pos < 0:
			brk_pos = bbcode.length()
		
		if brk_pos > pos:
			var text := bbcode.substr(pos, brk_pos - pos)
			if not code_tag:
				text = text.replace("\n", "\n\n")
			label.add_text(text)
		
		if brk_pos == bbcode.length():
			break #nothing else to add
		
		var brk_end := bbcode.find("]", brk_pos + 1)
		
		if brk_end == -1:
			var text := bbcode.substr(brk_pos, bbcode.length() - brk_pos)
			if not code_tag:
				text = text.replace("\n", "\n\n")
			label.add_text(text)
			break
		
		var tag := bbcode.substr(brk_pos + 1, brk_end - brk_pos - 1)
		
		if tag.begins_with("/"):
			var tag_ok = tag_stack.size() and tag_stack[0] == tag.substr(1, tag.length())
			if not tag_ok:
				label.add_text("[")
				pos = brk_pos + 1
				continue
			
			tag_stack.pop_front()
			pos = brk_end + 1
			if tag != "/img":
				label.pop()
				if code_tag:
					label.pop()
			code_tag = false
		
		elif code_tag:
			label.add_text("[")
			pos = brk_pos + 1
		
		elif tag.begins_with("method ") || tag.begins_with("member ") || tag.begins_with("signal ") || tag.begins_with("enum ") || tag.begins_with("constant "):
			var tag_end := tag.find(" ")
			var link_tag := tag.substr(0, tag_end)
			var link_target := tag.substr(tag_end + 1, tag.length()).lstrip(" ")
			
			label.push_color(link_color)
			label.push_meta("@" + link_tag + " " + link_target)
			label.add_text(link_target + ("()" if tag.begins_with("method ") else ""))
			label.pop()
			label.pop()
			pos = brk_end + 1
		
		elif class_list.has(tag):
			label.push_color(link_color)
			label.push_meta("#" + tag)
			label.add_text(tag)
			label.pop()
			label.pop()
			pos = brk_end + 1
		
		elif tag == "b":
			#use bold font
			label.push_font(doc_bold_font)
			pos = brk_end + 1
			tag_stack.push_front(tag)
		elif tag == "i":
			#use italics font
			label.push_color(headline_color)
			pos = brk_end + 1
			tag_stack.push_front(tag)
		elif tag == "code" || tag == "codeblock":
			#use monospace font
			label.push_font(doc_code_font)
			label.push_color(code_color)
			code_tag = true
			pos = brk_end + 1
			tag_stack.push_front(tag)
		elif tag == "kbd":
			#use keyboard font with custom color
			label.push_font(doc_kbd_font)
			label.push_color(kbd_color)
			code_tag = true # though not strictly a code tag, logic is similar
			pos = brk_end + 1
			tag_stack.push_front(tag)
		elif tag == "center":
			#align to center
			label.push_paragraph(RichTextLabel.ALIGN_CENTER, Control.TEXT_DIRECTION_AUTO, "")
			pos = brk_end + 1
			tag_stack.push_front(tag)
		elif tag == "br":
			#force a line break
			label.add_newline()
			pos = brk_end + 1
		elif tag == "u":
			#use underline
			label.push_underline()
			pos = brk_end + 1
			tag_stack.push_front(tag)
		elif tag == "s":
			#use strikethrough
			label.push_strikethrough()
			pos = brk_end + 1
			tag_stack.push_front(tag)
		elif tag == "url":
			var end := bbcode.find("[", brk_end)
			if end == -1:
				end = bbcode.length()
			var url = bbcode.substr(brk_end + 1, end - brk_end - 1)
			label.push_meta(url)
			
			pos = brk_end + 1
			tag_stack.push_front(tag)
		elif tag.begins_with("url="):
			var url := tag.substr(4, tag.length())
			label.push_meta(url)
			pos = brk_end + 1
			tag_stack.push_front("url")
		elif tag == "img":
			var end := bbcode.find("[", brk_end)
			if end == -1:
				end = bbcode.length()
			var image := bbcode.substr(brk_end + 1, end - brk_end - 1)
			var texture := load(base_path.plus_file(image)) as Texture
			if texture:
				label.add_image(texture)
			
			pos = end
			tag_stack.push_front(tag)
		elif tag.begins_with("color="):
			var col := tag.substr(6, tag.length())
			var color := Color(col)
			label.push_color(color)
			pos = brk_end + 1
			tag_stack.push_front("color")
		
		elif tag.begins_with("font="):
			var fnt := tag.substr(5, tag.length())
			var font := load(base_path.plus_file(fnt)) as Font
			if font.is_valid():
				label.push_font(font)
			else:
				label.push_font(doc_font)
			
			pos = brk_end + 1
			tag_stack.push_front("font")
		
		else:
			label.add_text("[") #ignore
			pos = brk_pos + 1


func sort_methods(a: Dictionary, b: Dictionary) -> bool:
	return a.name < b.name
