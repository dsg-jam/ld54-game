class_name TracksController extends Node2D

signal track_changed()

func _ready():
	for child in self.get_children():
		if child.is_in_group("track_switch"):
			child.switch_direction_toggled.connect(self._on_track_changed)
			child.left_track.signal_toggled.connect(self._on_track_changed)
			child.right_track.signal_toggled.connect(self._on_track_changed)
		else:
			child.signal_toggled.connect(self._on_track_changed)

func _on_track_changed():
	self.track_changed.emit()
