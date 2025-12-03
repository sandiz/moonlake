@tool
extends Control

# const FAL_API_KEY = "7f90fe57-7676-42b5-9b2b-a09202face5b:45dc1802c220a66d78359904ad188fb5"
const FAL_API_KEY = "f97be136-5389-431e-8b86-a9cfa51909b3:8acfbd9c8e16d2157a48c92c23ebe509"
const TEXT_TO_IMAGE_URL = "https://queue.fal.run/fal-ai/nano-banana"
const IMAGE_TO_3D_URL = "https://queue.fal.run/fal-ai/trellis"

var assets_dir = "res://ai_generated_assets/"
var assets_metadata_path = "res://ai_generated_assets/metadata.json"
var assets = []
var is_generating = false
var last_metadata_modified_time: int = 0
var refresh_timer: Timer

# UI references
var image_source_dropdown: OptionButton
var prompt_input: TextEdit
var drawing_canvas: DrawingCanvas
var clear_canvas_btn: Button
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
	setup_file_watcher()

func _ready() -> void:
	load_assets()
	populate_browser()
	populate_image_dropdown()
	update_last_modified_time()

func setup_ui() -> void:
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(vbox)

	var title = Label.new()
	title.text = "Moonlake AI"
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var prompt_label = Label.new()
	prompt_label.text = "Enter Prompt:"
	vbox.add_child(prompt_label)

	prompt_input = TextEdit.new()
	prompt_input.custom_minimum_size = Vector2(0, 80)
	prompt_input.placeholder_text = "Describe the 3D asset you want to generate..."
	vbox.add_child(prompt_input)

	# Image source selection
	var source_label = Label.new()
	source_label.text = "Or generate from existing asset:"
	vbox.add_child(source_label)

	image_source_dropdown = OptionButton.new()
	image_source_dropdown.add_item("(Generate new image)", 0)
	vbox.add_child(image_source_dropdown)

	vbox.add_child(HSeparator.new())

	# Drawing canvas section
	var draw_label = Label.new()
	draw_label.text = "Or just draw!"
	vbox.add_child(draw_label)

	drawing_canvas = DrawingCanvas.new()
	vbox.add_child(drawing_canvas)

	var canvas_buttons = HBoxContainer.new()
	vbox.add_child(canvas_buttons)

	clear_canvas_btn = Button.new()
	clear_canvas_btn.text = "Clear Drawing"
	clear_canvas_btn.pressed.connect(_on_clear_canvas_pressed)
	canvas_buttons.add_child(clear_canvas_btn)

	generate_btn = Button.new()
	generate_btn.text = "Generate 3D Asset"
	generate_btn.pressed.connect(_on_generate_pressed)
	vbox.add_child(generate_btn)

	status_label = Label.new()
	status_label.text = ""
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(status_label)

	vbox.add_child(HSeparator.new())

	# Asset Browser
	var browser_label = Label.new()
	browser_label.text = "Generated Assets:"
	vbox.add_child(browser_label)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 200)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	asset_grid = GridContainer.new()
	asset_grid.columns = 3
	asset_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(asset_grid)

	vbox.add_child(HSeparator.new())

	detail_panel = Panel.new()
	detail_panel.custom_minimum_size = Vector2(0, 500)
	detail_panel.visible = false
	vbox.add_child(detail_panel)

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

	detail_prompt = Label.new()
	detail_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_vbox.add_child(detail_prompt)

	detail_image = TextureRect.new()
	detail_image.custom_minimum_size = Vector2(200, 200)
	detail_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	detail_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_vbox.add_child(detail_image)

	detail_timestamp = Label.new()
	detail_timestamp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_vbox.add_child(detail_timestamp)

	image_source_dropdown.item_selected.connect(_on_image_source_changed)

func setup_file_watcher() -> void:
	# Create a timer to check for file changes every 2 seconds
	refresh_timer = Timer.new()
	refresh_timer.wait_time = 2.0
	refresh_timer.autostart = true
	refresh_timer.timeout.connect(_check_for_changes)
	add_child(refresh_timer)

func update_last_modified_time() -> void:
	if FileAccess.file_exists(assets_metadata_path):
		last_metadata_modified_time = FileAccess.get_modified_time(assets_metadata_path)

