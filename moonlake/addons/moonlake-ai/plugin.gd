@tool
extends EditorPlugin
var dock

func _enable_plugin() -> void:
	pass


func _disable_plugin() -> void:
	pass


func _enter_tree() -> void:
	dock = preload("res://addons/moonlake-ai/asset-dock.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
	print("Dock added to editor")


func _exit_tree() -> void:
	remove_control_from_docks(dock)
	dock.free()
	pass
