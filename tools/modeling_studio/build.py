"""SERA Modeling Studio: offline asset authoring, Blender 4.5 LTS.
Run using Blender --background --factory-startup --python-exit-code 1
--python tools/modeling_studio/build.py -- design.json output_directory
Coordinates: metres, Blender Z up, front -Y. No runtime dependencies.
"""
import json
import math
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

VIEWS = {
    "front": (0, -1, 0), "back": (0, 1, 0),
    "left": (-1, 0, 0), "right": (1, 0, 0),
    "top": (0, 0, 1), "bottom": (0, 0, -1),
    "front_3q": (1, -1, .65), "back_3q": (-1, 1, .65),
}


def active(obj):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def material(name, spec):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*spec["rgb"], 1.0)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = mat.diffuse_color
    shader.inputs["Metallic"].default_value = spec.get("metallic", .25)
    shader.inputs["Roughness"].default_value = spec.get("roughness", .45)
    return mat


def mesh(name, verts, faces):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    bm = bmesh.new()
    try:
        bm.from_mesh(data)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.to_mesh(data)
    finally:
        bm.free()
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    return obj


def loft(name, rings):
    # Rings are corresponding ordered convex or simple polygon outlines.
    n = len(rings[0])
    if n < 3 or len(rings) < 2 or any(len(r) != n for r in rings):
        raise ValueError("loft requires >=2 rings of equal vertex count >=3")
    faces = [tuple(reversed(range(n)))]
    for j in range(len(rings)-1):
        for i in range(n):
            a = j*n+i
            b = j*n+(i+1)%n
            faces.append((a, b, b+n, a+n))
    faces.append(tuple(range((len(rings)-1)*n, len(rings)*n)))
    return mesh(name, [v for ring in rings for v in ring], faces)


def box(name, size):
    if len(size) != 3 or min(size) <= 0:
        raise ValueError("positive box dimensions required")
    x,y,z = (v/2 for v in size)
    return loft(name, [[(-x,-y,h),(x,-y,h),(x,y,h),(-x,y,h)] for h in (-z,z)])


def prism(name, profile, depth):
    if depth <= 0:
        raise ValueError("positive extrusion depth required")
    return loft(name, [[(x,y,z) for x,y in profile] for z in (-depth/2,depth/2)])


def cylinder(name, radius, depth, sides=24):
    if radius <= 0 or sides < 3:
        raise ValueError("positive radius and >=3 sides required")
    return prism(name, [(radius*math.cos(2*math.pi*i/sides),
                         radius*math.sin(2*math.pi*i/sides)) for i in range(sides)], depth)


def tube(name, path, radius, sides=12):
    points = [Vector(p) for p in path]
    if len(points) < 2 or radius <= 0 or sides < 3:
        raise ValueError("invalid tube")
    rings = []
    previous = None
    for i,p in enumerate(points):
        tangent = points[min(i+1,len(points)-1)] - points[max(i-1,0)]
        if tangent.length < 1e-8:
            raise ValueError("degenerate tube tangent")
        tangent.normalize()
        u = previous - tangent*previous.dot(tangent) if previous is not None else Vector((0,0,1)).cross(tangent)
        if u.length < 1e-8:
            u = Vector((0,1,0)).cross(tangent)
        u.normalize()
        v = tangent.cross(u).normalized()
        rings.append([tuple(p+radius*(u*math.cos(2*math.pi*j/sides)+v*math.sin(2*math.pi*j/sides))) for j in range(sides)])
        previous = u
    return loft(name, rings)


def shape(name, spec):
    kind = spec["shape"]
    if kind == "box":
        obj = box(name, spec["size"])
    elif kind == "loft":
        obj = loft(name, spec["rings"])
    elif kind == "prism":
        obj = prism(name, spec["profile"], spec["depth"])
    elif kind == "cylinder":
        obj = cylinder(name, spec["radius"], spec["depth"], spec.get("sides",24))
    elif kind == "tube":
        obj = tube(name, spec["path"], spec["radius"], spec.get("sides",12))
    elif kind == "mesh":
        obj = mesh(name, spec["vertices"], spec["faces"])
    else:
        raise ValueError("unknown shape: "+kind)
    obj.location = spec.get("location", (0,0,0))
    obj.rotation_euler = [math.radians(a) for a in spec.get("rotation_deg", (0,0,0))]
    return obj


def apply_modifier(obj, mod):
    active(obj)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def build_part(spec, mats):
    obj = shape(spec["name"], spec)
    for i,cut in enumerate(spec.get("cuts", [])):
        cutter = shape(obj.name+"_cutter_"+str(i), cut)
        # Cut coordinates are relative to the part, not to world axes.
        cutter.parent = obj
        bpy.context.view_layer.update()
        mod = obj.modifiers.new("Cut", 'BOOLEAN')
        mod.operation = cut.get("operation", "DIFFERENCE")
        mod.solver = 'EXACT'
        mod.object = cutter
        apply_modifier(obj, mod)
        bpy.data.objects.remove(cutter, do_unlink=True)
    width = spec.get("bevel", 0)
    if width > 0:
        mod = obj.modifiers.new("Edge finish", 'BEVEL')
        mod.width = width
        mod.segments = spec.get("bevel_segments", 2)
        mod.limit_method = 'ANGLE'
        mod.harden_normals = True
        apply_modifier(obj, mod)
    if spec.get("weighted_normals", width > 0):
        for face in obj.data.polygons:
            face.use_smooth = True
        mod = obj.modifiers.new("Weighted normals", 'WEIGHTED_NORMAL')
        mod.keep_sharp = True
        apply_modifier(obj, mod)
    obj.data.materials.append(mats[spec["material"]])
    if spec.get("uv", True):
        active(obj)
        bpy.ops.object.mode_set(mode='EDIT')
        try:
            bpy.ops.mesh.select_all(action='SELECT')
            bpy.ops.uv.smart_project(island_margin=.025)
        finally:
            bpy.ops.object.mode_set(mode='OBJECT')
    return obj


