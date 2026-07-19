'use strict';
/* 火柴人骨架動畫工具 — 純前端單檔，無外部依賴。
   座標系：world = 邏輯像素 0..W / 0..H；主畫布繪製時 setTransform 到顯示尺寸。 */

// ---------- 骨架定義 ----------
const BASE_W = { torso:138, arm:32, leg:42 }; // 各部位基準線寬（world px）；肩(torso)比頭寬，頭才凸得出來

// 預設站姿（W=H=512 基準）；複製此幀當每一幀的起點。frame = {joints:{...}}
const BIND = { joints:{
  head:{x:256,y:101}, neck:{x:256,y:208}, hip:{x:256,y:333},
  shoulderL:{x:228,y:212}, elbowL:{x:214,y:284}, handL:{x:244,y:340},
  shoulderR:{x:284,y:212}, elbowR:{x:326,y:288}, handR:{x:354,y:340},
  hipL:{x:240,y:333}, kneeL:{x:228,y:411}, footL:{x:212,y:478},
  hipR:{x:272,y:333}, kneeR:{x:306,y:407}, footR:{x:328,y:478},
}};
const JOINTS = Object.keys(BIND.joints);

const C_BODY='#2b2f38', C_FRONT='#4aa3e0', C_BACK='#f5a623';
// 圖層：kind=torso/head 固定 z0；limb 可切前(+1)/後(-1)。繪製依 z 升冪、同 z 用此陣列順序 tiebreak
const GROUPS = [
  { id:'legB',  label:'腿 A',   kind:'limb', base:'leg', chain:['hipL','kneeL','footL'],      color:C_BACK,  z:-1 },
  { id:'armB',  label:'手臂 A', kind:'limb', base:'arm', chain:['shoulderL','elbowL','handL'], color:C_BACK,  z:-1 },
  { id:'torso', label:'軀幹',   kind:'torso',base:'torso',                                      color:C_BODY,  z:0  },
  { id:'head',  label:'頭',     kind:'head', base:'torso',                                      color:C_BODY,  z:0  },
  { id:'legF',  label:'腿 B',   kind:'limb', base:'leg', chain:['hipR','kneeR','footR'],       color:C_FRONT, z:1  },
  { id:'armF',  label:'手臂 B', kind:'limb', base:'arm', chain:['shoulderR','elbowR','handR'], color:C_FRONT, z:1  },
];
const GROUP_OF = {}; // joint -> group id（控制點著色用）
GROUPS.forEach(g=>{ if(g.chain) g.chain.forEach(j=>GROUP_OF[j]=g.id); });
GROUP_OF.neck=GROUP_OF.hip='torso'; GROUP_OF.head='head';

// 貼骨模式：每段骨頭一塊 patch（肢分兩段以跟隨彎曲）
const SEGS = [
  { g:'torso', a:'neck', b:'hip' },
  { g:'head',  head:true },
  { g:'armB', a:'shoulderL', b:'elbowL' }, { g:'armB', a:'elbowL', b:'handL' },
  { g:'armF', a:'shoulderR', b:'elbowR' }, { g:'armF', a:'elbowR', b:'handR' },
  { g:'legB', a:'hipL', b:'kneeL' }, { g:'legB', a:'kneeL', b:'footL' },
  { g:'legF', a:'hipR', b:'kneeR' }, { g:'legF', a:'kneeR', b:'footR' },
];

// ---------- 狀態 ----------
const clone = o => JSON.parse(JSON.stringify(o));
const S = {
  W:512, H:512, bg:'#ff00ff', grid:true, onion:true, expGrid:false,
  thickness:1, headR:54, fps:8,
  groups:{}, // id -> {color,z,visible}
  frames:[ clone(BIND) ], current:0,
  ref:{ img:null, name:'', mode:'off', op:0.55, scale:1, x:0, y:0, bound:false, patches:[] },
};
GROUPS.forEach(g=> S.groups[g.id]={ color:g.color, z:g.z, visible:true, opacity:1 });

let selected=null;          // 選中關節名
let dpr=Math.max(1,Math.min(3,window.devicePixelRatio||1));
let drawScale=1, dispSize=512;

// ---------- DOM ----------
const $=id=>document.getElementById(id);
const cv=$('cv'), ctx=cv.getContext('2d');