func _check_for_changes() -> void:
	if not FileAccess.file_exists(assets_metadata_path):
		return

	var current_modified_time = FileAccess.get_modified_time(assets_metadata_path)

	if current_modified_time != last_metadata_modified_time:
		print("Assets folder changed, refreshing...")
		last_metadata_modified_time = current_modified_time
		load_assets()
		populate_browser()
		populate_image_dropdown()

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

func populate_image_dropdown() -> void:
	# Clear existing items except the first one
	while image_source_dropdown.item_count > 1:
		image_source_dropdown.remove_item(1)

	# Add existing assets with images
	for i in range(assets.size()):
		var asset = assets[i]
		if asset.has("image_url") and not asset.image_url.is_empty():
			var label = asset.prompt.substr(0, 30) + ("..." if asset.prompt.length() > 30 else "")
			image_source_dropdown.add_item(label, i + 1)

func _on_clear_canvas_pressed() -> void:
	drawing_canvas.clear_canvas()
	status_label.text = ""

func _on_image_source_changed(index: int) -> void:
	if index == 0:
		# Generate new image mode
		prompt_input.text = ""
		prompt_input.placeholder_text = "Describe the 3D asset you want to generate..."
	else:
		# Use existing image mode - pre-fill but allow editing
		var asset_index = image_source_dropdown.get_item_id(index) - 1
		if asset_index >= 0 and asset_index < assets.size():
			var asset = assets[asset_index]
			prompt_input.text = asset.prompt
			prompt_input.placeholder_text = "Edit prompt for this image..."
		# Clear canvas when selecting existing asset (mutually exclusive)
		drawing_canvas.clear_canvas()

func _on_generate_pressed() -> void:
	# Prevent starting a new generation while one is in progress
	if is_generating:
		status_label.text = "Error: Generation already in progress, please wait..."
		return

	var prompt = prompt_input.text.strip_edges()

	# Check if we have a drawing (highest priority, mutually exclusive)
	if not drawing_canvas.is_empty():
		# Use the drawing for mesh generation
		if prompt.is_empty():
			status_label.text = "Error: Please enter a prompt for your drawing"
			return

		is_generating = true
		generate_btn.disabled = true
		status_label.text = "Generating 3D mesh from your drawing..."

		# Convert drawing to image and generate mesh
		generate_from_drawing(prompt)
		return

	var selected_index = image_source_dropdown.selected

	if selected_index == 0:
		# Generate new image from prompt (already declared at line 144)
		if prompt.is_empty():
			status_label.text = "Error: Please enter a prompt"
			return

		if FAL_API_KEY.is_empty():
			status_label.text = "Error: Please set FAL_API_KEY in the script"
			return

		is_generating = true
		generate_btn.disabled = true
		status_label.text = "Step 1/2: Generating image from prompt..."

		# Start image generation
		image_generator.generate_image(prompt)
	else:
		# Use existing image for mesh generation with current prompt
		var asset_index = image_source_dropdown.get_item_id(selected_index) - 1
		if asset_index >= 0 and asset_index < assets.size():
			var asset = assets[asset_index]

			if not asset.has("image_url") or asset.image_url.is_empty():
				status_label.text = "Error: Selected asset has no image"
				return

			# Use the current prompt text (which may have been edited)
			var current_prompt = prompt_input.text.strip_edges()
			if current_prompt.is_empty():
				status_label.text = "Error: Please enter a prompt"
				return

			is_generating = true
			generate_btn.disabled = true
			status_label.text = "Generating 3D mesh from existing image with custom prompt..."

			# Download the existing image and generate mesh with current prompt
			download_existing_image_for_mesh(asset.image_url, current_prompt)
		else:
			status_label.text = "Error: Invalid asset selected"

