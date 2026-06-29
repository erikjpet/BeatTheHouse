class_name ArtContracts
extends RefCounted

# Canonical low-resolution art boards used by procedural layout and canvas
# presentation. Keep these centralized so room and game modules do not invent
# competing surface dimensions.

const ENVIRONMENT_BOARD_SIZE := Vector2i(900, 430)
const GAME_BOARD_SIZE := Vector2i(900, 430)
const ICON_SIZE := Vector2i(32, 32)
