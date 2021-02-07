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
}

var doc_generator := preload("class_doc_generator.gd").new()
var rich_label_doc_exporter := preload("doc_exporter/rich_label_doc_exporter.gd").new()

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
var section_lines := []
var current_label: RichTextLabel

var theme := get_editor_interface().get_base_control().theme
var disabled_color := theme.get_color("disabled_font_color", "Editor")

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
	search_controls = _find_node_by_class(search_help, "LineEdit").get_parent()
	tree = _find_node_by_class(search_help, "Tree")
	
	section_list = ItemList.new()
	section_list.allow_reselect = true
	section_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section_list.connect("item_selected", self, "_on_SectionList_item_selected")
	_get_child_chain(script_editor, [0, 1, 0, 1]).add_child(section_list)
	
	rich_label_doc_exporter.theme = theme
	rich_label_doc_exporter.editor_settings = get_editor_interface().get_editor_settings()
	rich_label_doc_exporter.update_theme_vars()
	rich_label_doc_exporter.class_docs = class_docs
	rich_label_doc_exporter.class_list = Array(ClassDB.get_class_list())
	
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
	
	if tree.get_root():
		search_flags = search_controls.get_child(3).get_item_id(search_controls.get_child(3).selected)
		search_flags |= SEARCH_CASE * int(search_controls.get_child(1).pressed)
		search_term = search_controls.get_child(0).text
		
		for name in class_docs:
			_process_custom_class_item(name)
	
	var prev_section_lines := section_lines.duplicate(true)
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
		if doc_open and editor_help.name in class_docs:
			custom_doc_open = true
		
		if editor_help.name != text:
			text = editor_help.name
			
#			if text.right(text.length() - 1).is_valid_integer():
#				# potential duplicate
#				var should_delete := false
#				for doc in class_docs:
#					var name_at_front := text.find(doc) == 0
#					if name_at_front and text.right(doc.length()).is_valid_integer():
#						should_delete = true
#						break
			
			script_list.set_item_tooltip(i, text + " Class Reference")
			if custom_doc_open and text in class_docs:
				rich_label_doc_exporter.label = editor_help.get_child(0)
				var current := bool(rich_label_doc_exporter._generate(class_docs[text]))
				if current:
					current_label = rich_label_doc_exporter.label
		script_list.call_deferred("set_item_text", i, text)
	
	if prev_section_lines.size() != section_lines.size():
		section_list.clear()
		for section in section_lines:
			section_list.add_item(section[0])
	else:
		for i in section_lines.size():
			section_list.set_item_text(i, section_lines[i][0])
			section_list.set_item_tooltip(i, section_lines[i][0])
	
	if custom_doc_open:
		section_list.get_parent().get_child(3).set_deferred("visible", false)
		section_list.visible = true
	else:
		section_list.get_parent().get_child(3).set_deferred("visible", doc_open)
		section_list.visible = false


func _process_custom_class_item(cls_name: String) -> TreeItem:
	# Create tree item if it's not their.
	if doc_items.get(cls_name):
		doc_items[cls_name].clear_custom_color(0)
		doc_items[cls_name].clear_custom_color(1)
		return doc_items[cls_name]
	
	if not search_term.empty():
		if (search_flags & SEARCH_CASE) and cls_name.find(search_term) == -1:
			return null
		elif ~(search_flags & SEARCH_CASE) and cls_name.findn(search_term) == -1:
			return null
	
	var _class: ClassDocItem = class_docs[cls_name]
	var parent := tree.get_root()
	
	# Get inheritance chain of the class.
	var inherit_chain = [_class.base]
	while not inherit_chain[-1].empty():
		inherit_chain.append(rich_label_doc_exporter.get_parent_class(inherit_chain[-1]))
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
			var new_parent: TreeItem
			if inherit in class_docs:
				new_parent = _process_custom_class_item(inherit)
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
	item.set_icon(0, _get_class_icon("Object"))
	item.set_text(0, _class.name)
	item.set_text(1, "Class")
	item.set_tooltip(0, _class.brief)
	item.set_tooltip(1, _class.brief)
	item.set_metadata(0, "class_name:" + _class.name)
	doc_items[cls_name] = item
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
	
	var queue_delete := []
	for name in doc_items:
		if not name in docs:
			if doc_items[name]:
				doc_items[name].free()
			queue_delete.append(name)
	
	var keys := class_docs.keys()
	for key in keys:
		if not docs.has(key):
			rich_label_doc_exporter.class_list.erase(key)
			class_docs.erase(key)


func _on_SectionList_item_selected(index: int) -> void:
	if not current_label:
		return
	current_label.scroll_to_line(section_lines[index][1])


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

