package libmap;

enum abstract SpawnType(Int) from Int to Int {
    var WORLDSPAWN = 0;
    var MERGE_WORLDSPAWN = 1;
    var ENTITY = 2;
    var GROUP = 3;
}

class Entity {
    public var properties:Map<String, String> = [];
    public var brushes:Array<Brush> = [];
    public var center = hxmath.math.Vector3.zero;
    public var spawnType:SpawnType = WORLDSPAWN;

    public function new() {}
}