// ============================================================
//  繪製
// ============================================================
function stroke1(c,a,b,w,col){ c.lineCap='round';c.lineJoin='round';c.lineWidth=w;c.strokeStyle=col;
  c.beginPath();c.moveTo(a.x,a.y);c.lineTo(b.x,b.y);c.stroke(); }
function stroke2(c,p,w,col){ c.lineCap='round';c.lineJoin='round';c.lineWidth=w;c.strokeStyle=col;
  c.beginPath();c.moveTo(p[0].x,p[0].y);c.lineTo(p[1].x,p[1].y);c.lineTo(p[2].x,p[2].y);c.stroke(); }
function circle(c,p,r,col){ c.beginPath();c.arc(p.x,p.y,r,0,Math.PI*2);c.fillStyle=col;c.fill(); }

function widthOf(base){ return BASE_W[base]*S.thickness; }

function drawSkeleton(c, F, opt){
  opt=opt||{};
  const order=[...GROUPS].sort((a,b)=> (S.groups[a.id].z-S.groups[b.id].z));
  for(const g of order){
    const st=S.groups[g.id];
    if(!opt.mono && !st.visible) continue;
    const col=opt.mono || st.color;
    c.globalAlpha = (opt.alpha!=null) ? opt.alpha : (opt.mono ? 1 : (st.opacity!=null?st.opacity:1));
    if(g.kind==='torso'){
      stroke1(c, F.joints.neck, F.joints.hip, widthOf('torso'), col);
    } else if(g.kind==='head'){
      circle(c, F.joints.head, S.headR, col); // 頭直接坐在圓肩上，不畫脖子
    } else {
      const pts=g.chain.map(n=>F.joints[n]);
      stroke2(c, pts, widthOf(g.base), col);
    }
  }
  c.globalAlpha=1;
}

// 貼骨繪製：patch 已在綁定時把 ref 圖切成沿骨的圖塊，這裡依當前姿勢平移/旋轉/伸縮貼回
function drawPuppet(c, F){
  const P=S.ref.patches;
  const segOrder=SEGS.map((s,i)=>({s,i})).sort((A,B)=> S.groups[A.s.g].z-S.groups[B.s.g].z);
  for(const {s,i} of segOrder){
    if(!S.groups[s.g].visible) continue;
    const p=P[i]; if(!p) continue;
    const op=S.groups[s.g].opacity!=null?S.groups[s.g].opacity:1;
    if(s.head){
      c.globalAlpha=op;
      c.drawImage(p.canvas, F.joints.head.x - p.hb/2, F.joints.head.y - p.hb/2);
    } else {
      const A=F.joints[s.a], B=F.joints[s.b];
      const th=Math.atan2(B.y-A.y, B.x-A.x);
      const L=Math.hypot(B.x-A.x, B.y-A.y);
      const su=p.L>0? L/p.L : 1;
      c.save(); c.globalAlpha=op; c.translate(A.x,A.y); c.rotate(th); c.scale(su,1);
      c.drawImage(p.canvas, 0, -p.w/2); c.restore();
    }
  }
  c.globalAlpha=1;
}

function drawGrid(c){
  const W=S.W,H=S.H;
  c.save(); c.lineWidth=1.4;
  c.strokeStyle='rgba(0,229,255,.42)';                       // 外框（青）
  c.strokeRect(0.7,0.7,W-1.4,H-1.4);
  c.strokeStyle='rgba(90,255,150,.5)';                        // 垂直中線（綠）
  c.beginPath();c.moveTo(W/2,0);c.lineTo(W/2,H);c.stroke();
  c.strokeStyle='rgba(255,210,58,.5)';                        // 水平中線（黃）
  c.beginPath();c.moveTo(0,H/2);c.lineTo(W,H/2);c.stroke();
  c.restore();
}

function drawControls(c, F){
  c.globalAlpha=1;
  for(const name of JOINTS){
    const p=F.joints[name], sel=(name===selected);
    const gid=GROUP_OF[name];
    const col= sel ? '#5ac8fa' : (S.groups[gid]? S.groups[gid].color : '#ffffff');
    const r=(sel?8:6)/drawScale;
    c.beginPath(); c.arc(p.x,p.y, r+3/drawScale, 0,Math.PI*2); c.fillStyle='rgba(0,0,0,.5)'; c.fill(); // halo：任何底色都看得見
    c.beginPath(); c.arc(p.x,p.y, r, 0,Math.PI*2); c.fillStyle=col; c.fill();
    c.lineWidth=2/drawScale; c.strokeStyle='#fff'; c.stroke();
  }
}

