"""Offline textured review viewer; reuse the existing Modeling Studio WebGL controls.
Supports opaque, embedded PNG/JPEG base color with float TEXCOORD_0.
Unsupported data falls back to actual painted renders, not a fake textured model.
"""
import argparse
import base64
import json
import sys
from pathlib import Path
from factory import digest, glb, read, state, verify, write

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "modeling_studio"))
from offline_viewer import HEAD, SCRIPT, VIEWS

def replace_once(text, old, new):
    if text.count(old) != 1:
        raise ValueError("viewer upstream changed: " + old[:80])
    return text.replace(old, new, 1)

def script():
    s = SCRIPT
    patches = [
        ("function init(){", "async function init(){"),
        ("let low=[Infinity", """const texCache=new Map();
async function loadTexture(info){
  if(!info)return null;
  if((info.texCoord||0)!==0||info.extensions)throw Error('unsupported UV transform');
  if(texCache.has(info.index))return texCache.get(info.index);
  const t=g.textures[info.index],im=g.images[t.source],v=g.bufferViews[im.bufferView];
  if(!v||v.buffer!==0||!['image/png','image/jpeg'].includes(im.mimeType))throw Error('unsupported image');
  const start=v.byteOffset||0, bmp=await createImageBitmap(new Blob([bin.subarray(start,start+v.byteLength)],{type:im.mimeType}),{colorSpaceConversion:'none'});
  const tex=gl.createTexture();gl.bindTexture(gl.TEXTURE_2D,tex);
  gl.texImage2D(gl.TEXTURE_2D,0,gl.SRGB8_ALPHA8,gl.RGBA,gl.UNSIGNED_BYTE,bmp);bmp.close();
  const sp=(g.samplers||[])[t.sampler]||{};
  gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,sp.wrapS||10497);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,sp.wrapT||10497);
  gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,sp.minFilter||9987);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,sp.magFilter||9729);gl.generateMipmap(gl.TEXTURE_2D);
  texCache.set(info.index,tex);return tex;
}
let low=[Infinity"""),
        ("items.push({i,p:buffer", """let info=(mat.pbrMetallicRoughness||{}).baseColorTexture;
if(mat.alphaMode&&mat.alphaMode!=='OPAQUE')throw Error('unsupported alpha');
if(info&&p.attributes.TEXCOORD_0===undefined)throw Error('missing UV');
let uv=info?access(p.attributes.TEXCOORD_0,2):new Float32Array(pos.length/3*2),tex=await loadTexture(info);
items.push({uv:buffer(uv,gl.ARRAY_BUFFER),tex,i,p:buffer"""),
        ("in vec3 p;in vec3 n;uniform", "in vec3 p;in vec3 n;in vec2 uv;out vec2 UV;uniform"),
        ("void main(){vec3 v=", "void main(){UV=uv;vec3 v="),
        ("in vec3 N;uniform vec3 color,em;", "in vec3 N;in vec2 UV;uniform sampler2D albedo;uniform bool textured;uniform vec3 color,em;"),
        ("color*l+em", "color*(textured?texture(albedo,UV).rgb:vec3(1.))*l+em"),
        ("b=gl.getAttribLocation(program,'n');", "b=gl.getAttribLocation(program,'n'),uv=gl.getAttribLocation(program,'uv');gl.enableVertexAttribArray(uv);"),
        ("for(let t of items){gl.uniformMatrix4fv", "for(let t of items){gl.bindBuffer(gl.ARRAY_BUFFER,t.uv);gl.vertexAttribPointer(uv,2,gl.FLOAT,false,0,0);gl.activeTexture(gl.TEXTURE0);gl.bindTexture(gl.TEXTURE_2D,t.tex);gl.uniform1i(u('albedo'),0);gl.uniform1i(u('textured'),t.tex?1:0);gl.uniformMatrix4fv"),
        ("try{init();sync()}catch(e)", "(async()=>{try{await init();sync()}catch(e)"),
        ("requestAnimationFrame(frame);</script>", "requestAnimationFrame(frame);})();</script>"),
    ]
    # Texture initialization is asynchronous. Block user events until complete.
    s=replace_once(s,"let yaw=45","let ready=false;let yaw=45")
    s=replace_once(s,"function draw(){","function draw(){if(!ready)return;")
    for old,new in patches:
        s=replace_once(s,old,new)
    s=replace_once(s,"$('toggle').disabled=true}draw();","$('toggle').disabled=true}ready=true;draw();")
    s=replace_once(s,"'実GLB / '","'実GLB / base color / '")
    return s

def build(work, out):
    d=state(work); valid,_=verify(work,d)
    if "review" not in valid:
        raise ValueError("painted review required")
    if out.exists():
        raise ValueError("output must not exist")
    paint=work/"objects"/d["stages"]["paint"]["key"]
    review=work/"objects"/d["stages"]["review"]["key"]
    model=paint/"model.glb"; glb(model)
    data={"glb":base64.b64encode(model.read_bytes()).decode(),
          "images":{v:"data:image/png;base64,"+base64.b64encode((review/(v+".png")).read_bytes()).decode() for v in VIEWS},"joints":[]}
    header=HEAD.replace("CRATE / MODEL REVIEW","SERA / PARTS FACTORY").replace("3Dは確認用の簡易照明。","3Dはbase colorテクスチャ＋簡易照明。")
    if d.get("review_mode")=="supervised_self_review":
        header=header.replace("SERA / PARTS FACTORY","SERA / PARTS FACTORY — SELF REVIEW / NOT INDEPENDENT")
        if "SELF REVIEW / NOT INDEPENDENT" not in header:raise ValueError("review mode label missing")
    html=header+json.dumps(data,separators=(",",":"))+script()
    out.mkdir(parents=True)
    (out/"viewer.html").write_text(html,encoding="utf-8")
    write(out/"viewer_review.json",{"painted_glb_sha256":digest(model),"viewer_sha256":digest(out/"viewer.html"),"reviewer":"","texture_display":"pending","touch_controls":"pending"})
    print(out/"viewer.html")

if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("work",type=Path);p.add_argument("out",type=Path)
    a=p.parse_args();build(a.work.resolve(),a.out.resolve())
