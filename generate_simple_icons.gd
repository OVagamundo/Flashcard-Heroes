@tool
extends SceneTree

# One flat color per icon, as requested.
const C_HEART = Color("e53935") # Red
const C_FIST = Color("212121") # Black/Dark Grey
const C_FLAME = Color("ff5722") # Orange/Red

func _init():
	print("Generating 1-bit Flat Color Icons (64x64)...")
	
	# Defined as 16x16 bitmaps to be scaled by 4
	var heart_map = [
		"................",
		"................",
		"..XXX.....XXX...",
		".XXXXX...XXXXX..",
		"XXXXXXX.XXXXXXX.",
		"XXXXXXXXXXXXXXX.",
		"XXXXXXXXXXXXXXX.",
		"XXXXXXXXXXXXXXX.",
		".XXXXXXXXXXXXX..",
		"..XXXXXXXXXXX...",
		"...XXXXXXXXX....",
		"....XXXXXXX.....",
		".....XXXXX......",
		"......XXX.......",
		".......X........",
		"................",
	]
	
	# Side view fist / gauntlet
	var fist_map = [
		"................",
		"....XXXXXX......",
		"...XXXXXXXX.....",
		"..XXXXXXXXXX....",
		"..XXXXXXXXXX....",
		"..XXXXXXXXXX....",
		"..XXXXXXXXXX....",
		"..XXXXXXXXXXX...",
		"..XXXXXXXXXXX...",
		"...XXXXXXXXXX...",
		"....XXXXXXXX....",
		"....XXXXXXXX....",
		"....XXXXXXXX....",
		"....XXXXXXX.....",
		".....XXXXX......",
		"................"
	]
	
	# Simple flame
	var flame_map = [
		"................",
		".......X........",
		"......XXX.......",
		".....XXXXX......",
		"....XXXXXXX.....",
		"....XXXXXXX.....",
		"...XXXXXXXXX....",
		"..XXXXXXXXXXX...",
		"..XXXXXXXXXXX...",
		".XXXXXXXXXXXXX..",
		".XXXXXXXXXXXXX..",
		".XXXXXXXXXXXXX..",
		"..XXXXXXXXXXX...",
		"..XXXXXXXXXXX...",
		"...XXXXXXXXX....",
		"....XXXXXXX....."
	]

	generate_icon("icon_heart_pixel.png", heart_map, C_HEART)
	generate_icon("icon_fist_pixel.png", fist_map, C_FIST)
	generate_icon("icon_burn_pixel.png", flame_map, C_FLAME)
	
	print("Done.")
	quit()

func generate_icon(filename, bitmap, color):
	var w = 64
	var h = 64
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	
	# Map is 16x16. We scale by 4 to get 64x64.
	var scale = 4
	
	for y in range(16):
		var row = bitmap[y]
		for x in range(16):
			if row[x] == "X":
				# Fill the 4x4 block
				for dy in range(scale):
					for dx in range(scale):
						img.set_pixel(x * scale + dx, y * scale + dy, color)
						
	var path = "res://assets/Realistic/ui/textures/" + filename
	img.save_png(path)
	print("Saved: " + path)
