tool
extends EditorPlugin

var script_editor: ScriptEditor

var search_help: AcceptDialog
var tree: Tree

var script_list: ItemList
var script_tabs: TabContainer

var custom_classes := {}
#	"CustomObject": {
#		tree_item = null,
#		extend = "Object",
#		brief = "custom thingy...",
#		description = """This is a longer description.
#I'm sure this'll work [b]bold[/b], [i]italic[/i], [u]underline[/u] and [s]strikethrough[/s].
#[codeblock]
#this should look like a code block.
#[/codeblock]
#[img]res:#icon.png[/img]
#"""
#	},
#	"CustomSpatial": {
#		tree_item = null,
#		extend = "Spatial",
#		brief = "custom spatial thingy..."
#	},
#	"CustomCanvasItem": {
#		tree_item = null,
#		extend = "CanvasItem",
#		brief = "custom canvas thingy..."
#	}
#}

var custom_doc_panels := {}

var docs_utils := preload("class_docs_utils.gd").new()

var theme := get_editor_interface().get_base_control().theme
var disabled_color := theme.get_color("disabled_font_color", "Editor")

var doc_font := theme.get_font("doc", "EditorFonts")
var doc_bold_font := theme.get_font("doc_bold", "EditorFonts")
var doc_title_font := theme.get_font("doc_title", "EditorFonts")
var doc_code_font := theme.get_font("doc_source", "EditorFonts")

var title_color := theme.get_color("accent_color", "Editor")
var text_color := theme.get_color("default_color", "RichTextLabel")
var headline_color := theme.get_color("headline_color", "EditorHelp")
var base_type_color := title_color.linear_interpolate(text_color, 0.5)
var comment_color := text_color * Color(1, 1, 1, 0.6)
var symbol_color := comment_color
var value_color := text_color * Color(1, 1, 1, 0.6)
var qualifier_color := text_color * Color(1, 1, 1, 0.8)
var type_color := theme.get_color("accent_color", "Editor").linear_interpolate(text_color, 0.5)

var timer := Timer.new()

func _enter_tree() -> void:
	script_editor = get_editor_interface().get_script_editor()
	script_list = _find_node_by_class(script_editor, "ItemList")
	script_tabs = _get_child_chain(script_editor, [0, 1, 1])
	search_help = _find_node_by_class(script_editor, "EditorHelpSearch")
	tree = _find_node_by_class(search_help, "Tree")
	search_help.connect("go_to_help", self, "_on_SearchHelp_go_to_help")
	
	docs_utils.theme = theme
	docs_utils.editor_settings = get_editor_interface().get_editor_settings()
	docs_utils.update_colors()
	# TODO: Add class_list to docs utils
	
	add_child(timer)
	timer.wait_time = 0.5
	timer.one_shot = false
	timer.start()
	timer.connect("timeout", self, "_on_Timer_timeout")


func _process(delta: float) -> void:
	if not tree:
		return
	
	for name in custom_classes:
		_process_custom_class_item(custom_classes[name])
	
	for i in script_list.get_item_count():
		var icon := script_list.get_item_icon(i)
		var text := script_list.get_item_text(i)
		if icon != theme.get_icon("Help", "EditorIcons"):
			continue
		
		var editor_help = script_tabs.get_child(script_list.get_item_metadata(i))
		if text.empty():
			script_list.set_item_text(i, editor_help.name)
			script_list.set_item_tooltip(i, editor_help.name + " Class Reference")
			text = editor_help.name
			if text in custom_classes:
				_generate_doc(custom_classes[text], editor_help.get_child(0))


func _process_custom_class_item(_class: Dictionary) -> void:
	# Create tree item if it's not their.
