package libmap;

import libmap.EntityGeometry.FaceVertex;
import libmap.EntityGeometry.VertexTangent;
import hxmath.math.Matrix3x3;
import libmap.EntityGeometry.VertexUV;
import hxmath.math.Vector3;

class GeoGenerator {
    public static inline var EPSILON = 1e-10;

    var mapData:MapData;
    public function new(mapData) {
        this.mapData = mapData;
    }

    function sortVerticesByWinding(faceCenter:Vector3, faceBasis:Vector3, faceNormal:Vector3, lhs:FaceVertex, rhs:FaceVertex) {
        var lhs = lhs.vertex;
        var rhs = rhs.vertex;

        var u = faceBasis.clone().normalize();
        var v = (u % faceNormal).normalize();

        var localLhs = lhs - faceCenter;
        var lhsPU = localLhs * u;
        var lhsPV = localLhs * v;

        var localRhs = rhs - faceCenter;
        var rhsPU = localRhs * u;
        var rhsPV = localRhs * v;

        var lhsAngle = Math.atan2(lhsPV, lhsPU);
        var rhsAngle = Math.atan2(rhsPV, rhsPU);

        if (lhsAngle < rhsAngle) {
            return -1;
        } else if (lhsAngle > rhsAngle) {
            return 1;
        }

        return 0;
    }

    public function run() {
        for (e in 0...mapData.entities.length) {
            var entInst = mapData.entities[e];
            var entityGeoInst = [];
            mapData.entitiesGeo[e] = entityGeoInst;

            for (b in 0...entInst.brushes.length) {
                var brushInst = entInst.brushes[b];
                var brushGeoInst = [];
                entityGeoInst[b] = brushGeoInst;
                
                for (f in 0...brushInst.faces.length) {
                    brushGeoInst[f] = {
                        vertices: [],
                        indices: []
                    };
                }
            }
        }

        for (e in 0...mapData.entities.length) {
            var entInst = mapData.entities[e];
            entInst.center = Vector3.zero;
            for (b in 0...entInst.brushes.length) {
                var brushInst = entInst.brushes[b];
                brushInst.center = Vector3.zero;
                var vertCount = 0;

                generateBrushVertices(e, b);

                var brushGeoInst = mapData.entitiesGeo[e][b];
                for (f in 0...brushInst.faces.length) {
                    var faceGeoInst = brushGeoInst[f];

                    for (v in 0...faceGeoInst.vertices.length) {
                        brushInst.center += faceGeoInst.vertices[v].vertex;
                        vertCount++;
                    }
                }

                if (vertCount > 0)
                    brushInst.center /= vertCount;

                entInst.center += brushInst.center;
            }

            if (entInst.brushes.length > 0) 
                entInst.center /= entInst.brushes.length;
        }

        for (e in 0...mapData.entities.length) {
            var entityInst = mapData.entities[e];
            var entityGeoInst = mapData.entitiesGeo[e];

            for (b in 0...entityInst.brushes.length) {
                var brushInst = entityInst.brushes[b];
                var brushGeoInst = entityGeoInst[b];

                for (f in 0...brushInst.faces.length) {
                    var faceInst = brushInst.faces[f];
                    var faceGeoInst = brushGeoInst[f];

                    if (faceGeoInst.vertices.length < 3) 
                        continue;

                    var windFaceBasis = faceGeoInst.vertices[1].vertex - faceGeoInst.vertices[0].vertex;
                    var windFaceCenter = Vector3.zero;
                    var windFaceNormal = faceInst.planeNormal;

                    for (v in 0...faceGeoInst.vertices.length) 
                        windFaceCenter += faceGeoInst.vertices[v].vertex;

                    windFaceCenter /= faceGeoInst.vertices.length;

                    // somehow swapping b and a makes the order correct????? whatttttttttttt
                    faceGeoInst.vertices.sort((b, a) -> sortVerticesByWinding(windFaceCenter, windFaceBasis, windFaceNormal, a, b));
                }
            }
        }

        for (e in 0...mapData.entities.length) {
            var entityInst = mapData.entities[e];
            var entityGeoInst = mapData.entitiesGeo[e];
            for (b in 0...entityInst.brushes.length) {
                var brushInst = entityInst.brushes[b];
                var brushGeoInst = entityGeoInst[b];

                for (f in 0...brushInst.faces.length) {
                    var faceInst = brushInst.faces[f];
                    var faceGeoInst = brushGeoInst[f];

                    if (faceGeoInst.vertices.length < 3)
                        continue;

                    for (i in 0...faceGeoInst.vertices.length - 2) {
                        faceGeoInst.indices.push(0);
                        faceGeoInst.indices.push(i + 1);
                        faceGeoInst.indices.push(i + 2);
                    }
                }
            }
        }
    }

