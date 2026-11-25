extends RefCounted
## Diagnostic comparison only; no game material or UV mutation.
const TEMPLATE := """<!doctype html><html lang="ja"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Texture Studio | 3D検査</title><style>
*{box-sizing:border-box}body{margin:0;background:#101d28;color:#e6eef4;font:14px system-ui,sans-serif}header,nav,footer{padding:12px}h1{font-size:20px;margin:0 0 5px}p{margin:5px 0}button,select{background:#273e50;color:inherit;border:1px solid #628299;border-radius:7px;padding:9px;margin:2px}#stage{position:relative}canvas{width:100%;height: min(62vh,620px);min-height:240px;display:block;touch-action:none}#labels{display:flex;position:absolute;top:8px;left:0;right:0;pointer-events:none}#labels span{flex:1;text-align:center;text-shadow:0 1px 4px #000}#msg{white-space:pre-wrap;color:#9fd3e9}#atlas{display:flex;gap:12px;flex-wrap:wrap}#atlas img{width: min(40vw,256px);image-rendering:pixelated;background:#172b3c}small{color:#a9bfcc}</style>
<header><h1>TEXTURE STUDIO / 3D検査</h1><p id="name"></p><small>同一視点・正投影・最近傍サンプリング／診断用の非照明表示</small></header><nav><select id="mode"><option value="both">左右比較</option><option value="0">塗装中</option><option value="1">ベイク後</option></select><select id="angle"><option value="iso">斜め</option><option value="front">正面 −Z</option><option value="back">背面 ＋Z</option><option value="left">左 −X</option><option value="right">右 ＋X</option><option value="top">上</option><option value="bottom">下</option></select><button id="reset">リセット</button><button id="wire">三角線 OFF</button><button id="minus">−</button><button id="plus">＋</button></nav><div id="stage"><canvas id="c"></canvas><div id="labels"><span>塗装中</span><span>ベイク後</span></div></div><footer><p id="msg">読込中…</p><p id="diff"></p><small>ドラッグ：回転／Shift＋ドラッグまたは2本指：平行移動／ホイール・ピンチ：拡縮</small><details><summary>元画像とベイク画像</summary><div id="atlas"></div></details></footer>
<script id="payload" type="application/json">__TEXSTA_PAYLOAD__</script><script>
 'use strict';(async()=>{const $=id=>document.getElementById(id),c=$('c'),msg=$('msg');try{const d=JSON.parse($('payload').textContent);$('name').textContent=d.label;const ctx=c.getContext('2d',{alpha:false});let lo=[Infinity,Infinity,Infinity],hi=[-Infinity,-Infinity,-Infinity];const models=await Promise.all(d.models.map(async m=>{if(!m.positions.length||m.positions.length%9||m.uvs.length!==m.positions.length/3*2||!m.uvs.every(Number.isFinite))throw Error('メッシュ配列不整合');for(let i=0;i<m.positions.length;i++){let v=m.positions[i],k=i%3;if(!Number.isFinite(v))throw Error('座標不正');lo[k]=Math.min(lo[k],v);hi[k]=Math.max(hi[k],v)}let im=new Image;im.src='data:image/png;base64,'+m.png;await im.decode();$('atlas').append(im.cloneNode());let t=document.createElement('canvas');t.width=im.width;t.height=im.height;let tc=t.getContext('2d',{willReadFrequently:true});tc.drawImage(im,0,0);return {p:m.positions,uv:m.uvs,tex:tc.getImageData(0,0,t.width,t.height).data,w:t.width,h:t.height}}));if(models.length!==2)throw Error('比較データ不足');let center=lo.map((v,i)=>(v+hi[i])/2),radius=Math.max(.00001,Math.hypot(...hi.map((v,i)=>v-lo[i]))/2);let yaw=.65,pitch=.35,zoom=1,px=0,py=0,wire=false,queued=false;function draw(){queued=false;let ratio=Math.min(1,960/c.clientWidth,720/c.clientHeight),w=Math.max(2,Math.floor(c.clientWidth*ratio/2)*2),h=Math.max(2,Math.floor(c.clientHeight*ratio));if(c.width!==w||c.height!==h){c.width=w;c.height=h}let mode=$('mode').value,ids=mode==='both'?[0,1]:[Number(mode)];$('labels').innerHTML=ids.map(i=>'<span>'+['塗装中','ベイク後'][i]+'</span>').join('');let right=[Math.cos(yaw),0,-Math.sin(yaw)],up=[-Math.sin(yaw)*Math.sin(pitch),Math.cos(pitch),-Math.cos(yaw)*Math.sin(pitch)],f=[Math.sin(yaw)*Math.cos(pitch),Math.sin(pitch),Math.cos(yaw)*Math.cos(pitch)];let frame=ctx.createImageData(w,h),data=frame.data,depth=new Float32Array(w*h);depth.fill(-Infinity);for(let i=0;i<data.length;i+=4){data[i]=31;data[i+1]=48;data[i+2]=64;data[i+3]=255}const dot=(a,b)=>a[0]*b[0]+a[1]*b[1]+a[2]*b[2],edge=(a,b,x,y)=>(b[0]-a[0])*(y-a[1])-(b[1]-a[1])*(x-a[0]);ids.forEach((id,j)=>{let m=models[id],vw=w/ids.length,xoff=j*vw,s=.42*Math.min(vw,h)*zoom/radius,points=[];for(let k=0;k<m.p.length;k+=3){let q=[m.p[k]-center[0],m.p[k+1]-center[1],m.p[k+2]-center[2]];points.push([xoff+vw/2+dot(q,right)*s+px*vw/2,h/2-dot(q,up)*s+py*h/2,dot(q,f)])}for(let k=0;k<points.length;k+=3){let a=points[k],b=points[k+1],c=points[k+2],area=edge(a,b,c[0],c[1]);if(Math.abs(area)<1e-8)continue;let minx=Math.max(xoff,Math.floor(Math.min(a[0],b[0],c[0]))),maxx=Math.min(xoff+vw-1,Math.ceil(Math.max(a[0],b[0],c[0]))),miny=Math.max(0,Math.floor(Math.min(a[1],b[1],c[1]))),maxy=Math.min(h-1,Math.ceil(Math.max(a[1],b[1],c[1])));let lens=[Math.hypot(c[0]-b[0],c[1]-b[1]),Math.hypot(a[0]-c[0],a[1]-c[1]),Math.hypot(b[0]-a[0],b[1]-a[1])];for(let y=miny;y<=maxy;y++)for(let x=minx;x<=maxx;x++){let A=edge(b,c,x+.5,y+.5)/area,B=edge(c,a,x+.5,y+.5)/area,C=1-A-B;if(Math.min(A,B,C)<-1e-7)continue;let i=y*w+x,z=A*a[2]+B*b[2]+C*c[2];if(z<=depth[i])continue;depth[i]=z;let u=A*m.uv[k*2]+B*m.uv[k*2+2]+C*m.uv[k*2+4],v=A*m.uv[k*2+1]+B*m.uv[k*2+3]+C*m.uv[k*2+5],tx=Math.max(0,Math.min(m.w-1,Math.floor(u*m.w))),ty=Math.max(0,Math.min(m.h-1,Math.floor(v*m.h))),t=(ty*m.w+tx)*4;let line=wire&&Math.min(A*Math.abs(area)/Math.max(.001,lens[0]),B*Math.abs(area)/Math.max(.001,lens[1]),C*Math.abs(area)/Math.max(.001,lens[2]))<.8;for(let l=0;l<3;l++)data[i*4+l]=line?[30,52,71][l]:m.tex[t+l]}}});ctx.putImageData(frame,0,0);if(ids.length===2){let diff=0,visible=0;for(let y=0;y<h;y++)for(let x=0;x<w/2;x++){let a=y*w+x,b=a+w/2;if(depth[a]===-Infinity&&depth[b]===-Infinity)continue;visible++;if(data[a*4]!==data[b*4]||data[a*4+1]!==data[b*4+1]||data[a*4+2]!==data[b*4+2])diff++} $('diff').textContent='表示差分：'+diff+' / '+visible+' px（'+(visible?100*diff/visible:0).toFixed(3)+'%）';document.body.dataset.diff=String(diff)}else $('diff').textContent='単独表示';}function schedule(){if(!queued){queued=true;requestAnimationFrame(draw)}}function reset(){yaw=.65;pitch=.35;zoom=1;px=py=0;$('angle').value='iso';schedule()}$('mode').onchange=schedule;$('angle').onchange=()=>{[yaw,pitch]=({iso:[.65,.35],front:[Math.PI,0],back:[0,0],left:[-Math.PI/2,0],right:[Math.PI/2,0],top:[0,Math.PI/2],bottom:[0,-Math.PI/2]})[$('angle').value];schedule()};$('reset').onclick=reset;$('wire').onclick=()=>{wire=!wire;$('wire').textContent='三角線 '+(wire?'ON':'OFF');schedule()};function z(k){zoom=Math.max(.2,Math.min(12,zoom*k));schedule()}$('plus').onclick=()=>z(1.25);$('minus').onclick=()=>z(.8);c.onwheel=e=>{e.preventDefault();z(Math.exp(-e.deltaY*.001))};let pts=new Map();c.onpointerdown=e=>{c.setPointerCapture(e.pointerId);pts.set(e.pointerId,[e.clientX,e.clientY])};c.onpointermove=e=>{if(!pts.has(e.pointerId))return;let old=pts.get(e.pointerId),now=[e.clientX,e.clientY],dx=now[0]-old[0],dy=now[1]-old[1];if(pts.size===1&&!e.shiftKey){yaw-=dx*.01;pitch=Math.max(-Math.PI/2,Math.min(Math.PI/2,pitch+dy*.01));}else{let factor=pts.size===2?.5:1;px+=dx/c.clientWidth*2*factor;py+=dy/c.clientHeight*2*factor;if(pts.size===2){let other=[...pts.entries()].find(([id])=>id!==e.pointerId)[1],dist=v=>Math.hypot(v[0]-other[0],v[1]-other[1]);zoom=Math.max(.2,Math.min(12,zoom*dist(now)/Math.max(1,dist(old))))}}pts.set(e.pointerId,now);schedule()};c.onpointerup=c.onpointercancel=e=>pts.delete(e.pointerId);window.addEventListener('resize',schedule);msg.textContent=models.map((m,i)=>['塗装中','ベイク後'][i]+'：'+m.p.length/9+' 三角形 / '+m.w+'×'+m.h+' px').join('　|　');draw();document.body.dataset.ready='true'}catch(e){msg.textContent='検査表示エラー：'+e.message;document.body.dataset.ready='error'}})();</script></html>"""

