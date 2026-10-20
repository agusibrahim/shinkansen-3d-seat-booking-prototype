import * as THREE from './vendor/three.module.min.js';

// ============================================================================
// Procedural High-Res Textures for Authentic Indonesian KAI Seats & Cabin
// ============================================================================
const texCache = new Map();

function makeCanvasTex(key, width, height, drawFn) {
  if (texCache.has(key)) return texCache.get(key);
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext('2d');
  drawFn(ctx, width, height);
  const tex = new THREE.CanvasTexture(canvas);
  tex.colorSpace = THREE.LinearSRGBColorSpace;
  tex.wrapS = THREE.ClampToEdgeWrapping;
  tex.wrapT = THREE.ClampToEdgeWrapping;
  tex.needsUpdate = true;
  texCache.set(key, tex);
  return tex;
}

export function getKAILeatherTexture(variant = 'maroon', state = 'normal') {
  const key = `leather:${variant}:${state}`;
  return makeCanvasTex(key, 512, 512, (ctx, w, h) => {
    const palettes = {
      maroon: {
        normal: ['#7D3747', '#632836', '#511E2A'],
        highlighted: ['#592330', '#441923', '#331119'],
        selected: ['#1E9E52', '#137A3D', '#0D592B'],
        disabled: ['#AEB2BA', '#969AA3', '#7E828B']
      },
      blue: {
        normal: ['#485F8E', '#364A73', '#283859'],
        highlighted: ['#33456B', '#253452', '#1B263D'],
        selected: ['#1E9E52', '#137A3D', '#0D592B'],
        disabled: ['#AEB2BA', '#969AA3', '#7E828B']
      },
      premium: {
        normal: ['#A69384', '#8E7B6C', '#736255'],
        highlighted: ['#857467', '#6E5F53', '#574A40'],
        selected: ['#1E9E52', '#137A3D', '#0D592B'],
        disabled: ['#B5B8BF', '#9DA0A8', '#858890']
      },
      eko23: {
        normal: ['#BEB298', '#A69A80', '#8C8169'],
        highlighted: ['#9E937B', '#877D67', '#706754'],
        selected: ['#1E9E52', '#137A3D', '#0D592B'],
        disabled: ['#B8BBC2', '#A0A3AA', '#888B92']
      }
    };

    const pal = (palettes[variant] || palettes.maroon)[state] || palettes.maroon.normal;

    // Base vertical gradient
    const grad = ctx.createLinearGradient(0, 0, 0, h);
    grad.addColorStop(0, pal[0]);
    grad.addColorStop(0.65, pal[0]);
    grad.addColorStop(1, pal[1]);
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, w, h);

    // Soft side shading
    const sideGrad = ctx.createLinearGradient(0, 0, w, 0);
    sideGrad.addColorStop(0, 'rgba(0,0,0,0.18)');
    sideGrad.addColorStop(0.15, 'rgba(0,0,0,0)');
    sideGrad.addColorStop(0.85, 'rgba(0,0,0,0)');
    sideGrad.addColorStop(1, 'rgba(0,0,0,0.18)');
    ctx.fillStyle = sideGrad;
    ctx.fillRect(0, 0, w, h);

    // Subtle leather grain speckles
    ctx.fillStyle = 'rgba(255,255,255,0.025)';
    for (let i = 0; i < 1800; i++) {
      const rx = (i * 97) % w;
      const ry = (i * 53) % h;
      ctx.fillRect(rx, ry, 2, 2);
    }

    if (variant === 'maroon' || variant === 'blue') {
      // Subtle batik/geometric diamond motif on upper headrest of Blue New Gen seat
      if (variant === 'blue' && state === 'normal') {
        ctx.strokeStyle = 'rgba(30, 42, 70, 0.22)';
        ctx.lineWidth = 1.5;
        for (let y = 40; y < 210; y += 36) {
          for (let x = 60; x < w - 60; x += 36) {
            ctx.beginPath();
            ctx.moveTo(x, y - 10);
            ctx.lineTo(x + 10, y);
            ctx.lineTo(x, y + 10);
            ctx.lineTo(x - 10, y);
            ctx.closePath();
            ctx.stroke();
          }
        }
      }

      // Horizontal stitched rib groups in lumbar region (2 sets of 4 ribs, matching Image 1 & 2!)
      ctx.strokeStyle = pal[2];
      ctx.lineWidth = 3.5;
      const ribYGroups = [230, 244, 258, 272, 330, 344, 358, 372];
      for (const ry of ribYGroups) {
        ctx.beginPath();
        ctx.moveTo(24, ry);
        ctx.lineTo(w - 24, ry);
        ctx.stroke();
        ctx.strokeStyle = 'rgba(255,255,255,0.08)';
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.moveTo(24, ry + 2.5);
        ctx.lineTo(w - 24, ry + 2.5);
        ctx.stroke();
        ctx.strokeStyle = pal[2];
        ctx.lineWidth = 3.5;
      }

      // Horizontal divider seam below headrest
      ctx.strokeStyle = pal[2];
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.moveTo(16, 195);
      ctx.lineTo(w - 16, 195);
      ctx.stroke();
    } else if (variant === 'premium') {
      // Ekonomi Premium: Vertical center seam in upper headrest + 3 horizontal lumbar seams
      ctx.strokeStyle = pal[2];
      ctx.lineWidth = 4.5;
      // Vertical top seam
      ctx.beginPath();
      ctx.moveTo(w / 2, 18);
      ctx.lineTo(w / 2, 215);
      ctx.stroke();

      // Horizontal lumbar panel seams
      for (const ry of [215, 290, 365, 435]) {
        ctx.beginPath();
        ctx.moveTo(20, ry);
        ctx.lineTo(w - 20, ry);
        ctx.stroke();
      }
    } else if (variant === 'eko23') {
      // Ekonomi 2-3: Clean smooth vinyl bench with subtle lower lumbar crease
      ctx.strokeStyle = pal[2];
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.moveTo(10, 360);
      ctx.lineTo(w - 10, 360);
      ctx.stroke();
    }
  });
}