func generate_from_drawing(prompt: String):
	# Get the canvas image
	var canvas_image = drawing_canvas.get_canvas_image()

	# Convert image to PNG bytes
	var png_bytes = canvas_image.save_png_to_buffer()

	# We need to upload the image somewhere or encode it
	# For now, let's save it locally and use it
	var timestamp = Time.get_ticks_msec()
	var temp_image_path = assets_dir + "drawing_" + str(timestamp) + ".png"

	# Ensure directory exists
	if not DirAccess.dir_exists_absolute(assets_dir):
		DirAccess.make_dir_recursive_absolute(assets_dir)

	canvas_image.save_png(temp_image_path)
	print("Saved drawing to: ", temp_image_path)

	# For the mesh generation, we need a URL. Since we can't upload it,
	# we'll use a local file path approach similar to existing images
	# The API needs a URL, so we'll need to handle this differently

	# Actually, let's just convert it to base64 data URL
	var base64_image = Marshalls.raw_to_base64(png_bytes)
	var data_url = "data:image/png;base64," + base64_image

	status_label.text = "Uploading drawing for mesh generation..."

	# Start mesh generation with the drawing
	# Note: Not all APIs accept data URLs, we might need to upload it first
	mesh_generator.generate_mesh(data_url, prompt, png_bytes)

func download_existing_image_for_mesh(image_url: String, prompt: String):
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_existing_image_downloaded.bind(prompt, image_url))

	print("Downloading existing image: ", image_url)
	var error = http.request(image_url)

	if error != OK:
		status_label.text = "Error: Failed to download existing image"
		generate_btn.disabled = false
		http.queue_free()

func _on_existing_image_downloaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, prompt: String, image_url: String):
	var http = get_children().filter(func(n): return n is HTTPRequest)[0]
	http.queue_free()

	if response_code != 200:
		status_label.text = "Error: Failed to download existing image"
		generate_btn.disabled = false
		return

	#var base64_image = Marshalls.raw_to_base64(body)
	#var data_url = "data:image/png;base64," + base64_image

	# Start mesh generation with the existing image
	mesh_generator.generate_mesh(image_url, prompt, body)
	#image_generator.generate_image()

func _on_status_updated(status_text: String) -> void:
	status_label.text = status_text

func _on_image_gen_failed(error_message: String) -> void:
	status_label.text = "Error: " + error_message
	generate_btn.disabled = false
	is_generating = false

func _on_mesh_gen_failed(error_message: String) -> void:
	status_label.text = "Error: " + error_message
	generate_btn.disabled = false
	is_generating = false

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

		# Create a scene file for the mesh
		create_scene_for_mesh(mesh_path, mesh_filename, asset_id)

		status_label.text = "Success! 3D asset generated and saved."
	else:
		status_label.text = "Error: Failed to save mesh file"
		print("Failed to open file for writing: ", mesh_path)

	is_generating = false
	generate_btn.disabled = false
	populate_browser()

func create_scene_for_mesh(mesh_path: String, mesh_filename: String, asset_id: String):
	# Create a scene file that wraps the GLB mesh
	var scene_content = '[gd_scene load_steps=2 format=3]

[ext_resource type="PackedScene" path="%s" id="1"]

[node name="GeneratedAsset" instance=ExtResource("1")]
' % mesh_path

	var scene_path = assets_dir + "scene_" + asset_id + ".tscn"
	var scene_file = FileAccess.open(scene_path, FileAccess.WRITE)
	if scene_file:
		scene_file.store_string(scene_content)
		scene_file.close()
		print("Created scene file: ", scene_path)

		# Update asset metadata with scene path
		for asset in assets:
			if asset.id == asset_id:
				asset["scene_file"] = "scene_" + asset_id + ".tscn"
				save_metadata()
				break

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
		# Update our tracked modification time after saving
		update_last_modified_time()

func populate_browser() -> void:
	for child in asset_grid.get_children():
		child.queue_free()

	for asset in assets:
		var item = create_asset_item(asset)
		asset_grid.add_child(item)

	# Also update the dropdown
	populate_image_dropdown()

func create_asset_item(asset: Dictionary) -> Control:
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(100, 120)

	# Create draggable panel
	var panel = DraggableAsset.new()
	panel.setup(asset, assets_dir)
	panel.asset_clicked.connect(_on_asset_clicked)

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


	container.add_child(panel)

	var label = Label.new()
	label.text = asset.prompt.substr(0, 10) + ("..." if asset.prompt.length() > 10 else "")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(label)

	return container

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