#	print("+: " + str(_class.tree_item))
	if _class.tree_item:
		return
	
	var parent := tree.get_root()
	if not parent:
		return
	
	# Get inheritance chain of the class.
	var inherit_chain = [_class.base]
	while not inherit_chain[-1].empty():
		inherit_chain.append(ClassDB.get_parent_class(inherit_chain[-1]))
	inherit_chain.pop_back()
	inherit_chain.invert()
	
	# Find the tree item the class should be under.
	for inherit in inherit_chain:
		var failed := true
		var child := parent.get_children()
		while child and child.get_parent() == parent:
			if child.get_text(0) == inherit:
				parent = child
				failed = false
				break
			child = child.get_next()
		
		if failed:
			parent = tree.create_item(parent)
			parent.set_text(0, inherit)
			parent.set_text(1, "Class")
			parent.set_icon(0, _get_class_icon(inherit))
			parent.set_custom_color(0, disabled_color)
			parent.set_custom_color(1, disabled_color)
			parent.set_metadata(0, "class_name:" + inherit)
	
	var item := tree.create_item(parent)
	item.set_icon(0, _get_class_icon("Object"))
	item.set_text(0, _class.name)
	item.set_text(1, "Class")
	item.set_tooltip(0, _class.brief)
	item.set_tooltip(1, _class.brief)
	item.set_metadata(0, "class_name:" + _class.name)
	_class.tree_item = item


func _on_SearchHelp_go_to_help(data: String) -> void:
#	return
	print(data)


func _on_Timer_timeout() -> void:
	var classes: Array = ProjectSettings.get("_global_script_classes")
	var docs := {}
	for _class in classes:
		var doc := docs_utils.generate(_class["class"], _class["base"], _class["path"])
		docs[doc.name] = doc
		doc.tree_item = null
		if doc.name in custom_classes:
			doc.tree_item = custom_classes[doc.name].tree_item
		custom_classes[doc.name] = doc
	
	var queue_delete := []
	for name in custom_classes:
		if not name in docs:
			if custom_classes[name].tree_item:
				custom_classes[name].tree_item.free()
			queue_delete.append(name)
	for delete in queue_delete:
		custom_classes.erase(delete)


func _generate_doc(doc_data: Dictionary, text_label: RichTextLabel) -> void:
	text_label.visible = true
	text_label.clear()
	
	# Class Name
	text_label.push_font(doc_title_font)
	text_label.push_color(title_color)
	text_label.add_text("Class: ")
	text_label.push_color(headline_color)
	docs_utils.add_text(doc_data.name, text_label)
	text_label.pop()
	text_label.pop()
	text_label.pop()
	text_label.add_text("\n")
	
	# Ascendance
	if doc_data.base != "":
		text_label.push_color(title_color)
		text_label.push_font(doc_font)
		text_label.add_text("Inherits: ")
		text_label.pop()
		
		var inherits = doc_data.base
		
		while inherits != "":
			docs_utils.add_type(inherits, "", text_label)
			inherits = ClassDB.get_parent_class(inherits)
			
			if inherits != "":
				text_label.add_text(" < ")
		
		text_label.pop()
		text_label.add_text("\n")
	
	# Descendents
	var found := false
	var prev := false
	for name in custom_classes:
		if custom_classes[name].base == doc_data.name:
			if not found:
				text_label.push_color(title_color)
				text_label.push_font(doc_font)
				text_label.add_text("Inherited by: ")
				text_label.pop()
				found = true
			
			if prev:
				text_label.add_text(" , ")
			
			docs_utils.add_type(name, "", text_label)
			prev = true
	if found:
		text_label.pop()
		text_label.add_text("\n")
	
	text_label.add_text("\n")
	text_label.add_text("\n")
	
	# Brief description
	if doc_data.brief != "":
		text_label.push_color(text_color)
		text_label.push_font(doc_bold_font)
		text_label.push_indent(1)
		docs_utils.add_text(doc_data.brief, text_label)
		text_label.pop()
		text_label.pop()
		text_label.pop()
		text_label.add_text("\n")
		text_label.add_text("\n")
		text_label.add_text("\n")
	
	if doc_data.description != "":
		text_label.push_color(title_color)
		text_label.push_font(doc_title_font)
		text_label.add_text("Description")
		text_label.pop()
		text_label.pop()
		
		text_label.add_text("\n")
		text_label.add_text("\n")
		text_label.push_color(text_color)
		text_label.push_font(doc_font)
		text_label.push_indent(1)
		docs_utils.add_text(doc_data.description, text_label)
		text_label.pop()
		text_label.pop()
		text_label.pop()
		text_label.add_text("\n")
		text_label.add_text("\n")
		text_label.add_text("\n")
	
	# Online tutorials
	if doc_data.tutorials.size():
		text_label.push_color(title_color)
		text_label.push_font(doc_title_font)
		text_label.add_text("Online Tutorials")
		text_label.pop()
		text_label.pop()
		
		text_label.push_indent(1)
		text_label.push_font(doc_code_font)
		text_label.add_text("\n")
		
		for tutorial in doc_data.tutorials:
			var link: String = tutorial.link
			var linktxt: String = link if tutorial.title.empty() else tutorial.title
			var seppos := linktxt.find("//")
			if seppos != -1:
				linktxt = link.right(seppos + 2)
			
			text_label.push_color(symbol_color)
			text_label.append_bbcode("[url=" + link + "]" + linktxt + "[/url]")
			text_label.pop()
			text_label.add_text("\n")
		
		text_label.pop()
		text_label.pop()
		text_label.add_text("\n")
		text_label.add_text("\n")
	
	# Properties overview
	var skip_methods := []
	var property_descr := false
	
	if doc_data.properties.size():
