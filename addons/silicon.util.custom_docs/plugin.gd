tool
extends EditorPlugin

enum {
	SEARCH_CLASS = 1,
	SEARCH_METHOD = 2,
	SEARCH_SIGNAL = 4,
	SEARCH_CONSTANT = 8,
	SEARCH_PROPERTY = 16,
	SEARCH_THEME = 32,
	SEARCH_CASE = 64,
	SEARCH_TREE = 128
}

enum {
	ITEM_CLASS,
	ITEM_METHOD,
	ITEM_SIGNAL,
	ITEM_CONSTANT,
	ITEM_PROPERTY
}

var doc_generator := preload("class_doc_generator.gd").new()
var rich_label_doc_exporter := preload("doc_exporter/editor_help_doc_exporter.gd").new()

var script_editor: ScriptEditor

var search_help: AcceptDialog
var search_controls: HBoxContainer
var search_term: String
var search_flags: int
var tree: Tree

var script_list: ItemList
var script_tabs: TabContainer
var section_list: ItemList

var class_docs := {}
var doc_items := {}
var current_label: RichTextLabel

var theme: Theme
var disabled_color: Color

var timer := Timer.new()

func _enter_tree() -> void:
	theme = get_editor_interface().get_base_control().theme
	disabled_color = theme.get_color("disabled_font_color", "Editor")
	
	script_editor = get_editor_interface().get_script_editor()
	script_list = _find_node_by_class(script_editor, "ItemList")
	script_tabs = _get_child_chain(script_editor, [0, 1, 1])
	search_help = _find_node_by_class(script_editor, "EditorHelpSearch")
	search_controls = _find_node_by_class(search_help, "LineEdit").get_parent()
	tree = _find_node_by_class(search_help, "Tree")
	
	search_help.connect("go_to_help", self, "_on_SearchHelp_go_to_help")
	
	section_list = ItemList.new()
	section_list.allow_reselect = true
	section_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section_list.connect("item_selected", self, "_on_SectionList_item_selected")
	_get_child_chain(script_editor, [0, 1, 0, 1]).add_child(section_list)
	
	rich_label_doc_exporter.plugin = self
	rich_label_doc_exporter.theme = theme
	rich_label_doc_exporter.editor_settings = get_editor_interface().get_editor_settings()
	rich_label_doc_exporter.class_docs = class_docs
	rich_label_doc_exporter.class_list = Array(ClassDB.get_class_list())
	rich_label_doc_exporter.update_theme_vars()
	
	doc_generator.plugin = self
	
	add_child(timer)
	timer.wait_time = 0.5
	timer.one_shot = false
	timer.start()
	timer.connect("timeout", self, "_on_Timer_timeout")


func _exit_tree() -> void:
	## TODO: Save opened custom doc tabs.
	section_list.queue_free()