// 統一畫一幀。o:{grid,ghosts:[{F,color,alpha}],controls,trace,plain}
function drawFrame(c, F, o){
  o=o||{};
  const W=S.W,H=S.H;
  c.fillStyle=S.bg; c.fillRect(0,0,W,H);
  if(o.ghosts) for(const gh of o.ghosts) if(gh.F) drawSkeleton(c, gh.F, {mono:gh.color, alpha:gh.alpha});

  const usePuppet = !o.plain && S.ref.mode==='puppet' && S.ref.bound && S.ref.img;
  if(usePuppet){
    drawPuppet(c, F);
    if($('chkShowRig').checked) drawSkeleton(c, F, {alpha:.32});
  } else {
    drawSkeleton(c, F);
  }
  if(o.trace && S.ref.mode==='trace' && S.ref.img){
    c.globalAlpha=S.ref.op;
    c.drawImage(S.ref.img, S.ref.x, S.ref.y, S.ref.img.width*S.ref.scale, S.ref.img.height*S.ref.scale);
    c.globalAlpha=1;
  }
  if(o.grid) drawGrid(c);
  if(o.controls) drawControls(c, F);
}

function curFrame(){ return S.frames[S.current]; }

function render(){
  ctx.setTransform(dpr*drawScale,0,0,dpr*drawScale,0,0);
  const ghosts=[];
  if(S.onion){
    if(S.frames[S.current-1]) ghosts.push({F:S.frames[S.current-1], color:'#5aa0ff', alpha:.16});
    if(S.frames[S.current+1]) ghosts.push({F:S.frames[S.current+1], color:'#f5a623', alpha:.14});
  }
  drawFrame(ctx, curFrame(), { grid:S.grid, ghosts, controls:true, trace:true });
  $('curFrame').textContent=S.current+1;
  $('totFrame').textContent=S.frames.length;
}

// ============================================================
//  畫布尺寸適配
// ============================================================
function fit(){
  const wrap=cv.parentElement.parentElement; // .stagewrap
  const availW=wrap.clientWidth-36, availH=wrap.clientHeight-36;
  dispSize=Math.max(260, Math.min(availW, availH, 720));
  drawScale=dispSize/S.W;
  cv.style.width=dispSize+'px'; cv.style.height=dispSize+'px';
  cv.width=Math.round(dispSize*dpr); cv.height=Math.round(dispSize*dpr);
  render();
}

// ============================================================
//  互動：拖關節 / 平移
// ============================================================
let drag=null; // {joint} | {pan:true,last:{x,y}}
function evWorld(e){ const r=cv.getBoundingClientRect();
  return { x:(e.clientX-r.left)/drawScale, y:(e.clientY-r.top)/drawScale }; }
function hitJoint(w){
  const R=12/drawScale; let best=null,bd=R;
  const F=curFrame();
  for(const n of JOINTS){ const p=F.joints[n]; const d=Math.hypot(p.x-w.x,p.y-w.y);
    if(d<=bd){ bd=d; best=n; } }
  return best;
}
cv.addEventListener('pointerdown', e=>{
  cv.setPointerCapture(e.pointerId);
  const w=evWorld(e), j=hitJoint(w);
  if(j){ selected=j; drag={joint:j}; }
  else { drag={pan:true,last:w}; }
  render();
});
cv.addEventListener('pointermove', e=>{
  const w=evWorld(e);
  $('posReadout').textContent=`${Math.round(w.x)} , ${Math.round(w.y)}`;
  if(!drag) return;
  const F=curFrame();
  if(drag.joint){
    const p=F.joints[drag.joint];
    p.x=Math.max(-40,Math.min(S.W+40,w.x)); p.y=Math.max(-40,Math.min(S.H+40,w.y));
  } else if(drag.pan){
    const dx=w.x-drag.last.x, dy=w.y-drag.last.y;
    for(const n of JOINTS){ F.joints[n].x+=dx; F.joints[n].y+=dy; }
    drag.last=w;
  }
  render();
});
function endDrag(e){ if(!drag) return; try{cv.releasePointerCapture(e.pointerId);}catch(_){}
  drag=null; refreshThumb(S.current); }
cv.addEventListener('pointerup', endDrag);
cv.addEventListener('pointercancel', endDrag);

