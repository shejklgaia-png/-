/* SERA web form → actual Godot 4.7 GL Compatibility WASM.
   No JavaScript meshes, shaders, WebGL canvas or approximated shading. */
(()=>{"use strict";
const $=id=>document.getElementById(id);
const NAMESPACE="SERA_EQUIPMENT_GODOT_V1";
const DEFAULT_CAMERA={yaw:160,pitch:-18,roll:0,zoom:1,panX:0,panY:0,outlinePx:3};
const params={...DEFAULT_CAMERA};
let ready=false,readyResolve,readyReject,seq=0,renderQueue=Promise.resolve();
const pending=new Map();
const open=new Promise((resolve,reject)=>{readyResolve=resolve;readyReject=reject});
let lastRender={mode:"icon",selected:{head:"D",torso:"A",arms:"A",legs:"A",booster:"A",weapon_r:"A",weapon_l:"A"},size:1,keep_aspect:false,editing_slot:"head"};
const MAX_MESSAGE_LENGTH=3_000_000;
const clamp=(x,a,b)=>Math.max(a,Math.min(b,x));
const csrfOrigin=location.origin;
function status(message,failed=false){const el=$("status");if(!el)return;el.textContent=message;el.className=failed?"error":""}
function frame(){
 const iframe=$("godotPreview");
 return iframe?.contentWindow;
}
function post(type,payload={}){
 const windowFrame=frame();
 if(!windowFrame)throw Error("Godot iframe is not mounted");
 windowFrame.postMessage(JSON.stringify({namespace:NAMESPACE,type,...payload}),csrfOrigin);
}
async function engineReady(){
 if(ready)return;
 const timeout=new Promise((_,reject)=>setTimeout(()=>reject(Error("Godotプレビューを起動できませんでした。HTTPS環境とWebGL 2.0を確認してください。")),45000));
 await Promise.race([open,timeout]);
}
function cameraState(){
 return {yaw:params.yaw,pitch:params.pitch,roll:params.roll,zoom:params.zoom,panX:params.panX,panY:params.panY,outlinePx:params.outlinePx};
}
function applyFields(){
 for(const k of Object.keys(DEFAULT_CAMERA)){
  const field=$(k);if(field)field.value=String(params[k]);
  const value=$(k+"Val");
  if(value)value.textContent=k==="zoom"?Math.round(params[k]*100)+"%":k==="outlinePx"?params[k]+"px":k==="yaw"||k==="pitch"||k==="roll"?Math.round(params[k])+"°":Number(params[k]).toFixed(3);
 }
 const border=$("frame");if(border)border.classList.toggle("hidden",!$("showFrame")?.checked);
 updateIconPreset();
}
function updateIconPreset(){
 const target=$("presetText");if(!target||document.activeElement===target)return;
 const source={repository_path:"models/storage/カメラアイ頭部.bbmodel",fingerprint:"e79a33f57e7873f313f1a803488202206d36b8785d4d5bf2951bec316ae90bff",fingerprint_algorithm:"SHA-256",name:"カメラアイ頭部",element_count:6};
 const preset={format:"SERA_ICON_PRESET_V1",version:1,source,
  equipment:{blueprint_id:"H02",slot:lastRender.editing_slot,rig_set:String(lastRender.selected[lastRender.editing_slot]||"A")},
  render:{engine:"SERA Godot 4.7 GL Compatibility",camera:"orthographic_front",
    model_rotation_deg:{x:params.pitch,y:params.yaw,z:params.roll},
    model_scale:params.zoom,pan_clip:{x:params.panX,y:params.panY},
    auto_fit:0.76,outline:{enabled:params.outlinePx>0,stroke_px_at_512:params.outlinePx,
      crease_degrees:80,color:"#17212F"},
    image:{width:512,height:512,background:"transparent",ui_frame_baked:false}},
  note:"SERA actual Godot SeraRig / Equipment / ViewEdges. New classifications and effects require ChatGPT approval."};
 target.value="SERA_ICON_PRESET_V1\n"+JSON.stringify(preset,null,2);
}
function response(seqExpected,type){
 return new Promise((resolve,reject)=>{
  const timer=setTimeout(()=>{pending.delete(seqExpected);reject(Error("Godot rendering response timed out ("+type+")"));},18000);
  pending.set(seqExpected,{type,resolve:value=>{clearTimeout(timer);resolve(value)},reject});
 });
}
function runSerialized(data){
 // Prevent an out-of-order camera/mesh change from invalidating a PNG frame.
 const work=renderQueue.then(async()=>{
  await engineReady();
  const id=++seq;
  const wait=response(id,"SERA_PREVIEW_RENDERED");
  post("SET",{...data,seq:id,camera:cameraState()});
  await wait;
 });
 renderQueue=work.catch(e=>{status(e.message,true)});
 return work;
}
async function render(mode,selected={},size=1,keep_aspect=false,editing_slot=null){
 lastRender={mode,selected:{...selected},size:Number(size)||1,keep_aspect:!!keep_aspect,
   editing_slot:editing_slot||window.SERA_INTAKE_ACTIVE_SLOT||"head"};
 return runSerialized(lastRender);
}
async function snapshot(){
 await renderQueue;
 await engineReady();
 const id=++seq,wait=response(id,"SERA_PREVIEW_SNAPSHOT");
 post("SNAPSHOT",{seq:id});
 const payload=await wait;
 if(!payload.data_uri?.startsWith("data:image/png;base64,"))throw Error("Godot PNG capture failed");
 return payload.data_uri;
}
function cameraUpdate(){
 // Keep appearance consistent with both the standalone portrait and NEXUS.
 runSerialized(lastRender).catch(e=>status(e.message,true));
 applyFields();
}
function parsePreset(text){
 const start=text.indexOf("{");
 if(start<0)throw Error("JSON形式のアイコン設定が見つかりません");
 const p=JSON.parse(text.slice(start));
 if(p.format!=="SERA_ICON_PRESET_V1")throw Error("アイコン設定の形式が違います");
 const r=p.render||{},angles=r.model_rotation_deg||{},pan=r.pan_clip||{};
 return {yaw:angles.y,pitch:angles.x,roll:angles.z,zoom:r.model_scale,panX:pan.x,panY:pan.y,
   outlinePx:r.outline?.stroke_px_at_512};
}
function initPreset(){
 for(const key of Object.keys(DEFAULT_CAMERA)){
  const input=$(key);if(!input)continue;
  input.addEventListener("input",()=>{const n=Number(input.value);if(Number.isFinite(n)){params[key]=n;cameraUpdate()}});
 }
 $("showFrame")?.addEventListener("change",applyFields);
 $("reset")?.addEventListener("click",()=>{Object.assign(params,DEFAULT_CAMERA);post("RESET_CAMERA");applyFields()});
 $("copy")?.addEventListener("click",async()=>{updateIconPreset();const txt=$("presetText").value;
  try{await navigator.clipboard.writeText(txt);status("アイコン設定をコピーしました")}catch{$("presetText").select();status("設定を選択しました。手動でコピーしてください。")}
 });
 $("applyPreset")?.addEventListener("click",()=>{try{
  Object.assign(params,parsePreset($("presetText").value));applyFields();cameraUpdate();status("Godot撮影設定を適用しました");
 }catch(e){status("設定を読み込めません: "+e.message,true)}});
 const storageKey="SERA_GODOT_ICON_PRESETS_V1";
 function storage(){try{return JSON.parse(localStorage.getItem(storageKey)||"{}")}catch{return {}}}
 function updateList(){const picker=$("saved");if(!picker)return;picker.replaceChildren(new Option("設定を選択",""));
  for(const key of Object.keys(storage()))picker.add(new Option(key,key));
 }
 $("savePreset")?.addEventListener("click",()=>{updateIconPreset();const all=storage(),key="GODOT "+new Date().toLocaleString("ja-JP");all[key]=$("presetText").value;
  try{localStorage.setItem(storageKey,JSON.stringify(all));updateList();$("saved").value=key;status("この端末に保存しました");}catch(e){status("保存失敗: "+e.message,true)}
 });
 $("loadSaved")?.addEventListener("click",()=>{const chosen=storage()[$("saved").value];if(chosen){$("presetText").value=chosen;$("applyPreset").click()}});
 $("exportPreset")?.addEventListener("click",()=>{updateIconPreset();const url=URL.createObjectURL(new Blob([$("presetText").value],{type:"application/json"}));
  const a=document.createElement("a");a.href=url;a.download="SERA_GODOT_ICON_PRESET.json";a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
 });
 $("downloadPng")?.addEventListener("click",async()=>{try{
  const dataUri=await snapshot();const a=document.createElement("a");
  a.href=dataUri;a.download="SERA_GODOT_"+(lastRender.selected[lastRender.editing_slot]||"A")+"_512.png";a.click();
  status("GodotからPNG画像を取得しました");
 }catch(e){status("PNG保存失敗："+e.message,true)}});
 updateList();applyFields();
}
window.addEventListener("message",event=>{
 if(event.origin!==csrfOrigin||event.source!==frame())return;
 if(typeof event.data!=="string"||event.data.length>MAX_MESSAGE_LENGTH)return;
 let data;try{data=JSON.parse(event.data)}catch{return}
 if(!data||typeof data.type!=="string")return;
 switch(data.type){
  case "SERA_PREVIEW_READY":
   if(!ready){ready=true;readyResolve();}
   status("Godot GL Compatibility / 実装済のSeraRigとゲーム内素材で描画中");
   break;
  case "SERA_PREVIEW_RENDERED":
  case "SERA_PREVIEW_SNAPSHOT": {
    const result=pending.get(data.seq);
    if(result&&result.type===data.type){pending.delete(data.seq);result.resolve(data)}
    break;
  }
  case "SERA_PREVIEW_CAMERA":
   for(const [key,value] of Object.entries(data.camera||{})){
    if(Object.prototype.hasOwnProperty.call(DEFAULT_CAMERA,key)&&Number.isFinite(value))params[key]=value;
   }
   applyFields();
   break;
  case "SERA_PREVIEW_ERROR":
   status("Godotエラー: "+String(data.message||"unknown"),true);
   {const result=pending.get(data.seq);if(result){pending.delete(data.seq);result.reject(Error(data.message))}}
   break;
 }
});
window.SERA_INTAKE_RENDER={render,snapshot,camera:cameraState,previewKind:()=>lastRender.mode,ready:engineReady};
window.addEventListener("DOMContentLoaded",initPreset);
})();
