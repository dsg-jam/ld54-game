# Sits on top of two TrainWheels to move along a Track
class_name TrainVehicle extends Node2D

signal towed_mass_changed(mass_delta: float)

@export var wheel_distance: float = 58
@export var follow_distance: float = 26
@export var mass: float = 10

var towed_mass: float = 0
var total_mass: float = mass

@onready var front_wheel: TrainWheel = $RailFollower
@onready var back_wheel: TrainWheel = $RailFollower2
@onready var body: Node2D = $Body

func _ready() -> void:
	self.front_wheel.moved.connect(self.back_wheel.move_as_follower)

func _process(_delta: float) -> void:
	self.global_position = lerp(self.global_position, self.front_wheel.global_position, 0.8)
	self.body.look_at(self.back_wheel.global_position)

# Place this vehicle (and all of its wheels) on the track
func add_to_track(track: Path2D, offset: float = 1) -> void:
	self.front_wheel.set_track(track)
	self.front_wheel.progress = offset
	self.back_wheel.follow(self.front_wheel, self.wheel_distance)
	self.global_position = self.front_wheel.global_position

# Link another TrainVehicle to follow this one
func set_follower_car(car: TrainVehicle) -> void:
	car.front_wheel.collision_area.monitoring = false
	self.back_wheel.collision_area.monitoring = false
	car.add_to_track(self.back_wheel.current_track)
	car.front_wheel.follow(self.back_wheel, self.follow_distance)
	car.back_wheel.follow(car.front_wheel, car.wheel_distance)
	self.back_wheel.moved.connect(car.front_wheel.move_as_follower)
	car.towed_mass_changed.connect(self.change_towed_mass)
	self.change_towed_mass(car.total_mass)

# Disconnect this car's signals from its followers
func remove_follower_car(car: TrainVehicle) -> void:
	self.back_wheel.moved.disconnect(car.front_wheel.move_as_follower)
	car.towed_mass_changed.disconnect(self.change_towed_mass)
	self.change_towed_mass(-car.total_mass)

# Share the knowledge of the new total mass
func change_towed_mass(mass_delta: float) -> void:
	self.towed_mass += mass_delta
	self.total_mass = mass + towed_mass
	self.towed_mass_changed.emit(mass_delta)

func _on_RailFollower_track_changed() -> void:
	self.add_to_track(self.front_wheel.get_parent(), self.front_wheel.offset)
