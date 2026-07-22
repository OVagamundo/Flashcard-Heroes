@tool
extends SceneTree

# Palette: Wood & Gold RPG Style
const C_WOOD_DARK = Color("3e2723") # Darkest frame outline
const C_WOOD_MID = Color("5d4037") # Frame body
const C_WOOD_LIT = Color("8d6e63") # Frame highlight

const C_PARCHMENT = Color("d7ccc8") # Panel background (paper-like)
const C_GOLD = Color("ffb300") # Accents/Borders
const C_GOLD_LIT = Color("ffca28")
const C_GOLD_DARK = Color("c6a700")

const C_BTN_NORMAL = Color("6d4c41") # Standard wood button
const C_BTN_HOVER = Color("795548") # Lighter
const C_BTN_PRESSED = Color("4e342e") # Darker
const C_BTN_DISABLED = Color("555555")

const C_INPUT_BG = Color("3e2723") # Dark recessed wood

func _init():
	print("Starting V3 Asset Generation (Wood & Gold)...")
	var path = "res://assets/Realistic/ui/textures/"
	var dir = DirAccess.open(path)
	if not dir:
		DirAccess.make_dir_recursive_absolute(path)

	# 1. Main Panel (Wood Frame + Parchment Body)
	generate_panel_v3("panel_wood.png")

	# 2. Buttons (Wood Block + Gold Border)
	generate_button_v3("button_wood_normal.png", C_BTN_NORMAL)
	generate_button_v3("button_wood_hover.png", C_BTN_HOVER, true) # brighter gold
	generate_button_v3("button_wood_pressed.png", C_BTN_PRESSED)
	generate_button_v3("button_wood_disabled.png", C_BTN_DISABLED, false, true)

	# 3. Sliders
	generate_slider_track_v3("slider_wood_track.png")
	generate_slider_grabber_v3("slider_gold_grabber.png")

	# 4. Progress Bars (Health & Power)
	# Health: Red w/ Gold Border
	generate_bar_fill_v3("bar_health_fill.png", Color("d32f2f"), Color("b71c1c"))
	generate_bar_bg_v3("bar_bg.png") # Generic dark wood bg
	# Power: Blue w/ Silver/Gold Border
	generate_bar_fill_v3("bar_power_fill.png", Color("1976d2"), Color("0d47a1"))

	# 5. Input / LineEdit
	generate_input_v3("input_wood.png")

	# 6. Tabs
	generate_tab_v3("tab_wood_active.png", C_BTN_NORMAL)
	generate_tab_v3("tab_wood_inactive.png", C_BTN_PRESSED)

	# 7. Checkbox
	generate_checkbox_v3("checkbox_wood_checked.png", true)
	generate_checkbox_v3("checkbox_wood_unchecked.png", false)

	print("V3 Asset Generation Complete.")
	quit()

# --- Drawing Functions ---

func generate_panel_v3(filename):
	var w = 32; var h = 32
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	# Parchment Fill (inset 2px)
	for x in range(2, 30):
		for y in range(2, 30):
			img.set_pixel(x, y, C_PARCHMENT)
			# Add slight noise/texture to parchment? Keep simple for pixel art check 
			if (x + y) % 5 == 0: img.set_pixel(x, y, C_PARCHMENT.darkened(0.05))

	# Wood Frame (Border 4px visual, 9-slice)
	draw_frame(img, 0, 0, w, h, 4, C_WOOD_MID, C_WOOD_LIT, C_WOOD_DARK)
	
	# Gold Corner Accents (1px dot)
	img.set_pixel(1, 1, C_GOLD)
	img.set_pixel(w - 2, 1, C_GOLD)
	img.set_pixel(1, h - 2, C_GOLD)
	img.set_pixel(w - 2, h - 2, C_GOLD)

	save_image(img, filename)

func generate_button_v3(filename, base_col, highlight = false, grayscale = false):
	var w = 32; var h = 32
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	var border_col = C_GOLD if not grayscale else Color("555555")
	if highlight: border_col = C_GOLD_LIT

	# Fill body
	for x in range(2, 30):
		for y in range(2, 30):
			img.set_pixel(x, y, base_col)

	# Main Border (Gold/Frame)
	# Outer dark outline
	draw_rect_outline(img, 0, 0, w, h, C_WOOD_DARK)
	# Inner gold/metallic frame
	draw_rect_outline(img, 1, 1, w - 2, h - 2, border_col)
	
	# Bevel highlight on body
	draw_rect_outline(img, 2, 2, w - 4, h - 4, base_col.lightened(0.1))

	# 9-slice corners? No, buttons usually stretch mid. 
	# Let's add "nails" or bolts in corners
	var bolt = C_WOOD_DARK
	img.set_pixel(3, 3, bolt); img.set_pixel(w - 4, 3, bolt)
	img.set_pixel(3, h - 4, bolt); img.set_pixel(w - 4, h - 4, bolt)

	save_image(img, filename)

