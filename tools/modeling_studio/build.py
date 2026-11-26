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
from mathutils import Vector, Quaternion
sys.path.insert(0, str(Path(__file__).resolve().parent))
from geometry_review import fit_camera, mesh_interference
from wireframe_guides import solve as solve_wireframe
from hard_surface import compile_design, repeat_closed_path, positive
from mechanism_graph import compile_graph
from motion_lod import motion_review, export_lod
from joint_hierarchy_review import review_joints
from visibility_review import review_visibility
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
    if "emission" in spec:
        shader.inputs["Emission Color"].default_value = (*spec["emission"],1.0)
        shader.inputs["Emission Strength"].default_value = spec.get("emission_strength",1.0)
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


def wireframe_surface(name, verts, faces):
    # Construct a genuine edge mesh first, then populate its explicitly authored faces.
    edges = sorted({tuple(sorted((a,b))) for f in faces for a,b in zip(f,f[1:]+f[:1])})
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, edges, [])
    data.update()
    bm = bmesh.new()
    try:
        bm.from_mesh(data)
        bm.verts.ensure_lookup_table()
        for f in faces:
            bm.faces.new([bm.verts[i] for i in f])
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        if any(not e.is_manifold for e in bm.edges) or any(f.calc_area()<1e-12 for f in bm.faces):
            raise ValueError("invalid reconstructed surface: "+name)
        bm.to_mesh(data)
    finally:
        bm.free()
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    return obj


def write_wireframe_guides(spec, objects, out):
    nodes = {obj.name: obj for obj in objects}
    reports = {}
    # OBJ is a portable line-only mesh in world-space, before surface finishing.
    lines = ["# SERA wireframe guides; Blender XYZ metres; no faces"]
    offset = 1
    for part in spec["parts"]:
        if part["shape"] != "wireframe":
            continue
        verts, faces, guide = solve_wireframe(part)
        name = part["name"]
        reports[name] = guide
        matrix = nodes[name].matrix_world
        ids = {label: i+offset for i,label in enumerate(guide["points"])}
        lines.append("o "+name.replace(" ","_").replace("\n","_").replace("\r","_"))
        for v in verts:
            world = matrix @ Vector(v)
            lines.append("v %.9g %.9g %.9g"%tuple(world))
        for a,b in guide["edges"]:
            lines.append("l %d %d"%(ids[a],ids[b]))
        offset += len(verts)
    if reports:
        (out/"wireframe_guides.json").write_text(json.dumps(reports,indent=2),encoding="utf-8")
        (out/"wireframe_guides.obj").write_text("\n".join(lines)+"\n",encoding="utf-8")


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


def sweep(name, spec):
    points=[Vector(p) for p in spec["path"]]
    sections=spec["sections"]
    sides=int(spec.get("sides",8))
    if len(points)<2 or len(points)!=len(sections) or not 3<=sides<=128:
        raise ValueError("sweep path and sections must correspond")
    rings=[]
    previous=None
    for i,p in enumerate(points):
        t=points[min(i+1,len(points)-1)]-points[max(i-1,0)]
        if t.length<1e-8 or (i and (p-points[i-1]).length<1e-8):
            raise ValueError("degenerate sweep path")
        t.normalize()
        u=previous-t*previous.dot(t) if previous is not None else Vector(spec.get("up",(0,0,1))).cross(t)
        if u.length<1e-8:
            axis=min((Vector((1,0,0)),Vector((0,1,0)),Vector((0,0,1))),key=lambda a:abs(a.dot(t)))
            u=axis.cross(t)
        u.normalize()
        v=t.cross(u).normalized()
        rx,ry=map(positive,sections[i])
        rings.append([tuple(p+u*rx*math.cos(2*math.pi*j/sides)+v*ry*math.sin(2*math.pi*j/sides)) for j in range(sides)])
        previous=u
    return loft(name,rings)


