extends Node
## 全局单例（Autoload: Game）。保存当前玩家/关卡引用，以及瞄准冻结状态。

## 物理层（与 项目设置 > 层名称 一致）
const LAYER_WORLD := 1      # 第1层 world：TileMap 墙体
const LAYER_PLAYER := 2     # 第2层 player
const LAYER_ENEMY := 4      # 第3层 enemy：守卫（Area2D）
const LAYER_TRIGGER := 8    # 第4层 trigger：拾取物、出口

const TILE := 8.0           # 图格像素尺寸

var player: Player
var level: Level
## 瞄准冻结期间为 true。守卫、回旋镖等在冻结时暂停逻辑。
var frozen := false
