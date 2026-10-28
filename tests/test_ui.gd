extends "res://tests/test_case.gd"
## The menus: level-up cards, the shrine, results, the title screen, Codex.


func test_level_up_offers_and_picks() -> void:
	var main: Node = await start_run()
	var picked := []
	main.level_up.chosen.connect(func(upgrade: Resource) -> void: picked.append(upgrade))
	var offers: Array = main.player.available_upgrades(main.UPGRADE_POOL).slice(0, 3)
	main.level_up.open(offers, main.player)
	check(tree.paused, "pauses the run")
	check_eq(main.level_up.options.get_child_count(), 3, "three cards")
	main.level_up.pick(1)
	check_eq(picked, [offers[1]], "the second card")
	check(not tree.paused, "resumes")
	await end_run(main)


func test_card_colors_say_what_a_choice_is() -> void:
	var main: Node = await start_run()
	var player: Player = main.player
	var light := preload("res://data/weapons/goddess_light.tres")
	var guard := preload("res://data/items/wooden_guard.tres")
	check_eq(LevelUp.card_for(light, player).accent, UITheme.NEW_WEAPON, "new weapon")
	check_eq(LevelUp.card_for(guard, player).accent, UITheme.NEW_PASSIVE, "new passive")
	player.apply_upgrade(light)
	check_eq(LevelUp.card_for(light, player).accent, UITheme.UPGRADE, "a level")
	player.apply_upgrade(light)
	check_eq(LevelUp.card_for(light, player).accent, UITheme.FINAL, "last level before evolving")
	await end_run(main)


func test_shrine_needs_a_blessing_before_leaving() -> void:
	var main: Node = await start_run()
	var shrine = main.shrine
	shrine.open(5, main)
	await tree.process_frame
	check(shrine.visible, "opens")
	check_eq(shrine.blessing_choices().size(), 3, "three blessings")
	shrine.close()
	check(shrine.visible, "can't leave unblessed")
	shrine.blessing_choices()[0].emit_signal("pressed")
	check(shrine.blessed, "blessed")
	check(shrine.blessing_choices().is_empty(), "the others close")
	main.gold = 10000
	shrine.buy_training(shrine.TRAININGS[0])
	check_eq(int(main.training_ranks.get(shrine.TRAININGS[0].id, 0)), 1, "training bought")
	shrine.close()
	check(not shrine.visible, "leaves")
	check(Save.data.journey is Dictionary, "the journey is checkpointed")
	await end_run(main)


func test_results_screen_after_the_end() -> void:
	var main: Node = await start_run()
	Enemy.damage_log = {"Blade": 300.0, "Bomb": 100.0}
	main.awaiting_revive = true
	main.accept_fate()
	await tree.process_frame
	check(main.results.visible, "results shown")
	await end_run(main)


func test_title_screen_and_codex() -> void:
	Save.data.journey = {"day": 10, "level": 21}
	var title: Node = load("res://scenes/ui/title.tscn").instantiate()
	tree.root.add_child(title)
	await tree.process_frame
	title._show_menu(false)
	var items: Array = title._list.get_children().filter(func(n: Node) -> bool: return n is Button)
	var labels := items.map(func(b: Button) -> String: return b.text)
	check_eq(labels[0], "Continue", "a saved journey offers Continue first")
	check("Codex" in labels and "Credits" in labels, "Codex and Credits listed")
	title._codex.open()
	var progress: Array = title._codex._progress()
	check(progress[1] >= 30, "the Codex counts every entry")
	title._codex.close()
	title.queue_free()
	await tree.process_frame


func test_text_goes_through_translation() -> void:
	var spanish := Translation.new()
	spanish.locale = "es"
	spanish.add_message("Level %d", "Nivel %d")
	spanish.add_message("Settings", "Ajustes")
	TranslationServer.add_translation(spanish)
	var locale := TranslationServer.get_locale()
	TranslationServer.set_locale("es")
	var main: Node = await start_run()
	main.level_up.open(main.player.available_upgrades(main.UPGRADE_POOL).slice(0, 3), main.player)
	check_eq(main.level_up.title.text, "Nivel %d" % main.player.level, "formatted text is translated")
	main.level_up.pick(0)
	var item := UITheme.menu_item("Settings", func() -> void: pass)
	tree.root.add_child(item)
	await tree.process_frame
	check_eq(item.tr(item.text), "Ajustes", "plain labels translate by key")
	item.queue_free()
	TranslationServer.set_locale(locale)
	TranslationServer.remove_translation(spanish)
	await end_run(main)