export function getKAIWoodTexture(variant = 'teak') {
  const key = `wood:${variant}`;
  return makeCanvasTex(key, 256, 256, (ctx, w, h) => {
    ctx.fillStyle = variant === 'teak' ? '#9C6839' : '#7D5636';
    ctx.fillRect(0, 0, w, h);
    ctx.strokeStyle = variant === 'teak' ? 'rgba(95, 55, 22, 0.35)' : 'rgba(65, 38, 18, 0.35)';
    ctx.lineWidth = 2;
    for (let i = 0; i < 40; i++) {
      const y = (i * 7) % h;
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.bezierCurveTo(w * 0.3, y + 4, w * 0.7, y - 4, w, y + 2);
      ctx.stroke();
    }
  });
}

export function getSoftShadowTexture() {
  return makeCanvasTex('soft-shadow', 256, 256, (ctx, w, h) => {
    ctx.clearRect(0, 0, w, h);
    const grad = ctx.createRadialGradient(w / 2, h / 2, 10, w / 2, h / 2, w * 0.46);
    grad.addColorStop(0, 'rgba(0, 0, 0, 0.32)');
    grad.addColorStop(0.6, 'rgba(0, 0, 0, 0.12)');
    grad.addColorStop(1, 'rgba(0, 0, 0, 0)');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, w, h);
  });
}

// ============================================================================
// Helper: Rounded Box Geometry Builder
// ============================================================================
function createRoundedBox(width, height, depth, radius = 0.02) {
  const shape = new THREE.Shape();
  const hw = width / 2 - radius;
  const hh = height / 2 - radius;
  shape.moveTo(-hw, -height / 2);
  shape.lineTo(hw, -height / 2);
  shape.quadraticCurveTo(width / 2, -height / 2, width / 2, -hh);
  shape.lineTo(width / 2, hh);
  shape.quadraticCurveTo(width / 2, height / 2, hw, height / 2);
  shape.lineTo(-hw, height / 2);
  shape.quadraticCurveTo(-width / 2, height / 2, -width / 2, hh);
  shape.lineTo(-width / 2, -hh);
  shape.quadraticCurveTo(-width / 2, -height / 2, -hw, -height / 2);

  const extrudeSettings = {
    depth: Math.max(depth - radius * 2, 0.01),
    bevelEnabled: true,
    bevelSegments: 3,
    steps: 1,
    bevelSize: radius,
    bevelThickness: radius
  };
  const geo = new THREE.ExtrudeGeometry(shape, extrudeSettings);
  geo.center();
  // Normalize UVs to 0..1 on XY face
  const pos = geo.attributes.position;
  const uv = geo.attributes.uv;
  for (let i = 0; i < pos.count; i++) {
    const u = (pos.getX(i) + width / 2) / width;
    const v = 1 - (pos.getY(i) + height / 2) / height;
    uv.setXY(i, Math.max(0, Math.min(1, u)), Math.max(0, Math.min(1, v)));
  }
  geo.computeVertexNormals();
  return geo;
}

