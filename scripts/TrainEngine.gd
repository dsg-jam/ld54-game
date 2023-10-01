# Similar to TrainVehicle but it applies power to its front wheel
class_name TrainEngine extends TrainVehicle

signal train_info(info: Dictionary)
signal entered_station(station: TrainStation)

@export var max_force: float = 1000
@export var gravity: float = 9.8
@export var friction_coefficient: float = 0.1
@export var rolling_resistance_coefficient: float = 0.005
@export var air_resistance_coefficient: float = 0.10
@export var air_density: float = 1.0
@export var velocity_multiplier: float = 1.5
@export var brake_power: float = 12
@export var brake_application_speed: float = 5

const LOOK_AHEAD_TRACKS: int = 10

var _next_stop_distance: float = INF
var _breaking_distance: float = 0

var friction_force: float
var target_force_percent: float = 0
var applied_force: float = 0
var brake_force: float = 0
var velocity: float = 0

func _ready() -> void:
	super._ready()
	self._update_frictions()

# Update the friction forces that depend on mass when the towed mass changes
func change_towed_mass(mass_delta: float) -> void:
	super.change_towed_mass(mass_delta)
	self._update_frictions()

# Emit a signal to update the HUD
func _process(delta: float) -> void:
	super._process(delta)
	self._update_throttle(delta)
	self._update_brake(delta)
	self.train_info.emit({
		"throttle": target_force_percent,
		"force_applied": applied_force,
		"force_max": max_force,
		"brake": brake_force,
		"total_mass": total_mass,
		"velocity": velocity,
		"friction": friction_force,
		"drag": self._drag_force(),
	})

# Apply forces
func _physics_process(delta: float) -> void:
	self._find_distance_to_next_stop()
	self._update_auto_stop_break()
	
	self._updated_applied_force(delta)
	if self.velocity != 0 or self.applied_force != 0:
		self._move_with_friction(delta)

# Set the "throttle lever" position
func _update_throttle(delta: float) -> void:
	if Input.is_action_pressed("speed_up"):
		self.target_force_percent = min(self.target_force_percent + delta / 10, 1)
	elif Input.is_action_pressed("slow_down"):
		self.target_force_percent = max(self.target_force_percent - delta / 10, -1)
	elif Input.is_action_pressed("cut_throttle"):
		self.target_force_percent = 0

# Set the percent of the total force with which the brake is being applied
func _update_brake(delta: float) -> void:
	if Input.is_action_pressed("brake"):
		self.brake_force = clamp(self.brake_force + self.brake_application_speed * delta, 0, 1)
	elif self.brake_force > 0:
		self.brake_force = clamp(self.brake_force - self.brake_application_speed * delta, 0, 1)

# Move the front wheel by the applied force, minus friction forces
func _move_with_friction(delta: float) -> void:
	var resistance := self.friction_force + self._drag_force()
	if self.applied_force == 0 && abs(self.velocity) < resistance / self.total_mass * delta:
		self.velocity = 0
	else:
		if self.velocity > 0:
			self.velocity = self.velocity + ((self.applied_force - resistance) / self.total_mass * delta)
		elif self.velocity < 0:
			self.velocity = self.velocity + ((self.applied_force + resistance) / self.total_mass * delta)
		else:
			self.velocity = self.velocity + (self.applied_force / self.total_mass * delta)
	self._apply_brake(delta)
	self.front_wheel.move(self.velocity * self.velocity_multiplier * delta)

# Lerp the actual engine force from its current value to the throttle position
func _updated_applied_force(delta: float) -> void:
	self.applied_force = lerp(float(self.applied_force), float(self.max_force * self.target_force_percent), delta)
	if abs(self.applied_force) < 0.1: self.applied_force = 0

# Recalculate the velocity-independent friction forces for the current mass
func _update_frictions() -> void:
	self.friction_force = self.friction_coefficient * self.total_mass * self.gravity
	self.friction_force += self.rolling_resistance_coefficient * self.total_mass * self.gravity

# The air resistance force
func _drag_force() -> float:
	return (self.air_resistance_coefficient * self.air_density * (pow(self.velocity,2)/2))

# Reduce the velocity based on applied brake power
func _apply_brake(delta: float) -> void:
	if self.velocity == 0: return
	elif self.velocity > 0:
		self.velocity = max(self.velocity - self.brake_force * self.brake_power * delta, 0)
	elif self.velocity < 0:
		self.velocity = min(self.velocity + self.brake_force * self.brake_power * delta, 0)

func _update_auto_stop_break() -> void:
	if self._next_stop_distance <= self._breaking_distance:
		self.applied_force = 0
		self.target_force_percent = 0
		self.brake_force = 1.5

func _calc_breaking_distance() -> void:
	var time_to_stop = self.velocity / self.brake_power
	self._breaking_distance = time_to_stop * self.velocity / 2.0

func _get_track_entry_dir(track) -> Track.Directions:
	if self.front_wheel.direction == TrainWheel.Directions.TAILWARD and self.velocity >= 0:
		return Track.Directions.HEAD
	if track.is_in_group("track_switch"):
		return track.direction
	return Track.Directions.TAIL

func _get_initial_distance() -> float:
	if self.front_wheel.direction == TrainWheel.Directions.TAILWARD and self.velocity >= 0:
		return -(self.front_wheel.progress_ratio) * self.front_wheel.current_track_length
	return -(1.0-self.front_wheel.progress_ratio) * self.front_wheel.current_track_length

func _get_track_end_dir(from_dir: Track.Directions, track) -> Track.Directions:
	if track.is_in_group("track_switch"):
		var track_switch = track as TrackSwitch
		if from_dir == Track.Directions.HEAD:
			return track_switch.direction
	if from_dir == Track.Directions.HEAD:
		return Track.Directions.TAIL
	return Track.Directions.HEAD

func _get_track_length(from_dir: Track.Directions, track) -> float:
	if track.is_in_group("track_switch"):
		var track_switch = track as TrackSwitch
		if from_dir == Track.Directions.HEAD:
			if track.direction == Track.Directions.RIGHT:
				return track.right_track.curve.get_baked_length()
			return track.left_track.curve.get_baked_length()
		if from_dir == Track.Directions.RIGHT:
			return track.right_track.curve.get_baked_length()
		return track.left_track.curve.get_baked_length()
	return track.curve.get_baked_length()

func _is_stopping_track(distance: float, track) -> bool:
	if !track.is_in_group("train_station_track"):
		return false
	
	if self.velocity < 0:
		distance -= track.curve.get_baked_length()
	self._next_stop_distance = distance
	return true

func _find_distance_to_next_stop() -> void:
	var current_track = self.front_wheel.current_track
	if !current_track:
		return
	
	self._calc_breaking_distance()	
	
	if current_track.owner.is_in_group("track_switch"):
		current_track = current_track.owner
	
	var distance = self._get_initial_distance()
	var to_dir = Track.Directions.HEAD	
	var from_dir = self._get_track_entry_dir(current_track)
	
	for i in range(LOOK_AHEAD_TRACKS):
		to_dir = self._get_track_end_dir(from_dir, current_track)
		distance += self._get_track_length(from_dir, current_track)
		
		if self._is_stopping_track(distance, current_track):
			return
		
		from_dir = current_track.neighboring_tracks[to_dir][0]
		current_track = current_track.neighboring_tracks[to_dir][1]
	return

func _on_area_2d_area_entered(area: Area2D) -> void:
	if !area.is_in_group("train_station"): return
	self.entered_station.emit(area)
