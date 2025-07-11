extends Control

var main_menu = preload('res://scenes/menus/menu_title.tscn')
var game_over = preload('res://scenes/menus/game_over.tscn')
var you_win = preload('res://scenes/menus/win_screen.tscn')
var level_1 = preload('res://scenes/levels/level_1.tscn')

#func _ready():
	#print("LevelManager.gd active on node:", name, " path:", get_path())

func change_to_main_menu():
	get_tree().change_scene_to_packed(main_menu)

func change_to_game_over():
	get_tree().change_scene_to_packed(game_over)

func change_to_you_win():
	get_tree().change_scene_to_packed(you_win)

func change_to_level_1():
	get_tree().change_scene_to_packed(level_1)
