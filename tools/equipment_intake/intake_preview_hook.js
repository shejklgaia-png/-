/* Injected inside Icon Studio's renderer closure. Reuses its real Blockbench
   textured mesh parser and its exact camera gesture code. This mobile preview
   remains advisory: Godot native GL is authoritative for published portraits. */
let intakePreviewKind="icon",intakeOriginal=null,intakeDocumentCache={};
function intakeDoc(name){
 if(intakeDocumentCache[name])return intakeDocumentCache[name];
 const node=document.getElementById("intake-model-packs");
 const packs=JSON.parse(node.textContent);
 intakeDocumentCache[name]=JSON.parse(decodeBase64UTF8(packs[name]));
 return intakeDocumentCache[name];
}
function intakeSlot(path){
 const p=path.map(x=>String(x).replace(/[0-9]+$/g,"").toLowerCase());
 if(p.some(x=>x.includes("booster")||x.includes("thruster")))return "booster";
 if(p.some(x=>x.includes("katana")||x==="sword"||x==="sword2"))return "weapon_r";
 if(p.some(x=>x.includes("shield")))return "weapon_l";
 if(p.some(x=>x==="head"))return "head";
 if(p.some(x=>/shoulder|upperarm|forearm|hand/.test(x)))return "arms";
 if(p.some(x=>/thigh|lowerleg|foot/.test(x)))return "legs";
 if(p.length<=1)return "legs";
 return "torso";
}
function intakeWalk(doc,onMesh){
 const em=new Map(doc.elements.map(x=>[x.uuid,x])),gm=new Map((doc.groups||[]).map(x=>[x.uuid,x]));
 const walk=(items,path=[])=>{for(const t of items||[]){if(typeof t==="string"){const e=em.get(t);if(e)onMesh(e,path);continue}if(t&&typeof t==="object"){const g=gm.get(t.uuid)||t;walk(t.children||[],path.concat([g.name||""]))}}};
 walk(doc.outliner||[]);return em;
}
function intakeBounds(meshes){
 const a=[Infinity,Infinity,Infinity],b=[-Infinity,-Infinity,-Infinity];
 for(const e of meshes)for(const v of Object.values(e.vertices||{})){const o=e.origin||[0,0,0],q=rotatePoint(v,(e.rotation||[0,0,0]).map(Number)).map((x,i)=>x+o[i]);for(let i=0;i<3;i++){a[i]=Math.min(a[i],q[i]);b[i]=Math.max(b[i],q[i])}}
 return {lo:a,hi:b,center:a.map((v,i)=>(v+b[i])/2),size:a.map((v,i)=>Math.max(.00001,b[i]-v))};
}
function intakeExternal(doc,packName,select,reference,scale,keepAspect){
 const external=intakeDoc(packName),picked=[];
 intakeWalk(external,(e,path)=>{if(!select||select(e,path))picked.push(e)});
 if(!picked.length)return;
 const sourceBounds=intakeBounds(picked),refBounds=intakeBounds(reference);
 const ax=refBounds.size.map((v,i)=>v/sourceBounds.size[i]);
 const uniform=Math.min(...ax.filter(x=>x>0));
 const resolutions=[doc.resolution||{width:16,height:16},external.resolution||{width:16,height:16}];
 const uvScale=[Number(resolutions[0].width||16)/Number(resolutions[1].width||16),Number(resolutions[0].height||16)/Number(resolutions[1].height||16)];
 const textureOffset=(doc.textures||[]).length;
 doc.textures.push(...(external.textures||[]).map(x=>structuredClone(x)));
 let count=0;
 for(const src of picked){
  const item=structuredClone(src),oldOrigin=item.origin||[0,0,0],oldRotation=item.rotation||[0,0,0];
  item.uuid="intake_"+packName+"_"+count++;item.origin=[0,0,0];item.rotation=[0,0,0];item.visibility=true;item.export=true;
  for(const [key,vertex] of Object.entries(item.vertices||{})){
   let q=rotatePoint(vertex,oldRotation).map((v,i)=>v+Number(oldOrigin[i]||0));
   item.vertices[key]=q.map((v,i)=>refBounds.center[i]+(v-sourceBounds.center[i])*(keepAspect?uniform:ax[i])*scale);
  }
  for(const face of Object.values(item.faces||{})){
   if(face.texture!==null&&face.texture!==undefined)face.texture=Number(face.texture||0)+textureOffset;
   if(face.uv)for(const [k,uv] of Object.entries(face.uv))face.uv[k]=[uv[0]*uvScale[0],uv[1]*uvScale[1]];
  }
  doc.elements.push(item);doc.outliner.push(item.uuid);
 }
}
function intakeComposedDoc(selection,scale,keepAspect){
 const base=intakeDoc("equipment"),document3d=structuredClone(base),selectedMeshes=[];
 const reference={};
 intakeWalk(base,(e,path)=>{
  const root=(path[0]||"");const set=root==="Waist2"?"B":"A",slot=intakeSlot(path);
  if(set==="A"){(reference[slot]||(reference[slot]=[])).push(e)}
  let requested=selection[slot]||"A";
  if(slot==="booster"&&requested==="B")requested="A";
  if(slot==="head"&&["C","D"].includes(requested))return;
  if(slot==="legs"&&["C","D"].includes(requested))return;
  if(slot==="weapon_r"&&requested==="K")return;
  if(slot==="weapon_l"&&selection.weapon_r==="K")return;
  if(root.startsWith("Waist")&&requested===set)selectedMeshes.push(e);
 });
 document3d.elements=selectedMeshes.map(e=>{const x=structuredClone(e);x.visibility=true;x.export=true;return x});
 document3d.outliner=document3d.elements.map(x=>x.uuid);
 document3d.groups=[];
 if(selection.head==="D")intakeExternal(document3d,"head_d",null,reference.head,scale,keepAspect);
 if(selection.head==="C")intakeExternal(document3d,"head_c",null,reference.head,scale,keepAspect);
 if(selection.legs==="D")intakeExternal(document3d,"legs_d",null,reference.legs,1,true);
 if(selection.legs==="C")intakeExternal(document3d,"bird_leg",(e,path)=>path.some(x=>/bird_/i.test(x)),reference.legs,1,true);
 if(selection.weapon_r==="K")intakeExternal(document3d,"katana",(e,path)=>path.some(x=>/katana_/i.test(x)),reference.weapon_r,1,true);
 return document3d;
}
async function intakeRender(kind,selected={},scale=1,keepAspect=true){
 if(!gl||!model)return;
 if(!intakeOriginal)intakeOriginal=model;
 try{
  const doc=kind==="body"?intakeComposedDoc(selected,scale,keepAspect):intakeOriginal;
  parseModel(doc);await uploadTexture(doc);uploadGeometry();
  intakePreviewKind=kind;
  $('modelTitle').textContent=kind==="body"?"装備A基準・全身換装プレビュー":(intakeOriginal.name||"原本モデル");
  $('downloadPng').disabled=kind==="body";
  schedule();say(kind==="body"?"全身3D構成を表示。Godotネイティブと描画差があるため撮影確定はICONタブで行ってください。":"原本のアイコン撮影モード");
 }catch(e){say("換装プレビューの構成エラー："+e.message,true);console.error(e)}
}
window.SERA_INTAKE_RENDER={render:intakeRender,previewKind:()=>intakePreviewKind};
