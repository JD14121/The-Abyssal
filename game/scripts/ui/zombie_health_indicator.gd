extends Node2D
## World-space health label and bar for the playable-demo Zombie.

const BAR_WIDTH := 42.0
const BAR_HEIGHT := 5.0

var _health_receiver: CreatureHealthComponent
var _last_health := -1.0


func _ready() -> void:
	_health_receiver = get_parent().get_node_or_null("CreatureHealthComponent") as CreatureHealthComponent
	if _health_receiver != null:
		_health_receiver.health_changed.connect(_on_health_changed)
	queue_redraw()


func _process(_delta: float) -> void:
	if _health_receiver == null or not is_instance_valid(_health_receiver):
		return
	var current_health := _health_receiver.get_current_health()
	if not is_equal_approx(current_health, _last_health):
		_last_health = current_health
		queue_redraw()


func _draw() -> void:
	if _health_receiver == null:
		return
	var current_health := _health_receiver.get_current_health()
	var maximum_health := _health_receiver.get_max_health()
	if current_health < 0.0 or maximum_health <= 0.0:
		return
	var ratio := clampf(current_health / maximum_health, 0.0, 1.0)
	var bar_rect := Rect2(Vector2(-BAR_WIDTH * 0.5, 0.0), Vector2(BAR_WIDTH, BAR_HEIGHT))
	draw_string(ThemeDB.fallback_font, Vector2(-BAR_WIDTH * 0.5, -3.0), "%d / %d" % [roundi(current_health), roundi(maximum_health)],
		HORIZONTAL_ALIGNMENT_LEFT, BAR_WIDTH, 9, Color("fff4dc"))
	draw_rect(bar_rect, Color("221f1b"))
	var health_color := Color("75cf7c") if ratio > 0.5 else Color("e2bd58") if ratio > 0.25 else Color("e36b56")
	draw_rect(Rect2(bar_rect.position, Vector2(BAR_WIDTH * ratio, BAR_HEIGHT)), health_color)
	draw_rect(bar_rect, Color("fff4dc"), false, 1.0)


func _on_health_changed(_current_health: float, _maximum_health: float, _damage: float) -> void:
	queue_redraw()
