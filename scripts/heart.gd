extends Area2D
# heart.gd — Tim hồi máu rơi từ enemy, nhặt để hồi 1 HP

var fall_speed: float = 65.0
var _collected: bool  = false

@onready var sprite: ColorRect = $Sprite
@onready var label:  Label     = $Label

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(9.0).timeout.connect(_expire)

func _physics_process(delta: float) -> void:
	position.y += fall_speed * delta
	# Nhấp nháy nhẹ
	var t := Time.get_ticks_msec() * 0.004
	if is_instance_valid(sprite):
		sprite.color = Color(1.0, 0.2 + sin(t) * 0.15, 0.3 + sin(t) * 0.1)
	var vp := get_viewport_rect().size
	if position.y > vp.y + 40.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	if body.is_in_group("player"):
		_collected = true
		body.heal(1)
		queue_free()

func _expire() -> void:
	if not _collected:
		queue_free()
