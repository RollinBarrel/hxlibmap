package libmap;

import hxmath.math.Vector3;
import haxe.io.Eof;
import haxe.io.Input;

enum abstract ParseScope(Int) from Int to Int {
    var FILE;
    var COMMENT;
    var ENTITY;
    var PROPERTY_VALUE;
    var BRUSH;
    var PLANE_0;
    var PLANE_1;
    var PLANE_2;
    var TEXUTURE;
    var U;
    var V;
    var VALVE_U;
    var VALVE_V;
    var ROT;
    var U_SCALE;
    var V_SCALE;
}

class MapParser {
    var scope:ParseScope = FILE;
    var comment = false;
    var entityIdx = -1;
    var brushIdx = -1;
    var faceIdx = -1;
    var componentIdx = 0;
    var currentPropertyKey:String;
    var currentPropertyValue:String;
    var valveUVs = false;
    
    var currentFace:Face;
    var currentBrush:Brush;
    var currentEntity:Entity;

    public var input:Input;

    public var mapData:MapData;
    public function new(input) {
        this.input = input;
    }

    public function parse() {
        resetCurrentFace();
        resetCurrentBrush();
        resetCurrentEntity();
        mapData = new MapData();
        
        var buf = new StringBuf();
        inline function resetBuf() {
            #if hl
            @:privateAccess buf.pos = 0;
            @:privateAccess buf.size = 8;
            #else 
            buf = new StringBuf();
            #end
        }
        try {
            while (true) {
                var c = input.readByte();
                if (c == '\n'.code) {
                    token(buf.toString());
                    resetBuf();
                    newline();
                } else if ((c > 8 && c < 14) || c == 32) {
                    token(buf.toString());
                    resetBuf();
                } else {
                    buf.addChar(c);
                }
            }
        } catch (err:Eof) {}

        return mapData;
    }