// ============================================================================
// Unavailable Red Indicator Badge (Floating ⊘ when seat is disabled/occupied)
// ============================================================================
function createUnavailableIndicatorMesh() {
  const canvas = document.createElement('canvas');
  canvas.width = 128;
  canvas.height = 128;
  const ctx = canvas.getContext('2d');
  ctx.strokeStyle = '#CB3A64';
  ctx.lineWidth = 14;
  ctx.beginPath();
  ctx.arc(64, 64, 46, 0, Math.PI * 2);
  ctx.stroke();
  ctx.beginPath();
  ctx.moveTo(32, 96);
  ctx.lineTo(96, 32);
  ctx.stroke();

  const tex = new THREE.CanvasTexture(canvas);
  tex.colorSpace = THREE.LinearSRGBColorSpace;
  const mat = new THREE.MeshBasicMaterial({
    map: tex,
    transparent: true,
    opacity: 0,
    depthWrite: false,
    side: THREE.DoubleSide
  });
  const mesh = new THREE.Mesh(new THREE.PlaneGeometry(0.28, 0.28), mat);
  mesh.rotation.x = -Math.PI / 3;
  mesh.position.set(0, 0.68, 0.08);
  return { mesh, mat };
}

// ============================================================================
// 1 & 2. KAI Next Gen Seat Builder (Maroon Eksekutif & Navy Blue Ekonomi New Gen)
// ============================================================================
export function buildKAINextGenSeat(variant = 'maroon', isPairA = true, withShadowPlane = false) {
  const root = new THREE.Group();
  const leatherMats = [];
  const bolsterMats = [];
  const stateNodes = [];

  const makeLeatherMat = (isBolster = false) => {
    const tex = getKAILeatherTexture(variant, 'normal');
    const mat = new THREE.MeshBasicMaterial({ map: tex });
    if (isBolster) {
      mat.color.setRGB(0.86, 0.86, 0.86);
      bolsterMats.push(mat);
    } else {
      leatherMats.push(mat);
    }
    return mat;
  };

  // Optional floor shadow plane for Confirmation / Design System preview
  if (withShadowPlane) {
    const shMesh = new THREE.Mesh(
      new THREE.PlaneGeometry(1.75, 1.75),
      new THREE.MeshBasicMaterial({
        map: getSoftShadowTexture(),
        transparent: true,
        depthWrite: false
      })
    );
    shMesh.rotation.x = -Math.PI / 2;
    shMesh.position.set(0, 0.002, 0);
    root.add(shMesh);
  }

  // 1. Dark Twin Pedestal Base & Footrest
  const baseMat = new THREE.MeshBasicMaterial({ color: 0x23262e });
  const pedLeg = new THREE.Mesh(new THREE.BoxGeometry(0.38, 0.2, 0.34), baseMat);
  pedLeg.position.set(0, 0.1, -0.05);
  root.add(pedLeg);

  const footrestGroup = new THREE.Group();
  footrestGroup.position.set(0, 0.11, 0.2);
  const footBar = new THREE.Mesh(
    new THREE.BoxGeometry(0.38, 0.035, 0.16),
    makeLeatherMat(true)
  );
  footrestGroup.add(footBar);
  root.add(footrestGroup);

  // 2. Contoured Seat Cushion (Center Ribbed Pad + Left & Right Thigh Bolsters)
  const seatCushionGroup = new THREE.Group();
  seatCushionGroup.position.set(0, 0.25, 0.02);

  const centerCushion = new THREE.Mesh(
    createRoundedBox(0.35, 0.46, 0.11, 0.03),
    makeLeatherMat(false)
  );
  centerCushion.rotation.x = Math.PI / 2;
  seatCushionGroup.add(centerCushion);

  const thighBolsterGeo = createRoundedBox(0.095, 0.48, 0.13, 0.03);
  for (const side of [-1, 1]) {
    const tb = new THREE.Mesh(thighBolsterGeo, makeLeatherMat(true));
    tb.rotation.x = Math.PI / 2;
    tb.position.set(side * 0.195, 0.015, 0);
    seatCushionGroup.add(tb);
  }
  root.add(seatCushionGroup);

  // 3. Sculpted 3-Column Backrest + Organic Winged Headrest Ears ("Telinga" Sandaran)
  const backrestGroup = new THREE.Group();
  const baseBackPos = new THREE.Vector3(0, 0.3, -0.17);
  const normalQuat = new THREE.Quaternion().setFromEuler(new THREE.Euler(-0.15, 0, 0, 'ZYX'));
  const reclineQuat = new THREE.Quaternion().setFromEuler(new THREE.Euler(-0.42, 0, 0, 'ZYX'));
  backrestGroup.position.copy(baseBackPos);
  backrestGroup.quaternion.copy(normalQuat);

  // Center spine column (continuous lumbar + headrest, NO Shinkansen square pillow!)
  const centerSpine = new THREE.Mesh(
    createRoundedBox(0.32, 0.78, 0.1, 0.035),
    makeLeatherMat(false)
  );
  centerSpine.position.set(0, 0.39, 0);
  backrestGroup.add(centerSpine);

  // Left & right vertical backrest side bolsters
  const sideBolsterGeo = createRoundedBox(0.095, 0.76, 0.12, 0.035);
  for (const side of [-1, 1]) {
    const sb = new THREE.Mesh(sideBolsterGeo, makeLeatherMat(true));
    sb.position.set(side * 0.185, 0.39, 0.015);
    sb.rotation.y = -side * 0.12;
    backrestGroup.add(sb);
  }

  // Organic Winged Headrest Ears ("Telinga" Sandaran Kepala) curving forward at top left & right
  const earGeo = createRoundedBox(0.095, 0.27, 0.16, 0.04);
  for (const side of [-1, 1]) {
    const ear = new THREE.Mesh(earGeo, makeLeatherMat(true));
    ear.position.set(side * 0.215, 0.64, 0.065);
    ear.rotation.set(0.06, -side * 0.48, side * 0.08);
    backrestGroup.add(ear);
  }

  // Top curved headrest crown cap
  const crownCap = new THREE.Mesh(
    createRoundedBox(0.44, 0.09, 0.11, 0.035),
    makeLeatherMat(true)
  );
  crownCap.position.set(0, 0.77, 0.01);
  backrestGroup.add(crownCap);

  root.add(backrestGroup);

  stateNodes.push({
    object: backrestGroup,
    original: {
      position: baseBackPos.clone(),
      quaternion: normalQuat.clone(),
      scale: new THREE.Vector3(1, 1, 1)
    },
    stateTransforms: {
      highlighted: {
        position: baseBackPos.toArray(),
        quaternion: reclineQuat.toArray(),
        scale: [1, 1, 1]
      },
      selected: {
        position: baseBackPos.toArray(),
        quaternion: reclineQuat.toArray(),
        scale: [1, 1, 1]
      }
    }
  });

  // 4. Sleek Outer/Aisle Side Panel + Curved Wooden Armrest Rail + Recline Button
  const woodTex = getKAIWoodTexture(variant === 'maroon' ? 'teak' : 'walnut');
  const woodMat = new THREE.MeshBasicMaterial({ map: woodTex });
  const shellColor = variant === 'maroon' ? 0x9aa3b2 : 0xcdd2dc;
  const shellRecessColor = variant === 'maroon' ? 0x828b99 : 0xb8bec9;
  const shellMat = new THREE.MeshBasicMaterial({ color: shellColor });
  const recessMat = new THREE.MeshBasicMaterial({ color: shellRecessColor });
  const chromeMat = new THREE.MeshBasicMaterial({ color: 0xdce2ec });

  // Place full wooden-trimmed side panel on the outer/aisle side of the seat
  const outerSide = isPairA ? 1 : -1;
  const panelX = outerSide * 0.265;

  const sideShell = new THREE.Mesh(createRoundedBox(0.055, 0.36, 0.52, 0.02), shellMat);
  sideShell.position.set(panelX, 0.31, -0.01);
  root.add(sideShell);

  const sideRecess = new THREE.Mesh(createRoundedBox(0.06, 0.22, 0.36, 0.015), recessMat);
  sideRecess.position.set(panelX + outerSide * 0.003, 0.3, -0.01);
  root.add(sideRecess);

  // Top horizontal wooden armrest cap
  const woodTop = new THREE.Mesh(createRoundedBox(0.068, 0.045, 0.52, 0.015), woodMat);
  woodTop.position.set(panelX, 0.495, -0.005);
  root.add(woodTop);

  // Front vertical curved wooden nose trim
  const woodFront = new THREE.Mesh(createRoundedBox(0.068, 0.28, 0.055, 0.015), woodMat);
  woodFront.position.set(panelX, 0.37, 0.235);
  root.add(woodFront);

  // Silver recline button on front wooden trim (visible in both Maroon & Blue photos!)
  const btnMesh = new THREE.Mesh(new THREE.BoxGeometry(0.028, 0.042, 0.015), chromeMat);
  btnMesh.position.set(panelX, 0.34, 0.265);
  root.add(btnMesh);

  // 5. Slim Contoured Center Divider Armrest (between Seat A & Seat B)
  if (isPairA || withShadowPlane) {
    const divX = withShadowPlane ? -0.265 : -0.295;
    if (withShadowPlane) {
      // On standalone 3D preview, put matching wooden armrest on both left & right sides!
      const sideShellL = sideShell.clone();
      sideShellL.position.x = -panelX;
      const woodTopL = woodTop.clone();
      woodTopL.position.x = -panelX;
      const woodFrontL = woodFront.clone();
      woodFrontL.position.x = -panelX;
      root.add(sideShellL, woodTopL, woodFrontL);
    } else {
      const divColor = variant === 'maroon' ? 0xb8cbe0 : 0xe2e7f0;
      const divPaddle = new THREE.Mesh(
        createRoundedBox(0.036, 0.24, 0.26, 0.014),
        new THREE.MeshBasicMaterial({ color: divColor })
      );
      divPaddle.position.set(divX, 0.52, -0.08);
      divPaddle.rotation.x = -0.2;
      root.add(divPaddle);
    }
  }

  // 6. Unavailable Indicator
  const unavail = createUnavailableIndicatorMesh();
  root.add(unavail.mesh);

  const applyCustomState = (state) => {
    const tex = getKAILeatherTexture(variant, state);
    leatherMats.forEach((m) => {
      m.map = tex;
      m.needsUpdate = true;
    });
    bolsterMats.forEach((m) => {
      m.map = tex;
      m.needsUpdate = true;
    });
    unavail.mat.opacity = state === 'disabled' ? 1 : 0;
  };

  return { root, stateNodes, applyCustomState };
}