def build(spec):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = {name:material(name,s) for name,s in spec["materials"].items()}
    nodes = {}
    # Parent nodes must precede their children. Coordinates are parent-local.
    for part in spec["parts"]:
        name = part["name"]
        if name in nodes:
            raise ValueError("duplicate node: "+name)
        if part["shape"] == "pivot":
            obj = bpy.data.objects.new(name, None)
            bpy.context.collection.objects.link(obj)
            obj.location = part.get("location",(0,0,0))
            obj.rotation_euler = [math.radians(a) for a in part.get("rotation_deg",(0,0,0))]
        else:
            obj = build_part(part, mats)
        if "parent" in part:
            obj.parent = nodes[part["parent"]]
        nodes[name] = obj
    bpy.context.view_layer.update()
    return list(nodes.values())


def mesh_report(objects):
    rows = []
    for obj in objects:
        if obj.type != 'MESH':
            continue
        data = obj.data
        data.calc_loop_triangles()
        bm = bmesh.new()
        try:
            bm.from_mesh(data)
            rows.append(dict(name=obj.name, vertices=len(data.vertices),
                triangles=len(data.loop_triangles),
                non_manifold_edges=sum(not e.is_manifold for e in bm.edges),
                zero_area_faces=sum(f.calc_area()<1e-12 for f in bm.faces),
                signed_volume=bm.calc_volume(signed=True)))
        finally:
            bm.free()
    return rows


def aim(obj, target):
    obj.rotation_euler = (Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()


def render_views(objects, out, resolution, landmarks):
    corners = [obj.matrix_world @ Vector(c) for obj in objects if obj.type=='MESH' for c in obj.bound_box]
    if not corners:
        raise ValueError("model contains no mesh")
    low = Vector([min(v[i] for v in corners) for i in range(3)])
    high = Vector([max(v[i] for v in corners) for i in range(3)])
    center = (low+high)/2
    span = max((high-low).length, .001)
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 24
    scene.render.resolution_x = scene.render.resolution_y = resolution
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.film_transparent = True
    scene.view_settings.view_transform = 'AgX'
    scene.view_settings.exposure = 0.0
    scene.world = bpy.data.worlds.new("Review World")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (.35, .35, .35, 1)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = .6
    camera_data = bpy.data.cameras.new("Review Camera")
    camera = bpy.data.objects.new("Review Camera",camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera_data.type = 'ORTHO'
    camera_data.ortho_scale = span*1.12
    camera_data.clip_start = max(span*.0001, .00001)
    camera_data.clip_end = span*20
    lights = []
    for direction, strength in [((2,-3,4),100),((-3,-1,2),65),((1,3,3),110),((0,0,-4),55)]:
        data = bpy.data.lights.new("Review Light",'AREA')
        data.energy = strength*span**2
        data.shape = 'DISK'
        data.size = span*1.6
        light = bpy.data.objects.new("Review Light",data)
        scene.collection.objects.link(light)
        light.location = center+Vector(direction).normalized()*span*2
        aim(light,center)
        lights.append(light)
    projections = {}
    nodes = {obj.name: obj for obj in objects}
    for name,direction in VIEWS.items():
        camera.location = center+Vector(direction).normalized()*span*3
        if name in ("top","bottom"):
            camera.rotation_euler = (0,0,0) if name=="top" else (math.pi,0,0)
        else:
            aim(camera, center)
        bpy.context.view_layer.update()
        points = {}
        for label, point in landmarks.items():
            world = nodes[point["node"]].matrix_world @ Vector(point["local"])
            ndc = world_to_camera_view(scene, camera, world)
            points[label] = [ndc.x * resolution, (1-ndc.y) * resolution]
        projections[name] = {"landmarks": points, "resolution": resolution,
                             "ortho_scale": camera_data.ortho_scale}
        scene.render.filepath = str(out/(name+".png"))
        bpy.ops.render.render(write_still=True)
    (out/"projections.json").write_text(json.dumps(projections, indent=2), encoding="utf-8")
    for obj in [camera,*lights]:
        bpy.data.objects.remove(obj, do_unlink=True)


def main():
    args = sys.argv[sys.argv.index("--")+1:]
    if len(args)!=2:
        raise SystemExit("usage: build.py -- design.json output_directory")
    source,out = Path(args[0]).resolve(),Path(args[1]).resolve()
    spec = json.loads(source.read_text(encoding="utf-8"))
    if spec.get("format")!="SERA_MODELING_STUDIO_V1":
        raise ValueError("unsupported design format")
    # Refuse reuse, avoiding stale images or overwriting existing assets.
    out.mkdir(parents=True,exist_ok=False)
    objects = build(spec)
    report = mesh_report(objects)
    (out/"mesh_report.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
    bpy.ops.wm.save_as_mainfile(filepath=str(out/"model.blend"))
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(out/"model.glb"),export_format='GLB',
                              use_selection=True,export_yup=True,export_animations=False)
    resolution = int(spec.get("review_resolution",768))
    if not 128<=resolution<=2048:
        raise ValueError("review_resolution must be 128..2048")
    render_views(objects,out,resolution,spec.get("landmarks", {}))
    (out/"complete.json").write_text(json.dumps(dict(format=spec["format"],views=list(VIEWS),
        triangles=sum(row["triangles"] for row in report)),indent=2),encoding="utf-8")


if __name__ == "__main__":
    main()
