extends "res://tests/test_case.gd"

const REWARD_SCENE := preload(
	"res://scenes/components/engraving_reward_panel.tscn"
)


func run() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var panel: EngravingRewardPanel = REWARD_SCENE.instantiate()
	tree.root.add_child(panel)
	var card_catalog := CardCatalog.new()
	var engraving_catalog := EngravingCatalog.new()
	var profiles: Array[DieState] = []
	for index in range(6):
		profiles.append(DieState.new(StringName("d%d" % (index + 1)), index + 1))
	panel.bind_reward(
		[&"engraving_echo", &"engraving_anchor"],
		profiles,
		engraving_catalog,
		[&"shop_long_push"],
		card_catalog.starter_ids(),
		card_catalog
	)
	assert_true(
		"六颗实体骰子的编号" in panel.get_node("%DieHelpLabel").text,
		"reward UI should explain that D1-D6 are die identities, not face values"
	)
	assert_true(
		"触发面" in panel.get_node("%FaceHelpLabel").text
		and "掷出" in panel.get_node("%FaceHelpLabel").text,
		"reward UI should explain when an engraved face activates and what follows"
	)
	for child in panel.get_node("%RewardDeckGrid").get_children():
		assert_true(
			child is ShopCardToken,
			"replacement choices should render reusable visual card tokens"
		)
		if child is ShopCardToken:
			assert_true(
				child.text.is_empty()
				and child.get_node("CardFaceContent").is_complete_card_face(),
				"replacement choices should show their SVG card faces instead of name-only buttons"
			)
	for child in panel.get_node("%OfferRow").get_children():
		assert_true(
			child is EngravingOptionToken
			and child.text.is_empty()
			and child.get_node("%EngravingIcon").texture != null,
			"engraving choices should use SVG glyph cards instead of rule-text buttons"
		)
	for child in panel.get_node("%FaceGrid").get_children():
		assert_true(
			child is Button and child.text.is_empty() and child.icon != null,
			"engraved-face choices should use die-face SVG icons"
		)
	panel.free()
