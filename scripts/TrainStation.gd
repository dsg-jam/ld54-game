class_name TrainStation extends Node2D

signal timeout(station: TrainStation)

@export var warn_threshold: float = 10.0

@onready var _progress: TextureProgressBar = $TextureProgressBar
@onready var _timer: Timer = $Timer
@onready var _warn_indicator: Sprite2D = $Warn
@onready var _anim_player: AnimationPlayer = $AnimationPlayer

var available: bool

func _ready() -> void:
	self.reset()
	self._anim_player.play("blink")

func _process(_delta: float) -> void:
	if self._timer.is_stopped():
		return

	self._progress.value = 100 * self._timer.time_left / self._timer.wait_time
	self._warn_indicator.set_visible(self._timer.time_left < self.warn_threshold)

func start_timer(delay: float) -> void:
	assert(delay > 0)
	self.available = false
	self._progress.set_visible(true)
	self._timer.start(delay)

func reset() -> void:
	self._timer.stop()
	self._warn_indicator.set_visible(false)
	self._progress.set_visible(false)
	self.available = true

func _on_timer_timeout() -> void:
	self.timeout.emit(self)
