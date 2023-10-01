@tool
# A node that allows switching between two tracks
#
# Vehicles that enter at the head will be placed on the active track
class_name TrackSwitch extends Node2D

signal wheel_at_head(wheel: TrainWheel, extra: float, is_forward: bool)
signal wheel_at_left(wheel: TrainWheel, extra: float, is_forward: bool)
signal wheel_at_right(wheel: TrainWheel, extra: float, is_forward: bool)
signal switch_direction_toggled()

var neighboring_tracks: Dictionary

@export var direction := Track.Directions.RIGHT
@onready var left_track: Track = $LeftTrack
@onready var right_track: Track = $RightTrack
@onready var checkbutton: Button = $Button

func _ready() -> void:
	self._update_checkbutton()
	self._update_sprites()
	self.checkbutton.focus_mode = Control.FOCUS_NONE

# Change the direction of the switch
func switch() -> void:
	if self._has_wheels_on():
		self._update_checkbutton()
		return
	self.direction = Track.Directions.LEFT if direction == Track.Directions.RIGHT else Track.Directions.RIGHT
	self._update_sprites()
	self._update_checkbutton()
	self.switch_direction_toggled.emit()

func _update_checkbutton() -> void:
	self.checkbutton.button_pressed = direction == Track.Directions.RIGHT

# Connect the "from_side" of this track to the "to_side" of the other track
#
# This links both tracks to each other, so only call it once per connection
func link_track(other_track, from_side: Track.Directions, to_side: Track.Directions) -> void:
	self.neighboring_tracks[from_side] = [to_side, other_track]
	other_track.neighboring_tracks[to_side] = [from_side, self]
	self.wheel_at_signal(from_side).connect(other_track.enter_from_callable(to_side))
	other_track.wheel_at_signal(to_side).connect(self.enter_from_callable(from_side))

func wheel_at_signal(dir: Track.Directions) -> Signal:
	match dir:
		Track.Directions.HEAD:
			return self.wheel_at_head
		Track.Directions.LEFT:
			return self.wheel_at_left
		Track.Directions.RIGHT:
			return self.wheel_at_right
		_:
			push_error("invalid direction for track switch wheel")
			return Signal()

func enter_from_callable(dir: Track.Directions) -> Callable:
	match dir:
		Track.Directions.HEAD:
			return self.enter_from_head
		Track.Directions.LEFT:
			return self.enter_from_left
		Track.Directions.RIGHT:
			return self.enter_from_right
		_:
			push_error("invalid direction for track switch enter")
			return Callable()

# Wheel entering from the head
#
# Place it on the track direction that the switch is set to use
func enter_from_head(wheel: TrainWheel, extra: float, is_forward: bool) -> void:
	if self.direction == Track.Directions.LEFT:
		self.left_track.enter_from_head(wheel, extra, is_forward)
	else:
		self.right_track.enter_from_head(wheel, extra, is_forward)

# Wheel entering at the left tail
func enter_from_left(wheel: TrainWheel, extra: float, is_forward: bool) -> void:
	self.left_track.enter_from_tail(wheel, extra, is_forward)

# Wheel entering at the right tail
func enter_from_right(wheel: TrainWheel, extra: float, is_forward: bool) -> void:
	self.right_track.enter_from_tail(wheel, extra, is_forward)

# Check if the switch currently has wheels on it
func _has_wheels_on() -> bool:
	for child in self.right_track.get_children():
		if child.is_in_group("train_wheels"): return true
	for child in self.left_track.get_children():
		if child.is_in_group("train_wheels"): return true
	return false

# Update z-index and sprite visibility for current direction
func _update_sprites() -> void:
	self.left_track.get_node("Pointer").hide()
	self.right_track.get_node("Pointer").hide()
	self.left_track.z_index = 0
	self.right_track.z_index = 0
	
	if self.direction == Track.Directions.RIGHT:
		self.right_track.get_node("Pointer").show()
		self.right_track.z_index = 1
	else:
		self.left_track.get_node("Pointer").show()
		self.left_track.z_index = 1

func _on_Button_pressed() -> void:
	self.switch()

func _on_RightTrack_wheel_at_tail(wheel: TrainWheel, extra: float, is_forward: bool) -> void:
	self.wheel_at_right.emit(wheel, extra, is_forward)

func _on_LeftTrack_wheel_at_tail(wheel: TrainWheel, extra: float, is_forward: bool) -> void:
	self.wheel_at_left.emit(wheel, extra, is_forward)

func _on_RightTrack_wheel_at_head(wheel: TrainWheel, extra: float, is_forward: bool) -> void:
	self.wheel_at_head.emit(wheel, extra, is_forward)

func _on_LeftTrack_wheel_at_head(wheel: TrainWheel, extra: float, is_forward: bool) -> void:
	self.wheel_at_head.emit(wheel, extra, is_forward)
