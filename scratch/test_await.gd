extends SceneTree

func _init():
	print("Start")
	await my_void_coroutine()
	print("End")
	quit()

func my_void_coroutine() -> void:
	print("Coroutine start")
	await create_timer(1.0).timeout
	print("Coroutine end")