func _process(delta: float) -> void:
	if not tree:
		return
	
	# Update search help tree items
	if tree.get_root():
		search_flags = search_controls.get_child(3).get_item_id(search_controls.get_child(3).selected)
		search_flags |= SEARCH_CASE * int(search_controls.get_child(1).pressed)
		search_flags |= SEARCH_TREE * int(search_controls.get_child(2).pressed)
		search_term = search_controls.get_child(0).text
		
		for name in class_docs:
			if fits_search(name, ITEM_CLASS):
				_process_custom_item(name, ITEM_CLASS)
			
			for method in class_docs[name].methods:
				if fits_search(method.name, ITEM_METHOD):
					_process_custom_item(name + "." + method.name, ITEM_METHOD)
			
			for _signal in class_docs[name].signals:
				if fits_search(_signal.name, ITEM_SIGNAL):
					_process_custom_item(name + "." + _signal.name, ITEM_SIGNAL)
			
			for constant in class_docs[name].constants:
				if fits_search(constant.name, ITEM_CONSTANT):
					_process_custom_item(name + "." + constant.name, ITEM_CONSTANT)
			
			for property in class_docs[name].properties:
				if fits_search(property.name, ITEM_PROPERTY):
					_process_custom_item(name + "." + property.name, ITEM_PROPERTY)
	
	var custom_doc_open := false
	var doc_open := false
	for i in script_list.get_item_count():
		var icon := script_list.get_item_icon(i)
		var text := script_list.get_item_text(i)
		if icon != theme.get_icon("Help", "EditorIcons"):
			continue
		
		var editor_help = script_tabs.get_child(script_list.get_item_metadata(i))
		if editor_help.is_visible_in_tree():
			doc_open = true
		
		if editor_help.name != text:
			text = editor_help.name
			
			# Possible duplicate
			if text[-1].is_valid_integer():
				for doc in class_docs:
					if text.find(doc) != -1 and text.right(doc.length()).is_valid_integer():
						text = doc
						break
			
			script_list.set_item_tooltip(i, text + " Class Reference")
		
		if editor_help.is_visible_in_tree() and text in class_docs:
			custom_doc_open = true
			
			var label: RichTextLabel = editor_help.get_child(0)
			if current_label:
				current_label.disconnect("meta_clicked", self, "_on_EditorHelpLabel_meta_clicked")
			if current_label != label:
				call_deferred("_update_doc", label, text)
			current_label = label
			current_label.connect("meta_clicked", self, "_on_EditorHelpLabel_meta_clicked", [current_label])
		
		script_list.call_deferred("set_item_text", i, text)
	
	if custom_doc_open:
		section_list.get_parent().get_child(3).set_deferred("visible", false)
		section_list.visible = true
	else:
		section_list.get_parent().get_child(3).set_deferred("visible", doc_open)
		section_list.visible = false


func get_parent_class(_class: String) -> String:
	if class_docs.has(_class):
		return class_docs[_class].base
	return ClassDB.get_parent_class(_class)


func fits_search(name: String, type: int) -> bool:
	if type == ITEM_CLASS and not (search_flags & SEARCH_CLASS):
		return false
	elif type == ITEM_METHOD and not (search_flags & SEARCH_METHOD) or search_term.empty():
		return false
	elif type == ITEM_SIGNAL and not (search_flags & SEARCH_SIGNAL) or search_term.empty():
		return false
	elif type == ITEM_CONSTANT and not (search_flags & SEARCH_CONSTANT) or search_term.empty():
		return false
	elif type == ITEM_PROPERTY and not (search_flags & SEARCH_PROPERTY) or search_term.empty():
		return false
	
	if not search_term.empty():
		if (search_flags & SEARCH_CASE) and name.find(search_term) == -1:
			return false
		elif ~(search_flags & SEARCH_CASE) and name.findn(search_term) == -1:
			return false
	
	return true


func _update_doc(label: RichTextLabel, _class: String) -> void:
	rich_label_doc_exporter.label = label
	rich_label_doc_exporter._generate(class_docs[_class])
	
	var section_lines := rich_label_doc_exporter.section_lines
	section_list.clear()
	for i in section_lines.size():
		section_list.add_item(section_lines[i][0])
		section_list.set_item_metadata(i, section_lines[i][1])


