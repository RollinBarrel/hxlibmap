package libmap;

import hxmath.math.Vector3;

typedef FacePoints = {
    var v0:Vector3;
    var v1:Vector3;
    var v2:Vector3;
}

typedef StandardUV = {
    var u:Float;
    var v:Float;
}

typedef ValveTextureAxis = {
    var axis:Vector3;
    var offset:Float;
}

typedef ValveUV = {
    var u:ValveTextureAxis;
    var v:ValveTextureAxis;
}

typedef FaceUVExtra = {
    var rot:Float;
    var scaleX:Float;
    var scaleY:Float;
}

typedef Face = {
    var planePoints:FacePoints;
    var planeNormal:Vector3;
    var planeDist:Float;

    var textureIdx:Int;

    var isValveUV:Bool;
    var uvStandard:StandardUV;
    var uvValve:ValveUV;
    var uvExtra:FaceUVExtra;
}