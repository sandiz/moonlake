@tool
extends RefCounted
class_name MoonlakeUI

static func setup_ui(parent: Control, callbacks: Dictionary) -> Dictionary:
	var ui_refs = {}

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(vbox)

	var title = Label.new()
	title.text = "Moonlake AI"
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var prompt_label = Label.new()
	prompt_label.text = "Enter Prompt:"
	vbox.add_child(prompt_label)

	var prompt_input = TextEdit.new()
	prompt_input.custom_minimum_size = Vector2(0, 80)
	prompt_input.placeholder_text = "Describe the 3D asset you want to generate..."
	vbox.add_child(prompt_input)
	ui_refs["prompt_input"] = prompt_input

	# Image source selection
	var source_label = Label.new()
	source_label.text = "Or generate from existing asset:"
	vbox.add_child(source_label)

	var image_source_dropdown = OptionButton.new()
	image_source_dropdown.add_item("(Generate new image)", 0)
	vbox.add_child(image_source_dropdown)
	ui_refs["image_source_dropdown"] = image_source_dropdown

	vbox.add_child(HSeparator.new())

	# Drawing canvas section
	var draw_label = Label.new()
	draw_label.text = "Or just draw!"
	vbox.add_child(draw_label)

	var canvas = DrawingCanvas.new()
	vbox.add_child(canvas)
	ui_refs["drawing_canvas"] = canvas

	var canvas_buttons = HBoxContainer.new()
	vbox.add_child(canvas_buttons)

	var clear_btn = Button.new()
	clear_btn.text = "Clear Drawing"
	if callbacks.has("on_clear_canvas"):
		clear_btn.pressed.connect(callbacks.on_clear_canvas)
	canvas_buttons.add_child(clear_btn)
	ui_refs["clear_canvas_btn"] = clear_btn

	var generate_btn = Button.new()
	generate_btn.text = "Generate 3D Asset"
	if callbacks.has("on_generate"):
		generate_btn.pressed.connect(callbacks.on_generate)
	vbox.add_child(generate_btn)
	ui_refs["generate_btn"] = generate_btn

	var status_label = Label.new()
	status_label.text = ""
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(status_label)
	ui_refs["status_label"] = status_label

	vbox.add_child(HSeparator.new())

	# Asset Browser
	var browser_label = Label.new()
	browser_label.text = "Generated Assets:"
	vbox.add_child(browser_label)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 200)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var asset_grid = GridContainer.new()
	asset_grid.columns = 3
	asset_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(asset_grid)
	ui_refs["asset_grid"] = asset_grid

	vbox.add_child(HSeparator.new())

	var detail_panel = Panel.new()
	detail_panel.custom_minimum_size = Vector2(0, 500)
	detail_panel.visible = false
	vbox.add_child(detail_panel)
	ui_refs["detail_panel"] = detail_panel

	var detail_margin = MarginContainer.new()
	detail_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	detail_margin.add_theme_constant_override("margin_left", 10)
	detail_margin.add_theme_constant_override("margin_right", 10)
	detail_margin.add_theme_constant_override("margin_top", 10)
	detail_margin.add_theme_constant_override("margin_bottom", 10)
	detail_panel.add_child(detail_margin)

	var detail_vbox = VBoxContainer.new()
	detail_vbox.add_theme_constant_override("separation", 8)
	detail_margin.add_child(detail_vbox)

	var detail_title = Label.new()
	detail_title.text = "Asset Details"
	detail_title.add_theme_font_size_override("font_size", 16)
	detail_vbox.add_child(detail_title)

	detail_vbox.add_child(HSeparator.new())

	var detail_prompt = Label.new()
	detail_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_vbox.add_child(detail_prompt)
	ui_refs["detail_prompt"] = detail_prompt

	var detail_image = TextureRect.new()
	detail_image.custom_minimum_size = Vector2(200, 200)
	detail_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	detail_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_vbox.add_child(detail_image)
	ui_refs["detail_image"] = detail_image

	var detail_timestamp = Label.new()
	detail_timestamp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_vbox.add_child(detail_timestamp)
	ui_refs["detail_timestamp"] = detail_timestamp

	return ui_refs