#		section_line.push_back(Pair<String, int>(TTR("Properties"), text_label.get_line_count() - 2))
		text_label.push_color(title_color)
		text_label.push_font(doc_title_font)
		text_label.add_text("Properties")
		text_label.pop()
		text_label.pop()
		
		text_label.add_text("\n")
		text_label.push_font(doc_code_font)
		text_label.push_indent(1)
		text_label.push_table(2)
		text_label.set_table_column_expand(1, true, 1)
		
		for property in doc_data.properties:
#			property_line[doc_data.properties[i].name] = text_label.get_line_count() - 2 #gets overridden if description
			text_label.push_cell()
			text_label.push_align(RichTextLabel.ALIGN_RIGHT)
			text_label.push_font(doc_code_font)
			docs_utils.add_type(property.type, property.enumeration, text_label)
			text_label.pop()
			text_label.pop()
			text_label.pop()
			
			var describe := false
			
			if property.setter != "":
				skip_methods.append(property.setter)
				describe = true
			if property.getter != "":
				skip_methods.append(property.getter)
				describe = true
			
			if property.description != "":
				describe = true
			
			text_label.push_cell()
			text_label.push_font(doc_code_font)
			text_label.push_color(headline_color)
			
			if describe:
				text_label.push_meta("@member " + property.name)
			
			docs_utils.add_text(property.name, text_label)
			
			if describe:
				text_label.pop()
				property_descr = true
			
			if property.default != "":
				text_label.push_color(symbol_color)
				text_label.add_text(" [default: ")
				text_label.pop()
				text_label.push_color(value_color)
				docs_utils.add_text(property.default, text_label)
				text_label.pop()
				text_label.push_color(symbol_color)
				text_label.add_text("]")
				text_label.pop()

			text_label.pop()
			text_label.pop()
			text_label.pop()

		text_label.pop() #table
		text_label.pop()
		text_label.pop() # font
		text_label.add_text("\n")
		text_label.add_text("\n")

	# Methods overview
	var method_descr := false
	var sort_methods: bool = get_editor_interface().get_editor_settings().get("text_editor/help/sort_functions_alphabetically")
	var methods := []
	
	for method in doc_data.methods:
		if skip_methods.has(method.name):
			if method.args.size() == 0 or (method.args.size() == 1 and method.return_type == "void"):
				continue
		methods.push_back(method)
	
	if methods.size():
		if sort_methods:
			methods.sort_custom(docs_utils, "sort_methods")