func _process_custom_item(name: String, type := ITEM_CLASS) -> TreeItem:
	# Create tree item if it's not their.
	if doc_items.get(name + str(type)):
		doc_items[name + str(type)].clear_custom_color(0)
		doc_items[name + str(type)].clear_custom_color(1)
		return doc_items[name + str(type)]
	
	var parent := tree.get_root()
	var sub_name: String
	if name.find(".") != -1:
		var split := name.split(".")
		name = split[0]
		sub_name = split[1]
	
	var _class: ClassDocItem = class_docs[name]
	
	if search_flags & SEARCH_TREE:
		# Get inheritance chain of the class.
		var inherit_chain = [_class.base]
		while not inherit_chain[-1].empty():
			inherit_chain.append(get_parent_class(inherit_chain[-1]))
		inherit_chain.pop_back()
		inherit_chain.invert()
		if not sub_name.empty():
			inherit_chain.append(name)
		
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
				var new_parent: TreeItem
				if inherit in class_docs:
					new_parent = _process_custom_item(inherit)
				if not new_parent:
					new_parent = tree.create_item(parent)
					new_parent.set_text(0, inherit)
					new_parent.set_text(1, "Class")
					new_parent.set_icon(0, _get_class_icon(inherit))
					new_parent.set_metadata(0, "class_name:" + inherit)
					new_parent.set_custom_color(0, disabled_color)
					new_parent.set_custom_color(1, disabled_color)
				parent = new_parent
	
	var item := tree.create_item(parent)
	if not sub_name.empty():
		name += "." + sub_name
	var display_name := sub_name if search_flags & SEARCH_TREE else name
	match type:
		ITEM_CLASS:
			item.set_text(0, name)
			item.set_text(1, "Class")
			item.set_tooltip(0, _class.brief)
			item.set_tooltip(1, _class.brief)
			item.set_metadata(0, "class_name:" + name)
			item.set_icon(0, _get_class_icon("Object"))
			
		ITEM_METHOD:
			item.set_text(0, display_name)
			item.set_text(1, "Method")
			var method := _class.get_method_doc(sub_name)
			item.set_tooltip(0, method.return_type + " " + name + "()")
			item.set_tooltip(1, item.get_tooltip(0))
			item.set_metadata(0, "class_method:" + name.replace(".", ":"))
			item.set_icon(0, theme.get_icon("MemberMethod", "EditorIcons"))
			
		ITEM_SIGNAL:
			item.set_text(0, display_name)
			item.set_text(1, "Signal")
			var _signal := _class.get_signal_doc(sub_name)
			item.set_tooltip(0, name + "()")
			item.set_tooltip(1, item.get_tooltip(0))
			item.set_metadata(0, "class_signal:" + name.replace(".", ":"))
			item.set_icon(0, theme.get_icon("MemberSignal", "EditorIcons"))
			
		ITEM_CONSTANT:
			item.set_text(0, display_name)
			item.set_text(1, "Constant")
			var constant := _class.get_constant_doc(sub_name)
			item.set_tooltip(0, name)
			item.set_tooltip(1, item.get_tooltip(0))
			item.set_metadata(0, "class_constant:" + name.replace(".", ":"))
			item.set_icon(0, theme.get_icon("MemberConstant", "EditorIcons"))
			
		ITEM_PROPERTY:
			item.set_text(0, display_name)
			item.set_text(1, "Property")
			var property := _class.get_property_doc(sub_name)
			item.set_tooltip(0, property.type + " " + name)
			item.set_tooltip(1, item.get_tooltip(0))
			item.set_metadata(0, "class_property:" + name.replace(".", ":"))
			item.set_icon(0, theme.get_icon("MemberProperty", "EditorIcons"))
	
	doc_items[name + str(type)] = item
	return item


func _on_Timer_timeout() -> void:
	rich_label_doc_exporter.update_theme_vars()
	
	var classes: Array = ProjectSettings.get("_global_script_classes")
	var docs := {}
	for _class in classes:
		var doc := doc_generator.generate(_class["class"], _class["base"], _class["path"])
		docs[doc.name] = doc
		class_docs[doc.name] = doc
		if doc.name in rich_label_doc_exporter.class_list:
			rich_label_doc_exporter.class_list.append(doc.name)
	
	# Periodically clean up tree items
	for name in doc_items:
		if not doc_items[name]:
			doc_items.erase(name)
	
	var keys := class_docs.keys()
	for key in keys:
		if not docs.has(key):
			rich_label_doc_exporter.class_list.erase(key)
			class_docs.erase(key)


func _on_EditorScript_tab_changed(index: int) -> void:
	pass


func _on_EditorHelpLabel_meta_clicked(meta, label: RichTextLabel) -> void:
	print(meta)


func _on_SearchHelp_go_to_help(tag: String) -> void:
	pass
#	print(tag)


func _on_SectionList_item_selected(index: int) -> void:
	if not current_label:
		return
	current_label.scroll_to_line(section_list.get_item_metadata(index))


func _get_class_icon(_class: String) -> Texture:
	if theme.has_icon(_class, "EditorIcons"):
		return theme.get_icon(_class, "EditorIcons")
	return _get_class_icon("Object")


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

