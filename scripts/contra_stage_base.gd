extends RefCounted
class_name ContraStageBase

var main: Node2D

func _init(_main: Node2D):
	main = _main

func setup():
	pass

# Helper proxy methods to reach contra_main functions easily
func _get_world(): return main._world
func _get_camera(): return main.camera
func _get_parallax(): return main._parallax_bg
func _get_ground_y(x: float) -> float: return main._get_ground_y(x)
func _spawn_enemy(x, y, is_off = false): main._spawn_enemy(x, y, is_off)
func _spawn_heavy_enemy(x, y, type: String, is_ally: bool = false, can_shoot: bool = true): main._spawn_heavy_enemy(x, y, type, is_ally, can_shoot)
func _spawn_turret(x, y): main._spawn_turret(x, y)
func _add_bg_soldier(x, y, is_tun = false): main._add_individual_background_soldier(x, y, is_tun)
