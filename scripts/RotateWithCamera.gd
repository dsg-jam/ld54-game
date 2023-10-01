extends Node2D

func _process(_delta: float) -> void:
	var camera := self.get_viewport().get_camera_2d()
	if camera:
		self.global_rotation = camera.global_rotation
	else:
		self.global_rotation = 0;