// ============================================================================
// 3. KAI Ekonomi Premium Seat Builder (Taupe/Tan 2-2 + Open Curved Chrome Armrests)
// ============================================================================
export function buildKAIEkonomiPremiumSeat(isPairA = true, withShadowPlane = false) {
  const root = new THREE.Group();
  const leatherMats = [];
  const bolsterMats = [];
  const stateNodes = [];

  const makeLeatherMat = (isBolster = false) => {
    const tex = getKAILeatherTexture('premium', 'normal');
    const mat = new THREE.MeshBasicMaterial({ map: tex });
    if (isBolster) {
      mat.color.setRGB(0.9, 0.9, 0.9);
      bolsterMats.push(mat);
    } else {
      leatherMats.push(mat);
    }
    return mat;
  };

  if (withShadowPlane) {
    const shMesh = new THREE.Mesh(
      new THREE.PlaneGeometry(1.75, 1.75),
      new THREE.MeshBasicMaterial({
        map: getSoftShadowTexture(),
        transparent: true,
        depthWrite: false
      })
    );
    shMesh.rotation.x = -Math.PI / 2;
    shMesh.position.set(0, 0.002, 0);
    root.add(shMesh);
  }

  // 1. Brushed Steel Underframe Pedestal
  const steelMat = new THREE.MeshBasicMaterial({ color: 0xb8c0ca });
  const darkMetalMat = new THREE.MeshBasicMaterial({ color: 0x2b2e35 });
  const baseFrame = new THREE.Mesh(new THREE.BoxGeometry(0.42, 0.18, 0.34), darkMetalMat);
  baseFrame.position.set(0, 0.09, -0.04);
  root.add(baseFrame);

  // 2. Plump Taupe/Tan Seat Cushion
  const cushionGroup = new THREE.Group();
  cushionGroup.position.set(0, 0.24, 0.03);
  const centerPad = new THREE.Mesh(
    createRoundedBox(0.36, 0.47, 0.12, 0.032),
    makeLeatherMat(false)
  );
  centerPad.rotation.x = Math.PI / 2;
  cushionGroup.add(centerPad);

  const sideBolsterGeo = createRoundedBox(0.09, 0.48, 0.135, 0.032);
  for (const side of [-1, 1]) {
    const sb = new THREE.Mesh(sideBolsterGeo, makeLeatherMat(true));
    sb.rotation.x = Math.PI / 2;
    sb.position.set(side * 0.195, 0.01, 0);
    cushionGroup.add(sb);
  }
  root.add(cushionGroup);

  // 3. Tall Flat-Top Contoured Backrest (NO side wings, vertical top seam + horizontal lumbar panels!)
  const backrestGroup = new THREE.Group();
  const baseBackPos = new THREE.Vector3(0, 0.29, -0.17);
  const normalQuat = new THREE.Quaternion().setFromEuler(new THREE.Euler(-0.14, 0, 0, 'ZYX'));
  const reclineQuat = new THREE.Quaternion().setFromEuler(new THREE.Euler(-0.36, 0, 0, 'ZYX'));
  backrestGroup.position.copy(baseBackPos);
  backrestGroup.quaternion.copy(normalQuat);

  const centerBack = new THREE.Mesh(
    createRoundedBox(0.35, 0.79, 0.105, 0.035),
    makeLeatherMat(false)
  );
  centerBack.position.set(0, 0.4, 0);
  backrestGroup.add(centerBack);

  const backBolsterGeo = createRoundedBox(0.095, 0.79, 0.125, 0.035);
  for (const side of [-1, 1]) {
    const bb = new THREE.Mesh(backBolsterGeo, makeLeatherMat(true));
    bb.position.set(side * 0.195, 0.4, 0.015);
    bb.rotation.y = -side * 0.1;
    backrestGroup.add(bb);
  }
  root.add(backrestGroup);

  stateNodes.push({
    object: backrestGroup,
    original: {
      position: baseBackPos.clone(),
      quaternion: normalQuat.clone(),
      scale: new THREE.Vector3(1, 1, 1)
    },
    stateTransforms: {
      highlighted: {
        position: baseBackPos.toArray(),
        quaternion: reclineQuat.toArray(),
        scale: [1, 1, 1]
      },
      selected: {
        position: baseBackPos.toArray(),
        quaternion: reclineQuat.toArray(),
        scale: [1, 1, 1]
      }
    }
  });

  // 4. Open Curved Armrests on Chrome Metal Support Posts + Round Recline Knob (Image 2!)
  const armPadMat = new THREE.MeshBasicMaterial({ color: 0x362822 });
  const buildOpenArmrest = (xPos) => {
    const g = new THREE.Group();
    g.position.set(xPos, 0, 0);

    // Rear & front chrome support posts (open underneath!)
    const rearPost = new THREE.Mesh(new THREE.BoxGeometry(0.026, 0.24, 0.045), steelMat);
    rearPost.position.set(0, 0.34, -0.15);
    g.add(rearPost);

    const frontPost = new THREE.Mesh(new THREE.BoxGeometry(0.026, 0.24, 0.04), steelMat);
    frontPost.position.set(0, 0.33, 0.19);
    frontPost.rotation.x = 0.22;
    g.add(frontPost);

    // Top dark-espresso curved armrest pad
    const topPad = new THREE.Mesh(createRoundedBox(0.052, 0.042, 0.44, 0.015), armPadMat);
    topPad.position.set(0, 0.465, 0.02);
    g.add(topPad);

    // Downward-curving front tip of armrest pad
    const frontTip = new THREE.Mesh(createRoundedBox(0.052, 0.09, 0.05, 0.015), armPadMat);
    frontTip.position.set(0, 0.43, 0.22);
    frontTip.rotation.x = 0.35;
    g.add(frontTip);

    // Round black recline knob on side of pivot
    const knob = new THREE.Mesh(new THREE.CylinderGeometry(0.022, 0.022, 0.045, 12), darkMetalMat);
    knob.rotation.z = Math.PI / 2;
    knob.position.set(0, 0.31, 0.16);
    g.add(knob);

    return g;
  };

  if (withShadowPlane) {
    root.add(buildOpenArmrest(0.265));
    root.add(buildOpenArmrest(-0.265));
  } else if (isPairA) {
    root.add(buildOpenArmrest(0.265));
    root.add(buildOpenArmrest(-0.295));
  } else {
    root.add(buildOpenArmrest(-0.265));
  }

  const unavail = createUnavailableIndicatorMesh();
  root.add(unavail.mesh);

  const applyCustomState = (state) => {
    const tex = getKAILeatherTexture('premium', state);
    leatherMats.forEach((m) => {
      m.map = tex;
      m.needsUpdate = true;
    });
    bolsterMats.forEach((m) => {
      m.map = tex;
      m.needsUpdate = true;
    });
    unavail.mat.opacity = state === 'disabled' ? 1 : 0;
  };

  return { root, stateNodes, applyCustomState };
}