def revolve(name, spec):
    # Closed radial/axial profile with nonzero radii; useful for rings and flanged joints.
    profile=[(positive(r),float(z)) for r,z in spec["profile"]]
    sides=int(spec.get("sides",24))
    if len(profile)<3 or len(set(profile))!=len(profile) or not 3<=sides<=256 or not all(math.isfinite(z) for r,z in profile):
        raise ValueError("invalid closed radial profile")
    n=len(profile)
    verts=[(r*math.cos(2*math.pi*i/sides),r*math.sin(2*math.pi*i/sides),z) for i in range(sides) for r,z in profile]
    faces=[(i*n+j,i*n+(j+1)%n,((i+1)%sides)*n+(j+1)%n,((i+1)%sides)*n+j) for i in range(sides) for j in range(n)]
    return mesh(name,verts,faces)


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
    elif kind == "sweep":
        obj = sweep(name, spec)
    elif kind == "revolve":
        obj = revolve(name, spec)
    elif kind == "repeat_path":
        verts, faces = repeat_closed_path(spec)
        obj = mesh(name, verts, faces)
    elif kind == "wireframe":
        verts, faces, guide = solve_wireframe(spec)
        obj = wireframe_surface(name, verts, faces)
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


def apply_normal_finish(obj, cfg):
    """Preserve intentional hard edges; smooth only the declared curvature."""
    mode = cfg["mode"]
    if mode == "flat":
        for poly in obj.data.polygons:
            poly.use_smooth = False
        obj.data.update()
        return
    bm = bmesh.new()
    try:
        bm.from_mesh(obj.data)
        bm.normal_update()
        limit = math.radians(cfg["angle_deg"])
        for face in bm.faces:
            face.smooth = True
        for edge in bm.edges:
            edge.smooth = (edge.is_manifold and
                           edge.calc_face_angle(0.0) <= limit)
        bm.to_mesh(obj.data)
    finally:
        bm.free()
    obj.data.update()
    if mode == "weighted":
        mod = obj.modifiers.new("Declared weighted normals", 'WEIGHTED_NORMAL')
        mod.keep_sharp = True
        mod.mode = 'FACE_AREA_WITH_ANGLE'
        apply_modifier(obj, mod)


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
        if 'bevel_angle_deg' in spec:
            mod.angle_limit = math.radians(spec['bevel_angle_deg'])
        mod.harden_normals = True
        apply_modifier(obj, mod)
    if "cleanup_distance" in spec:
        # Explicit opt-in repair of coincident cutter/bevel vertices, before UV.
        dist=float(spec["cleanup_distance"])
        if not 0<dist<=1e-5:raise ValueError("invalid cleanup distance")
        bm=bmesh.new()
        try:
            bm.from_mesh(obj.data)
            bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=dist)
            bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=dist)
            bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
            if any(not e.is_manifold for e in bm.edges):
                raise ValueError("cleanup produced non-manifold mesh: "+obj.name)
            bm.to_mesh(obj.data)
        finally:bm.free()
        obj.data.update()
        obj.data.calc_loop_triangles()
        for tri in obj.data.loop_triangles:
            a,b,c=(obj.data.vertices[i].co for i in tri.vertices)
            if (b-a).cross(c-a).length<1e-12:
                raise ValueError("cleanup left degenerate triangle: "+obj.name)
    if "normal_finish" in spec:
        apply_normal_finish(obj, spec["normal_finish"])
    elif spec.get("weighted_normals", width > 0):
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


