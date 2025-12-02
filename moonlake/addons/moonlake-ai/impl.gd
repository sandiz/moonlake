@tool
extends Control

@onready var prompt_input: TextEdit
@onready var generate_btn: Button
@onready var status_label: Label
@onready var asset_grid: GridContainer
@onready var detail_panel: Panel
@onready var detail_prompt: Label
@onready var detail_image: TextureRect
@onready var detail_timestamp: Label


# API Configuration
const FAL_API_KEY = "7f90fe57-7676-42b5-9b2b-a09202face5b:45dc1802c220a66d78359904ad188fb5"
const TEXT_TO_IMAGE_URL = "https://queue.fal.run/fal-ai/nano-banana"
const IMAGE_TO_3D_URL = "https://queue.fal.run/fal-ai/trellis"

# Asset storage
var assets_dir = "res://ai_generated_assets/"
var assets_metadata_path = "res://ai_generated_assets/metadata.json"
var assets = []

func _enter_tree() -> void:
	setup_ui()

func _ready() -> void:
	load_assets()
	populate_browser()

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
	
	# Step 1: Text to Image
	generate_image_from_text(prompt)

func generate_image_from_text(prompt) -> void:
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_image_request_queued.bind(prompt))

	var headers = [
		"Authorization: Key " + FAL_API_KEY,
		"Content-Type: application/json"
	]

	var body = JSON.stringify({
		"prompt": prompt,
		"num_images": 1,
		"aspect_ratio": "1:1",
		"output_format": "png"
	})

	print("Sending request to: ", TEXT_TO_IMAGE_URL)
	print("Headers: ", headers)
	print("Body: ", body)

	var error = http.request(TEXT_TO_IMAGE_URL, headers, HTTPClient.METHOD_POST, body)

	if error != OK:
		status_label.text = "Error: Failed to start image generation request"
		generate_btn.disabled = false
		http.queue_free()

func _on_image_request_queued(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, prompt: String):
	var http = get_children().filter(func(n): return n is HTTPRequest)[0]
	http.queue_free()

	print("Response code: ", response_code)
	print("Response body: ", body.get_string_from_utf8())

	if response_code != 200:
		status_label.text = "Error: Image generation failed (HTTP %d)" % response_code
		generate_btn.disabled = false
		return

	var json = JSON.parse_string(body.get_string_from_utf8())

	if json == null or not json.has("request_id"):
		status_label.text = "Error: Invalid response (no request_id)"
		generate_btn.disabled = false
		return

	var request_id = json.request_id
	var status_url = json.status_url if json.has("status_url") else (TEXT_TO_IMAGE_URL + "/requests/" + request_id + "/status")
	var response_url = json.response_url if json.has("response_url") else (TEXT_TO_IMAGE_URL + "/requests/" + request_id)
	status_label.text = "Waiting for image generation... (polling)"

	# Start polling for the status
	poll_image_result(status_url, response_url, prompt)

func poll_image_result(status_url: String, response_url: String, prompt: String):
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_image_poll_result.bind(status_url, response_url, prompt))

	var headers = [
		"Authorization: Key " + FAL_API_KEY
	]

	print("Polling status: ", status_url)

	var error = http.request(status_url, headers, HTTPClient.METHOD_GET)

	if error != OK:
		status_label.text = "Error: Failed to poll for result"
		generate_btn.disabled = false
		http.queue_free()

func _on_image_poll_result(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, status_url: String, response_url: String, prompt: String):
	var http = get_children().filter(func(n): return n is HTTPRequest)[0]
	http.queue_free()

	print("Poll response code: ", response_code)
	print("Poll response: ", body.get_string_from_utf8())

	if response_code != 200 and response_code != 202:
		status_label.text = "Error: Status check failed (HTTP %d)" % response_code
		generate_btn.disabled = false
		return

	var json = JSON.parse_string(body.get_string_from_utf8())

	if json == null:
		status_label.text = "Error: Invalid status response"
		generate_btn.disabled = false
		return

	# Check status field
	if json.has("status"):
		var status = json.status
		print("Current status: ", status)

		if status == "IN_PROGRESS" or status == "IN_QUEUE":
			# Wait and poll again
			print("Waiting 2 seconds before next poll...")
			await get_tree().create_timer(2.0).timeout
			print("Polling again now...")
			poll_image_result(status_url, response_url, prompt)
			return
		elif status == "COMPLETED":
			# Now fetch the actual result from response_url
			fetch_completed_result(response_url, prompt)
			return
		else:
			status_label.text = "Error: Unexpected status: " + status
			generate_btn.disabled = false
			return

	status_label.text = "Error: No status field in response"
	generate_btn.disabled = false

