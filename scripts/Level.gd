extends Control

@export var next_level: PackedScene
@export var main_menu: PackedScene

@onready var _time_display: Label = $Control/Time
@onready var _objective_container: Container = $Control/VBoxContainer
@onready var _game_over_overlay: Control = $Overlay/GameOver
@onready var _level_complete_overlay: Control = $Overlay/LevelComplete
@onready var _game_complete_overlay: Control = $Overlay/GameComplete

var _start_time_ms: int
var _routes: Array[TrainRoute]
var _route_labels: Array[Label]
var _objective_counters: Array[int]

func _ready() -> void:
	self._start_time_ms = Time.get_ticks_msec()
	self._game_over_overlay.set_visible(false)
	self._level_complete_overlay.set_visible(false)
	self._game_complete_overlay.set_visible(false)
	
	var tree := self.get_tree()
	self._routes.assign(tree.get_nodes_in_group("train_route"))
	
	var route_idx := 0
	for route in self._routes:
		route.train_stopped.connect(self._on_train_stopped.bind(route_idx))
		route.train_game_over.connect(self._on_train_game_over.bind(route_idx))

		var label := Label.new()
		self._objective_container.add_child(label)
		self._route_labels.push_back(label)
		self._objective_counters.push_back(0)
		self._update_objective(route_idx)

		route_idx += 1

func _process(_delta: float) -> void:
	var offset_ms := Time.get_ticks_msec() - self._start_time_ms
	var secs := int(offset_ms / 1000.0) % 60
	var minutes = int(offset_ms / 60_000.0)
	self._time_display.text = "%d:%02d" % [minutes, secs]

func _on_train_game_over(_train: TrainEngine, _route_idx: int) -> void:
	self._game_over_overlay.set_visible(true)

func _on_train_stopped(_train: TrainEngine, route_idx: int) -> void:
	self._objective_counters[route_idx] += 1
	self._update_objective(route_idx)
	self._check_win_condition()

func _update_objective(route_idx: int) -> void:
	var route := self._routes[route_idx]
	var label := self._route_labels[route_idx]
	var counter := self._objective_counters[route_idx]
	label.text = "%s: %d/%d" % [route.route_name, counter, route.route_objective]

func _check_win_condition() -> void:
	for route_idx in len(self._routes):
		var route := self._routes[route_idx]
		var counter := self._objective_counters[route_idx]
		if counter < route.route_objective:
			return
	if self.next_level:
		self._level_complete_overlay.set_visible(true)
	else:
		self._game_complete_overlay.set_visible(true)

func _on_restart_button_pressed() -> void:
	self.get_tree().reload_current_scene()

func _on_next_button_pressed() -> void:
	self.get_tree().change_scene_to_packed(self.next_level)

func _on_main_menu_button_pressed() -> void:
	self.get_tree().change_scene_to_packed(self.main_menu)