def render_views(objects, out, resolution, landmarks, cameras, camera_fits, part_targets=None):
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
    cameras = dict(cameras)
    fitted = {}
    for name, cfg in camera_fits.items():
        if name in cameras:
            raise ValueError('camera fit and manual override conflict: '+name)
        if cfg.get('projection') != 'orthographic' or cfg.get('resolution') != resolution:
            raise ValueError('camera fit requires matching square orthographic image resolution')
        labels = cfg['landmarks']
        world = [list(nodes[landmarks[k]['node']].matrix_world @ Vector(landmarks[k]['local'])) for k in labels]
        fitted[name] = fit_camera(world,list(labels.values()),resolution)
        cameras[name] = fitted[name]
    (out/'camera_fit.json').write_text(json.dumps(fitted,indent=2),encoding='utf-8')
    if not set(cameras) <= set(VIEWS):
        raise ValueError("camera overrides must name an existing review view")
    for name,direction in VIEWS.items():
        cfg = cameras.get(name,{})
        target = Vector(cfg.get("target",center))
        direction = Vector(cfg.get("direction",direction))
        scale = float(cfg.get("ortho_scale",span*1.12))
        if direction.length < 1e-8 or not math.isfinite(scale) or scale<=0:
            raise ValueError("invalid camera configuration: "+name)
        camera_data.ortho_scale = scale
        camera.location = target+direction.normalized()*span*3
        if abs(direction.normalized().z)>0.999999:
            camera.rotation_euler = (0,0,0) if direction.z>0 else (math.pi,0,0)
        else:
            aim(camera, target)
        if "quaternion" in cfg:
            camera.rotation_euler = Quaternion(cfg["quaternion"]).to_euler()
        roll = math.radians(float(cfg.get("roll_degrees",0)))
        if roll:
            camera.rotation_euler = (camera.rotation_euler.to_quaternion() @ Quaternion((0,0,1),roll)).to_euler()
        bpy.context.view_layer.update()
        points = {}
        for label, point in landmarks.items():
            world = nodes[point["node"]].matrix_world @ Vector(point["local"])
            ndc = world_to_camera_view(scene, camera, world)
            points[label] = [ndc.x * resolution, (1-ndc.y) * resolution]
        part_bounds={}
        for part_name in (part_targets or {}):
            obj=nodes[part_name]
            if obj.type!='MESH':
                raise ValueError('part projection requires mesh: '+part_name)
            coords=[world_to_camera_view(scene,camera,obj.matrix_world@v.co) for v in obj.data.vertices]
            if not coords:
                raise ValueError('empty part mesh: '+part_name)
            part_bounds[part_name]=[min(v.x for v in coords)*resolution,min(1-v.y for v in coords)*resolution,
                                    max(v.x for v in coords)*resolution,max(1-v.y for v in coords)*resolution]
        projections[name] = {"landmarks": points, "part_bounds_px":part_bounds, "resolution": resolution,
                             "ortho_scale": camera_data.ortho_scale, "camera_location": list(camera.location),
                             "camera_rotation": list(camera.rotation_euler), "target": list(target)}
        scene.render.filepath = str(out/(name+".png"))
        bpy.ops.render.render(write_still=True)
    (out/"projections.json").write_text(json.dumps(projections, indent=2), encoding="utf-8")
    for obj in [camera,*lights]:
        bpy.data.objects.remove(obj, do_unlink=True)


def export_grouped(objects, path):
    """Join export-only copies by parent and material; keep editable source unchanged."""
    groups={}
    for obj in objects:
        if obj.type=="MESH":
            key=(obj.parent.name if obj.parent else "",obj.data.materials[0].name)
            groups.setdefault(key,[]).append(obj)
    copies=[]
    try:
        for (parent,mat),members in groups.items():
            dup=[]
            for obj in members:
                copy=obj.copy()
                copy.data=obj.data.copy()
                bpy.context.collection.objects.link(copy)
                dup.append(copy)
                copies.append(copy)
            bpy.ops.object.select_all(action="DESELECT")
            for obj in dup: obj.select_set(True)
            bpy.context.view_layer.objects.active=dup[0]
            bpy.ops.object.join()
            dup[0].name=parent+"_"+mat+"_export"
        bpy.ops.object.select_all(action="DESELECT")
        for obj in bpy.context.scene.objects:
            if obj.type=="EMPTY" or (obj.type=="MESH" and obj not in objects):
                obj.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",
                                  use_selection=True,export_yup=True,export_animations=False)
    finally:
        for obj in list(bpy.context.scene.objects):
            if obj.type=="MESH" and obj not in objects:
                bpy.data.objects.remove(obj,do_unlink=True)
    return len(groups)

