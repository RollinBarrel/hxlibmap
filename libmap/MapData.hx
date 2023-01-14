package libmap;

typedef TextureData = {
    var name:String;
    var width:Int;
    var height:Int;
}

typedef WorldspawnLayer = {
    var textureIdx:Int;
    var buildVisuals:Bool;
}

class MapData {
    public var entities:Array<Entity> = [];
    public var entitiesGeo:Array<EntityGeometry> = [];

    public var textures:Array<TextureData> = [];

    public var worldspawnLayers:Array<WorldspawnLayer> = [];
    public inline function registerWorldspawnLayer(name:String, buildVisuals:Bool) {
        worldspawnLayers.push({
            textureIdx: findTexture(name),
            buildVisuals: buildVisuals
        });
    }
    public function findWorldspawnLayer(textureIdx:Int) {
        for (i in 0...worldspawnLayers.length) {
            if (worldspawnLayers[i].textureIdx == textureIdx)
                return i;
        }

        return -1;
    }

    public function setTextureSize(name:String, width:Int, height:Int) {
        for (t in textures) {
            if (t.name == name) {
                t.width = width;
                t.height = height;
                return;
            }
        }
    }

    public function setSpawnTypeByClassname(key:String, spawnType:Entity.SpawnType) {
        for (e in entities) {
            if (e.properties.exists("classname")) {
                e.spawnType = spawnType;
            }
        }
    }

    public function registerTexture(name:String) {
        for (i in 0...textures.length) {
            if (textures[i].name == name)
                return i;
        }

        var tex = {
            name: name,
            width: 0,
            height: 0
        };
        return textures.push(tex) - 1;
    }
    public function findTexture(textureName:String) {
        for (i in 0...textures.length) {
            if (textures[i].name == textureName)
                return i;
        }

        return -1;
    }

    public function new() {}
}