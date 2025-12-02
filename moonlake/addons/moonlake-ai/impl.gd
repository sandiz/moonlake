@tool
extends Control

#const FAL_API_KEY = "7f90fe57-7676-42b5-9b2b-a09202face5b:45dc1802c220a66d78359904ad188fb5"
const FAL_API_KEY = "f97be136-5389-431e-8b86-a9cfa51909b3:8acfbd9c8e16d2157a48c92c23ebe509"
const TEXT_TO_IMAGE_URL = "https://queue.fal.run/fal-ai/nano-banana"
const IMAGE_TO_3D_URL = "https://queue.fal.run/fal-ai/trellis"

var assets_dir = "res://ai_generated_assets/"
var assets_metadata_path = "res://ai_generated_assets/metadata.json"
var assets = []

# UI references
var prompt_input: TextEdit
var generate_btn: Button
var status_label: Label
var asset_grid: GridContainer
var detail_panel: Panel
var detail_prompt: Label
var detail_image: TextureRect
var detail_timestamp: Label

# Generator instances
var image_generator: ImageGenerator
var mesh_generator: MeshGenerator

func _enter_tree() -> void:
	setup_ui()
	setup_generators()

func _ready() -> void:
	load_assets()
	populate_browser()

func setup_ui() -> void:
	var ui_refs = MoonlakeUI.setup_ui(self, {
		"on_generate": _on_generate_pressed
	})

	# Store UI references
	prompt_input = ui_refs.prompt_input
	generate_btn = ui_refs.generate_btn
	status_label = ui_refs.status_label
	asset_grid = ui_refs.asset_grid
	detail_panel = ui_refs.detail_panel
	detail_prompt = ui_refs.detail_prompt
	detail_image = ui_refs.detail_image
	detail_timestamp = ui_refs.detail_timestamp

func setup_generators() -> void:
	# Create image generator
	image_generator = ImageGenerator.new(FAL_API_KEY, TEXT_TO_IMAGE_URL)
	add_child(image_generator)
	image_generator.image_generated.connect(_on_image_generated)
	image_generator.generation_failed.connect(_on_image_gen_failed)
	image_generator.status_updated.connect(_on_status_updated)

	# Create mesh generator
	mesh_generator = MeshGenerator.new(FAL_API_KEY, IMAGE_TO_3D_URL)
	add_child(mesh_generator)
	mesh_generator.mesh_generated.connect(_on_mesh_generated)
	mesh_generator.generation_failed.connect(_on_mesh_gen_failed)
	mesh_generator.status_updated.connect(_on_status_updated)

func _on_generate_pressed() -> void:
	var prompt = prompt_input.text.strip_edges()

	if prompt.is_empty():
		status_label.text = "Error: Please enter a prompt"
		return

	if FAL_API_KEY.is_empty():
		status_label.text = "Error: Please set FAL_API_KEY in the script"
		return

	generate_btn.disabled = true
	status_label.text = "Step 1/2: Generating image from prompt..."

	# Start image generation
	image_generator.generate_image(prompt)

func _on_status_updated(status_text: String) -> void:
	status_label.text = status_text

func _on_image_gen_failed(error_message: String) -> void:
	status_label.text = "Error: " + error_message
	generate_btn.disabled = false

func _on_mesh_gen_failed(error_message: String) -> void:
	status_label.text = "Error: " + error_message
	generate_btn.disabled = false

func _on_image_generated(image_url: String, image_data: PackedByteArray, prompt: String) -> void:
	# Image generation complete, start mesh generation
	mesh_generator.generate_mesh(image_url, prompt, image_data)

func _on_mesh_generated(mesh_data: Dictionary, image_url: String, image_data: PackedByteArray, prompt: String) -> void:
	# Mesh generation complete, save the asset
	save_asset(prompt, image_url, image_data, mesh_data)

