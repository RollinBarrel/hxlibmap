package libmap;

import libmap.EntityGeometry.FaceVertex;

typedef Surface = {
    var vertices:Array<FaceVertex>;
    var indices:Array<Int>;
}

enum abstract SplitType(Int) from Int to Int {
    var NONE;
    var ENTITY;
    var BRUSH;
}

class SurfaceGatherer {
    var mapData:MapData;
    public var splitType = NONE;
    public var entityFilterIdx = -1;
    public var textureFilterIdx = -1;
    public var brushFilterTextureIdx = -1;
    public var faceFilterTextureIdx = -1;
    public var filterWorldspawnLayers = true;

    public var outSurfaces:Array<Surface>;

    public function new(mapData) {
        this.mapData = mapData;
    }

    public inline function setBrushFilterTexture(name:String) {
        brushFilterTextureIdx = mapData.findTexture(name);
    }
    public inline function setFaceFilterTexture(name:String) {
        faceFilterTextureIdx = mapData.findTexture(name);
    }
    public inline function setTextureFilter(name:String) {
        textureFilterIdx = mapData.findTexture(name);
    }
    public function run() {
        resetState();

        var indexOffset = 0;
        var surfInst:Surface = null;
        
        if (splitType == NONE) 
            surfInst = addSurface();

        for (e in 0...mapData.entities.length) {
            if (filterEntity(e))
                continue;

            var entityInst = mapData.entities[e];

            if (splitType == ENTITY) {
                if (entityInst.spawnType == MERGE_WORLDSPAWN) {
                    addSurface();
                    surfInst = outSurfaces[0];
                    indexOffset = surfInst.vertices.length;
                } else {
                    surfInst = addSurface();
                    indexOffset = surfInst.vertices.length;
                }
            }

            for (b in 0...entityInst.brushes.length) {
                if (filterBrush(e, b)) 
                    continue;

                if (splitType == BRUSH) {
                    indexOffset = 0;
                    surfInst = addSurface();
                }

                var brushInst = entityInst.brushes[b];

                for (f in 0...brushInst.faces.length) {
                    if (filterFace(e, b, f))
                        continue;

                    var faceGeoInst = mapData.entitiesGeo[e][b][f];
                    for (vertex in faceGeoInst.vertices) {
                        if (entityInst.spawnType == ENTITY || entityInst.spawnType == GROUP)
                            vertex.vertex -= entityInst.center;
                        
                        surfInst.vertices.push(vertex);
                    }

                    for (i in 0...(faceGeoInst.vertices.length - 2) * 3) 
                        surfInst.indices.push(faceGeoInst.indices[i] + indexOffset);

                    indexOffset += faceGeoInst.vertices.length;
                }
            }
        }
    }

    public function filterEntity(entityIdx:Int) {
        return entityFilterIdx != -1 && entityIdx != entityFilterIdx;
    }
    public function filterBrush(entityIdx:Int, brushIdx:Int) {
        var faces = mapData.entities[entityIdx].brushes[brushIdx].faces;

        if (brushFilterTextureIdx != -1) {
            var fullyTextured = true;

            for (f in faces) {
                if (f.textureIdx != brushFilterTextureIdx) {
                    fullyTextured = false;
                    break;
                }
            }

            if (fullyTextured)
                return true;
        }

        for (f in faces) {
            for (l in mapData.worldspawnLayers) {
                trace(f, l);
                if (f.textureIdx == l.textureIdx) {
                    return filterWorldspawnLayers;
                }
            }
        }

        return false;
    }
    public function filterFace(entityIdx:Int, brushIdx:Int, faceIdx:Int) {
        var faceInst = mapData.entities[entityIdx].brushes[brushIdx].faces[faceIdx];
        var faceGeoInst = mapData.entitiesGeo[entityIdx][brushIdx][faceIdx];
        
        if (faceGeoInst.vertices.length < 3)
            return true;
        
        if (faceFilterTextureIdx != -1 && faceInst.textureIdx == faceFilterTextureIdx)
            return true;
    
        if (textureFilterIdx != -1 && faceInst.textureIdx != textureFilterIdx)
            return true;

        return false;
    }

    public function addSurface() {
        var s:Surface = {
            vertices: [],
            indices: []
        };
        outSurfaces.push(s);
        return s;
    }
    public inline function resetState() {
        outSurfaces = [];
    }
    public function resetParams() {
        splitType = NONE;
        entityFilterIdx = -1;
        textureFilterIdx = -1;
        brushFilterTextureIdx = -1;
        faceFilterTextureIdx = -1;
        filterWorldspawnLayers = true;
    }
}