document.addEventListener('keydown', e=>{
  if(!selected) return;
  if(/^(INPUT|SELECT|TEXTAREA)$/.test(document.activeElement.tagName)) return;
  const step=e.shiftKey?5:1; let dx=0,dy=0;
  if(e.key==='ArrowLeft')dx=-step; else if(e.key==='ArrowRight')dx=step;
  else if(e.key==='ArrowUp')dy=-step; else if(e.key==='ArrowDown')dy=step; else return;
  e.preventDefault();
  const p=curFrame().joints[selected]; p.x+=dx; p.y+=dy;
  render(); refreshThumb(S.current);
});

// ============================================================
//  時間軸
// ============================================================
const THUMB=62;
let thumbCanvases=[];
function drawThumb(c,F){
  const s=THUMB/S.W;
  c.setTransform(s,0,0,s,0,0);
  drawFrame(c, F, { grid:false, controls:false, plain:true });
}
function refreshThumb(i){ const c=thumbCanvases[i]; if(c) drawThumb(c.getContext('2d'), S.frames[i]); }
function buildTimeline(){
  const box=$('frames'); box.innerHTML=''; thumbCanvases=[];
  S.frames.forEach((F,i)=>{
    const d=document.createElement('div'); d.className='frm'+(i===S.current?' sel':'');
    d.dataset.i=i;
    const cvs=document.createElement('canvas'); cvs.width=THUMB;cvs.height=THUMB;
    cvs.style.width=THUMB+'px';cvs.style.height=THUMB+'px';
    const idx=document.createElement('span'); idx.className='idx'; idx.textContent=i+1;
    const del=document.createElement('button'); del.className='del'; del.textContent='✕'; del.title='刪除此幀';
    del.addEventListener('click', ev=>{ ev.stopPropagation(); delFrame(i); });
    d.append(cvs,idx,del);
    d.addEventListener('click', ()=>{ S.current=i; selected=null; syncSel(); render(); });
    box.appendChild(d);
    thumbCanvases.push(cvs);
    drawThumb(cvs.getContext('2d'), F);
  });
}
function syncSel(){
  [...$('frames').children].forEach((el,i)=> el.classList.toggle('sel', i===S.current));
}
function dupFrame(){
  S.frames.splice(S.current+1, 0, clone(curFrame()));
  S.current++; selected=null; buildTimeline(); render();
}
function addFrame(){
  S.frames.splice(S.current+1, 0, clone(BIND));
  S.current++; selected=null; buildTimeline(); render();
}
function delFrame(i){
  if(S.frames.length<=1) return;
  S.frames.splice(i,1);
  if(S.current>=S.frames.length) S.current=S.frames.length-1;
  else if(i<S.current) S.current--;
  selected=null; buildTimeline(); render();
}
function moveFrame(dir){
  const j=S.current+dir;
  if(j<0||j>=S.frames.length) return;
  [S.frames[S.current],S.frames[j]]=[S.frames[j],S.frames[S.current]];
  S.current=j; buildTimeline(); render();
}

// ---------- 播放 ----------
let playing=false, raf=0, playIdx=0, lastT=0, acc=0;
function play(){
  if(S.frames.length<2) return;
  playing=true; playIdx=S.current; lastT=0; acc=0;
  $('btnPlay').textContent='⏸ 停止'; $('btnPlay').classList.add('on');
  raf=requestAnimationFrame(tick);
}
function stop(){
  playing=false; cancelAnimationFrame(raf);
  $('btnPlay').textContent='▶ 播放'; $('btnPlay').classList.remove('on');
  [...$('frames').children].forEach(el=>el.classList.remove('playing'));
  render();
}
function tick(t){
  if(!playing) return;
  if(!lastT) lastT=t;
  acc+=(t-lastT)/1000; lastT=t;
  const spf=1/S.fps;
  while(acc>=spf){ acc-=spf; playIdx=(playIdx+1)%S.frames.length; }
  ctx.setTransform(dpr*drawScale,0,0,dpr*drawScale,0,0);
  drawFrame(ctx, S.frames[playIdx], { grid:S.grid, controls:false });
  [...$('frames').children].forEach((el,i)=> el.classList.toggle('playing', i===playIdx));
  raf=requestAnimationFrame(tick);
}

