extends SceneTree

func _init():
	_check_image("res://assets/ui/textures/token_100yen.png")
	_check_image("res://assets/ui/textures/gachaball.png")
	quit()

func _check_image(path: String):
	print("\n--- Image: ", path, " ---")
	var img = Image.new()
	var err = img.load(path)
	if err != OK:
		print("Failed to load: ", err)
		return
	var w = img.get_width()
	var h = img.get_height()
	var bright_colors = {}
	for y in range(h):
		for x in range(w):
			var c = img.get_pixel(x, y)
			if c.a > 0.1 and c.r > 0.8: # Only bright things
				var hex = c.to_html(false)
				if not bright_colors.has(hex):
					bright_colors[hex] = c
	
	print("Bright colors found:")
	for hex in bright_colors:
		var c = bright_colors[hex]
		var dist = abs(c.r - 1.0) + abs(c.g - 0.945098) + abs(c.b - 0.909804)
		print("- #", hex, " (Dist to target: ", dist, ") -> ", c)

