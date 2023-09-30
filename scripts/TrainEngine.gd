# Similar to TrainVehicle but it applies power to its front wheel
class_name TrainEngine extends TrainVehicle

signal train_info(info: Dictionary)

@export var max_force: float = 1000
@export var gravity: float = 9.8
@export var friction_coefficient: float = 0.1
@export var rolling_resistance_coefficient: float = 0.005
@export var air_resistance_coefficient: float = 0.10
@export var air_density: float = 1.0
@export var velocity_multiplier: float = 1.5
@export var brake_power: float = 12
@export var brake_application_speed: float = 5

var friction_force: float
var target_force_percent: float = 0
var applied_force: float = 0
var brake_force: float = 0
var velocity: float = 0

func _ready() -> void:
	self._update_frictions()

# Update the friction forces that depend on mass when the towed mass changes
func change_towed_mass(mass_delta: float) -> void:
	super.change_towed_mass(mass_delta)
	self._update_frictions()

# Emit a signal to update the HUD
func _process(delta: float) -> void:
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
	if self.applied_force == 0 && abs(self.velocity) < self.resistance / self.total_mass * self.delta:
		self.velocity = 0
	else:
		if self.velocity > 0:
			self.velocity = self.velocity + ((self.applied_force - self.resistance) / self.total_mass * self.delta)
		elif self.velocity < 0:
			self.velocity = self.velocity + ((self.applied_force + self.resistance) / self.total_mass * self.delta)
		else:
			self.velocity = self.velocity + (self.applied_force / self.total_mass * self.delta)
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
		self.velocity = max(self.velocity - self.brake_force * self.brake_power * self.delta, 0)
	elif self.velocity < 0:
		self.velocity = min(self.velocity + self.brake_force * self.brake_power * self.delta, 0)
