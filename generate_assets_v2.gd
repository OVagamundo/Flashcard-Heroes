@tool
extends SceneTree

# Configuration for colors (Slate/Silver & Beige/Wood theme)
const COLOR_PANEL_BG = Color("3c465a") # Slate Blue
const COLOR_PANEL_BORDER = Color("b4b4b4") # Light Grey
const COLOR_PANEL_BORDER_DARK = Color("2b2116") # Dark Outline

const COLOR_BTN_NORMAL = Color("e2cfa4") # Beige
const COLOR_BTN_HOVER = Color("ebdcb8") # Light Beige
const COLOR_BTN_PRESSED = Color("c4a474") # Dark Beige
const COLOR_BTN_DISABLED = Color("7a7a7a") # Grey

const COLOR_INPUT_BG = Color("252525") # Dark Field
const COLOR_ACCENT = Color("ffd700") # Gold

func _init():
	print("Starting asset generation...")
	var dir = DirAccess.open("res://assets/Realistic/ui/textures")
	if not dir:
		print("Creating directory...")
		DirAccess.make_dir_recursive_absolute("res://assets/Realistic/ui/textures")
	
	# 1. Panels
	generate_9slice_rect("panel_32x32.png", 32, 32, COLOR_PANEL_BG, COLOR_PANEL_BORDER, 2)
	
	# 2. Buttons
	generate_button("button_normal_32x32.png", COLOR_BTN_NORMAL)
	generate_button("button_hover_32x32.png", COLOR_BTN_HOVER)
	generate_button("button_pressed_32x32.png", COLOR_BTN_PRESSED)
	generate_button("button_disabled_32x32.png", COLOR_BTN_DISABLED)
	
	# 3. Sliders (Grabber & Track)
	generate_slider_grabber("slider_grabber_16x16.png")
	generate_slider_track("slider_track_32x8.png")
	
	# 4. Progress Bars
	generate_flat_rect("progress_fill.png", 32, 8, Color("44ff44"), Color("114411"))
	generate_flat_rect("progress_bg.png", 32, 8, Color("222222"), Color("000000"))
	
	# 5. LineEdit
	generate_9slice_rect("line_edit.png", 32, 32, COLOR_INPUT_BG, Color("555555"), 2, true) # Recessed
	
	# 6. Tabs
	generate_tab("tab_active.png", COLOR_PANEL_BG)
	generate_tab("tab_inactive.png", COLOR_PANEL_BG.darkened(0.3))
	
	# 7. Checkbox
	generate_checkbox("checkbox_checked.png", true)
	generate_checkbox("checkbox_unchecked.png", false)
	
	print("Asset generation complete.")
	quit()

func generate_9slice_rect(filename, w, h, bg, border, border_width, recessed = false):
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	for x in range(w):
		for y in range(h):
			if x < border_width or x >= w - border_width or y < border_width or y >= h - border_width:
				img.set_pixel(x, y, border)
			else:
				img.set_pixel(x, y, bg)
	
	# Highlights/Shadows
	var light = border.lightened(0.3)
	var dark = border.darkened(0.3)
	
	if recessed:
		var temp = light
		light = dark
		dark = temp
		
	# Top line highlight
	for x in range(1, w - 1):
		img.set_pixel(x, 0, light)
		img.set_pixel(x, 1, light) # thick
		
	# Left line highlight
	for y in range(1, h - 1):
		img.set_pixel(0, y, light)
		img.set_pixel(1, y, light)
		
	# Bottom shadow
	for x in range(1, w - 1):
		img.set_pixel(x, h - 1, dark)
		img.set_pixel(x, h - 2, dark)
		
	# Right shadow
	for y in range(1, h - 1):
		img.set_pixel(w - 1, y, dark)
		img.set_pixel(w - 2, y, dark)

	save_image(img, filename)

func generate_flat_rect(filename, w, h, bg, border):
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(bg)
	# Simple border
	for x in range(w):
		img.set_pixel(x, 0, border)
		img.set_pixel(x, h - 1, border)
	for y in range(h):
		img.set_pixel(0, y, border)
		img.set_pixel(w - 1, y, border)
	save_image(img, filename)

func generate_button(filename, base_color):
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var outline = Color("2b2116")
	
	# Fill base
	for x in range(2, 30):
		for y in range(2, 30):
			img.set_pixel(x, y, base_color)
			
	# Heavy Outline
	for x in range(32):
		for y in range(32):
			if x < 2 or x >= 30 or y < 2 or y >= 30:
				# Corners transparent? No, blocky corners
				if (x < 2 and y < 2) or (x >= 30 and y < 2) or (x < 2 and y >= 30) or (x >= 30 and y >= 30):
					# Transparent corners for rounded look? Reference was blocky.
					# Let's keep corners black for sturdy look
					pass
				img.set_pixel(x, y, outline)
				
	# Inner Bevel
	var light = base_color.lightened(0.2)
	var dark = base_color.darkened(0.2)
	
	for i in range(2, 30):
		img.set_pixel(i, 2, light)
		img.set_pixel(i, 3, light)
		img.set_pixel(2, i, light)
		img.set_pixel(3, i, light)
		
		img.set_pixel(i, 28, dark)
		img.set_pixel(i, 29, dark)
		img.set_pixel(28, i, dark)
		img.set_pixel(29, i, dark)
		
	save_image(img, filename)

func generate_slider_grabber(filename):
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var color = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	# Draw a circle-ish shape or block
	for x in range(16):
		for y in range(16):
			if x > 2 and x < 13 and y > 2 and y < 13:
				img.set_pixel(x, y, COLOR_BTN_NORMAL)
			else:
				if x > 4 and x < 11 and y > 0 and y < 16: # vertical bar look
					img.set_pixel(x, y, COLOR_PANEL_BORDER_DARK)
	save_image(img, filename)

func generate_slider_track(filename):
	# Thin line with border
	var img = Image.create(32, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(32):
		for y in range(2, 6):
			img.set_pixel(x, y, Color("111111"))
	save_image(img, filename)

func generate_tab(filename, color):
	# Like a panel but open bottom
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var border = COLOR_PANEL_BORDER
	
	for x in range(32):
		for y in range(32):
			if x < 2 or x >= 30 or y < 2: # No bottom border
				img.set_pixel(x, y, border)
			else:
				img.set_pixel(x, y, color)
	save_image(img, filename)

func generate_checkbox(filename, checked):
	var img = Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(COLOR_INPUT_BG)
	var border = Color("888888")
	
	# Border
	for x in range(24):
		img.set_pixel(x, 0, border)
		img.set_pixel(x, 1, border)
		img.set_pixel(x, 22, border)
		img.set_pixel(x, 23, border)
	for y in range(24):
		img.set_pixel(0, y, border)
		img.set_pixel(1, y, border)
		img.set_pixel(22, y, border)
		img.set_pixel(23, y, border)
		
	if checked:
		var mark_color = Color("44cc44")
		# Draw X or Check
		for i in range(4, 20):
			img.set_pixel(i, i, mark_color)
			img.set_pixel(i, 23 - i, mark_color)
			
	save_image(img, filename)

func save_image(img: Image, filename: String):
	var path = "res://assets/Realistic/ui/textures/" + filename
	img.save_png(path)
	print("Generated: " + path)