// ============================================================
//  圖層面板
// ============================================================
function buildLayers(){
  const box=$('layerList'); box.innerHTML='';
  // 顯示順序：前(z大)在上，較直覺
  const order=[...GROUPS].sort((a,b)=> S.groups[b.id].z-S.groups[a.id].z);
  for(const g of order){
    const st=S.groups[g.id];
    const row=document.createElement('div'); row.className='layer'+(st.visible?'':' hidden');

    const col=document.createElement('input'); col.type='color'; col.value=st.color; col.title='顏色';
    const nm=document.createElement('div'); nm.className='name';
    nm.innerHTML=g.label+(g.kind==='limb'?' <small>'+(st.z>0?'前':'後')+'</small>':'');
    const z=document.createElement('button'); z.className='zbtn';
    const eye=document.createElement('button'); eye.className='eye'; eye.textContent=st.visible?'👁':'🚫'; eye.title='顯示 / 隱藏';

    const op=document.createElement('div'); op.className='op';
    const olbl=document.createElement('span'); olbl.className='olbl'; olbl.textContent='◑'; olbl.title='不透明度';
    const oi=document.createElement('input'); oi.type='range'; oi.min='0.1'; oi.max='1'; oi.step='0.05';
    oi.value=st.opacity!=null?st.opacity:1; oi.style.accentColor=st.color;
    const ov=document.createElement('span'); ov.className='oval'; ov.textContent=Math.round((st.opacity!=null?st.opacity:1)*100)+'%';

    col.addEventListener('input',()=>{ st.color=col.value; oi.style.accentColor=col.value; render(); refreshAllThumbs(); });
    if(g.kind==='limb'){
      z.textContent=st.z>0?'▲ 前':'▼ 後'; z.title='切換前 / 後';
      z.addEventListener('click',()=>{ st.z=-st.z; buildLayers(); render(); refreshAllThumbs(); });
    } else { z.textContent='—'; z.disabled=true; z.style.opacity='.4'; }
    eye.addEventListener('click',()=>{ st.visible=!st.visible; buildLayers(); render(); refreshAllThumbs(); });
    oi.addEventListener('input',()=>{ st.opacity=parseFloat(oi.value); ov.textContent=Math.round(st.opacity*100)+'%';
      render(); refreshAllThumbs(); });

    op.append(olbl,oi,ov);
    row.append(col,nm,z,eye,op);
    box.appendChild(row);
  }
}
function refreshAllThumbs(){ S.frames.forEach((_,i)=>refreshThumb(i)); }

// ============================================================
//  參考圖
// ============================================================
function setRefMode(mode){
  S.ref.mode=mode;
  [...$('refModeSeg').children].forEach(b=> b.classList.toggle('on', b.dataset.mode===mode));
  const hasImg=!!S.ref.img;
  $('refCtrls').style.display=(mode!=='off'&&hasImg)?'block':'none';
  $('puppetBox').style.display=(mode==='puppet')?'block':'none';
  $('traceHint').style.display=(mode==='trace')?'block':'none';
  render();
}
function placeRefDefault(){
  const img=S.ref.img; if(!img) return;
  S.ref.scale=(S.H*0.82)/img.height;
  S.ref.x=(S.W-img.width*S.ref.scale)/2;
  S.ref.y=S.H*0.09;
  syncRefSliders();
}
function syncRefSliders(){
  $('rngRefScale').value=S.ref.scale; $('valRefScale').textContent=S.ref.scale.toFixed(2);
  $('rngRefX').value=S.ref.x; $('rngRefY').value=S.ref.y;
  $('rngRefOp').value=S.ref.op; $('valRefOp').textContent=S.ref.op.toFixed(2).replace(/^0/,'');
}