func save_asset(prompt: String, image_url: String, image_data: PackedByteArray, mesh_data: Dictionary):
	print("Saving asset...")
	print("Mesh data received: ", mesh_data)

	# Ensure assets directory exists
	if not DirAccess.dir_exists_absolute(assets_dir):
		DirAccess.make_dir_recursive_absolute(assets_dir)

	var timestamp = Time.get_datetime_string_from_system()
	var asset_id = str(Time.get_ticks_msec())

	# Save thumbnail image
	var image = Image.new()
	var image_error = image.load_png_from_buffer(image_data)
	if image_error == OK:
		var thumb_path = assets_dir + "thumb_" + asset_id + ".png"
		image.save_png(thumb_path)
		print("Saved thumbnail to: ", thumb_path)

	# Extract mesh file URL from mesh_data
	var mesh_url = ""
	var mesh_filename = "mesh_" + asset_id + ".glb"

	if mesh_data.has("model_mesh"):
		var model_mesh = mesh_data.model_mesh
		if model_mesh is Dictionary and model_mesh.has("url"):
			mesh_url = model_mesh.url
			if model_mesh.has("file_name"):
				var original_name = model_mesh.file_name
				var extension = original_name.get_extension()
				mesh_filename = "mesh_" + asset_id + "." + extension
		print("Mesh URL to download: ", mesh_url)

	# Create metadata entry
	var asset_metadata = {
		"id": asset_id,
		"prompt": prompt,
		"image_url": image_url,
		"thumbnail": "thumb_" + asset_id + ".png",
		"mesh_file": mesh_filename,
		"mesh_url": mesh_url,
		"created_at": timestamp
	}

	assets.append(asset_metadata)
	save_metadata()

	# Download the mesh file
	if not mesh_url.is_empty():
		status_label.text = "Downloading 3D mesh file..."
		download_mesh_file(mesh_url, mesh_filename, asset_id)
	else:
		status_label.text = "Success! Asset generated (no mesh file found)."
		generate_btn.disabled = false
		populate_browser()

func download_mesh_file(mesh_url: String, mesh_filename: String, asset_id: String):
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_mesh_file_downloaded.bind(mesh_filename, asset_id))

	print("Downloading mesh file from: ", mesh_url)
	var error = http.request(mesh_url)

	if error != OK:
		status_label.text = "Error: Failed to download mesh file"
		generate_btn.disabled = false
		http.queue_free()

func _on_mesh_file_downloaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, mesh_filename: String, asset_id: String):
	var http = get_children().filter(func(n): return n is HTTPRequest)[0]
	http.queue_free()

	print("Mesh file download response code: ", response_code)
	print("Mesh file size: ", body.size(), " bytes")

	if response_code != 200:
		status_label.text = "Error: Failed to download mesh file (HTTP %d)" % response_code
		generate_btn.disabled = false
		return

	# Save the mesh file
	var mesh_path = assets_dir + mesh_filename
	var file = FileAccess.open(mesh_path, FileAccess.WRITE)
	if file:
		file.store_buffer(body)
		file.close()
		print("Saved mesh file to: ", mesh_path)
		status_label.text = "Success! 3D asset generated and saved."
	else:
		status_label.text = "Error: Failed to save mesh file"
		print("Failed to open file for writing: ", mesh_path)

	generate_btn.disabled = false
	populate_browser()