def main():
    args = sys.argv[sys.argv.index("--")+1:]
    if len(args)!=2:
        raise SystemExit("usage: build.py -- design.json output_directory")
    source,out = Path(args[0]).resolve(),Path(args[1]).resolve()
    spec = json.loads(source.read_text(encoding="utf-8"))
    if spec.get("format")!="SERA_MODELING_STUDIO_V1":
        raise ValueError("unsupported design format")
    # Parts Factory jobs require an authorization bound to the accepted design.
    if source.name.lower().startswith('pf_') or 'parts_factory' in spec:
        sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'parts_factory'))
        from quality_gates import validate_permit
        validate_permit(spec,source)
    # Refuse reuse, avoiding stale images or overwriting existing assets.
    out.mkdir(parents=True,exist_ok=False)
    spec, mechanism = compile_graph(spec)
    spec, authoring = compile_design(spec)
    from surface_authoring import compile_surfaces
    spec, surfaces = compile_surfaces(spec)
    if surfaces is not None:
        (out/'surface_authoring_report.json').write_text(json.dumps(surfaces,indent=2),encoding='utf-8')
    if mechanism is not None:
        (out/'mechanism_graph.json').write_text(json.dumps(mechanism,indent=2),encoding='utf-8')
    objects = build(spec)
    if spec.get('joint_checks'):
        joint_report = review_joints(objects,spec['joint_checks'])
        (out/'joint_hierarchy_review.json').write_text(json.dumps(joint_report,indent=2),encoding='utf-8')
        if not joint_report['all_passed']:
            raise ValueError('joint hierarchy review failed')
    if authoring is not None:
        (out/'hard_surface_plan.json').write_text(json.dumps(authoring,indent=2),encoding='utf-8')
        (out/'compiled_design.json').write_text(json.dumps(spec,indent=2),encoding='utf-8')
    write_wireframe_guides(spec, objects, out)
    if spec.get('visibility_checks'):
        visibility = review_visibility(spec['visibility_checks'])
        (out/'visibility_review.json').write_text(json.dumps(visibility,indent=2),encoding='utf-8')
    if spec.get('attachment_checks'):
        from attachment_review import review as review_attachments
        review_attachments(objects,spec['attachment_checks'],out)
    if spec.get('attachment_graph'):
        from attachment_review import graph_review
        graph_review(objects,spec['attachment_graph'],out)
    if spec.get('texture_handoff'):
        (out/'texture_handoff.json').write_text(json.dumps(spec['texture_handoff'],indent=2),encoding='utf-8')
    report = mesh_report(objects)
    interference = mesh_interference(objects,spec.get("intentional_overlaps",[]))
    motion = motion_review(objects,spec.get("motion_sweeps",[]),spec.get("intentional_overlaps",[]))
    (out/"motion_review.json").write_text(json.dumps(motion,indent=2),encoding="utf-8")
    (out/"interference.json").write_text(json.dumps(interference,indent=2),encoding="utf-8")
    (out/"mesh_report.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
    bpy.ops.wm.save_as_mainfile(filepath=str(out/"model.blend"))
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(out/"model.glb"),export_format='GLB',
                              use_selection=True,export_yup=True,export_animations=False)
    if spec.get("grouped_export"):
        n=export_grouped(objects,out/"model_grouped.glb")
        (out/"grouped_export.json").write_text(json.dumps({"mesh_groups":n,"source_meshes":len(report),"source_triangles":sum(row["triangles"] for row in report),"limits":"Material/pivot grouping only; triangle count and imported hierarchy require verification."},indent=2))
    if spec.get("lod"):
        lod = export_lod(objects,spec["lod"],out/"model_lod.glb")
        (out/"lod_report.json").write_text(json.dumps(lod,indent=2),encoding="utf-8")
    resolution = int(spec.get("review_resolution",768))
    if not 128<=resolution<=2048:
        raise ValueError("review_resolution must be 128..2048")
    render_views(objects,out,resolution,spec.get("landmarks", {}),spec.get("review_cameras", {}),spec.get("camera_fits", {}), authoring.get("part_targets", {}) if authoring else {})
    if spec.get("clay_review", False):
        # Render the identical geometry/cameras without palette or emission.
        # Material override is render-only; exported GLB/BLEND stay unchanged.
        clay = out / "clay"
        clay.mkdir()
        view_layer = bpy.context.view_layer
        previous = view_layer.material_override
        neutral = material("Form review neutral", {
            "rgb": [.36, .36, .36], "metallic": 0, "roughness": .65})
        try:
            view_layer.material_override = neutral
            render_views(objects, clay, resolution, spec.get("landmarks", {}),
                         spec.get("review_cameras", {}), spec.get("camera_fits", {}),
                         authoring.get("part_targets", {}) if authoring else {})
        finally:
            view_layer.material_override = previous
        (clay / "review_mode.json").write_text(json.dumps({
            "mode": "neutral_material", "geometry": "same exported model",
            "aesthetic_review": "pending",
            "limitations": "Neutral render is evidence, not automatic approval."
        }, indent=2), encoding="utf-8")
    (out/"complete.json").write_text(json.dumps(dict(format=spec["format"],views=list(VIEWS),
        triangles=sum(row["triangles"] for row in report)),indent=2),encoding="utf-8")


if __name__ == "__main__":
    main()