func fetch_completed_result(response_url: String, prompt: String):
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_completed_result_fetched.bind(prompt))

	var headers = [
		"Authorization: Key " + FAL_API_KEY
	]

	print("Fetching completed result: ", response_url)

	var error = http.request(response_url, headers, HTTPClient.METHOD_GET)

	if error != OK:
		status_label.text = "Error: Failed to fetch result"
		generate_btn.disabled = false
		http.queue_free()

func _on_completed_result_fetched(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, prompt: String):
	var http = get_children().filter(func(n): return n is HTTPRequest)[0]
	http.queue_free()

	print("Result response code: ", response_code)
	print("Result response: ", body.get_string_from_utf8())

	if response_code != 200:
		status_label.text = "Error: Failed to fetch result (HTTP %d)" % response_code
		generate_btn.disabled = false
		return

	var json = JSON.parse_string(body.get_string_from_utf8())

	if json == null or not json.has("images") or json.images.is_empty():
		status_label.text = "Error: No images in result"
		generate_btn.disabled = false
		return

	var image_url = json.images[0].url
	status_label.text = "Step 2/2: Converting image to 3D mesh..."

	# Download the image first
	download_image(image_url, prompt)
		
func download_image(image_url: String, prompt: String):
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_image_downloaded.bind(prompt, image_url))
	
	var error = http.request(image_url)
	
	if error != OK:
		status_label.text = "Error: Failed to download image"
		generate_btn.disabled = false
		http.queue_free()

func _on_image_downloaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, prompt: String, image_url: String):
	var http = get_children().filter(func(n): return n is HTTPRequest)[0]
	http.queue_free()
	
	if response_code != 200:
		status_label.text = "Error: Failed to download image"
		generate_btn.disabled = false
		return
	
	# Now generate 3D mesh from image
	generate_mesh_from_image(image_url, prompt, body)

func generate_mesh_from_image(image_url: String, prompt: String, image_data: PackedByteArray):
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_mesh_request_queued.bind(prompt, image_url, image_data))

	var headers = [
		"Authorization: Key " + FAL_API_KEY,
		"Content-Type: application/json"
	]

	var body = JSON.stringify({
		"image_url": image_url
	})

	print("Sending 3D mesh request to: ", IMAGE_TO_3D_URL)
	print("Image URL: ", image_url)

	var error = http.request(IMAGE_TO_3D_URL, headers, HTTPClient.METHOD_POST, body)

	if error != OK:
		status_label.text = "Error: Failed to start 3D generation request"
		generate_btn.disabled = false
		http.queue_free()

func _on_mesh_request_queued(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, prompt: String, image_url: String, image_data: PackedByteArray):
	var http = get_children().filter(func(n): return n is HTTPRequest)[0]
	http.queue_free()

	print("Mesh queue response code: ", response_code)
	print("Mesh queue response: ", body.get_string_from_utf8())

	if response_code != 200:
		status_label.text = "Error: 3D generation failed to queue (HTTP %d)" % response_code
		generate_btn.disabled = false
		return

	var json = JSON.parse_string(body.get_string_from_utf8())

	if json == null or not json.has("request_id"):
		status_label.text = "Error: Invalid 3D queue response (no request_id)"
		generate_btn.disabled = false
		return

	var request_id = json.request_id
	var status_url = json.status_url if json.has("status_url") else (IMAGE_TO_3D_URL + "/requests/" + request_id + "/status")
	var response_url = json.response_url if json.has("response_url") else (IMAGE_TO_3D_URL + "/requests/" + request_id)
	status_label.text = "Converting to 3D mesh... (polling)"

	# Start polling for the 3D mesh result
	poll_mesh_result(status_url, response_url, prompt, image_url, image_data)

