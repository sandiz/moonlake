@tool
extends Node
class_name ImageGenerator

signal image_generated(image_url: String, image_data: PackedByteArray, prompt: String)
signal generation_failed(error_message: String)
signal status_updated(status_text: String)

var api_key: String
var api_url: String

func _init(key: String, url: String):
	api_key = key
	api_url = url

func generate_image(prompt: String) -> void:
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_image_request_queued.bind(prompt, http))

	var headers = [
		"Authorization: Key " + api_key,
		"Content-Type: application/json"
	]

	var body = JSON.stringify({
		"prompt": prompt,
		"num_images": 1,
		"aspect_ratio": "1:1",
		"output_format": "png"
	})

	print("Sending request to: ", api_url)
	print("Headers: ", headers)
	print("Body: ", body)

	var error = http.request(api_url, headers, HTTPClient.METHOD_POST, body)

	if error != OK:
		generation_failed.emit("Failed to start image generation request")
		http.queue_free()

func _on_image_request_queued(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, prompt: String, http: HTTPRequest):
	http.queue_free()

	print("Response code: ", response_code)
	print("Response body: ", body.get_string_from_utf8())

	if response_code != 200:
		generation_failed.emit("Image generation failed (HTTP %d)" % response_code)
		return

	var json = JSON.parse_string(body.get_string_from_utf8())

	if json == null or not json.has("request_id"):
		generation_failed.emit("Invalid response (no request_id)")
		return

	var request_id = json.request_id
	var status_url = json.status_url if json.has("status_url") else (api_url + "/requests/" + request_id + "/status")
	var response_url = json.response_url if json.has("response_url") else (api_url + "/requests/" + request_id)
	status_updated.emit("Waiting for image generation... (polling)")

	poll_image_result(status_url, response_url, prompt)

func poll_image_result(status_url: String, response_url: String, prompt: String):
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_image_poll_result.bind(status_url, response_url, prompt, http))

	var headers = [
		"Authorization: Key " + api_key
	]

	print("Polling status: ", status_url)

	var error = http.request(status_url, headers, HTTPClient.METHOD_GET)

	if error != OK:
		generation_failed.emit("Failed to poll for result")
		http.queue_free()

func _on_image_poll_result(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, status_url: String, response_url: String, prompt: String, http: HTTPRequest):
	http.queue_free()

	print("Poll response code: ", response_code)
	print("Poll response: ", body.get_string_from_utf8())

	if response_code != 200 and response_code != 202:
		generation_failed.emit("Status check failed (HTTP %d)" % response_code)
		return

	var json = JSON.parse_string(body.get_string_from_utf8())

	if json == null:
		generation_failed.emit("Invalid status response")
		return

	if json.has("status"):
		var status = json.status
		print("Current status: ", status)

		if status == "IN_PROGRESS" or status == "IN_QUEUE":
			print("Waiting 2 seconds before next poll...")
			await get_tree().create_timer(2.0).timeout
			print("Polling again now...")
			poll_image_result(status_url, response_url, prompt)
			return
		elif status == "COMPLETED":
			fetch_completed_result(response_url, prompt)
			return
		else:
			generation_failed.emit("Unexpected status: " + status)
			return

	generation_failed.emit("No status field in response")

func fetch_completed_result(response_url: String, prompt: String):
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_completed_result_fetched.bind(prompt, http))

	var headers = [
		"Authorization: Key " + api_key
	]

	print("Fetching completed result: ", response_url)

	var error = http.request(response_url, headers, HTTPClient.METHOD_GET)

	if error != OK:
		generation_failed.emit("Failed to fetch result")
		http.queue_free()

func _on_completed_result_fetched(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, prompt: String, http: HTTPRequest):
	http.queue_free()

	print("Result response code: ", response_code)
	print("Result response: ", body.get_string_from_utf8())

	if response_code != 200:
		generation_failed.emit("Failed to fetch result (HTTP %d)" % response_code)
		return

	var json = JSON.parse_string(body.get_string_from_utf8())

	if json == null or not json.has("images") or json.images.is_empty():
		generation_failed.emit("No images in result")
		return

	var image_url = json.images[0].url
	status_updated.emit("Step 2/2: Converting image to 3D mesh...")

	download_image(image_url, prompt)

func download_image(image_url: String, prompt: String):
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_image_downloaded.bind(prompt, image_url, http))

	var error = http.request(image_url)

	if error != OK:
		generation_failed.emit("Failed to download image")
		http.queue_free()

func _on_image_downloaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, prompt: String, image_url: String, http: HTTPRequest):
	http.queue_free()

	if response_code != 200:
		generation_failed.emit("Failed to download image")
		return

	# Emit success with the image data
	image_generated.emit(image_url, body, prompt)
