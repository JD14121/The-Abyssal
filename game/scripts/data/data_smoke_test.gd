extends Node
## Temporary project entry point for data verification, without gameplay or UI.


func _ready() -> void:
	if not DataRegistry.is_loaded():
		push_error("[DataSmokeTest] DataRegistry failed to load; stopping startup.")
		get_tree().quit(1)
		return
	print("[DataSmokeTest] Startup validation passed.")
