"""Encode actual Godot frame captures; verify frame count, timestamps and duration."""
from pathlib import Path
from fractions import Fraction
import sys,json,hashlib,subprocess,shutil

def run(*args):
    return subprocess.check_output(args,text=True)

def main(root):
    report=json.loads((root/"motion_report.json").read_text())
    godot=json.loads((root/"godot_review.json").read_text())
    fps=int(report["fps"]); n=int(report["end_frame"])
    folder=root/"movie_frames"
    expected=[folder/f"frame_{i:04d}.png" for i in range(1,n+1)]
    if sorted(folder.glob("*.png"))!=expected or godot.get("movie_frames")!=list(range(1,n+1)):
        raise ValueError("missing, unexpected or noncontiguous rendered frames")
    if not godot.get("movie_capture_pass") or not godot.get("roundtrip_pass"):
        raise ValueError("invalid Godot review")
    timeline={"source":"actual Godot GLB preview, no interpolation or generated frames",
        "authored_fps":fps,"authored_frames":n,"clip_seconds":(n-1)/fps,
        "endpoint_policy":"includes final pose for one frame duration",
        "source_frame_sha256":[hashlib.sha256(p.read_bytes()).hexdigest() for p in expected],
        "events":{name:{"frame":f,"time_seconds":(f-1)/fps,"slow_time_seconds":2*(f-1)/fps} for name,f in report["events"].items()},
        "outputs":{}}
    for name,rate in (("normal",fps),("half_speed",fps//2)):
        path=root/f"motion_{name}.mp4"
        subprocess.run(["ffmpeg","-hide_banner","-loglevel","error","-nostdin","-y",
            "-framerate",str(rate),"-start_number","1","-i",str(folder/"frame_%04d.png"),
            "-frames:v",str(n),"-an","-c:v","libx264","-threads","2","-crf","18",
            "-pix_fmt","yuv420p","-movflags","+faststart",str(path)],check=True)
        data=json.loads(run("ffprobe","-v","error","-select_streams","v:0","-count_frames",
            "-show_streams","-show_frames","-show_entries",
            "stream=codec_name,width,height,avg_frame_rate,nb_read_frames,duration:frame=best_effort_timestamp_time",
            "-of","json",str(path)))
        stream=data["streams"][0]; times=[float(f["best_effort_timestamp_time"]) for f in data["frames"]]
        if (len(times)!=n or int(stream["nb_read_frames"])!=n
            or Fraction(stream["avg_frame_rate"])!=rate
            or abs(float(stream["duration"])-n/rate)>0.001
            or any(abs(t-i/rate)>0.00001 for i,t in enumerate(times))):
            raise ValueError("encoded timing mismatch: "+name)
        timeline["outputs"][name]={"file":path.name,"fps":rate,"frames":n,
            "duration_seconds":float(stream["duration"]),"codec":stream["codec_name"],
            "resolution":[stream["width"],stream["height"]],
            "sha256":hashlib.sha256(path.read_bytes()).hexdigest(),"timing_pass":True}
    (root/"video_report.json").write_text(json.dumps(timeline,indent=2))
    # Keep sparse actual PNGs and lossily encoded videos; drop large full sequence only after verification.
    shutil.rmtree(folder)

if __name__=="__main__": main(Path(sys.argv[1]))
