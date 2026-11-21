/* SERA Equipment Intake — no network, never auto-register unapproved values. */
(()=>{"use strict";
const $=id=>document.getElementById(id);
const DB=JSON.parse($("intake-reference-data").textContent);
const SLOT_NAMES={head:"頭部",torso:"胴体",arms:"腕部",legs:"下半身",booster:"ブースター",weapon_r:"右手武器",weapon_l:"左手武器"};
const STAT_NAMES={weight_pct:"重量",hp:"HP",defense:"防御率",en_output_mult:"EN出力",lock_range:"ロック距離",tracking:"追従性能",attack_mult:"攻撃倍率",guard_defense_mult:"ガード防御倍率",guard_speed_mult:"ガード速度",guard_reaction:"ガード反動",run_speed:"歩行速度",boost_speed_mult:"ブースト速度倍率",damage_time_mult:"被弾硬直",damage_push_mult:"ノックバック",down_hits:"ダウン被弾回数",weight_class:"重量区分",run_motion:"移動モーション",boost_speed:"ブースト速度",energy_cost_mult:"EN消費倍率",step_speed_mult:"ステップ速度倍率",step_time_mult:"ステップ時間倍率",melee_boost_speed:"攻撃追尾速度",melee_boost_duration:"攻撃追尾時間",attack_damage:"近接攻撃力",break_damage:"部位破壊力",stagger_gain:"怯み蓄積",attack_energy:"攻撃EN消費",stagger_extend:"怯み延長",guard_cost_mult:"ガードEN消費",guard_transition:"ガード移行時間",bash_damage:"バッシュ攻撃力",bash_break:"バッシュ破壊力",charge_damage:"チャージ攻撃力",charge_break:"チャージ破壊力",charge_guard_mult:"チャージガード",energy_shield:"ENシールド"};
const STAT_KEYS=[...new Set(Object.values(DB.profiles).flatMap(v=>Object.values(v).flatMap(spec=>Object.keys(spec))))].filter(x=>x!=="weight_class");
const materials=[["scrap_low","汎用スクラップ"],["scrap_mid","応用スクラップ"],["scrap_high","高度スクラップ"],["alloy_low","基礎金属複合材"],["alloy_mid","精密金属複合材"],["alloy_high","高次金属複合材"],["electronics_low","汎用電子部品"],["electronics_mid","精密電子部品"],["electronics_high","高度電子部品"],["organic_low","微弱有機素材"],["organic_mid","活性有機素材"],["organic_high","旺盛有機素材"]];
const choices={head:["A","B","C","D"],torso:["A","B"],arms:["A","B"],legs:["A","B","C","D"],booster:["A","B"],weapon_r:["A","B","K"],weapon_l:["A","B"]};
const labels={head:{A:"A 標準頭部",B:"B 重装頭部",C:"C 頭部",D:"D アイリス"},legs:{A:"A 標準脚",B:"B 重量脚",C:"C 鳥脚",D:"D 重量脚"},weapon_r:{A:"A エッジブレード",B:"B ブレード",K:"K カタナ"}};
let activeTab="setup",slot="head",selected=Object.fromEntries(Object.keys(choices).map(x=>[x,"A"])),scaleDelta=0,keepAspect=false;
let statPct={},customClassifications={},materialEntries=[{id:"scrap_low",count:0}],showAll=true;
let radarNear="", thumbnailCache={}, imageCache=new Map(), hiddenVariants=new Set();
const clamp=(x,a,b)=>Math.max(a,Math.min(b,x));
const profile=(s,set)=>DB.profiles[s][set]||DB.profiles[s].A;
const metric=(key,base)=>key==="defense"?((base*100).toFixed(2)+"%"):typeof base==="number"?Number(base.toFixed(4)).toString():String(base);
const percentValue=(key,index)=>{const id=key+(index==null?"":"."+index);return Object.prototype.hasOwnProperty.call(statPct,id)?statPct[id]:100;};
function getDraft(){
 const base=profile(slot,"A"),result={};
 for(const key of Object.keys(base)){
  if(typeof base[key]==="number")result[key]=base[key]*percentValue(key)/100;
  else if(Array.isArray(base[key]))result[key]=base[key].map((v,i)=>v*percentValue(key,i)/100);
  else if(typeof base[key]==="string"||typeof base[key]==="boolean")result[key]=customClassifications[key]??base[key];
 }
 return result;
}
function weightClass(pct){return pct<=70?"light":pct>=140?"heavy":"medium"}
function effectiveWeight(){
 const weights=Object.keys(DB.shares);let mass=0;
 for(const s of weights){if(s==="weapon_l"&&selected.weapon_r==="K")continue;const w=s===slot?getDraft().weight_pct:profile(s,selected[s]).weight_pct||100;mass+=(DB.shares[s]||0)*w}
 return mass;
}
function setTab(name){
 activeTab=name;
 document.querySelectorAll("[data-section]").forEach(n=>n.hidden=n.dataset.section!==name);
 document.querySelectorAll("[data-nav]").forEach(n=>n.classList.toggle("active",n.dataset.nav===name));
 $("intake-controls").hidden=name!=="icon";
 $("intake-picker").hidden=name!=="rig";
 $("rigHint").textContent=name==="rig"?"全身装備を表示（ゲーム本体とは描画差があります）":"原本モデルを表示";
 if(window.SERA_INTAKE_RENDER)window.SERA_INTAKE_RENDER.render(name==="rig"?"body":"icon",selected,scaleMultiplier());
 if(name==="analysis"){drawCharts();warmComparisonThumbnails();}
 if(name==="output")updateOutput();
}
function sizeMultiplier(){
 return scaleDelta>=0?1+scaleDelta/100:1/(1-scaleDelta/100);
}
function renderSize(){
 $("sizeDelta").value=scaleDelta;$("sizeNumber").value=scaleDelta;
 $("sizeEffective").textContent=(sizeMultiplier()*100).toFixed(1)+"%";
 $("sizeAspect").checked=keepAspect;
 window.SERA_INTAKE_RENDER?.render("body",selected,sizeMultiplier(),keepAspect);
}
function numericRow(key,base,index=null){
 const id=key+(index==null?"":"."+index), val=percentValue(key,index),number=base*val/100;
 const box=document.createElement("div");box.className="statrow";
 const name=document.createElement("span");name.textContent=(STAT_NAMES[key]||key)+(index!=null?" "+(index+1)+"段目":"");
 const slide=document.createElement("input");slide.type="range";slide.min=0;slide.max=400;slide.step=1;slide.value=val;
 const numberInput=document.createElement("input");numberInput.type="number";numberInput.min=0;numberInput.max=400;numberInput.step=1;numberInput.value=val;numberInput.className="ratioNumber";numberInput.setAttribute("aria-label",name.textContent+" A比 %");
 const absolute=document.createElement("output");absolute.textContent=metric(key,number);
 function sync(e){const n=clamp(Number(e.target.value)||0,0,400);statPct[id]=n;slide.value=n;numberInput.value=n;absolute.textContent=metric(key,base*n/100);updateWeight();if(activeTab==="analysis")drawCharts();}
 slide.addEventListener("input",sync);numberInput.addEventListener("input",sync);
 box.append(name,slide,numberInput,absolute);return box;
}
function classifyRow(key,base){
 const box=document.createElement("div");box.className="statrow classrow";
 const name=document.createElement("span");name.textContent=STAT_NAMES[key]||key;box.append(name);
 const select=document.createElement("select");
 const current=customClassifications[key]??base;
 const options=Array.from(new Set(Object.values(DB.profiles[slot]).map(o=>o[key]).filter(x=>x!==undefined).concat([base])));
 options.forEach(option=>{const e=document.createElement("option");e.value=String(option);e.textContent=String(option);select.append(e)});
 const customOpt=document.createElement("option");customOpt.value="__other__";customOpt.textContent="新しい分類（要相談）";select.append(customOpt);
 const custom=document.createElement("input");custom.type="text";custom.placeholder="新規分類名（ChatGPTと要相談）";custom.hidden=true;custom.className="wide";
 if(options.some(o=>String(o)===String(current)))select.value=String(current);else{select.value="__other__";custom.hidden=false;custom.value=String(current)}
 select.addEventListener("change",()=>{custom.hidden=select.value!=="__other__";customClassifications[key]=select.value==="__other__"?custom.value:(typeof base==="boolean"?select.value==="true":select.value)});
 custom.addEventListener("input",()=>{customClassifications[key]=custom.value});
 box.append(select,custom);return box;
}
function renderStats(){
 const root=$("statRows");root.replaceChildren();
 const base=DB.profiles[slot].A;
 $("statSlot").textContent=SLOT_NAMES[slot];
 for(const key of STAT_KEYS){
  const value=base[key];
  if(value===undefined){const div=document.createElement("div");div.className="statrow disabled";div.textContent=(STAT_NAMES[key]||key)+"　— 対象外";root.append(div);continue}
  if(typeof value==="number")root.append(numericRow(key,value));
  else if(Array.isArray(value))value.forEach((v,i)=>root.append(numericRow(key,v,i)));
  else root.append(classifyRow(key,value));
 }
 updateWeight();
}
function updateWeight(){
 const draft=getDraft(),weight=Number(draft.weight_pct||100),total=effectiveWeight();
 $("massStatus").textContent="部位 "+weight.toFixed(1)+"% ["+weightClass(weight)+"] ／ 全身 "+total.toFixed(1)+"% ["+weightClass(total)+"]";
}
function renderMaterials(){
 const root=$("materialRows");root.replaceChildren();
 materialEntries.forEach((entry,i)=>{
  const row=document.createElement("div");row.className="materialRow";
  const sel=document.createElement("select");materials.forEach(([id,name])=>{const o=document.createElement("option");o.value=id;o.textContent=name;sel.append(o)});sel.value=entry.id;sel.addEventListener("change",()=>entry.id=sel.value);
  const num=document.createElement("input");num.type="number";num.min=0;num.max=9999;num.value=entry.count;num.addEventListener("input",()=>entry.count=clamp(Math.round(Number(num.value)||0),0,9999));
  const del=document.createElement("button");del.textContent="削除";del.addEventListener("click",()=>{materialEntries.splice(i,1);renderMaterials()});
  row.append(sel,num,del);root.append(row);
 });
}
function chartCanvas(id,fn){
 const can=$(id),width=Math.min(630,Math.max(300,can.parentElement.clientWidth-24));can.width=width*2;can.height=width*2;can.style.width=width+"px";can.style.height=width+"px";const c=can.getContext("2d");c.scale(2,2);fn(c,width);
}
function drawRadar(){
 const base=DB.profiles[slot].A,draft=getDraft();
 const keys=Object.keys(base).filter(k=>typeof base[k]==="number"&&k!=="weight_pct"&&base[k]!==0).slice(0,8);if(keys.length<3){$("nearest").textContent="比較可能な3項目以上の数値が必要です";return}
 let nearest="",score=Infinity;
 for(const [variant,spec] of Object.entries(DB.profiles[slot])){let loss=0;for(const key of keys){const ratio=(draft[key]||0)/(base[key]||1),other=(spec[key]||0)/(base[key]||1);loss+=(ratio-other)**2;}if(loss<score){nearest=variant;score=loss}}
 radarNear=nearest;$("nearest").textContent="最も近い既存パーツ："+SLOT_NAMES[slot]+" "+nearest+"　（性能形状距離 "+Math.sqrt(score).toFixed(3)+"）";
 const image=$("nearestThumb");image.src=thumbnailCache[slot+nearest]||"";image.alt=SLOT_NAMES[slot]+nearest+" 3Dサムネイル";
 chartCanvas("radar", (c,w)=>{
  const cx=w/2,cy=w/2,r=w*.30,n=keys.length; c.fillStyle="#132532";c.fillRect(0,0,w,w);
  for(let ring=1;ring<=4;ring++){c.strokeStyle="#365265";c.beginPath();for(let i=0;i<n;i++){const a=-Math.PI/2+i*2*Math.PI/n;const x=cx+Math.cos(a)*r*ring/4,y=cy+Math.sin(a)*r*ring/4;if(!i)c.moveTo(x,y);else c.lineTo(x,y)}c.closePath();c.stroke()}
  function polygon(spec,color,fill){c.beginPath();keys.forEach((key,i)=>{const a=-Math.PI/2+i*2*Math.PI/n,v=clamp((spec[key]||0)/(base[key]||1),0,2)/2;const x=cx+Math.cos(a)*r*v,y=cy+Math.sin(a)*r*v;if(!i)c.moveTo(x,y);else c.lineTo(x,y)});c.closePath();c.fillStyle=fill;c.fill();c.strokeStyle=color;c.lineWidth=2;c.stroke()}
  polygon(DB.profiles[slot][nearest],"#7999aa","rgba(121,153,170,.10)");polygon(draft,"#92dbef","rgba(93,193,216,.18)");
  keys.forEach((key,i)=>{const a=-Math.PI/2+i*2*Math.PI/n;c.fillStyle="#cfdee4";c.font="11px sans-serif";c.textAlign="center";c.fillText((STAT_NAMES[key]||key).slice(0,8),cx+Math.cos(a)*r*1.17,cy+Math.sin(a)*r*1.17+4)});
 });
}
function drawDistribution(){
 const bx=$("distX").value,by=$("distY").value;
 const base=DB.profiles[slot].A,draft=getDraft();if(!bx||!by)return;
 chartCanvas("distribution",(c,w)=>{
  c.fillStyle="#132532";c.fillRect(0,0,w,w);c.strokeStyle="#2c4757";
  for(let i=0;i<=4;i++){let q=w*.12+i*(w*.76/4);c.beginPath();c.moveTo(q,w*.12);c.lineTo(q,w*.88);c.moveTo(w*.12,q);c.lineTo(w*.88,q);c.stroke()}
  const query=$("distSearch").value.trim().toLowerCase();
 const points=Object.entries(DB.profiles[slot]).map(([key,p])=>({key,p})).filter(x=>(showAll||x.key===selected[slot])&&!hiddenVariants.has(slot+x.key)&&(!query||(labels[slot]?.[x.key]||x.key).toLowerCase().includes(query)));points.push({key:"NEW",p:draft});
  const pos=(v,key)=>clamp((Number(v||0)/Number(base[key]||1)-0)*.36,.0,.76)*w+w*.12;
  for(const {key,p} of points){const x=pos(p[bx],bx),y=w-pos(p[by],by);c.fillStyle=key==="NEW"?"#b0ecf7":"#7398aa";
   const pic=key==="NEW"?null:imageCache.get(slot+key);
   if(pic&&pic.complete&&pic.naturalWidth){c.drawImage(pic,x-16,y-16,32,32);c.strokeStyle="#80b2c4";c.strokeRect(x-16,y-16,32,32)}
   else{c.beginPath();c.arc(x,y,key==="NEW"?8:6,0,Math.PI*2);c.fill()}
   c.font="12px sans-serif";c.textAlign="left";c.fillText(key,x+18,y-13)}

  c.fillStyle="#cbdce7";c.font="12px sans-serif";c.fillText("X: "+(STAT_NAMES[bx]||bx),w*.12,16);c.fillText("Y: "+(STAT_NAMES[by]||by),w*.12,32);
 });
}
function renderDistributionLegend(){
 const root=$("distLegend");root.replaceChildren();
 for(const value of Object.keys(DB.profiles[slot])){
  const name=labels[slot]?.[value]||SLOT_NAMES[slot]+" "+value;
  if($("distSearch").value.trim()&&!name.toLowerCase().includes($("distSearch").value.trim().toLowerCase()))continue;
  const row=document.createElement("label");row.className="distLegendRow";
  const show=document.createElement("input");show.type="checkbox";show.checked=!hiddenVariants.has(slot+value);
  show.addEventListener("change",()=>{if(show.checked)hiddenVariants.delete(slot+value);else hiddenVariants.add(slot+value);drawDistribution()});
  const img=document.createElement("img");img.width=40;img.height=40;img.alt=name;img.src=thumbnailCache[slot+value]||"";
  const txt=document.createElement("span");txt.textContent=name;row.append(show,img,txt);root.append(row);
 }
}
function drawCharts(){renderDistributionLegend();drawRadar();drawDistribution()}
async function warmComparisonThumbnails(){
 if(!window.SERA_INTAKE_RENDER)return;
 const saved={...selected};let updated=false;
 for(const variant of Object.keys(DB.profiles[slot])){
  const key=slot+variant;
  if(thumbnailCache[key])continue;
  await window.SERA_INTAKE_RENDER.render("body",{...saved,[slot]:variant},1,false);
  thumbnailCache[key]=$("glview").toDataURL("image/png");
  const image=new Image();image.src=thumbnailCache[key];
  image.onload=()=>{if(activeTab==="analysis")drawDistribution()};imageCache.set(key,image);
  updated=true;
 }
 await window.SERA_INTAKE_RENDER.render(activeTab==="rig"?"body":"icon",saved,sizeMultiplier(),keepAspect);
 if(updated&&activeTab==="analysis")drawCharts();
}

function updateOutput(){
 const data={format:"SERA_EQUIPMENT_INTAKE_V1",version:1,source:{repository_path:DB.source.path,sha256:DB.source.sha256,base_commit:DB.source.commit},equipment:{blueprint_id:$("blueprint").value.trim(),name:$("equipName").value.trim(),slot,rig_set:$("rigSet").value,rig_selection:{...selected}},model:{size_delta_percent:scaleDelta,effective_scale_percent:sizeMultiplier()*100,keep_aspect:keepAspect,standard:"A slot OBB reference; preview is advisory"},stats:{a_relative_percent:{...statPct},absolute:getDraft(),part_weight_class:weightClass(getDraft().weight_pct||100),whole_weight_pct:effectiveWeight(),whole_weight_class:weightClass(effectiveWeight()),unapproved_classifications:{...customClassifications}},recipe:materialEntries.filter(x=>x.count>0).map(x=>({...x})),special_effects:{description:$("specialEffect").value,approval_required:true,implementation_status:"PENDING_CHATGPT_DISCUSSION"},render_preset_text:$("presetText").value,review_required:true};
 const content="SERA_EQUIPMENT_INTAKE_V1\n"+JSON.stringify(data,null,2);$("exportText").value=content;return content;
}
async function copy(){
 const txt=updateOutput();try{await navigator.clipboard.writeText(txt);$("intakeMessage").textContent="コピーしました。ChatGPTへ貼り付けて送信してください。"}catch{$("exportText").focus();$("exportText").select();$("intakeMessage").textContent="手動で選択中のテキストをコピーしてください。"}
}
function renderPickers(){
 const root=$("partChoices");root.replaceChildren();
 for(const [key,opts] of Object.entries(choices)){
  const wrapper=document.createElement("div");wrapper.className="pickRow";const label=document.createElement("span");label.textContent=SLOT_NAMES[key];
  const picker=document.createElement("details");picker.className="pickDropdown";
  const summary=document.createElement("summary");summary.textContent=(labels[key]?.[selected[key]]||key+" "+selected[key]);picker.append(summary);
  const list=document.createElement("div");list.className="pickerMenu";
  for(const value of opts){
   const btn=document.createElement("button");btn.type="button";const img=document.createElement("img");img.alt="装備プレビュー";img.src=thumbnailCache[key+value]||"";img.width=40;img.height=40;
   const txt=document.createElement("span");txt.textContent=labels[key]?.[value]||key+" "+value;
   btn.append(img,txt);btn.addEventListener("click",async()=>{selected[key]=value;picker.open=false;renderPickers();await window.SERA_INTAKE_RENDER?.render("body",selected,sizeMultiplier(),keepAspect);const src=$("glview").toDataURL("image/png");thumbnailCache[key+value]=src;renderPickers();updateWeight()});list.append(btn)}
  picker.append(list);wrapper.append(label,picker);root.append(wrapper);
  picker.addEventListener("toggle",async()=>{if(!picker.open||activeTab!=="rig")return;
    const saved={...selected};for(const value of opts){const id=key+value;if(thumbnailCache[id])continue;
      await window.SERA_INTAKE_RENDER?.render("body",{...saved,[key]:value},1,true);
      thumbnailCache[id]=$("glview").toDataURL("image/png");
      const image=[...list.querySelectorAll("button img")][opts.indexOf(value)];if(image)image.src=thumbnailCache[id];
    }
    await window.SERA_INTAKE_RENDER?.render("body",saved,sizeMultiplier(),keepAspect);
  });
 }
}
function init(){
 document.querySelectorAll("[data-nav]").forEach(btn=>btn.addEventListener("click",()=>setTab(btn.dataset.nav)));
 $("slot").addEventListener("change",e=>{slot=e.target.value;statPct={};customClassifications={};renderStats();renderPickers()});
 $("rigSet").addEventListener("change",e=>{selected[slot]=e.target.value;renderPickers();updateWeight()});
 $("sizeDelta").addEventListener("input",e=>{scaleDelta=Number(e.target.value);renderSize()});
 $("sizeNumber").addEventListener("input",e=>{scaleDelta=clamp(Number(e.target.value)||0,-300,300);renderSize()});
 $("sizeAspect").addEventListener("change",e=>{keepAspect=e.target.checked;renderSize()});
 $("addMaterial").addEventListener("click",()=>{materialEntries.push({id:"scrap_low",count:0});renderMaterials()});
 $("copyIntake").addEventListener("click",copy);
 $("shareIntake").addEventListener("click",async()=>{const text=updateOutput();try{if(navigator.share)await navigator.share({text,title:"SERA EQUIPMENT INTAKE"});else await copy()}catch{await copy()}});
 $("distAll").addEventListener("change",e=>{showAll=e.target.checked;drawDistribution()});
 for(const s of Object.keys(DB.profiles)){const o=document.createElement("option");o.value=s;o.textContent=SLOT_NAMES[s];$("slot").append(o)}
 for(const [key,name] of Object.entries(STAT_NAMES)){const o1=document.createElement("option");o1.value=key;o1.textContent=name;const o2=o1.cloneNode(true);$("distX").append(o1);$("distY").append(o2)}
 $("distX").value="weight_pct";$("distY").value="defense";
 $("distX").addEventListener("change",drawDistribution);$("distY").addEventListener("change",drawDistribution);
 $("distSearch").addEventListener("input",drawCharts);
 $("slot").value=slot;
 $("rigSet").replaceChildren(...choices[slot].map(x=>{const o=document.createElement("option");o.value=x;o.textContent=x;return o}));
 $("slot").addEventListener("change",()=>{$("rigSet").replaceChildren(...choices[slot].map(x=>{const o=document.createElement("option");o.value=x;o.textContent=x;return o}));$("rigSet").value=selected[slot]});
 renderStats();renderMaterials();renderPickers();renderSize();setTab("setup");
}
window.addEventListener("DOMContentLoaded",init);
})();