#		section_line.push_back(Pair<String, int>(TTR("Methods"), text_label.get_line_count() - 2))
		text_label.push_color(title_color)
		text_label.push_font(doc_title_font)
		text_label.add_text("Methods")
		text_label.pop()
		text_label.pop()
		
		text_label.add_text("\n")
		text_label.push_font(doc_code_font)
		text_label.push_indent(1)
		text_label.push_table(2)
		text_label.set_table_column_expand(1, true, 1)
		
		var any_previous := false
		for _pass in 2:
			var m := []
			for i in methods.size():
				var q: String = methods[i].qualifiers
				if (_pass == 0 and q.find("virtual") != -1) or (_pass == 1 and q.find("virtual") == -1):
					m.push_back(methods[i])
			
			if any_previous and not m.empty():
				text_label.push_cell()
				text_label.pop() #cell
				text_label.push_cell()
				text_label.pop() #cell
			
			var group_prefix := ""
			for i in m.size():
				var new_prefix: String = m[i].name.substr(0, 3)
				var is_new_group := false
				
				if i < m.size() - 1 and new_prefix == m[i + 1].name.substr(0, 3) and new_prefix != group_prefix:
					is_new_group = i > 0
					group_prefix = new_prefix
				elif group_prefix != "" and new_prefix != group_prefix:
					is_new_group = true
					group_prefix = ""
				
				if is_new_group and _pass == 1:
					text_label.push_cell()
					text_label.pop() #cell
					text_label.push_cell()
					text_label.pop() #cell
				
				if m[i].description != "":
					method_descr = true
				
				docs_utils.add_method(m[i], true, text_label)
			
			any_previous = !m.empty()
		
		text_label.pop() #table
		text_label.pop()
		text_label.pop() # font
		text_label.add_text("\n")
		text_label.add_text("\n")

	# Theme properties
