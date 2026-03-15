@tool
class_name StaggeredGridContainer
extends Container

@export var columns: int = 6:
	set(value):
		columns = maxi(1, value)
		queue_sort()

@export var h_separation: float = 0.0:
	set(value):
		h_separation = value
		queue_sort()

@export var v_separation: float = -12.86:
	set(value):
		v_separation = value
		queue_sort()

func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_sort_staggered_children()
	elif what == NOTIFICATION_THEME_CHANGED:
		queue_sort()

func _sort_staggered_children() -> void:
	var valid_children = []
	for child in get_children():
		if child is Control and child.visible:
			valid_children.append(child)
			
	if valid_children.is_empty():
		return
		
	# Find max slot size from first child (assuming uniform sizes)
	var first_child = valid_children[0]
	var cell_size = first_child.get_combined_minimum_size()
	
	# If children are using fixed size without min_size, fallback to size
	if cell_size.x == 0:
		cell_size = first_child.size
	
	# --- Added Auto-Centering Logic ---
	var total_grid_width = columns * cell_size.x + (columns - 1) * h_separation
	var total_grid_height = _get_minimum_size().y
	
	var container_width = size.x
	var container_height = size.y
	
	var offset_x = maxf(0.0, (container_width - total_grid_width) / 2.0)
	var offset_y = maxf(0.0, (container_height - total_grid_height) / 2.0)
	# ----------------------------------
	
	var row = 0
	var col = 0
	
	# Calculate total rows to enable bottom-to-top filling
	var total_items = valid_children.size()
	var items_per_pair = columns + (columns - 1)
	var full_pairs = int(floor(float(total_items) / float(items_per_pair)))
	var remaining_items = total_items % items_per_pair
	
	var total_num_rows = full_pairs * 2
	if remaining_items > 0:
		total_num_rows += 1
		if remaining_items > columns:
			total_num_rows += 1
			
	if total_num_rows == 0:
		total_num_rows = 1
	
	for child in valid_children:
		var stagger_offset = 0.0
		# Odd rows are staggered (offset by half a cell width)
		if row % 2 != 0:
			stagger_offset = (cell_size.x + h_separation) / 2.0
		
		# Invert row for bottom-to-top layout
		var inverted_row = (total_num_rows - 1) - row
		
		# Apply centering offsets to final position
		var child_x = offset_x + stagger_offset + col * (cell_size.x + h_separation)
		var child_y = offset_y + inverted_row * (cell_size.y + v_separation)
		
		# Pixel-snap the final slot rect so exported/mobile builds don't rasterize
		# the gachaball shell on fractional coordinates. The battle inventory does
		# not use this container path, so snapping here restores parity.
		child_x = roundf(child_x)
		child_y = roundf(child_y)
		
		# Set child rect
		fit_child_in_rect(child, Rect2(child_x, child_y, cell_size.x, cell_size.y))
		
		# Wrap to next row
		col += 1
		
		# Odd rows have 1 less column to fit perfectly without horizontal scrolling
		var max_cols_in_row = columns if (row % 2 == 0) else (columns - 1)
		
		if col >= max_cols_in_row:
			col = 0
			row += 1

func _get_minimum_size() -> Vector2:
	var valid_children = []
	for child in get_children():
		if child is Control and child.visible:
			valid_children.append(child)
			
	if valid_children.is_empty():
		return Vector2.ZERO
		
	var first_child = valid_children[0]
	var cell_size = first_child.get_combined_minimum_size()
	if cell_size.x == 0:
		cell_size = first_child.size
	
	var total_items = valid_children.size()
	if total_items == 0:
		return Vector2.ZERO
		
	# Calculate rows more accurately based on alternating column counts
	var items_per_pair = columns + (columns - 1)
	var full_pairs = int(floor(float(total_items) / float(items_per_pair)))
	var remaining_items = total_items % items_per_pair
	
	var rows = full_pairs * 2
	if remaining_items > 0:
		rows += 1
		if remaining_items > columns:
			rows += 1
	
	var min_w = columns * cell_size.x + (columns - 1) * h_separation
	
	var min_h = rows * cell_size.y + (rows - 1) * v_separation
	
	return Vector2(min_w, min_h)