func generate_slider_track_v3(filename):
	var w = 32; var h = 10
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	# Dark wood trough
	for x in range(w):
		for y in range(2, 8):
			img.set_pixel(x, y, C_WOOD_DARK)
	
	# Light bottom edge
	for x in range(w):
		img.set_pixel(x, 7, C_WOOD_LIT)

	save_image(img, filename)

func generate_slider_grabber_v3(filename):
	var w = 14; var h = 20 # Tall chunky grabber
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	# Shield/Block shape
	for x in range(2, w - 2):
		for y in range(2, h - 2):
			img.set_pixel(x, y, C_GOLD)
	
	# Outline
	draw_rect_outline(img, 1, 1, w - 2, h - 2, C_WOOD_DARK)
	img.set_pixel(w / 2, h / 2, C_WOOD_DARK) # Center dot

	save_image(img, filename)

func generate_bar_bg_v3(filename):
	var w = 32; var h = 12
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(C_WOOD_DARK.darkened(0.3))
	# Frame
	draw_rect_outline(img, 0, 0, w, h, C_WOOD_MID)
	save_image(img, filename)

func generate_bar_fill_v3(filename, col_mid, col_dark):
	var w = 32; var h = 12
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	# Inset fill
	for x in range(1, w - 1):
		for y in range(1, h - 1):
			if y < h / 2: img.set_pixel(x, y, col_mid)
			else: img.set_pixel(x, y, col_dark) # Gradient effect
			
	# Top highlight
	for x in range(1, w - 1):
		img.set_pixel(x, 2, col_mid.lightened(0.3))

	save_image(img, filename)

func generate_input_v3(filename):
	var w = 32; var h = 32
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(C_INPUT_BG)
	
	# Sunken Frame
	draw_frame(img, 0, 0, w, h, 2, C_WOOD_DARK, C_WOOD_DARK, C_WOOD_LIT) # Inverted light/dark for sunk
	save_image(img, filename)

func generate_tab_v3(filename, base_col):
	var w = 32; var h = 32
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	# Fill rounded top
	for x in range(2, 30):
		for y in range(2, 32):
			img.set_pixel(x, y, base_col)
			
	# Border (No bottom)
	for x in range(32):
		img.set_pixel(x, 1, C_WOOD_DARK)
		img.set_pixel(x, 2, C_GOLD) # Gold highlight on top
	for y in range(1, 32):
		img.set_pixel(1, y, C_WOOD_DARK)
		img.set_pixel(w - 2, y, C_WOOD_DARK)

	save_image(img, filename)

func generate_checkbox_v3(filename, checked):
	var w = 24; var h = 24
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(C_INPUT_BG)
	
	draw_rect_outline(img, 0, 0, w, h, C_GOLD)
	
	if checked:
		# Draw Gold X
		for i in range(4, 20):
			img.set_pixel(i, i, C_GOLD_LIT)
			img.set_pixel(i, 23 - i, C_GOLD_LIT)
	
	save_image(img, filename)

# Utilities
func draw_rect_outline(img, x, y, w, h, col):
	for i in range(x, x + w):
		img.set_pixel(i, y, col)
		img.set_pixel(i, y + h - 1, col)
	for j in range(y, y + h):
		img.set_pixel(x, j, col)
		img.set_pixel(x + w - 1, j, col)

func draw_frame(img, x, y, w, h, thick, col_base, col_light, col_dark):
	# Simple beveled frame loop
	for t in range(thick):
		var rect_x = x + t
		var rect_y = y + t
		var rect_w = w - (t * 2)
		var rect_h = h - (t * 2)
		
		# Top/Left Light
		for i in range(rect_w): img.set_pixel(rect_x + i, rect_y, col_light)
		for j in range(rect_h): img.set_pixel(rect_x, rect_y + j, col_light)
		
		# Bottom/Right Dark
		for i in range(rect_w): img.set_pixel(rect_x + i, rect_y + rect_h - 1, col_dark)
		for j in range(rect_h): img.set_pixel(rect_x + rect_w - 1, rect_y + j, col_dark)

func save_image(img: Image, filename: String):
	var path = "res://assets/Realistic/ui/textures/" + filename
	img.save_png(path)
	print("Generated: " + path)
