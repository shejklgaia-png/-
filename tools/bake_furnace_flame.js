// Offline deterministic authoring generator; not run by Godot.
function bakeFurnace(){
  const W=80,H=88,N=W*H,F=96,C=12,R=8,AW=W*C,AH=H*R;
  const clamp=(v,a=0,b=1)=>Math.max(a,Math.min(b,v));
  const smooth=(a,b,x)=>{const q=clamp((x-a)/(b-a));return q*q*(3-2*q)};
  const lerp=(a,b,t)=>a+(b-a)*t;
  const sources=[9,23,39,55,70], strengths=[.83,1.0,.93,1.08,.77];
  let heat=new Float32Array(N),soot=new Float32Array(N),vx=new Float32Array(N),vy=new Float32Array(N),tmp=new Float32Array(N),back=new Float32Array(N);
  const g=(x,s)=>Math.exp(-x*x/(2*s*s));
  function sample(a,x,y){if(x<0||x>W-1||y<0||y>H-1)return 0;let ix=Math.min(W-2,Math.floor(x)),iy=Math.min(H-2,Math.floor(y)),fx=x-ix,fy=y-iy,i=iy*W+ix;return lerp(lerp(a[i],a[i+1],fx),lerp(a[i+W],a[i+W+1],fx),fy)}
  const vort=[];
  let seed=20261124;
  function rnd(){seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296}
  function advect(a,decay){
    for(let y=0;y<H;y++)for(let x=0;x<W;x++){let i=y*W+x;tmp[i]=sample(a,x-vx[i],y-vy[i])}
    for(let y=0;y<H;y++)for(let x=0;x<W;x++){let i=y*W+x;back[i]=sample(tmp,x+vx[i],y+vy[i])}
    const out=new Float32Array(N);
    for(let y=1;y<H-1;y++)for(let x=1;x<W-1;x++){
      let i=y*W+x,px=clamp(x-vx[i],0,W-1.001),py=clamp(y-vy[i],0,H-1.001),j=Math.floor(py)*W+Math.floor(px);
      let mn=Math.min(a[j],a[j+1],a[j+W],a[j+W+1]),mx=Math.max(a[j],a[j+1],a[j+W],a[j+W+1]);
      let c=clamp(tmp[i]+.45*(a[i]-back[i]),mn,mx);
      let d=(tmp[i-1]+tmp[i+1]+tmp[i-W]+tmp[i+W])*.25;
      out[i]=Math.max(0,lerp(c,d,.035)*decay);
    }return out;
  }
  const palette=[],alpha=[];
  const warm=[[91,18,4],[157,32,5],[205,54,7],[241,81,9],[255,115,14],[255,155,29],[255,190,50],[255,218,91],[255,237,146],[255,249,208],[255,255,239],[34,65,190],[57,129,255],[144,204,255],[218,237,255],[0,0,0]];
  for(let c=0;c<16;c++)for(let a=0;a<16;a++){palette.push(...warm[c]);alpha.push(c===15?0:Math.round(a*255/15))}
  const fields=[];
  for(let step=0;step<180+(F+16)*2;step++){
    for(let j=0;j<sources.length;j++){
      if((step+j*7)%(19+j*3)===0){
        let side=rnd()<.5?-1:1;
        vort.push({x:sources[j]+side*(3.5+rnd()*1.6),y:5+rnd()*5,spin:-side*(.55+rnd()*.65),r:4+rnd()*3,life:0});
      }
    }
    for(let k=vort.length-1;k>=0;k--){let v=vort[k];v.life++;v.y+=.65+.004*v.y;v.x+=.12*Math.sin(v.life*.13+v.spin);v.r+=.033;if(v.y>H+8||v.life>112)vort.splice(k,1)}
    for(let y=0;y<H;y++)for(let x=0;x<W;x++){
      let i=y*W+x,h=y/(H-1),vX=.14*Math.sin(y*.115+step*.021)+.10*Math.sin(x*.18+y*.09-step*.027),vY=.50+.49*smooth(0,.48,h)+.24*clamp(heat[i]);
      let nearest=0;for(let j=0;j<sources.length;j++){let w=g(x-sources[j],4.3+2*h);vY+=w*.24;nearest+=(sources[j]-x)*w*.031*(1-smooth(0,.34,h));}
      vX+=nearest;
      for(const v of vort){let dx=x-v.x,dy=y-v.y,rr=dx*dx+dy*dy;if(rr>v.r*v.r*6)continue;let k=v.spin*Math.exp(-rr/(2*v.r*v.r))/v.r*smooth(0,5,v.life)*(1-smooth(72,112,v.life));vX-=dy*k;vY+=dx*k;}
      vx[i]=clamp(vX,-1.4,1.4);vy[i]=clamp(vY,.11,2.0);
    }
    heat=advect(heat,.982);soot=advect(soot,.987);
    for(let y=1;y<=8;y++)for(let x=1;x<W-1;x++){
      let i=y*W+x;
      for(let j=0;j<sources.length;j++){
        let pulse=.80+.15*Math.sin(step*.127+j*2.17)+.07*Math.sin(step*.211+j*.8);
        let width=2.05+.17*j%0.5+.25*Math.sin(step*.045+j);
        let center=sources[j]+.33*Math.sin(step*.08+j*2.1)*y/8;
        let plume=g(x-center,width*(1+.025*y))*g(y-3.0,3.0)*strengths[j]*pulse;
        heat[i]=Math.max(heat[i],plume*1.28);
        soot[i]=Math.max(soot[i],plume*smooth(1,7,y)*.95);
      }
    }
    for(let y=1;y<H-1;y++)for(let x=1;x<W-1;x++){
      let i=y*W+x,h=y/(H-1);
      // Luminous soot grows after the attached reaction and oxidizes downstream.
      soot[i]=clamp(soot[i]+.028*heat[i]*smooth(.045,.19,h)*(1-smooth(.40,.8,h))-.008*smooth(.45,.95,h)*soot[i],0,1.3);
      heat[i]*=1-.012*smooth(.58,.95,h);
    }
    if(step>=180&&(step-180)%2===0){fields.push({heat:heat.slice(),soot:soot.slice()});}
  }
  const atlas=new Uint8Array(AW*AH);
  function sampleFrame(f,x,y){
    // Crossfade a 16-frame overlap only at the loop tail; frame zero
    // continues the same uninterrupted simulation segment.
    let a=fields[f+16],b=fields[f+16];let blend=0;
    if(f>=F-16){b=fields[f-(F-16)];blend=smooth(0,16,f-(F-16)+1)}
    let i=y*W+x;let ht=lerp(a.heat[i],b.heat[i],blend),st=lerp(a.soot[i],b.soot[i],blend);
    let h=y/(H-1),side=smooth(1,5,x)*smooth(1,5,W-1-x),top=1-smooth(.86,.98,h);
    let warmWeight=smooth(.035,.16,h),blueWeight=1-smooth(.055,.16,h);
    let lum=ht*(.40+.60*Math.sqrt(Math.max(0,st)));
    let aWarm=smooth(.065,.62,lum)*warmWeight;
    let aBlue=smooth(.075,.75,ht)*blueWeight*.90;
    let op=clamp(Math.max(aWarm,aBlue))*side*top*smooth(0,2,y);
    if(op<.033)return 240;
    let col;
    if(aBlue>aWarm*1.22)col=11+Math.round(clamp(ht*0.92)*3);
    else{
      let brightness=clamp(lum*1.18+ht*.11);
      col=Math.round(clamp(brightness*10,0,10));
    }
    return col*16+Math.round(op*15);
  }
  let coverage=[],blue=[],hot=[];
  for(let f=0;f<F;f++){let count=0,bc=0,hc=0;
    for(let y=0;y<H;y++)for(let x=0;x<W;x++){
      let p=sampleFrame(f,x,y),row=Math.floor(f/C)*H+(H-1-y),col=(f%C)*W+x;
      atlas[row*AW+col]=p;
      if(alpha[p]>32)count++;if(p>=176&&p<240&&alpha[p]>32)bc++;if(p>=128&&p<176&&alpha[p]>32)hc++;
    }coverage.push(count/N);blue.push(bc/N);hot.push(hc/N);
  }
  function png(w,h,arr){
    const raw=new Uint8Array((w+1)*h);
    for(let y=0;y<h;y++)raw.set(arr.subarray(y*w,(y+1)*w),y*(w+1)+1);
    const bytes=[0x78,0x01];let bit=0,bits=0;
    function put(v,n){bit|=v<<bits;bits+=n;while(bits>=8){bytes.push(bit&255);bit>>>=8;bits-=8}}
    function rev(v,n){let r=0;while(n--){r=(r<<1)|(v&1);v>>>=1}return r}
    function lit(v){if(v<144)put(rev(48+v,8),8);else if(v<256)put(rev(400+v-144,9),9);else if(v<280)put(rev(v-256,7),7);else put(rev(192+v-280,8),8)}
    const lb=[3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258],le=[0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0],db=[1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577],de=[0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13];
    put(1,1);put(1,2);
    const last=new Int32Array(65536);last.fill(-1);
    const hash=i=>((raw[i]*251+raw[i+1])*251+raw[i+2])&65535;
    for(let i=0;i<raw.length;){
      let n=0,d=0;
      if(i+2<raw.length){let k=hash(i),j=last[k];if(j>=0&&i-j<=32768){while(n<258&&i+n<raw.length&&raw[j+n]===raw[i+n])n++;d=i-j;}last[k]=i;}
      if(n>=4){let l=lb.length-1;while(lb[l]>n)l--;lit(257+l);put(n-lb[l],le[l]);let k=db.length-1;while(db[k]>d)k--;put(rev(k,5),5);put(d-db[k],de[k]);for(let q=1;q<n&&i+q+2<raw.length;q++)last[hash(i+q)]=i+q;i+=n;}
      else{lit(raw[i]);i++}
    }
    lit(256);if(bits)bytes.push(bit&255);
    let a=1,b=0;for(const x of raw){a=(a+x)%65521;b=(b+a)%65521}
    const be=v=>[(v>>>24)&255,(v>>>16)&255,(v>>>8)&255,v&255];bytes.push(...be((b<<16)|a));
    const out=[137,80,78,71,13,10,26,10];
    function chunk(name,data){const tag=[...name].map(x=>x.charCodeAt(0));out.push(...be(data.length),...tag);let crc=0xffffffff;for(const x of tag){crc^=x;for(let i=0;i<8;i++)crc=(crc>>>1)^((crc&1)?0xedb88320:0)}for(const x of data){out.push(x);crc^=x;for(let i=0;i<8;i++)crc=(crc>>>1)^((crc&1)?0xedb88320:0)}out.push(...be((crc^0xffffffff)>>>0))}
    chunk("IHDR",[...be(w),...be(h),8,3,0,0,0]);chunk("PLTE",palette);chunk("tRNS",alpha);chunk("IDAT",bytes);chunk("IEND",[]);return new Uint8Array(out);
  }
  function base64(a){const abc="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";let s="";for(let i=0;i<a.length;i+=3){let n=(a[i]<<16)|((a[i+1]||0)<<8)|(a[i+2]||0);s+=abc[(n>>>18)&63]+abc[(n>>>12)&63]+(i+1<a.length?abc[(n>>>6)&63]:"=")+(i+2<a.length?abc[n&63]:"=")}return s}
  const preview=new Uint8Array(W*H);
  for(let y=0;y<H;y++)preview.set(atlas.subarray(y*AW,y*AW+W),y*W);
  return {base64:base64(png(AW,AH,atlas)),preview:base64(png(W,H,preview)),stats:{width:AW,height:AH,frames:F,coverage:[Math.min(...coverage),Math.max(...coverage)],blue:[Math.min(...blue),Math.max(...blue)],whiteYellow:[Math.min(...hot),Math.max(...hot)]}};
}
const result = bakeFurnace();
if (typeof require !== 'undefined') require('fs').writeFileSync('furnace_flame_atlas.png', Buffer.from(result.base64,'base64'));