    public function generateBrushVertices(entityIdx:Int, brushIdx:Int) {
        var entInst = mapData.entities[entityIdx];
        var brushInst = entInst.brushes[brushIdx];

        for (f0 in 0...brushInst.faces.length) {
            for (f1 in 0...brushInst.faces.length) {
                for (f2 in 0...brushInst.faces.length) {
                    var vertex = intersectFaces(brushInst.faces[f0], brushInst.faces[f1], brushInst.faces[f2]);
                    if (vertex != null) {
                        if (vertexInHull(brushInst.faces, vertex)) {
                            var faceInst = brushInst.faces[f0];
                            var faceGeoInst = mapData.entitiesGeo[entityIdx][brushIdx][f0];

                            var normal:Vector3;

                            var phongPoroperty = entInst.properties.get("_phong");
                            var phong = phongPoroperty != null && phongPoroperty == "1";
                            if (phong) {
                                var phongAngleProperty = entInst.properties.get("_phong_angle");
                                if (phongAngleProperty != null) {
                                    var threshold = Math.cos((Std.parseFloat(phongAngleProperty) + 0.01) * 0.0174533);
                                    normal = brushInst.faces[f0].planeNormal;
                                    if (brushInst.faces[f0].planeNormal * brushInst.faces[f1].planeNormal > threshold) {
                                        normal += brushInst.faces[f1].planeNormal;
                                    }
                                    if (brushInst.faces[f0].planeNormal * brushInst.faces[f2].planeNormal > threshold) {
                                        normal += brushInst.faces[f2].planeNormal;
                                    }
                                    normal.normalize();
                                } else {
                                    normal = brushInst.faces[f0].planeNormal + brushInst.faces[f1].planeNormal + brushInst.faces[f2].planeNormal;
                                    normal.normalize();
                                }
                            } else {
                                normal = faceInst.planeNormal;
                            }

                            var texture = mapData.textures[faceInst.textureIdx];

                            var uv:VertexUV;
                            var tangent:VertexTangent;
                            if (faceInst.isValveUV) {
                                uv = getValveUV(vertex, faceInst, texture.width, texture.height);
                                tangent = getValveTangent(faceInst);
                            } else {
                                uv = getStandardUV(vertex, faceInst, texture.width, texture.height);
                                tangent = getStandardTangent(faceInst);
                            }

                            var uniqueVertex = true;
                            var duplicateIndex = -1;

                            for (v in 0...faceGeoInst.vertices.length) {
                                var compVertex = faceGeoInst.vertices[v].vertex;
                                if ((vertex - compVertex).length < EPSILON) {
                                    uniqueVertex = false;
                                    duplicateIndex = v;
                                    break;
                                }
                            }

                            if (uniqueVertex) {
                                faceGeoInst.vertices.push({
                                    vertex: vertex,
                                    normal: normal,
                                    uv: uv,
                                    tangent: tangent
                                });
                            } else if (phong) {
                                faceGeoInst.vertices[duplicateIndex].normal += normal;
                            }
                        }
                    }
                }
            }
        }

        for (f in 0...brushInst.faces.length) {
            var faceGeoInst = mapData.entitiesGeo[entityIdx][brushIdx][f];
            for (vert in faceGeoInst.vertices) 
                vert.normal.normalize();
        }
    }
    public function intersectFaces(f0:Face, f1:Face, f2:Face):Vector3 {
        var denom = (f0.planeNormal % f1.planeNormal) * f2.planeNormal;

        if (denom < EPSILON)
            return null;

        // vec3_div_double(vec3_add(vec3_add(vec3_mul_double(vec3_cross(normal1, normal2), f0.plane_dist), vec3_mul_double(vec3_cross(normal2, normal0), f1.plane_dist)), vec3_mul_double(vec3_cross(normal0, normal1), f2.plane_dist)), denom);
        return (((f1.planeNormal % f2.planeNormal) * f0.planeDist) + ((f2.planeNormal % f0.planeNormal) * f1.planeDist) + ((f0.planeNormal % f1.planeNormal) * f2.planeDist)) / denom;
    }
    public function vertexInHull(faces:Array<Face>, vertex:Vector3) {
        for (face in faces) {
            var proj = face.planeNormal * vertex;

            if (proj > face.planeDist && Math.abs(face.planeDist - proj) > EPSILON)
                return false;
        }

        return true;
    }

    public function getStandardUV(vertex:Vector3, face:Face, textureWidth:Int, textureHeight:Int) { 
        var du = Math.abs(face.planeNormal * Vector3.zAxis);
        var dr = Math.abs(face.planeNormal * Vector3.yAxis);
        var df = Math.abs(face.planeNormal * Vector3.xAxis);

        var uvOut:VertexUV = {u: 0, v: 0};

        if (du >= dr && du >= df) {
            uvOut = {u: vertex.x, v: -vertex.y};
        } else if (dr >= du && dr >= df) {
            uvOut = {u: vertex.x, v: -vertex.z};
        } else if (df >= du && df >= dr) {
            uvOut = {u: vertex.y, v: -vertex.z};
        }

        var angle = face.uvExtra.rot * Math.PI / 180.;
        var rotated:VertexUV = {
            u: uvOut.u * Math.cos(angle) - uvOut.v * Math.sin(angle),
            v: uvOut.u * Math.sin(angle) + uvOut.v * Math.cos(angle)
        };

        uvOut = rotated;

        uvOut.u /= textureWidth;
        uvOut.v /= textureHeight;

        uvOut.u /= face.uvExtra.scaleX;
        uvOut.v /= face.uvExtra.scaleY;

        uvOut.u += face.uvStandard.u / textureWidth;
        uvOut.v += face.uvStandard.v / textureHeight;

        return uvOut;
    }
    public function getValveUV(vertex:Vector3, face:Face, textureWidth:Int, textureHeight:Int) { 
        var uvOut:VertexUV = {
            u: face.uvValve.u.axis * vertex,
            v: face.uvValve.v.axis * vertex
        };

        uvOut.u /= textureWidth;
        uvOut.v /= textureHeight;

        uvOut.u /= face.uvExtra.scaleX;
        uvOut.u /= face.uvExtra.scaleY;

        uvOut.u += face.uvValve.u.offset / textureWidth;
        uvOut.v += face.uvValve.v.offset / textureHeight;

        return uvOut;
    }

    function rotationMatrix(axis:Vector3, angle:Float) {
		var cos = Math.cos(angle);
        var sin = Math.sin(angle);

		var cos1 = 1 - cos;

		var x = -axis.x;
        var y = -axis.y;
        var z = -axis.z;

		var xx = x * x;
        var yy = y * y;
        var zz = z * z;

		var len = 1. / Math.sqrt(xx + yy + zz);

		x *= len;
		y *= len;
		z *= len;

		var xcos1 = x * cos1;
        var zcos1 = z * cos1;
        return new Matrix3x3(
            cos + x * xcos1, y * xcos1 - z * sin, x * zcos1 + y * sin,
            y * xcos1 + z * sin, cos + y * y * cos1, y * zcos1 - x * sin,
            x * zcos1 - y * sin, y * zcos1 + x * sin, cos + z * zcos1
        );
	}
    inline function sign(v:Float) return (v > 0) ? 1 : ((v < 0) ? -1 : 0);

    public function getStandardTangent(face:Face) {
        var du = Math.abs(face.planeNormal * Vector3.zAxis);
        var dr = Math.abs(face.planeNormal * Vector3.yAxis);
        var df = Math.abs(face.planeNormal * Vector3.xAxis);

        var dua = Math.abs(du);
        var dra = Math.abs(dr);
        var dfa = Math.abs(df);

        var uAxis = Vector3.zero;
        var vSign = 0.;

        if (dua >= dra && dua >= dfa) {
            uAxis = Vector3.xAxis;
            vSign = sign(du);
        } else if (dra >= dua && dra >= dfa) {
            uAxis = Vector3.xAxis;
            vSign = -sign(dr);
        } else if (dfa >= dua && dfa >= dra) {
            uAxis = Vector3.yAxis;
            vSign = sign(df);
        }

        vSign *= sign(face.uvExtra.scaleY);
        uAxis = rotationMatrix(face.planeNormal, -face.uvExtra.rot * Math.PI / 180.0 * vSign) * uAxis;

        return new VertexTangent(uAxis.x, uAxis.y, uAxis.z, vSign);
    }
    public function getValveTangent(face:Face) {
        var uAxis = face.uvValve.u.axis.clone().normalize();
        var vAxis = face.uvValve.v.axis.clone().normalize();

        var vSign = -sign((face.planeNormal % uAxis) * vAxis);

        return new VertexTangent(uAxis.x, uAxis.y, uAxis.z, vSign);
    }

    public function getBrushVertexCount(entityIdx:Int, brushIdx:Int) {
        var vertexCount = 0;
        for (i in 0...mapData.entities[entityIdx].brushes[brushIdx].faces.length) 
            vertexCount += mapData.entitiesGeo[entityIdx][brushIdx][i].vertices.length;
        return vertexCount;
    }
    public function getBrushIndexCount(entityIdx:Int, brushIdx:Int) {
        var indexCount = 0;
        for (i in 0...mapData.entities[entityIdx].brushes[brushIdx].faces.length) 
            indexCount += mapData.entitiesGeo[entityIdx][brushIdx][i].indices.length;
        return indexCount;
    }
}