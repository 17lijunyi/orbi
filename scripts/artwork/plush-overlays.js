(function () {
  'use strict';
  const TAU = Math.PI * 2;
  function oval(c, x, y, rx, ry) {
    c.beginPath(); c.ellipse(x, y, rx, ry, 0, 0, TAU); c.closePath();
  }
  function capsule(c, x, y, w, h, r) {
    c.beginPath(); c.roundRect(x, y, w, h, r); c.closePath();
  }
  function ink(c, y1 = -25, y2 = 25) {
    const g = c.createLinearGradient(-18, y1, 20, y2);
    g.addColorStop(0, '#3b3c39'); g.addColorStop(.47, '#232522'); g.addColorStop(1, '#131512');
    return g;
  }
  function shadow(c, blur = 2, y = 1.4) {
    c.shadowColor = 'rgba(0,0,0,.19)'; c.shadowBlur = blur; c.shadowOffsetY = y;
  }
  function noShadow(c) { c.shadowColor = 'transparent'; c.shadowBlur = 0; c.shadowOffsetX = 0; c.shadowOffsetY = 0; }
  function setup(c, cx, cy, scale) {
    c.save(); c.translate(cx, cy); c.scale(scale, scale);
    c.lineJoin = 'round'; c.lineCap = 'round'; shadow(c);
    c.fillStyle = ink(c); c.strokeStyle = '#242623';
  }
  function glint(c, x, y, r) {
    noShadow(c); c.fillStyle = '#fbfcf9'; oval(c, x, y, r, r * .91); c.fill();
  }
  function star(c, x, y, r) {
    c.beginPath(); c.moveTo(x, y-r); c.quadraticCurveTo(x+r*.27,y-r*.25,x+r,y);
    c.quadraticCurveTo(x+r*.27,y+r*.25,x,y+r); c.quadraticCurveTo(x-r*.27,y+r*.25,x-r,y);
    c.quadraticCurveTo(x-r*.27,y-r*.25,x,y-r); c.closePath(); c.fill();
  }
  function drawEyes(c, kind, cx, cy, scale = 1) {
    setup(c, cx, cy, scale);
    for (const side of [-1, 1]) {
      const x = side * 25;
      c.fillStyle = ink(c); shadow(c);
      if (kind === 'lashes') {
        oval(c,x,0,8.6,14); c.fill();
        c.beginPath(); c.moveTo(x+side*3,-10); c.quadraticCurveTo(x+side*11,-7,x+side*23,-6);
        c.quadraticCurveTo(x+side*17,0,x+side*7,1); c.closePath(); c.fill();
      } else if (kind === 'sparkle') {
        capsule(c,x-13,-25,26,47,13); c.fill(); noShadow(c); c.fillStyle='#fffffc';
        star(c,x-1,-8,11); star(c,x+5,12,4);
      } else if (kind === 'tall') {
        capsule(c,x-11,-20,22,40,11); c.fill(); glint(c,x-2.5,-9,5);
      } else if (kind === 'dots') {
        oval(c,x,0,6.5,6.5); c.fill();
      } else if (kind === 'round') {
        oval(c,x,0,15,15); c.fill(); glint(c,x-5,-6,5.1);
      } else if (kind === 'googly') {
        const white=c.createRadialGradient(x-6,-7,1,x,0,16);
        white.addColorStop(0,'#fffefa'); white.addColorStop(.7,'#f6f5f1'); white.addColorStop(1,'#bbbdb5');
        c.fillStyle=white; oval(c,x,0,15,15.5); c.fill(); noShadow(c);
        c.fillStyle=ink(c); oval(c,x-side*3,1,9.8,10); c.fill(); glint(c,x-side*3-3,-2.5,3.5);
      } else if (kind === 'sleepy') {
        oval(c,x,7,7,13); c.fill(); capsule(c,x-20,-9,40,11,6); c.fill();
      } else if (kind === 'oval') {
        oval(c,x,0,7.1,11.8); c.fill();
      }
    }
    c.restore();
  }
  function wire(c, width = 3.6) {
    c.strokeStyle=ink(c); c.lineWidth=width; shadow(c,1.7,.8);
  }
  function lens(c, points) {
    c.beginPath(); c.moveTo(points[0][0],points[0][1]);
    for(let i=1;i<points.length;i++) c.lineTo(points[i][0],points[i][1]);
    c.closePath(); c.fill();
  }
  function drawGlasses(c, kind, cx, cy, scale = 1) {
    setup(c,cx,cy,scale); wire(c);
    if(kind==='monocle') {
      oval(c,26,0,26,29); c.stroke();
      c.beginPath(); c.moveTo(51,8); c.bezierCurveTo(51,30,62,51,86,53); c.stroke();
      noShadow(c); c.strokeStyle='rgba(255,255,255,.13)'; c.lineWidth=1;
      c.beginPath(); c.ellipse(26,0,25,28,0,Math.PI*1.05,Math.PI*1.8); c.stroke();
    } else if(kind==='round') {
      for(const x of [-28,28]) { oval(c,x,0,23,30); c.stroke(); }
      c.beginPath(); c.moveTo(-5,-3); c.quadraticCurveTo(0,-9,5,-3); c.moveTo(-57,-1);c.lineTo(-51,-1);
      c.moveTo(51,-1);c.lineTo(57,-1);c.stroke();
    } else if(kind==='shades') {
      c.fillStyle=ink(c,-25,25);
      for(const x of [-30,30]) { oval(c,x,0,25,25);c.fill(); }
      wire(c,5); c.beginPath();c.moveTo(-6,-1);c.quadraticCurveTo(0,-11,6,-1);c.stroke();
      noShadow(c);c.strokeStyle='rgba(255,255,255,.11)';c.lineWidth=2;
      for(const x of [-30,30]) {c.beginPath();c.ellipse(x,0,23,23,0,Math.PI*1.08,Math.PI*1.6);c.stroke();}
    } else if(kind==='square') {
      c.fillStyle=ink(c,-20,25);
      lens(c,[[-56,-21],[-5,-21],[-9,21],[-46,21]]);
      lens(c,[[5,-21],[56,-21],[46,21],[9,21]]);
      c.lineWidth=6;c.beginPath();c.moveTo(-11,-15);c.quadraticCurveTo(0,-20,11,-15);c.stroke();
    } else if(kind==='classic') {
      c.fillStyle=ink(c,-20,25);
      c.beginPath();c.moveTo(-60,-17);c.quadraticCurveTo(-41,-23,-12,-17);c.lineTo(-5,-13);
      c.lineTo(5,-13);c.lineTo(12,-17);c.quadraticCurveTo(41,-23,60,-17);c.lineTo(59,-7);
      c.lineTo(52,-3);c.quadraticCurveTo(48,24,31,24);c.quadraticCurveTo(9,24,7,-4);
      c.quadraticCurveTo(0,-10,-7,-4);c.quadraticCurveTo(-9,24,-31,24);c.quadraticCurveTo(-48,24,-52,-3);
      c.lineTo(-59,-7);c.closePath();c.fill();
      noShadow(c);c.strokeStyle='rgba(255,255,255,.12)';c.lineWidth=1.8;
      c.beginPath();c.moveTo(-53,-14);c.quadraticCurveTo(-37,-18,-17,-13);c.moveTo(17,-13);c.quadraticCurveTo(37,-18,53,-14);c.stroke();
    }
    c.restore();
  }
  function fabric(c,x,y,rx,ry) {
    c.save(); oval(c,x,y,rx,ry);c.clip();noShadow(c);
    c.strokeStyle='rgba(255,255,255,.055)';c.lineWidth=.65;
    for(let i=0;i<70;i++) {
      const a=i*2.39996323, r=Math.sqrt((i+.5)/70);
      const px=x+Math.cos(a)*r*rx,py=y+Math.sin(a)*r*ry;
      c.beginPath();c.moveTo(px,py);c.lineTo(px+2.1,py-1.6);c.stroke();
    }
    c.restore();
  }
  function hatBrim(c, y, rx, ry) {
    shadow(c,5,4); c.fillStyle=ink(c,y-ry,y+ry);oval(c,0,y,rx,ry);c.fill();
  }
  function drawAccessory(c,kind,cx,cy,scale=1) {
    setup(c,cx,cy,scale);shadow(c,5,4);
    if(kind==='headphones') {
      c.strokeStyle='#171a17';c.lineWidth=22;
      c.beginPath();c.moveTo(-239,26);c.bezierCurveTo(-259,-287,259,-287,239,26);c.stroke();
      noShadow(c);c.strokeStyle='#51544e';c.lineWidth=4;
      c.beginPath();c.moveTo(-237,-24);c.bezierCurveTo(-223,-252,223,-252,237,-24);c.stroke();
      for(const side of [-1,1]) {
        shadow(c,6,3);c.fillStyle=ink(c,-50,105);
        capsule(c,side*241-31,-44,62,141,29);c.fill();
        noShadow(c);c.fillStyle='#3c3f38';capsule(c,side*241-22,-37,11,121,6);c.fill();
      }
    } else if(kind==='bowtie') {
      c.translate(0,350);c.fillStyle=ink(c,-50,45);
      for(const side of [-1,1]) {
        c.beginPath();c.moveTo(side*7,-6);c.lineTo(side*83,-44);
        c.quadraticCurveTo(side*105,-54,side*105,-29);c.lineTo(side*105,35);
        c.quadraticCurveTo(side*105,55,side*84,46);c.lineTo(side*7,12);c.closePath();c.fill();
      }
      c.fillStyle=ink(c,-15,20);capsule(c,-15,-15,30,37,11);c.fill();
      noShadow(c);c.strokeStyle='rgba(255,255,255,.08)';c.lineWidth=2;
      c.beginPath();c.moveTo(-90,-34);c.lineTo(-20,-3);c.moveTo(20,-3);c.lineTo(90,-34);c.stroke();
    } else if(kind==='bowler') {
      c.translate(0,-179);c.rotate(-.07);hatBrim(c,0,133,34);
      c.fillStyle=ink(c,-104,10);c.beginPath();c.moveTo(-98,-6);c.bezierCurveTo(-98,-138,99,-138,99,-6);
      c.quadraticCurveTo(0,30,-98,-6);c.closePath();c.fill();
      c.fillStyle='#151714';c.beginPath();c.ellipse(0,-5,98,24,0,0,Math.PI);c.quadraticCurveTo(0,5,-98,-5);c.fill();
      fabric(c,0,-50,90,48);
    } else if(kind==='tophat') {
      c.translate(0,-170);c.rotate(.055);hatBrim(c,0,124,31);
      c.fillStyle=ink(c,-150,6);c.beginPath();c.moveTo(-79,-6);c.lineTo(-93,-142);
      c.quadraticCurveTo(0,-171,93,-142);c.lineTo(79,-6);c.quadraticCurveTo(0,24,-79,-6);c.closePath();c.fill();
      c.fillStyle='#111411';c.beginPath();c.moveTo(-81,-31);c.quadraticCurveTo(0,-8,81,-31);c.lineTo(79,-8);
      c.quadraticCurveTo(0,17,-79,-8);c.closePath();c.fill();
      noShadow(c);c.strokeStyle='rgba(255,255,255,.12)';c.lineWidth=2;
      c.beginPath();c.moveTo(-87,-140);c.quadraticCurveTo(0,-163,85,-141);c.stroke();
    } else if(kind==='beret') {
      c.translate(-14,-195);c.rotate(-.2);c.fillStyle=ink(c,-75,20);
      c.beginPath();c.moveTo(-132,10);c.bezierCurveTo(-141,-49,-37,-102,64,-67);
      c.bezierCurveTo(122,-50,143,-8,116,9);c.bezierCurveTo(43,41,-60,42,-132,10);c.closePath();c.fill();
      c.fillStyle='#171a17';oval(c,3,16,113,17);c.fill();
      c.fillStyle=ink(c,-96,-64);capsule(c,13,-95,14,33,7);c.fill();fabric(c,-3,-26,115,43);
    } else if(kind==='pompom') {
      c.translate(0,-226);c.fillStyle=ink(c,-44,40);oval(c,0,0,44,45);c.fill();fabric(c,0,0,44,45);
    } else if(kind==='tuft') {
      c.translate(0,-209);c.rotate(-.1);c.fillStyle=ink(c,-80,20);
      for(const p of [[-37,-13,21,37],[0,-35,22,42],[37,-25,20,39]]){oval(c,...p);c.fill();}
      c.beginPath();c.moveTo(-55,5);c.quadraticCurveTo(0,26,55,5);c.lineTo(45,-22);c.lineTo(-44,-24);c.closePath();c.fill();
    } else if(kind==='crown') {
      c.translate(0,-191);c.rotate(-.06);c.fillStyle=ink(c,-92,24);
      c.beginPath();c.moveTo(-96,13);c.lineTo(-117,-74);c.lineTo(-57,-31);c.lineTo(0,-112);
      c.lineTo(57,-31);c.lineTo(117,-74);c.lineTo(96,13);c.quadraticCurveTo(0,40,-96,13);c.closePath();c.fill();
      for(const [x,y] of [[-117,-74],[0,-112],[117,-74]]){oval(c,x,y,10,10);c.fill();}
      c.fillStyle='#3c413a';c.beginPath();c.moveTo(-93,0);c.quadraticCurveTo(0,24,93,0);c.lineTo(90,15);c.quadraticCurveTo(0,38,-90,15);c.closePath();c.fill();
      noShadow(c);c.fillStyle='#555d52';for(const x of [-47,0,47]){oval(c,x,8+(x===0?5:0),4,4);c.fill();}
    }
    c.restore();
  }
  window.OrbiParts={drawEyes,drawGlasses,drawAccessory};
})();