    public function token(buf:String) {
        if (comment)
            return;
        if (buf.charAt(0) == "/" && buf.charAt(1) == "/") {
            comment = true;
            return;
        }

        switch (scope) {
            case FILE: 
                if (buf.charAt(0) == "{") {
                    entityIdx++;
                    brushIdx = -1;
                    scope = ENTITY;
                }
            case ENTITY:
                if (buf.charAt(0) == '"') {
                    currentPropertyKey = buf.substring(1, buf.length - 1);
                    if (buf.charAt(buf.length - 1) == '"') {
                        scope = PROPERTY_VALUE;
                    }
                } else if (buf.charAt(0) == "{") {
                    brushIdx++;
                    faceIdx = -1;
                    scope = BRUSH;
                } else if (buf.charAt(0) == "}") {
                    commitEntity();
                    scope = FILE;
                }
            case PROPERTY_VALUE:
                var isFirst = buf.charAt(0) == '"';
                var isLast = buf.charAt(buf.length - 1) == '"';

                var end = isLast ? buf.length - 1 : buf.length;
                if (isFirst) {
                    currentPropertyValue = buf.substring(1, end);
                } else {
                    currentPropertyValue += " " + buf.substring(0, end);
                }

                if (isLast) {
                    currentEntity.properties[currentPropertyKey] = currentPropertyValue;
                    scope = ENTITY;
                }
            case BRUSH:
                if (buf.charAt(0) == "(") {
                    faceIdx++;
                    componentIdx = 0;
                    scope = PLANE_0;
                } else if (buf.charAt(0) == "}") {
                    commitBrush();
                    scope = ENTITY;
                }
            case PLANE_0:
                if (buf.charAt(0) == ")") {
                    componentIdx = 0;
                    scope = PLANE_1;
                } else {
                    switch (componentIdx) {
                        case 0:
                            currentFace.planePoints.v0.x = Std.parseFloat(buf);
                        case 1:
                            currentFace.planePoints.v0.y = Std.parseFloat(buf);
                        case 2:
                            currentFace.planePoints.v0.z = Std.parseFloat(buf);
                        default:
                    }
                    componentIdx++;
                }
            case PLANE_1:
                if (buf.charAt(0) == "(") {
                    return;
                } else if (buf.charAt(0) == ")") {
                    componentIdx = 0;
                    scope = PLANE_2;
                } else {
                    switch (componentIdx) {
                        case 0:
                            currentFace.planePoints.v1.x = Std.parseFloat(buf);
                        case 1:
                            currentFace.planePoints.v1.y = Std.parseFloat(buf);
                        case 2:
                            currentFace.planePoints.v1.z = Std.parseFloat(buf);
                        default:
                    }
                    componentIdx++;
                }
            case PLANE_2:
                if (buf.charAt(0) == "(") {
                    return;
                } else if (buf.charAt(0) == ")") {
                    scope = TEXUTURE;
                } else {
                    switch (componentIdx) {
                        case 0:
                            currentFace.planePoints.v2.x = Std.parseFloat(buf);
                        case 1:
                            currentFace.planePoints.v2.y = Std.parseFloat(buf);
                        case 2:
                            currentFace.planePoints.v2.z = Std.parseFloat(buf);
                        default:
                    }
                    componentIdx++;
                }
            case TEXUTURE:
                currentFace.textureIdx = mapData.registerTexture(buf);
                scope = U;
            case U:
                if (buf.charAt(0) == "[") {
                    valveUVs = true;
                    componentIdx = 0;
                    scope = VALVE_U;
                } else {
                    valveUVs = false;
                    currentFace.uvStandard.u = Std.parseFloat(buf);
                    scope = V;
                }
            case V:
                currentFace.uvStandard.v = Std.parseFloat(buf);
                scope = ROT;
            case VALVE_U:
                if (buf.charAt(0) == "]") {
                    componentIdx = 0;
                    scope = VALVE_V;
                } else {
                    switch (componentIdx) {
                        case 0:
                            currentFace.uvValve.u.axis.x = Std.parseFloat(buf);
                        case 1:
                            currentFace.uvValve.u.axis.y = Std.parseFloat(buf);
                        case 2:
                            currentFace.uvValve.u.axis.z = Std.parseFloat(buf);
                        case 3:
                            currentFace.uvValve.u.offset = Std.parseFloat(buf);
                        default:
                    }
                    componentIdx++;
                }
            case VALVE_V:
                if (buf.charAt(0) == "[") {
                    return;
                } else if (buf.charAt(0) == "]") {
                    scope = ROT;
                } else {
                    switch (componentIdx) {
                        case 0:
                            currentFace.uvValve.v.axis.x = Std.parseFloat(buf);
                        case 1:
                            currentFace.uvValve.v.axis.y = Std.parseFloat(buf);
                        case 2:
                            currentFace.uvValve.v.axis.z = Std.parseFloat(buf);
                        case 3:
                            currentFace.uvValve.v.offset = Std.parseFloat(buf);
                        default:
                    }
                    componentIdx++;
                }
            case ROT:
                currentFace.uvExtra.rot = Std.parseFloat(buf);
                scope = U_SCALE;
            case U_SCALE:
                currentFace.uvExtra.scaleX = Std.parseFloat(buf);
                scope = V_SCALE;
            case V_SCALE:
                currentFace.uvExtra.scaleY = Std.parseFloat(buf);
                commitFace();
                scope = BRUSH;
            default:
        }
    }
    public function newline() {
        comment = false;
    }

    public function commitFace() {
        var v0v1 = currentFace.planePoints.v1 - currentFace.planePoints.v0;
        var v1v2 = currentFace.planePoints.v2 - currentFace.planePoints.v1;
        currentFace.planeNormal = v1v2.crossWith(v0v1).normalize();
        currentFace.planeDist = currentFace.planeNormal * currentFace.planePoints.v0;
        currentFace.isValveUV = valveUVs;

        currentBrush.faces.push(currentFace);

        resetCurrentFace();
    }
    public function commitBrush() {
        currentEntity.brushes.push(currentBrush);
        resetCurrentBrush();
    }
    public function commitEntity() {
        mapData.entities.push(currentEntity);
        resetCurrentEntity();
    }

    public function resetCurrentFace() {
        currentFace = {
            planePoints: {
                v0: Vector3.zero,
                v1: Vector3.zero,
                v2: Vector3.zero
            },
            planeNormal: Vector3.zero,
            planeDist: 0,
            textureIdx: 0,
            isValveUV: false,
            uvStandard: {
                u: 0,
                v: 0
            },
            uvValve: {
                u: {
                    axis: Vector3.zero,
                    offset: 0
                },
                v: {
                    axis: Vector3.zero,
                    offset: 0
                }
            },
            uvExtra: {
                rot: 0,
                scaleX: 0,
                scaleY: 0
            }
        };
    }
    public function resetCurrentBrush() {
        currentBrush = {
            faces: [],
            center: Vector3.zero
        };
    }
    public function resetCurrentEntity() {
        currentEntity = new Entity();
    }
}