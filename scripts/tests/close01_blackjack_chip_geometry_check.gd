extends SceneTree
const Game=preload("res://scripts/games/blackjack.gd")
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label)
func _init():
 var game=Game.new()
 for center in [Vector2(40,438),Vector2(128.5,215.25)]:
  for radius in [9.0,11.0,16.5]:
   var points:PackedVector2Array=game._cached_chip_rim_geometry(center,radius)
   check(points.size()==24,"Exactly twelve independent rim segments")
   for index in range(12):
    var angle=(float(index)/12.0)*PI*2.0
    var direction=Vector2(cos(angle),sin(angle))
    check(points[index*2]==center+direction*radius*0.70,"Original inner endpoint is exact")
    check(points[index*2+1]==center+direction*radius*0.98,"Original outer endpoint is exact")
   var cached:PackedVector2Array=game._cached_chip_rim_geometry(center,radius)
   check(cached==points,"Cache preserves every endpoint")
 for index in range(160):game._cached_chip_rim_geometry(Vector2(index,0),9)
 check(game.chip_rim_geometry_cache.size()==128,"Moving chips cannot grow the cache beyond128 geometries")
 print("CLOSE01_CHIP_GEOMETRY "+JSON.stringify({"checks":checks,"failures":failures}))
 quit(0 if failures.is_empty() else 1)