func load_assets() -> void:
	if FileAccess.file_exists(assets_metadata_path):
		var file = FileAccess.open(assets_metadata_path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			var parsed = JSON.parse_string(json_string)
			if parsed != null and parsed is Array:
				assets = parsed
			file.close()

func save_metadata():
	var file = FileAccess.open(assets_metadata_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(assets, "\t"))
		file.close()

func populate_browser() -> void:
	for child in asset_grid.get_children():
		child.queue_free()

	for asset in assets:
		var item = create_asset_item(asset)
		asset_grid.add_child(item)

func create_asset_item(asset: Dictionary) -> Control:
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(100, 120)

	# Use a Panel instead of Button for better drag-and-drop
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(100, 100)

	# Make it clickable
	panel.gui_input.connect(_on_asset_panel_input.bind(asset))

	var thumb_path = assets_dir + asset.thumbnail
	if FileAccess.file_exists(thumb_path):
		var image_bytes = FileAccess.get_file_as_bytes(thumb_path)
		var image = Image.new()
		var error = image.load_png_from_buffer(image_bytes)
		if error == OK:
			var texture = ImageTexture.create_from_image(image)
			var texture_rect = TextureRect.new()
			texture_rect.texture = texture
			texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texture_rect.custom_minimum_size = Vector2(90, 90)
			texture_rect.position = Vector2(5, 5)
			texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(texture_rect)

			# Add 3D badge overlay
			if asset.has("mesh_file") and not asset.mesh_file.is_empty():
				var badge = Label.new()
				badge.text = "3D"
				badge.add_theme_font_size_override("font_size", 10)
				badge.add_theme_color_override("font_color", Color.WHITE)
				badge.add_theme_color_override("font_outline_color", Color.BLACK)
				badge.add_theme_constant_override("outline_size", 2)
				badge.position = Vector2(5, 5)
				badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
				panel.add_child(badge)

	# Store asset data on the panel for drag-and-drop
	panel.set_meta("asset_data", asset)

	container.add_child(panel)

	var label = Label.new()
	label.text = asset.prompt.substr(0, 15) + ("..." if asset.prompt.length() > 15 else "")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	container.add_child(label)

	# Show mesh format below prompt
	if asset.has("mesh_file") and not asset.mesh_file.is_empty():
		var mesh_label = Label.new()
		var extension = asset.mesh_file.get_extension().to_upper()
		mesh_label.text = "[" + extension + " Model]"
		mesh_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mesh_label.add_theme_font_size_override("font_size", 9)
		mesh_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		container.add_child(mesh_label)

	# Enable drag-and-drop
	container.set_drag_forwarding(
		Callable(),
		_get_drag_data_for_asset.bind(asset),
		Callable()
	)

	return container

func _on_asset_panel_input(event: InputEvent, asset: Dictionary):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_asset_clicked(asset)

func _get_drag_data_for_asset(from_position: Vector2, asset: Dictionary):
	# Only allow dragging if there's a mesh file
	if not asset.has("mesh_file") or asset.mesh_file.is_empty():
		return null

	var mesh_path = assets_dir + asset.mesh_file
	if not FileAccess.file_exists(mesh_path):
		return null

	print("Starting drag for: ", mesh_path)

	# Create drag preview
	var preview = VBoxContainer.new()

	var thumb_path = assets_dir + asset.thumbnail
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
	label.text = asset.mesh_file
	label.add_theme_font_size_override("font_size", 10)
	preview.add_child(label)

	set_drag_preview(preview)

	# Return drag data in the format the editor expects
	# For scene files, we need to provide a "files" array
	return {
		"type": "files",
		"files": [mesh_path]
	}

func _on_asset_clicked(asset: Dictionary):
	detail_panel.visible = true
	detail_prompt.text = "Prompt: " + asset.prompt

	var detail_text = "Created: " + asset.created_at
	if asset.has("mesh_file") and not asset.mesh_file.is_empty():
		detail_text += "\nMesh: " + asset.mesh_file
		var mesh_path = assets_dir + asset.mesh_file
		if FileAccess.file_exists(mesh_path):
			var file_size = FileAccess.get_file_as_bytes(mesh_path).size()
			detail_text += " (" + str(file_size / 1024) + " KB)"
	detail_timestamp.text = detail_text

	# Load and display thumbnail
	var thumb_path = assets_dir + asset.thumbnail
	if FileAccess.file_exists(thumb_path):
		var image_bytes = FileAccess.get_file_as_bytes(thumb_path)
		var image = Image.new()
		var error = image.load_png_from_buffer(image_bytes)
		if error == OK:
			detail_image.texture = ImageTexture.create_from_image(image)