func poll_mesh_result(status_url: String, response_url: String, prompt: String, image_url: String, image_data: PackedByteArray):
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_mesh_poll_result.bind(status_url, response_url, prompt, image_url, image_data))

	var headers = [
		"Authorization: Key " + FAL_API_KEY
	]

	print("Polling mesh status: ", status_url)

	var error = http.request(status_url, headers, HTTPClient.METHOD_GET)

	if error != OK:
		status_label.text = "Error: Failed to poll for 3D result"
		generate_btn.disabled = false
		http.queue_free()

func _on_mesh_poll_result(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, status_url: String, response_url: String, prompt: String, image_url: String, image_data: PackedByteArray):
	var http = get_children().filter(func(n): return n is HTTPRequest)[0]
	http.queue_free()

	print("Mesh poll response code: ", response_code)
	print("Mesh poll response: ", body.get_string_from_utf8())

	if response_code != 200 and response_code != 202:
		status_label.text = "Error: 3D status check failed (HTTP %d)" % response_code
		generate_btn.disabled = false
		return

	var json = JSON.parse_string(body.get_string_from_utf8())

	if json == null:
		status_label.text = "Error: Invalid 3D status response"
		generate_btn.disabled = false
		return

	# Check status field
	if json.has("status"):
		var status = json.status
		print("Current 3D mesh status: ", status)

		if status == "IN_PROGRESS" or status == "IN_QUEUE":
			# Wait and poll again
			print("Waiting 3 seconds before next mesh poll...")
			await get_tree().create_timer(3.0).timeout
			print("Polling mesh again now...")
			poll_mesh_result(status_url, response_url, prompt, image_url, image_data)
			return
		elif status == "COMPLETED":
			# Now fetch the actual 3D mesh result
			fetch_completed_mesh(response_url, prompt, image_url, image_data)
			return
		else:
			status_label.text = "Error: Unexpected 3D status: " + status
			generate_btn.disabled = false
			return

	status_label.text = "Error: No status field in 3D response"
	generate_btn.disabled = false

func fetch_completed_mesh(response_url: String, prompt: String, image_url: String, image_data: PackedByteArray):
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_mesh_result_fetched.bind(prompt, image_url, image_data))

	var headers = [
		"Authorization: Key " + FAL_API_KEY
	]

	print("Fetching completed 3D mesh: ", response_url)

	var error = http.request(response_url, headers, HTTPClient.METHOD_GET)

	if error != OK:
		status_label.text = "Error: Failed to fetch 3D mesh"
		generate_btn.disabled = false
		http.queue_free()

func _on_mesh_result_fetched(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, prompt: String, image_url: String, image_data: PackedByteArray):
	var http = get_children().filter(func(n): return n is HTTPRequest)[0]
	http.queue_free()

	print("Mesh result response code: ", response_code)
	print("Mesh result response: ", body.get_string_from_utf8())

	if response_code != 200:
		status_label.text = "Error: Failed to fetch 3D mesh (HTTP %d)" % response_code
		generate_btn.disabled = false
		return

	var json = JSON.parse_string(body.get_string_from_utf8())

	if json == null:
		status_label.text = "Error: Invalid 3D mesh result"
		generate_btn.disabled = false
		return

	# Save the asset with mesh data
	save_asset(prompt, image_url, image_data, json)

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
				# Use the original extension
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
	
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(100, 100)
	btn.pressed.connect(_on_asset_clicked.bind(asset))
	
	var thumb_path = assets_dir + asset.thumbnail
	if FileAccess.file_exists(thumb_path):
		var image = Image.new()
		var error = image.load(thumb_path)
		if error == OK:
			var texture = ImageTexture.create_from_image(image)
			var texture_rect = TextureRect.new()
			texture_rect.texture = texture
			texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texture_rect.custom_minimum_size = Vector2(90, 90)
			texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(texture_rect)

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
				btn.add_child(badge)

	container.add_child(btn)

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
	
	# btn.set_drag_forwarding(Callable(), _get_drag_data.bind(asset), Callable())
	
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
		var image = Image.new()
		var error = image.load(thumb_path)
		if error == OK:
			detail_image.texture = ImageTexture.create_from_image(image)