static func _model(mesh: ArrayMesh, image: Image) -> Dictionary:
    if mesh == null or image == null or image.is_empty():
        return {}
    var positions: Array[float] = []
    var uvs: Array[float] = []
    for s in range(mesh.get_surface_count()):
        if mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
            return {}
        var arrays: Array = mesh.surface_get_arrays(s)
        var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
        var coords: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
        var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
        var count: int = verts.size() if indices.is_empty() else indices.size()
        if count == 0 or count % 3 != 0 or coords.size() != verts.size():
            return {}
        for i in range(count):
            var index: int = i if indices.is_empty() else indices[i]
            if index < 0 or index >= verts.size():
                return {}
            var p: Vector3 = verts[index]
            var uv: Vector2 = coords[index]
            if not p.is_finite() or not uv.is_finite():
                return {}
            positions.append(p.x)
            positions.append(p.y)
            positions.append(p.z)
            uvs.append(uv.x)
            uvs.append(uv.y)
    var png: PackedByteArray = image.save_png_to_buffer()
    if positions.is_empty() or png.is_empty():
        return {}
    return {"positions":positions,"uvs":uvs,"png":Marshalls.raw_to_base64(png)}

static func write(path: String, label: String, before_mesh: ArrayMesh, before_image: Image, after_mesh: ArrayMesh, after_image: Image) -> Error:
    var before: Dictionary = _model(before_mesh,before_image)
    var after: Dictionary = _model(after_mesh,after_image)
    if before.is_empty() or after.is_empty():
        return ERR_INVALID_DATA
    # Escape opening tags so an authored name cannot close the JSON element.
    var payload: String = JSON.stringify({"label":label,"models":[before,after]},"",true,true).replace("<","\\u003c")
    var file := FileAccess.open(path,FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_string(TEMPLATE.replace("__TEXSTA_PAYLOAD__",payload))
    var err: Error = file.get_error()
    file.close()
    return err
