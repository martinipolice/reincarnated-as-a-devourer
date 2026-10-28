class_name Hunger
## The price of Devouring. Every essence taken feeds the Hunger; its tier
## rises at 4, 8 and 12 Devours. Each tier makes you stronger, but every
## Devour heals less, elites come for you more often, and the goddess's
## gifts weaken. Player.hunger_tier() reads it from the Devour count.

const NAMES := ["Sated", "Hungry", "Ravenous", "Insatiable"]
const COLORS := [Color(0.7, 0.85, 0.7), Color(0.95, 0.8, 0.45), Color(1.0, 0.5, 0.3), Color(0.9, 0.2, 0.25)]
## Devours needed for each tier.
const AT := [0, 4, 8, 12]
## Per tier: damage bonus, share of the normal Devour heal, elite interval
## multiplier, blessings the goddess offers, share of her Tears' heal.
const MIGHT := [0.0, 0.05, 0.1, 0.18]
const HEAL := [1.0, 0.7, 0.45, 0.2]
const ELITES := [1.0, 0.9, 0.8, 0.65]
const BLESSINGS := [3, 3, 2, 2]
const TEARS := [1.0, 1.0, 0.85, 0.7]
const WARNINGS := [
	"",
	"Your Devours heal less; elites come more often.",
	"Your Devours heal little; the goddess offers less.",
	"Your Devours barely heal; elites hunt you; her Tears weaken.",
]


static func tier(devours: int) -> int:
	var found := 0
	for i in AT.size():
		if devours >= AT[i]:
			found = i
	return found