// 綁定：以「當前幀」為 bind pose，把 ref 圖沿每根骨切成 patch。
// 影像像素(ipx,ipy) → patch 局部(u沿骨,v垂直) 為仿射；用 setTransform 直接 drawImage。
function bindPuppet(){
  if(!S.ref.img){ return; }
  const F=curFrame(), img=S.ref.img, sc=S.ref.scale, rx=S.ref.x, ry=S.ref.y;
  const patches=new Array(SEGS.length).fill(null);
  SEGS.forEach((s,i)=>{
    if(s.head){
      const hb=Math.max(8, Math.ceil(S.headR*2*1.6));
      const cx=F.joints.head.x, cy=F.joints.head.y;
      const cvp=document.createElement('canvas'); cvp.width=hb;cvp.height=hb;
      const pc=cvp.getContext('2d');
      // ipx*sc + rx = cx - hb/2 + u  ⇒  u = sc*ipx + (rx-(cx-hb/2))
      pc.setTransform(sc,0,0,sc, rx-(cx-hb/2), ry-(cy-hb/2));
      pc.drawImage(img,0,0);
      patches[i]={ canvas:cvp, hb };
    } else {
      const A=F.joints[s.a], B=F.joints[s.b];
      const th=Math.atan2(B.y-A.y,B.x-A.x), cos=Math.cos(th), sin=Math.sin(th);
      const L=Math.max(1,Math.round(Math.hypot(B.x-A.x,B.y-A.y)));
      const w=Math.max(2,Math.round(BASE_W[GROUPS.find(g=>g.id===s.g).base]*S.thickness*1.7));
      const cvp=document.createElement('canvas'); cvp.width=L;cvp.height=w;
      const pc=cvp.getContext('2d');
      const dx0=rx-A.x, dy0=ry-A.y;
      // 見檔頭說明：a,d=sc·cos ; c=sc·sin ; b=-sc·sin ; e,f 為平移
      pc.setTransform( sc*cos, -sc*sin, sc*sin, sc*cos,
                       dx0*cos+dy0*sin, -dx0*sin+dy0*cos + w/2 );
      pc.drawImage(img,0,0);
      patches[i]={ canvas:cvp, L, w };
    }
  });
  S.ref.patches=patches; S.ref.bound=true;
  render();
}

// ============================================================
//  匯出 / 存讀
// ============================================================
const EXP=2; // 匯出放大倍率
function renderTo(c, F, withGrid){
  drawFrame(c, F, { grid:withGrid, controls:false }); // 用當前 ref 模式（含 puppet），不畫描圖底/控制點/洋蔥皮
}
function download(blob, name){
  const a=document.createElement('a'); a.href=URL.createObjectURL(blob); a.download=name;
  a.click(); setTimeout(()=>URL.revokeObjectURL(a.href),1000);
}
function exportFrame(){
  const cvs=document.createElement('canvas'); cvs.width=S.W*EXP;cvs.height=S.H*EXP;
  const c=cvs.getContext('2d'); c.setTransform(EXP,0,0,EXP,0,0);
  renderTo(c, curFrame(), S.expGrid);
  cvs.toBlob(b=>download(b, `skeleton_frame${S.current+1}.png`));
}
function exportSheet(){
  const n=S.frames.length;
  const cvs=document.createElement('canvas'); cvs.width=S.W*EXP*n; cvs.height=S.H*EXP;
  const c=cvs.getContext('2d');
  S.frames.forEach((F,i)=>{ c.setTransform(EXP,0,0,EXP, i*S.W*EXP, 0); renderTo(c, F, S.expGrid); });
  cvs.toBlob(b=>download(b, `skeleton_sheet_${n}f.png`));
}
function saveProject(){
  const data={ v:1, W:S.W,H:S.H, bg:S.bg, grid:S.grid, onion:S.onion, expGrid:S.expGrid,
    thickness:S.thickness, headR:S.headR, fps:S.fps, groups:S.groups, frames:S.frames };
  download(new Blob([JSON.stringify(data)],{type:'application/json'}), 'stickman_project.json');
}
function loadProject(file){
  const rd=new FileReader();
  rd.onload=()=>{ try{
    const d=JSON.parse(rd.result);
    if(!d.frames||!d.frames.length) throw new Error('無 frames');
    S.W=d.W||512; S.H=d.H||512; S.bg=d.bg||'#ff00ff';
    S.grid=!!d.grid; S.onion=d.onion!==false; S.expGrid=!!d.expGrid;
    S.thickness=d.thickness||1; S.headR=d.headR||52; S.fps=d.fps||8;
    if(d.groups) for(const id in S.groups) if(d.groups[id]) Object.assign(S.groups[id], d.groups[id]);
    S.frames=d.frames; S.current=0; selected=null;
    S.ref.bound=false;
    syncAllControls(); buildLayers(); buildTimeline(); fit();
  }catch(err){ alert('讀取失敗：'+err.message); } };
  rd.readAsText(file);
}

// 把 state 同步回所有輸入元件
function syncAllControls(){
  $('selSize').value=String(S.W);
  $('inpBg').value=S.bg; $('bgHex').textContent=S.bg;
  $('chkGrid').checked=S.grid; $('chkOnion').checked=S.onion; $('chkExpGrid').checked=S.expGrid;
  $('rngThick').value=S.thickness; $('valThick').textContent=S.thickness.toFixed(2);
  $('rngHead').value=S.headR; $('valHead').textContent=S.headR;
  $('inpFps').value=S.fps;
  const range=S.W;
  $('rngRefX').min=-range;$('rngRefX').max=range;$('rngRefY').min=-range;$('rngRefY').max=range;
  syncRefSliders();
}