// ============================================================================
// 4. KAI Ekonomi 2-3 Bench Seat Builder (Upright 90° Cream Vinyl Bench + Tubular Pipe Frame)
// ============================================================================
export function buildKAIEkonomi23Seat(seatRole = 'b', withShadowPlane = false) {
  // seatRole: 'a' (window left of 3-bench), 'b' (middle of 3-bench), 'c' (aisle left of 3-bench),
  //           'd' (aisle right of 2-bench), 'e' (window right of 2-bench)
  const root = new THREE.Group();
  const leatherMats = [];

  const makeVinylMat = () => {
    const tex = getKAILeatherTexture('eko23', 'normal');
    const mat = new THREE.MeshBasicMaterial({ map: tex });
    leatherMats.push(mat);
    return mat;
  };

  if (withShadowPlane) {
    const shMesh = new THREE.Mesh(
      new THREE.PlaneGeometry(1.75, 1.75),
      new THREE.MeshBasicMaterial({
        map: getSoftShadowTexture(),
        transparent: true,
        depthWrite: false
      })
    );
    shMesh.rotation.x = -Math.PI / 2;
    shMesh.position.set(0, 0.002, 0);
    root.add(shMesh);
  }

  const pipeMat = new THREE.MeshBasicMaterial({ color: 0xc8d0d8 });
  const blackArmMat = new THREE.MeshBasicMaterial({ color: 0x24211f });
  const w = withShadowPlane ? 0.92 : 0.495;

  // 1. Flat Continuous Bench Cushion (Cream/Khaki Vinyl)
  const cushion = new THREE.Mesh(
    createRoundedBox(w, 0.45, 0.11, 0.025),
    makeVinylMat()
  );
  cushion.rotation.x = Math.PI / 2;
  cushion.position.set(0, 0.25, 0.04);
  root.add(cushion);

  // 2. Upright (~90°) Flat Bench Backrest (Cream/Khaki Vinyl, NO headrest pillow!)
  const backrest = new THREE.Mesh(
    createRoundedBox(w, 0.72, 0.09, 0.03),
    makeVinylMat()
  );
  backrest.position.set(0, 0.64, -0.14);
  backrest.rotation.x = -0.04; // Nearly vertical 90-degree upright bench!
  root.add(backrest);

  // 3. Continuous Round Tubular Stainless-Steel Pipe Frame around Top & Outer Sides (Image 3!)
  const pipeRadius = 0.014;
  const topPipe = new THREE.Mesh(
    new THREE.CylinderGeometry(pipeRadius, pipeRadius, w + 0.02, 12),
    pipeMat
  );
  topPipe.rotation.z = Math.PI / 2;
  topPipe.position.set(0, 1.03, -0.155);
  root.add(topPipe);

  const hasLeftEnd = withShadowPlane || seatRole === 'c' || seatRole === 'e';
  const hasRightEnd = withShadowPlane || seatRole === 'a' || seatRole === 'd';

  const buildPipeEndAndArmrest = (sideSign) => {
    const g = new THREE.Group();
    const xEdge = sideSign * (w / 2);

    // Vertical stainless steel pipe along side of backrest down to floor leg
    const vPipe = new THREE.Mesh(
      new THREE.CylinderGeometry(pipeRadius, pipeRadius, 0.98, 12),
      pipeMat
    );
    vPipe.position.set(xEdge, 0.53, -0.155);
    g.add(vPipe);

    // U-shaped tubular leg under front of bench
    const frontLeg = new THREE.Mesh(
      new THREE.CylinderGeometry(pipeRadius, pipeRadius, 0.24, 12),
      pipeMat
    );
    frontLeg.position.set(xEdge, 0.12, 0.2);
    g.add(frontLeg);

    const bottomRunner = new THREE.Mesh(
      new THREE.CylinderGeometry(pipeRadius, pipeRadius, 0.36, 12),
      pipeMat
    );
    bottomRunner.rotation.x = Math.PI / 2;
    bottomRunner.position.set(xEdge, 0.02, 0.02);
    g.add(bottomRunner);

    // Open tubular armrest loop + curved black armrest pad
    const armFrontSupport = new THREE.Mesh(
      new THREE.CylinderGeometry(0.011, 0.011, 0.22, 10),
      pipeMat
    );
    armFrontSupport.position.set(xEdge, 0.34, 0.18);
    g.add(armFrontSupport);

    const blackPad = new THREE.Mesh(
      createRoundedBox(0.044, 0.036, 0.36, 0.012),
      blackArmMat
    );
    blackPad.position.set(xEdge, 0.45, 0.02);
    g.add(blackPad);

    return g;
  };

  if (hasLeftEnd) root.add(buildPipeEndAndArmrest(-1));
  if (hasRightEnd) root.add(buildPipeEndAndArmrest(1));

  const unavail = createUnavailableIndicatorMesh();
  root.add(unavail.mesh);

  const applyCustomState = (state) => {
    const tex = getKAILeatherTexture('eko23', state);
    leatherMats.forEach((m) => {
      m.map = tex;
      m.needsUpdate = true;
    });
    unavail.mat.opacity = state === 'disabled' ? 1 : 0;
  };

  return { root, stateNodes: [], applyCustomState };
}

