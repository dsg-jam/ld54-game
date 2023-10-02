extends CenterContainer

@export var start_level: PackedScene

func _on_start_button_pressed() -> void:
	self.get_tree().change_scene_to_packed(self.start_level)
