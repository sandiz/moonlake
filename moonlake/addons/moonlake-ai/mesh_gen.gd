@tool
extends Node
class_name MeshGenerator

signal mesh_generated(mesh_data: Dictionary, image_url: String, image_data: PackedByteArray, prompt: String)
signal generation_failed(error_message: String)
signal status_updated(status_text: String)

var api_key: String
var api_url: String

func _init(key: String, url: String):
	api_key = key
	api_url = url

func generate_mesh(image_url: String, prompt: String, image_data: PackedByteArray) -> void:
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_mesh_request_queued.bind(prompt, image_url, image_data, http))

	var headers = [
		"Authorization: Key " + api_key,
		"Content-Type: application/json"
	]

	var body = JSON.stringify({
		"image_url": image_url
	})

	print("Sending 3D mesh request to: ", api_url)
	print("Image URL: ", image_url)

	var error = http.request(api_url, headers, HTTPClient.METHOD_POST, body)

	if error != OK:
		generation_failed.emit("Failed to start 3D generation request")
		http.queue_free()

func _on_mesh_request_queued(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, prompt: String, image_url: String, image_data: PackedByteArray, http: HTTPRequest):
	http.queue_free()

	print("Mesh queue response code: ", response_code)
	print("Mesh queue response: ", body.get_string_from_utf8())

	if response_code != 200:
		generation_failed.emit("3D generation failed to queue (HTTP %d)" % response_code)
		return

	var json = JSON.parse_string(body.get_string_from_utf8())

	if json == null or not json.has("request_id"):
		generation_failed.emit("Invalid 3D queue response (no request_id)")
		return

	var request_id = json.request_id
	var status_url = json.status_url if json.has("status_url") else (api_url + "/requests/" + request_id + "/status")
	var response_url = json.response_url if json.has("response_url") else (api_url + "/requests/" + request_id)
	status_updated.emit("Converting to 3D mesh... (polling)")

	poll_mesh_result(status_url, response_url, prompt, image_url, image_data)

func poll_mesh_result(status_url: String, response_url: String, prompt: String, image_url: String, image_data: PackedByteArray):
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_mesh_poll_result.bind(status_url, response_url, prompt, image_url, image_data, http))

	var headers = [
		"Authorization: Key " + api_key
	]

	print("Polling mesh status: ", status_url)

	var error = http.request(status_url, headers, HTTPClient.METHOD_GET)

	if error != OK:
		generation_failed.emit("Failed to poll for 3D result")
		http.queue_free()

func _on_mesh_poll_result(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, status_url: String, response_url: String, prompt: String, image_url: String, image_data: PackedByteArray, http: HTTPRequest):
	http.queue_free()

	print("Mesh poll response code: ", response_code)
	print("Mesh poll response: ", body.get_string_from_utf8())

	if response_code != 200 and response_code != 202:
		generation_failed.emit("3D status check failed (HTTP %d)" % response_code)
		return

	var json = JSON.parse_string(body.get_string_from_utf8())

	if json == null:
		generation_failed.emit("Invalid 3D status response")
		return

	if json.has("status"):
		var status = json.status
		print("Current 3D mesh status: ", status)

		if status == "IN_PROGRESS" or status == "IN_QUEUE":
			print("Waiting 3 seconds before next mesh poll...")
			await get_tree().create_timer(3.0).timeout
			print("Polling mesh again now...")
			poll_mesh_result(status_url, response_url, prompt, image_url, image_data)
			return
		elif status == "COMPLETED":
			fetch_completed_mesh(response_url, prompt, image_url, image_data)
			return
		else:
			generation_failed.emit("Unexpected 3D status: " + status)
			return

	generation_failed.emit("No status field in 3D response")

func fetch_completed_mesh(response_url: String, prompt: String, image_url: String, image_data: PackedByteArray):
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_mesh_result_fetched.bind(prompt, image_url, image_data, http))

	var headers = [
		"Authorization: Key " + api_key
	]

	print("Fetching completed 3D mesh: ", response_url)

	var error = http.request(response_url, headers, HTTPClient.METHOD_GET)

	if error != OK:
		generation_failed.emit("Failed to fetch 3D mesh")
		http.queue_free()

func _on_mesh_result_fetched(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, prompt: String, image_url: String, image_data: PackedByteArray, http: HTTPRequest):
	http.queue_free()

	print("Mesh result response code: ", response_code)
	print("Mesh result response: ", body.get_string_from_utf8())

	if response_code != 200:
		generation_failed.emit("Failed to fetch 3D mesh (HTTP %d)" % response_code)
		return

	var json = JSON.parse_string(body.get_string_from_utf8())

	if json == null:
		generation_failed.emit("Invalid 3D mesh result")
		return

	# Emit success with mesh data
	mesh_generated.emit(json, image_url, image_data, prompt)