function changeSize(newW){
  const sx=newW/S.W;
  S.frames.forEach(F=>{ for(const n in F.joints){ F.joints[n].x*=sx; F.joints[n].y*=sx; } });
  S.headR*=sx; S.ref.x*=sx; S.ref.y*=sx; S.ref.scale*=sx; S.ref.bound=false;
  S.W=newW; S.H=newW;
  syncAllControls(); buildTimeline(); fit();
}

// ============================================================
//  事件接線
// ============================================================
$('selSize').addEventListener('change', e=> changeSize(parseInt(e.target.value,10)));
$('inpBg').addEventListener('input', e=>{ S.bg=e.target.value; $('bgHex').textContent=S.bg; render(); refreshAllThumbs(); });
$('chkGrid').addEventListener('change', e=>{ S.grid=e.target.checked; render(); });
$('chkOnion').addEventListener('change', e=>{ S.onion=e.target.checked; render(); });
$('chkExpGrid').addEventListener('change', e=>{ S.expGrid=e.target.checked; });
$('rngThick').addEventListener('input', e=>{ S.thickness=parseFloat(e.target.value); $('valThick').textContent=S.thickness.toFixed(2);
  S.ref.bound=false; render(); refreshAllThumbs(); });
$('rngHead').addEventListener('input', e=>{ S.headR=parseFloat(e.target.value); $('valHead').textContent=S.headR;
  S.ref.bound=false; render(); refreshAllThumbs(); });
$('inpFps').addEventListener('change', e=>{ S.fps=Math.max(1,Math.min(30,parseInt(e.target.value,10)||8)); e.target.value=S.fps; });

$('btnDup').addEventListener('click', dupFrame);
$('btnAdd').addEventListener('click', addFrame);
$('btnMoveL').addEventListener('click', ()=>moveFrame(-1));
$('btnMoveR').addEventListener('click', ()=>moveFrame(1));
$('btnPlay').addEventListener('click', ()=> playing?stop():play());

$('btnExpFrame').addEventListener('click', exportFrame);
$('btnExpSheet').addEventListener('click', exportSheet);
$('btnSave').addEventListener('click', saveProject);
$('fileProj').addEventListener('change', e=>{ if(e.target.files[0]) loadProject(e.target.files[0]); e.target.value=''; });

// 參考圖
[...$('refModeSeg').children].forEach(b=> b.addEventListener('click', ()=> setRefMode(b.dataset.mode)));
$('fileRef').addEventListener('change', e=>{
  const f=e.target.files[0]; if(!f) return;
  const rd=new FileReader();
  rd.onload=()=>{ const img=new Image(); img.onload=()=>{
    S.ref.img=img; S.ref.name=f.name; S.ref.bound=false;
    placeRefDefault();
    if(S.ref.mode==='off') setRefMode('trace'); else setRefMode(S.ref.mode);
    render();
  }; img.src=rd.result; };
  rd.readAsDataURL(f); e.target.value='';
});
$('btnRefClear').addEventListener('click', ()=>{ S.ref.img=null; S.ref.bound=false; S.ref.patches=[]; setRefMode('off'); });
$('rngRefOp').addEventListener('input', e=>{ S.ref.op=parseFloat(e.target.value); $('valRefOp').textContent=S.ref.op.toFixed(2).replace(/^0/,''); render(); });
$('rngRefScale').addEventListener('input', e=>{ S.ref.scale=parseFloat(e.target.value); $('valRefScale').textContent=S.ref.scale.toFixed(2); S.ref.bound=false; render(); });
$('rngRefX').addEventListener('input', e=>{ S.ref.x=parseFloat(e.target.value); S.ref.bound=false; render(); });
$('rngRefY').addEventListener('input', e=>{ S.ref.y=parseFloat(e.target.value); S.ref.bound=false; render(); });
$('btnBind').addEventListener('click', bindPuppet);
$('chkShowRig').addEventListener('change', render);

window.addEventListener('resize', fit);

// ---------- init ----------
syncAllControls();
buildLayers();
buildTimeline();
fit();
