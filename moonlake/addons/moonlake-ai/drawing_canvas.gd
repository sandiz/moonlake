@tool
extends Control
class_name DrawingCanvas

var drawing = false
var strokes = []  # Array of stroke arrays
var current_stroke = []
var brush_color = Color.BLACK
var brush_size = 3.0
var background_color = Color.WHITE

func _ready():
	custom_minimum_size = Vector2(0, 200)

func _draw():
	# Draw background
	draw_rect(Rect2(Vector2.ZERO, size), background_color, true)

	# Draw all strokes
	for stroke in strokes:
		for i in range(1, stroke.size()):
			draw_line(stroke[i-1], stroke[i], brush_color, brush_size)

	# Draw current stroke
	for i in range(1, current_stroke.size()):
		draw_line(current_stroke[i-1], current_stroke[i], brush_color, brush_size)

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				drawing = true
				current_stroke = [event.position]
			else:
				drawing = false
				if current_stroke.size() > 0:
					strokes.append(current_stroke.duplicate())
					current_stroke = []
			queue_redraw()

	elif event is InputEventMouseMotion and drawing:
		current_stroke.append(event.position)
		queue_redraw()

func clear_canvas():
	strokes.clear()
	current_stroke.clear()
	queue_redraw()

func is_empty() -> bool:
	return strokes.is_empty() and current_stroke.is_empty()

func get_canvas_image() -> Image:
	# Create an image from the canvas
	var img = Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGB8)

	# Fill with background color
	img.fill(background_color)

	# Draw all strokes onto the image
	for stroke in strokes:
		for i in range(1, stroke.size()):
			draw_line_on_image(img, stroke[i-1], stroke[i])

	return img

func draw_line_on_image(img: Image, from: Vector2, to: Vector2):
	# Simple line drawing using Bresenham's algorithm
	var x0 = int(from.x)
	var y0 = int(from.y)
	var x1 = int(to.x)
	var y1 = int(to.y)

	var dx = abs(x1 - x0)
	var dy = abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx - dy

	while true:
		# Draw a circle for brush size
		for bx in range(-int(brush_size/2), int(brush_size/2) + 1):
			for by in range(-int(brush_size/2), int(brush_size/2) + 1):
				var px = x0 + bx
				var py = y0 + by
				if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
					if bx * bx + by * by <= (brush_size/2) * (brush_size/2):
						img.set_pixel(px, py, brush_color)

		if x0 == x1 and y0 == y1:
			break

		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy
