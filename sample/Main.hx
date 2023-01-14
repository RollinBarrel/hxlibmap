import libmap.MapParser;
import libmap.SurfaceGatherer.Surface;
import h3d.prim.Polygon;
import h3d.scene.Mesh;

class Main extends hxd.App {
    static function main() {
        #if sys
        hxd.Res.initLocal();
        #else
        hxd.Res.initEmbed();
        #end
        new Main();
    }

    public function loadMap(entry:hxd.fs.FileEntry) {
        var input = entry.open();
        var data = new libmap.MapParser(input).parse();
        input.close();

        for (tex in data.textures) {
            var size = hxd.Res.load(tex.name + ".jpg").toImage().getSize();
            tex.width = size.width;
            tex.height = size.height;
        }

        new libmap.GeoGenerator(data).run();

        var gatherer = new libmap.SurfaceGatherer(data);
        gatherer.filterWorldspawnLayers = false;
        gatherer.run();

        return makePrim(gatherer.outSurfaces);
    }

    public function makePrim(surfaces:Array<Surface>) {
        var verts = [];
        var normals = [];
        var tangents = [];
        var uvs = [];
        var idx = new hxd.IndexBuffer();

        for (surface in surfaces) {
            for (vert in surface.vertices) {
                verts.push(new h3d.col.Point(vert.vertex.x, vert.vertex.y, vert.vertex.z));
                normals.push(new h3d.col.Point(vert.normal.x, vert.normal.y, vert.normal.z));
                tangents.push(new h3d.col.Point(vert.tangent.x, vert.tangent.y, vert.tangent.z));
                uvs.push(new h3d.prim.UV(vert.uv.u, vert.uv.v));
            }
            for (i in surface.indices)
                idx.push(i);
        }

        var p = new Polygon(verts, idx);
        p.normals = normals;
        p.tangents = tangents;
        p.uvs = uvs;

        return p;
    }

    override public function init() {
        cast (s3d.lightSystem, h3d.scene.fwd.LightSystem).ambientLight.set(1, 1, 1);
        s3d.camera.rightHanded = true;
        new h3d.scene.CameraController(512, s3d);
        
        var tex = hxd.Res.grass.toTexture();
        tex.wrap = Repeat;
        var material = h3d.mat.Material.create(tex);
        material.shadows = false;
        
        var mapMesh = new Mesh(loadMap(hxd.Res.map.entry), material, s3d);
        #if (debug && sys)
        hxd.Res.map.watch(() -> {
            mapMesh.primitive = loadMap(hxd.Res.map.entry);
        });
        #end
    }
}