#	if doc_data.theme_properties.size():
#
#		section_line.push_back(Pair<String, int>(TTR("Theme Properties"), text_label.get_line_count() - 2))
#		text_label.push_color(title_color)
#		text_label.push_font(doc_title_font)
#		text_label.add_text(TTR("Theme Properties"))
#		text_label.pop()
#		text_label.pop()
#
#		text_label.push_indent(1)
#		text_label.push_table(2)
#		text_label.set_table_column_expand(1, 1)
#
#		for int i = 0 i < doc_data.theme_properties.size() i++:
#
#			theme_property_line[doc_data.theme_properties[i].name] = text_label.get_line_count() - 2 #gets overridden if description
#
#			text_label.push_cell()
#			text_label.push_align(RichTextLabel.ALIGN_RIGHT)
#			text_label.push_font(doc_code_font)
#			//docs_utils.add_type(doc_data.theme_properties[i].type)
#			text_label.pop()
#			text_label.pop()
#			text_label.pop()
#
#			text_label.push_cell()
#			text_label.push_font(doc_code_font)
#			text_label.push_color(headline_color)
#			//docs_utils.add_text(doc_data.theme_properties[i].name)
#			text_label.pop()
#
#			if doc_data.theme_properties[i].default != "":
#				text_label.push_color(symbol_color)
#				text_label.add_text(" [" + TTR("default:") + " ")
#				text_label.pop()
#				text_label.push_color(value_color)
#				//docs_utils.add_text(_fix_constant(doc_data.theme_properties[i].default))
#				text_label.pop()
#				text_label.push_color(symbol_color)
#				text_label.add_text("]")
#				text_label.pop()
#			}
#
#			text_label.pop()
#
#			if doc_data.theme_properties[i].description != "":
#				text_label.push_font(doc_font)
#				text_label.add_text("  ")
#				text_label.push_color(comment_color)
#				//docs_utils.add_text(doc_data.theme_properties[i].description)
#				text_label.pop()
#				text_label.pop()
#			}
#			text_label.pop() # cell
#		}
#
#		text_label.pop() # table
#		text_label.pop()
#		text_label.add_text("\n")
#		text_label.add_text("\n")
#	}
#
#	# Signals
#	if doc_data.signals.size():
#
#		if sort_methods:
#			doc_data.signals.sort()
#		}
#
#		section_line.push_back(Pair<String, int>(TTR("Signals"), text_label.get_line_count() - 2))
#		text_label.push_color(title_color)
#		text_label.push_font(doc_title_font)
#		text_label.add_text(TTR("Signals"))
#		text_label.pop()
#		text_label.pop()
#
#		text_label.add_text("\n")
#		text_label.add_text("\n")
#
#		text_label.push_indent(1)
#
#		for int i = 0 i < doc_data.signals.size() i++:
#
#			signal_line[doc_data.signals[i].name] = text_label.get_line_count() - 2 #gets overridden if description
#			text_label.push_font(doc_code_font) # monofont
#			text_label.push_color(headline_color)
#			//docs_utils.add_text(doc_data.signals[i].name)
#			text_label.pop()
#			text_label.push_color(symbol_color)
#			text_label.add_text("(")
#			text_label.pop()
#			for int j = 0 j < doc_data.signals[i].args.size() j++:
#				text_label.push_color(text_color)
#				if j > 0)
#					text_label.add_text(", ")
#
#				//docs_utils.add_text(doc_data.signals[i].args[j].name)
#				text_label.add_text(": ")
#				//docs_utils.add_type(doc_data.signals[i].args[j].type)
#				if doc_data.signals[i].args[j].default != "":
#
#					text_label.push_color(symbol_color)
#					text_label.add_text(" = ")
#					text_label.pop()
#					//docs_utils.add_text(doc_data.signals[i].args[j].default)
#				}
#
#				text_label.pop()
#			}
#
#			text_label.push_color(symbol_color)
#			text_label.add_text(")")
#			text_label.pop()
#			text_label.pop() # end monofont
#			if doc_data.signals[i].description != "":
#
#				text_label.push_font(doc_font)
#				text_label.push_color(comment_color)
#				text_label.push_indent(1)
#				//docs_utils.add_text(doc_data.signals[i].description)
#				text_label.pop() # indent
#				text_label.pop()
#				text_label.pop() # font
#			}
#			text_label.add_text("\n")
#			text_label.add_text("\n")
#		}
#
#		text_label.pop()
#		text_label.add_text("\n")
#	}
#
#	# Constants and enums
#	if doc_data.constants.size():
#
#		Map<String, Vector<DocData.ConstantDoc> > enums
#		Vector<DocData.ConstantDoc> constants
#
#		for int i = 0 i < doc_data.constants.size() i++:
#
#			if doc_data.constants[i].enumeration != String():
#				if !enums.has(doc_data.constants[i].enumeration):
#					enums[doc_data.constants[i].enumeration] = Vector<DocData.ConstantDoc>()
#				}
#
#				enums[doc_data.constants[i].enumeration].push_back(doc_data.constants[i])
#			} else {
#
#				constants.push_back(doc_data.constants[i])
#			}
#		}
#
#		# Enums
#		if enums.size():
#
#			section_line.push_back(Pair<String, int>(TTR("Enumerations"), text_label.get_line_count() - 2))
#			text_label.push_color(title_color)
#			text_label.push_font(doc_title_font)
#			text_label.add_text(TTR("Enumerations"))
#			text_label.pop()
#			text_label.pop()
#			text_label.push_indent(1)
#
#			text_label.add_text("\n")
#
#			for Map<String, Vector<DocData.ConstantDoc> >.Element *E = enums.front() E E = E->next():
#
#				enum_line[E->key()] = text_label.get_line_count() - 2
#
#				text_label.push_color(title_color)
#				text_label.add_text("enum  ")
#				text_label.pop()
#				text_label.push_font(doc_code_font)
#				String e = E->key()
#				if (e.get_slice_count(".") > 1) and (e.get_slice(".", 0) == edited_class):
#					e = e.get_slice(".", 1)
#				}
#
#				text_label.push_color(headline_color)
#				text_label.add_text(e)
#				text_label.pop()
#				text_label.pop()
#				text_label.push_color(symbol_color)
#				text_label.add_text(":")
#				text_label.pop()
#				text_label.add_text("\n")
#
#				text_label.push_indent(1)
#				Vector<DocData.ConstantDoc> enum_list = E->get()
#
#				Map<String, int> enumValuesContainer
#				int enumStartingLine = enum_line[E->key()]
#
#				for int i = 0 i < enum_list.size() i++:
#					if doc_data.name == "@GlobalScope")
#						enumValuesContainer[enum_list[i].name] = enumStartingLine
#
#					# Add the enum constant line to the constant_line map so we can locate it as a constant
#					constant_line[enum_list[i].name] = text_label.get_line_count() - 2
#
#					text_label.push_font(doc_code_font)
#					text_label.push_color(headline_color)
#					//docs_utils.add_text(enum_list[i].name)
#					text_label.pop()
#					text_label.push_color(symbol_color)
#					text_label.add_text(" = ")
#					text_label.pop()
#					text_label.push_color(value_color)
#					//docs_utils.add_text(_fix_constant(enum_list[i].value))
#					text_label.pop()
#					text_label.pop()
#					if enum_list[i].description != "":
#						text_label.push_font(doc_font)
#						#text_label.add_text("  ")
#						text_label.push_indent(1)
#						text_label.push_color(comment_color)
#						//docs_utils.add_text(enum_list[i].description)
#						text_label.pop()
#						text_label.pop()
#						text_label.pop() # indent
#						text_label.add_text("\n")
#					}
#
#					text_label.add_text("\n")
#				}
#
#				if doc_data.name == "@GlobalScope")
#					enum_values_line[E->key()] = enumValuesContainer
#
#				text_label.pop()
#
#				text_label.add_text("\n")
#			}
#
#			text_label.pop()
#			text_label.add_text("\n")
#		}
#
#		# Constants
#		if constants.size():
#
#			section_line.push_back(Pair<String, int>(TTR("Constants"), text_label.get_line_count() - 2))
#			text_label.push_color(title_color)
#			text_label.push_font(doc_title_font)
#			text_label.add_text(TTR("Constants"))
#			text_label.pop()
#			text_label.pop()
#			text_label.push_indent(1)
#
#			text_label.add_text("\n")
#
#			for int i = 0 i < constants.size() i++:
#
#				constant_line[constants[i].name] = text_label.get_line_count() - 2
#				text_label.push_font(doc_code_font)
#
#				if constants[i].value.begins_with("Color(") and constants[i].value.ends_with(")"):
#					String stripped = constants[i].value.replace(" ", "").replace("Color(", "").replace(")", "")
#					Vector<float> color = stripped.split_floats(",")
#					if color.size() >= 3:
#						text_label.push_color(Color(color[0], color[1], color[2]))
#						static const CharType prefix[3] = { 0x25CF /* filled circle */, ' ', 0 }
#						text_label.add_text(String(prefix))
#						text_label.pop()
#					}
#				}
#
#				text_label.push_color(headline_color)
#				//docs_utils.add_text(constants[i].name)
#				text_label.pop()
#				text_label.push_color(symbol_color)
#				text_label.add_text(" = ")
#				text_label.pop()
#				text_label.push_color(value_color)
#				//docs_utils.add_text(_fix_constant(constants[i].value))
#				text_label.pop()
#
#				text_label.pop()
#				if constants[i].description != "":
#					text_label.push_font(doc_font)
#					text_label.push_indent(1)
#					text_label.push_color(comment_color)
#					//docs_utils.add_text(constants[i].description)
#					text_label.pop()
#					text_label.pop()
#					text_label.pop() # indent
#					text_label.add_text("\n")
#				}
#
#				text_label.add_text("\n")
#			}
#
#			text_label.pop()
#			text_label.add_text("\n")
#		}
#	}
#
#	# Property descriptions
#	if property_descr:
#
#		section_line.push_back(Pair<String, int>(TTR("Property Descriptions"), text_label.get_line_count() - 2))
#		text_label.push_color(title_color)
#		text_label.push_font(doc_title_font)
#		text_label.add_text(TTR("Property Descriptions"))
#		text_label.pop()
#		text_label.pop()
#
#		text_label.add_text("\n")
#		text_label.add_text("\n")
#
#		for int i = 0 i < doc_data.properties.size() i++:
#
#			if doc_data.properties[i].overridden)
#				continue
#
#			property_line[doc_data.properties[i].name] = text_label.get_line_count() - 2
#
#			text_label.push_table(2)
#			text_label.set_table_column_expand(1, 1)
#
#			text_label.push_cell()
#			text_label.push_font(doc_code_font)
#			//docs_utils.add_type(doc_data.properties[i].type, doc_data.properties[i].enumeration)
#			text_label.add_text(" ")
#			text_label.pop() # font
#			text_label.pop() # cell
#
#			text_label.push_cell()
#			text_label.push_font(doc_code_font)
#			text_label.push_color(headline_color)
#			//docs_utils.add_text(doc_data.properties[i].name)
#			text_label.pop() # color
#
#			if doc_data.properties[i].default != "":
#				text_label.push_color(symbol_color)
#				text_label.add_text(" [" + TTR("default:") + " ")
#				text_label.pop() # color
#
#				text_label.push_color(value_color)
#				//docs_utils.add_text(_fix_constant(doc_data.properties[i].default))
#				text_label.pop() # color
#
#				text_label.push_color(symbol_color)
#				text_label.add_text("]")
#				text_label.pop() # color
#			}
#
#			text_label.pop() # font
#			text_label.pop() # cell
#
#			Map<String, DocData.MethodDoc> method_map
#			for int j = 0 j < methods.size() j++:
#				method_map[methods[j].name] = methods[j]
#			}
#
#			if doc_data.properties[i].setter != "":
#
#				text_label.push_cell()
#				text_label.pop() # cell
#
#				text_label.push_cell()
#				text_label.push_font(doc_code_font)
#				text_label.push_color(text_color)
#				if method_map[doc_data.properties[i].setter].args.size() > 1:
#					# Setters with additional args are exposed in the method list, so we link them here for quick access.
#					text_label.push_meta("@method " + doc_data.properties[i].setter)
#					text_label.add_text(doc_data.properties[i].setter + TTR("(value)"))
#					text_label.pop()
#				} else {
#					text_label.add_text(doc_data.properties[i].setter + TTR("(value)"))
#				}
#				text_label.pop() # color
#				text_label.push_color(comment_color)
#				text_label.add_text(" setter")
#				text_label.pop() # color
#				text_label.pop() # font
#				text_label.pop() # cell
#				method_line[doc_data.properties[i].setter] = property_line[doc_data.properties[i].name]
#			}
#
#			if doc_data.properties[i].getter != "":
#
#				text_label.push_cell()
#				text_label.pop() # cell
#
#				text_label.push_cell()
#				text_label.push_font(doc_code_font)
#				text_label.push_color(text_color)
#				if method_map[doc_data.properties[i].getter].args.size() > 0:
#					# Getters with additional args are exposed in the method list, so we link them here for quick access.
#					text_label.push_meta("@method " + doc_data.properties[i].getter)
#					text_label.add_text(doc_data.properties[i].getter + "()")
#					text_label.pop()
#				} else {
#					text_label.add_text(doc_data.properties[i].getter + "()")
#				}
#				text_label.pop() #color
#				text_label.push_color(comment_color)
#				text_label.add_text(" getter")
#				text_label.pop() #color
#				text_label.pop() #font
#				text_label.pop() #cell
#				method_line[doc_data.properties[i].getter] = property_line[doc_data.properties[i].name]
#			}
#
#			text_label.pop() # table
#
#			text_label.add_text("\n")
#			text_label.add_text("\n")
#
#			text_label.push_color(text_color)
#			text_label.push_font(doc_font)
#			text_label.push_indent(1)
#			if doc_data.properties[i].description.strip_edges() != String():
#				//docs_utils.add_text(doc_data.properties[i].description)
#			} else {
#				text_label.add_image(get_icon("Error", "EditorIcons"))
#				text_label.add_text(" ")
#				text_label.push_color(comment_color)
#				text_label.append_bbcode(TTR("There is currently no description for this property. Please help us by [color=$color][url=$url]contributing one[/url][/color]!").replace("$url", CONTRIBUTE_URL).replace("$color", link_color_text))
#				text_label.pop()
#			}
#			text_label.pop()
#			text_label.pop()
#			text_label.pop()
#			text_label.add_text("\n")
#			text_label.add_text("\n")
#			text_label.add_text("\n")
#		}
#	}
#
#	# Method descriptions
#	if method_descr:
#
#		section_line.push_back(Pair<String, int>(TTR("Method Descriptions"), text_label.get_line_count() - 2))
#		text_label.push_color(title_color)
#		text_label.push_font(doc_title_font)
#		text_label.add_text(TTR("Method Descriptions"))
#		text_label.pop()
#		text_label.pop()
#
#		text_label.add_text("\n")
#		text_label.add_text("\n")
#
#		for int pass = 0 pass < 2 pass++:
#			Vector<DocData.MethodDoc> methods_filtered
#
#			for int i = 0 i < methods.size() i++:
#				const String &q = methods[i].qualifiers
#				if (pass == 0 and q.find("virtual") != -1) or (pass == 1 and q.find("virtual") == -1):
#					methods_filtered.push_back(methods[i])
#				}
#			}
#
#			for int i = 0 i < methods_filtered.size() i++:
#
#				text_label.push_font(doc_code_font)
#				_add_method(methods_filtered[i], false)
#				text_label.pop()
#
#				text_label.add_text("\n")
#				text_label.add_text("\n")
#
#				text_label.push_color(text_color)
#				text_label.push_font(doc_font)
#				text_label.push_indent(1)
#				if methods_filtered[i].description.strip_edges() != String():
#					//docs_utils.add_text(methods_filtered[i].description)
#				} else {
#					text_label.add_image(get_icon("Error", "EditorIcons"))
#					text_label.add_text(" ")
#					text_label.push_color(comment_color)
#					text_label.append_bbcode(TTR("There is currently no description for this method. Please help us by [color=$color][url=$url]contributing one[/url][/color]!").replace("$url", CONTRIBUTE_URL).replace("$color", link_color_text))
#					text_label.pop()
#				}
#
#				text_label.pop()
#				text_label.pop()
#				text_label.pop()
#				text_label.add_text("\n")
#				text_label.add_text("\n")
#				text_label.add_text("\n")
#			}
#		}
#	}
#	scroll_locked = false


func _get_class_icon(_class: String) -> Texture:
	var icon := theme.get_icon(_class, "EditorIcons")
	if not icon:
		icon = _get_class_icon("Object")
	return icon


func _get_child_chain(node: Node, indices: Array) -> Node:
	var child := node
	for index in indices:
		child = child.get_child(index)
		if not child:
			return null
	return child


func _find_node_by_class(node: Node, _class: String) -> Node:
	if node.is_class(_class):
		return node
	
	for child in node.get_children():
		var result = _find_node_by_class(child, _class)
		if result:
			return result
	
	return null

