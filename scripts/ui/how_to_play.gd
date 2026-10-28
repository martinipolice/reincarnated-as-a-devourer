class_name HowToPlay
## The controls card and a short guide to a journey, shown in the pause menu
## and from the title screen.

## [what, how]; "{action}" becomes the current device's controls.
const CONTROLS := [
	["Move", "{move}"],
	["Attack", "Automatic"],
	["Devour (hold on an essence)", "{devour}"],
	["Drink the Goddess's Tears", "{flask}"],
	["Pause, build, settings", "{pause}"],
	["Pick a level-up", "{pick}"],
	["Navigate menus", "{menus}"],
]

const GUIDE := [
	"Survive 20 days, one minute each. On Day 20 the Demon King comes for you.",
	"Collect the green gems to level up, then choose a new weapon or upgrade. You can carry four weapons at a time.",
	"Elites drop a glowing essence. Hold {devour} on it to Devour: a lasting power, at the cost of some max HP.",
	"Golden arrows at the screen's edge point to chests; colored ones to essences.",
	"Your style rank (D to SSS) climbs as you kill and drops two ranks when you're hit. Higher ranks pay more gold and XP.",
	"From Day 5, elites can carry a trait: Swift, Armored, Splitting or Vampiric. They pay double gold.",
	"The goddess finds you on Days 5, 10, 15 and 19. She refills your Tears, gives a free blessing, and sells training for gold. The journey saves there.",
	"At her shrine you may seal one covenant: a curse until the next shrine, for a reward.",
	"You live only once. If you fall, she can pull you back for gold, and the price doubles each time. Keep some gold in reserve.",
	"Goddess Light and Aegis evolve with a passive at Lv 3 (Vigor and Guard); the other weapons with Devoured essences.",
	"Each Devour offers two mutations: the essence's classic boost, or another with its own cost. Both count toward evolutions.",
	"Every Devour feeds your Hunger (Sated, Hungry, Ravenous, Insatiable): more damage, but Devours heal less, elites come more often and the goddess gives less.",
	"At a level-up you can Reroll, Banish a card for the journey, or Skip it for gold. The goddess sells more rerolls and banishes.",
	"At Lv 3 each weapon offers two branches. Take one, and it grows to Lv 5.",
	"Hold 2 or more of each of two certain essences and they resonate: a lasting bonus. The Codex lists the pairs you've found.",
	"From Day 2, landmarks appear (follow their arrows): a cursed altar tests you for a reward, a bloody well trades HP for gold, a cage frees a strong elite, a grave leaves a gift.",
	"On Days 10 and 15 a mini-boss stalks the ruins. Fell it for gold, a golden chest and an essence.",
	"Going further unlocks new starting weapons, chosen when you begin a journey.",
]


static func build() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.add_child(heading("Controls"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	for row: Array in CONTROLS:
		var action := Label.new()
		action.text = row[0]
		grid.add_child(action)
		var keys := Label.new()
		var how := Game.prompts(row[1])
		keys.text = how.left(1).to_upper() + how.substr(1)  # a table cell, not a sentence
		keys.add_theme_color_override("font_color", UITheme.GOLD)
		grid.add_child(keys)
	column.add_child(grid)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	column.add_child(gap)
	column.add_child(heading("Your Journey"))
	for line: String in GUIDE:
		var label := Label.new()
		label.text = "·  " + Game.prompts(line)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(560, 0)
		column.add_child(label)
	return column


static func heading(text: String) -> Label:
	var label := UITheme.title_label(text, 36, UITheme.GOLD)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return label
