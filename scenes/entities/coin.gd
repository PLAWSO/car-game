extends Area3D

const ROT_SPEED = 1 # number of degrees the coin rotates every frame

@export var hud : CanvasLayer

func _process(_delta: float) -> void:
	rotate_y(deg_to_rad(ROT_SPEED))

func _on_body_entered(_body: Node3D) -> void:
	Global.coins += 1
	SoundManager.play_coin_sound()
	hud.get_node("CoinsLabel").text = str(Global.coins)
	if Global.coins >= Global.NUM_COINS_TO_WIN:
		LevelManager.change_to_you_win()
	set_collision_layer_value(3, false)
	set_collision_mask_value(1, false)
	$AnimationPlayer.play("bounce")

func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	queue_free()
