"""Offline rigid-node animation authoring. Blender 4.5 LTS only."""
import argparse, json, math, sys
from pathlib import Path
import bpy
from mathutils import Vector

def main():
    p=argparse.ArgumentParser()
    p.add_argument("design",type=Path); p.add_argument("out",type=Path)
    a=p.parse_args(sys.argv[sys.argv.index("--")+1:])
    d=json.loads(a.design.read_text()); out=a.out.resolve()
    if d["format"]!="SERA_MOTION_LAB_V1": raise ValueError("format")
    fps=int(d.get("fps",60)); end=int(d["end_frame"])
    if fps not in (30,60) or not 2<=end<=601: raise ValueError("fps/frame limit")
    out.mkdir(parents=True,exist_ok=False)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene
    scene.render.fps=fps; scene.frame_start=1; scene.frame_end=end
    nodes={}
    if d.get("source_glb"):
        src=(a.design.parent/d["source_glb"]).resolve()
        if src.suffix.lower()!=".glb": raise ValueError("GLB only")
        bpy.ops.import_scene.gltf(filepath=str(src))
        nodes={o.name:o for o in scene.objects}
        if any(o.type=="ARMATURE" for o in nodes.values()):
            raise ValueError("V1 rigid object rig only; armature is not supported")
        if any(o.animation_data and (o.animation_data.action or o.animation_data.nla_tracks) for o in nodes.values()):
            raise ValueError("Use an unanimated source GLB")
    else:
        # Standalone procedural authoring example; never a production SERA model.
        for part in d["parts"]:
            name=part["id"]
            if name in nodes: raise ValueError("duplicate node")
            if part.get("size"):
                bpy.ops.mesh.primitive_cube_add()
                o=bpy.context.object; o.dimensions=part["size"]
                bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
                mat=bpy.data.materials.new(name); mat.diffuse_color=(*part.get("rgb",[.3,.5,.7]),1); o.data.materials.append(mat)
                bevel=o.modifiers.new("Edge relief","BEVEL"); bevel.width=.025; bevel.segments=2
            else:
                o=bpy.data.objects.new(name,None); scene.collection.objects.link(o)
            o.name=name; nodes[name]=o
            if part.get("parent"): o.parent=nodes[part["parent"]]
            o.location=part.get("location",[0,0,0])
    for name,channels in d["tracks"].items():
        o=nodes[name]; o.rotation_mode="XYZ"
        for prop,keys in channels.items():
            if prop not in ("location","rotation_deg"): raise ValueError("unsupported channel")
            if not keys or keys[0]["frame"]!=1 or keys[-1]["frame"]!=end: raise ValueError("explicit endpoints required")
            last=0
            for k in keys:
                f=int(k["frame"]); v=k["value"]
                if f<=last or f>end or len(v)!=3 or not all(math.isfinite(x) for x in v): raise ValueError("invalid key")
                last=f
                path="location" if prop=="location" else "rotation_euler"
                setattr(o,path,v if prop=="location" else [math.radians(x) for x in v])
                o.keyframe_insert(data_path=path,frame=f,group=name)
        action=o.animation_data.action
        # Blender 4.5 layered actions: access the object's channel bag.
        for layer in action.layers:
            for strip in layer.strips:
                bag=strip.channelbag(o.animation_data.action_slot)
                if bag:
                    for fc in bag.fcurves:
                        for kp in fc.keyframe_points:
                            kp.interpolation="BEZIER"
                            kp.handle_left_type="AUTO_CLAMPED"; kp.handle_right_type="AUTO_CLAMPED"
    # Evaluate every authored frame, not just key poses. Contacts use world positions.
    samples=[]; contacts=[]
    for f in range(1,end+1):
        scene.frame_set(f); bpy.context.view_layer.update()
        points={}
        for name,point in d.get("markers",{}).items():
            v=nodes[point["node"]].matrix_world @ Vector(point.get("local",[0,0,0]))
            points[name]=list(v)
        samples.append({"frame":f,"markers":points})
    for c in d.get("contacts",[]):
        first,last=c["frames"]; name=c["marker"]
        if not 1<=first<=last<=end: raise ValueError("contact interval")
        values=[]
        for s in samples[first-1:last]:
            target=Vector(s["markers"][c["target_marker"]]) if "target_marker" in c else Vector(c["target"])
            values.append((Vector(s["markers"][name])-target).length)
        contacts.append({"marker":name,"frames":[first,last],"max_error_m":max(values),"mean_error_m":sum(values)/len(values),"tolerance_m":c.get("tolerance_m",.01),"within_tolerance":max(values)<=c.get("tolerance_m",.01)})
    (out/"motion_report.json").write_text(json.dumps({"fps":fps,"end_frame":end,"samples":samples,"contacts":contacts,"limitations":["contact markers only; no full collision or IK solve","visual quality not auto-approved"]},indent=2))
    scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(out/"motion.blend"))
    bpy.ops.export_scene.gltf(filepath=str(out/"motion.glb"),export_format="GLB",export_animations=True,export_animation_mode="SCENE",export_frame_range=True,export_force_sampling=True)
    # Render actual animated geometry, using fixed framing for all samples.
    center=Vector(d["review"]["target"]); scale=float(d["review"]["scale"])
    scene.render.engine="BLENDER_WORKBENCH"
    scene.display.shading.light="STUDIO"; scene.display.shading.color_type="MATERIAL"
    scene.display.shading.show_shadows=True; scene.display.shading.show_cavity=True
    scene.display.shading.background_type="WORLD"
    scene.world=bpy.data.worlds.new("ReviewWorld"); scene.world.color=(.12,.12,.12)
    scene.render.resolution_x=640; scene.render.resolution_y=640; scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"
    camera_data=bpy.data.cameras.new("ReviewCamera"); camera_data.type="ORTHO"; camera_data.ortho_scale=scale
    camera=bpy.data.objects.new("ReviewCamera",camera_data); scene.collection.objects.link(camera); scene.camera=camera
    for name,offset in {"front":(0,-8,0),"side":(8,0,0),"three_quarter":(6,-8,5)}.items():
        camera.location=center+Vector(offset); camera.rotation_euler=(center-camera.location).to_track_quat("-Z","Y").to_euler()
        for f in sorted(set([1,end]+list(range(1,end+1,max(1,(end-1)//8))))):
            scene.frame_set(f); scene.render.filepath=str(out/f"{name}_{f:04}.png")
            bpy.ops.render.render(write_still=True)
    (out/"blender_complete.json").write_text(json.dumps({"source":str(a.design.name),"frames":end,"fps":fps}))
if __name__=="__main__": main()