// ============================================================================
// 5. KAI Stainless Steel Next Gen Coach End / Power Car (replaces Shinkansen Nose Cone!)
// ============================================================================
export function buildKAICoachEndChassis() {
  const group = new THREE.Group();

  // Corrugated Stainless Steel Coach Body (box-shaped KAI coach, NOT bullet nose!)
  const bodyMat = new THREE.MeshBasicMaterial({ color: 0xc4c8cf });
  const roofMat = new THREE.MeshBasicMaterial({ color: 0xb4b8c0 });
  const darkBandMat = new THREE.MeshBasicMaterial({ color: 0x23262e });
  const magentaMat = new THREE.MeshBasicMaterial({ color: 0xd82b79 });
  const bogieMat = new THREE.MeshBasicMaterial({ color: 0x2c3038 });

  const bodyBox = new THREE.Mesh(new THREE.BoxGeometry(3.4, 2.25, 8.2), bodyMat);
  bodyBox.position.set(0, 1.55, -3.5);
  group.add(bodyBox);

  // Curved stainless steel roof + 3 Rooftop AC Units (matching Image 1!)
  const roofBox = new THREE.Mesh(createRoundedBox(3.32, 0.36, 8.2, 0.12), roofMat);
  roofBox.position.set(0, 2.75, -3.5);
  group.add(roofBox);

  for (const acZ of [-1.2, -3.5, -5.8]) {
    const acPod = new THREE.Mesh(createRoundedBox(1.85, 0.26, 1.45, 0.05), bodyMat);
    acPod.position.set(0, 2.98, acZ);
    group.add(acPod);
  }

  // Dark window band & Argo Bromo Anggrek Magenta Livery Stripe on both sides
  for (const side of [-1, 1]) {
    const winBand = new THREE.Mesh(new THREE.PlaneGeometry(7.8, 0.68), darkBandMat);
    winBand.rotation.y = side * (Math.PI / 2);
    winBand.position.set(side * 1.705, 1.85, -3.5);
    group.add(winBand);

    const magStripe = new THREE.Mesh(new THREE.PlaneGeometry(7.8, 0.24), magentaMat);
    magStripe.rotation.y = side * (Math.PI / 2);
    magStripe.position.set(side * 1.705, 1.05, -3.5);
    group.add(magStripe);
  }

  // Bogies underneath
  for (const bz of [-1.5, -5.5]) {
    const bogie = new THREE.Mesh(new THREE.BoxGeometry(2.8, 0.42, 1.8), bogieMat);
    bogie.position.set(0, 0.28, bz);
    group.add(bogie);
  }

  return group;
}
