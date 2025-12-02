@tool
extends Panel
class_name DraggableAsset

var asset_data: Dictionary
var assets_dir: String

signal asset_clicked(asset: Dictionary)

func setup(asset: Dictionary, dir: String):
	asset_data = asset
	assets_dir = dir
	custom_minimum_size = Vector2(100, 100)

func _get_drag_data(at_position: Vector2):
	# Only allow dragging if there's a scene file
	if not asset_data.has("scene_file") or asset_data.scene_file.is_empty():
		return null

	var scene_path = assets_dir + asset_data.scene_file
	if not FileAccess.file_exists(scene_path):
		return null

	print("Starting drag for scene: ", scene_path)

	# Create drag preview
	var preview = VBoxContainer.new()

	var thumb_path = assets_dir + asset_data.thumbnail
	if FileAccess.file_exists(thumb_path):
		var image_bytes = FileAccess.get_file_as_bytes(thumb_path)
		var image = Image.new()
		var error = image.load_png_from_buffer(image_bytes)
		if error == OK:
			var texture = ImageTexture.create_from_image(image)
			var texture_rect = TextureRect.new()
			texture_rect.texture = texture
			texture_rect.custom_minimum_size = Vector2(64, 64)
			texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			preview.add_child(texture_rect)

	var label = Label.new()
	label.text = asset_data.scene_file if asset_data.has("scene_file") else "3D Asset"
	label.add_theme_font_size_override("font_size", 10)
	preview.add_child(label)

	set_drag_preview(preview)

	# Return drag data in the format the editor expects
	return {
		"type": "files",
		"files": [scene_path]
	}

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not event.double_click:
				asset_clicked.emit(asset_data)
