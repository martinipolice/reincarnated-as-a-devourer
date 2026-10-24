class_name HowToPlay
## The controls card and a short guide to a journey, shown in the pause menu
## and from the title screen.

const CONTROLS := [
	["Move", "WASD / arrow keys"],
	["Attack", "Automatic"],
	["Devour (hold on an essence)", "E / Space"],
	["Drink the Goddess's Tears", "Q"],
	["Pause, build, settings", "Esc / P"],
	["Pick a level-up", "Click, 1-3, or arrows + Enter"],
	["Navigate menus", "Arrows / Tab + Enter, Esc to go back"],
]

const GUIDE := [
	"Survive 20 days, one minute each. On Day 20 the Demon King comes for you.",
	"Collect the green gems to level up, then choose a new weapon or upgrade. You can carry four weapons at a time.",
	"Elites drop a glowing essence. Hold E on it to Devour: a lasting power, at the cost of some max HP.",
	"Golden arrows at the screen's edge point to chests; colored ones to essences.",
	"Your style rank (D to SSS) climbs as you kill and drops two ranks when you're hit. Higher ranks pay more gold and XP.",
	"From Day 3, elites can carry a trait: Swift, Armored, Splitting or Vampiric. They pay double gold.",
	"The goddess finds you on Days 5, 10, 15 and 19. She refills your Tears, gives a free blessing, and sells training for gold. The journey saves there.",
	"At her shrine you may seal one covenant: a curse until the next shrine, for a reward.",
	"You live only once. If you fall, she can pull you back for gold, and the price doubles each time. Keep some gold in reserve.",
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
		keys.text = row[1]
		keys.add_theme_color_override("font_color", UITheme.GOLD)
		grid.add_child(keys)
	column.add_child(grid)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	column.add_child(gap)
	column.add_child(heading("Your Journey"))
	for line: String in GUIDE:
		var label := Label.new()
		label.text = "·  " + line
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(560, 0)
		column.add_child(label)
	return column


static func heading(text: String) -> Label:
	var label := UITheme.title_label(text, 36, UITheme.GOLD)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return label
