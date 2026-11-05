extends Control
## Additive-blend overlay for the board: bloom, tracers, explosions, wall-edge glow.

const View = preload("res://ui/board_view.gd")

var board = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat

func _draw() -> void:
	if board != null and board.game != null:
		View.draw_glow(board, self)
