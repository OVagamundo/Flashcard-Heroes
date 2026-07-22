@tool
extends SceneTree

# Palette
const C_HEART_FILL = Color("e53935") # Red
const C_HEART_SHADE = Color("b71c1c")
const C_HEART_OUTLINE = Color("4b0000")

const C_POWER_FILL = Color("1e88e5") # Blue
const C_POWER_SHADE = Color("0d47a1")
const C_POWER_OUTLINE = Color("002171")

func _init():
	print("Starting Icon Generation V6 (Balanced)...")
	var path = "res://assets/Realistic/ui/textures/"
	
	# 1. Wide Heart (64x64) - Tuned to hold "99"
	generate_heart("icon_heart_bg.png")

	# 2. Wide Shield (64x64) - Tuned to match Heart size
	generate_shield("icon_power_bg.png")
	
	print("Icon Generation Complete.")
	quit()

func generate_heart(filename):
	var w = 64; var h = 64
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	
	# Simple chunky pixel heart
	# Draw broad strokes
	var center_x = 32
	var center_y = 32
	
	# Fill logic: Union of two circles and a triangle, basically
	for x in range(w):
		for y in range(h):
			var dx = (x - center_x) / 32.0
			var dy = - (y - 36) / 32.0 # Higher center
			# Heart Equation
			var val = pow(dx * dx + dy * dy - 1.0, 3) - dx * dx * pow(dy, 3)
			if val <= 0.0:
				img.set_pixel(x, y, C_HEART_FILL)

	# Expand slightly to be chunky
	var img2 = expand_shape(img, C_HEART_FILL)
	process_pixel_art(img2, C_HEART_FILL, C_HEART_SHADE, C_HEART_OUTLINE)
	save_image(img2, filename)

func generate_shield(filename):
	var w = 64; var h = 64
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	
	# Chunky Shield (Heater Shield shape)
	# Rect top, Curve bottom
	for x in range(w):
		for y in range(h):
			var in_shield = false
			# Main box 
			if x >= 8 and x <= 56:
				if y >= 8 and y <= 32: in_shield = true
				if y > 32:
					# Elliptic curve to bottom point
					var dy = (y - 32)
					var dx = abs(x - 32)
					# x^2/a^2 + y^2/b^2 <= 1
					# a = 24, b = 28
					if (pow(dx, 2) / pow(24, 2) + pow(dy, 2) / pow(24, 2)) <= 1.0:
						in_shield = true
			if in_shield:
				img.set_pixel(x, y, C_POWER_FILL)

	# Expand to match heart weight
	var img2 = expand_shape(img, C_POWER_FILL)
	process_pixel_art(img2, C_POWER_FILL, C_POWER_SHADE, C_POWER_OUTLINE)
	save_image(img2, filename)

func expand_shape(src: Image, col):
	var dst = src.duplicate()
	var w = src.get_width()
	var h = src.get_height()
	for x in range(1, w - 1):
		for y in range(1, h - 1):
			if src.get_pixel(x, y).a > 0:
				dst.set_pixel(x + 1, y, col)
				dst.set_pixel(x - 1, y, col)
				dst.set_pixel(x, y + 1, col)
				dst.set_pixel(x, y - 1, col)
	return dst

func process_pixel_art(img: Image, fill_col, shade_col, outline_col):
	var w = img.get_width()
	var h = img.get_height()
	
	# 1. Shading (Inset)
	for x in range(w):
		for y in range(h):
			if img.get_pixel(x, y).a > 0:
				# Distance from bottom-right
				if x > 32 or y > 32:
					img.set_pixel(x, y, shade_col)
	
	# Restore Fill (Center)
	for x in range(4, w - 4):
		for y in range(4, h - 4):
			if img.get_pixel(x, y).a > 0:
				if x < 40 and y < 40:
					img.set_pixel(x, y, fill_col)
					
	# 2. Outline
	var temp = img.duplicate()
	for x in range(w):
		for y in range(h):
			if temp.get_pixel(x, y).a == 0:
				var has_neighbor = false
				for dx in [-1, 0, 1]:
					for dy in [-1, 0, 1]:
						if x + dx >= 0 and x + dx < w and y + dy >= 0 and y + dy < h:
							if temp.get_pixel(x + dx, y + dy).a > 0:
								has_neighbor = true
				if has_neighbor:
					img.set_pixel(x, y, outline_col)

	# 3. Highlight
	for x in range(10, 30):
		for y in range(10, 30):
			if img.get_pixel(x, y) == fill_col:
				if (x + y) % 4 == 0:
					img.set_pixel(x, y, fill_col.lightened(0.4))

func save_image(img: Image, filename: String):
	var path = "res://assets/Realistic/ui/textures/" + filename
	img.save_png(path)
	print("Generated: " + path)
