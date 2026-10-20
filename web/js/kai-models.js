import * as THREE from './vendor/three.module.min.js';

// ============================================================================
// 100% Pure Indonesian KAI 3D Geometry, Studio-Lit Shader & Texture Engine
// Zero Shinkansen meshes, zero Shinkansen .scn buffers, zero Shinkansen textures
// ============================================================================
const texCache = new Map();

const whitePixel = new Uint8Array([255, 255, 255, 255]);
const defaultWhiteTex = new THREE.DataTexture(whitePixel, 1, 1, THREE.RGBAFormat);
defaultWhiteTex.needsUpdate = true;

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

// Studio 3-Point Lit + AO + Specular Shader (No external lights needed!)
const KAI_VERT = `
  varying vec2 vUv;
  varying vec3 vWorldNormal;
  varying vec3 vViewPosition;
  varying vec3 vLocalPos;

  void main() {
    vUv = uv;
    vLocalPos = position;
    vec4 worldPos = modelMatrix * vec4(position, 1.0);
    vWorldNormal = normalize(mat3(modelMatrix) * normal);
    vec4 mvPos = viewMatrix * worldPos;
    vViewPosition = -mvPos.xyz;
    gl_Position = projectionMatrix * mvPos;
  }
`;

const KAI_FRAG = `
  uniform vec3 uColor;
  uniform sampler2D uMap;
  uniform bool uHasMap;
  uniform float uRoughness;
  uniform float uMetalness;
  uniform float uOpacity;

  varying vec2 vUv;
  varying vec3 vWorldNormal;
  varying vec3 vViewPosition;
  varying vec3 vLocalPos;

  void main() {
    vec4 texSample = uHasMap ? texture2D(uMap, vUv) : vec4(1.0);
    vec3 base = uColor * texSample.rgb;
    float alpha = uOpacity * texSample.a;
    if (alpha <= 0.01) discard;

    vec3 N = normalize(vWorldNormal);
    vec3 V = normalize(vViewPosition);

    // 3-point studio lighting in world space
    vec3 L1 = normalize(vec3(-0.45, 0.82, 0.55));
    vec3 L2 = normalize(vec3(0.65, 0.45, 0.35));
    vec3 L3 = normalize(vec3(0.0, 0.65, -0.75));

    float diff1 = max(dot(N, L1), 0.0);
    float diff2 = max(dot(N, L2), 0.0);
    float diff3 = max(dot(N, L3), 0.0);

    // Hemisphere ambient (warm ceiling + cool floor bounce)
    float hemi = 0.5 + 0.5 * N.y;
    vec3 ambient = mix(vec3(0.55, 0.56, 0.60), vec3(0.96, 0.95, 0.94), hemi) * 0.66;

    vec3 diffuseLight = ambient + diff1 * vec3(0.52) + diff2 * vec3(0.24) + diff3 * vec3(0.18);

    // Specular highlight (Blinn-Phong)
    vec3 H1 = normalize(L1 + V);
    float shininess = mix(14.0, 96.0, 1.0 - uRoughness);
    float specPower = pow(max(dot(N, H1), 0.0), shininess);
    float specStrength = mix(0.08, 0.55, uMetalness) * (1.0 - uRoughness * 0.65);
    vec3 specColor = mix(vec3(1.0), base + vec3(0.25), uMetalness) * specPower * specStrength;

    // Subtle vertical self-AO
    float ao = clamp(0.84 + 0.22 * clamp(vLocalPos.y * 1.5, 0.0, 1.0), 0.78, 1.06);

    vec3 finalRgb = clamp(base * diffuseLight * ao + specColor, 0.0, 1.0);
    gl_FragColor = vec4(finalRgb, alpha);
  }
`;

export function createKAIMaterial({
  color = 0xffffff,
  map = null,
  roughness = 0.55,
  metalness = 0.05,
  opacity = 1.0,
  transparent = false,
  doubleSided = false
} = {}) {
  const c = new THREE.Color();
  if (typeof color === 'number') {
    c.setRGB(
      ((color >> 16) & 255) / 255,
      ((color >> 8) & 255) / 255,
      (color & 255) / 255,
      THREE.LinearSRGBColorSpace
    );
  } else if (Array.isArray(color)) {
    c.setRGB(color[0], color[1], color[2], THREE.LinearSRGBColorSpace);
  }
  return new THREE.ShaderMaterial({
    vertexShader: KAI_VERT,
    fragmentShader: KAI_FRAG,
    uniforms: {
      uColor: { value: new THREE.Vector3(c.r, c.g, c.b) },
      uMap: { value: map || defaultWhiteTex },
      uHasMap: { value: Boolean(map) },
      uRoughness: { value: roughness },
      uMetalness: { value: metalness },
      uOpacity: { value: opacity }
    },
    transparent: transparent || opacity < 0.999,
    depthWrite: !(transparent || opacity < 0.999),
    side: doubleSided ? THREE.DoubleSide : THREE.FrontSide
  });
}

// ============================================================================
// High-Res Procedural Upholstery, Wood, Curtain & PIDS Textures
// ============================================================================
export function getKAILeatherTexture(variant = 'maroon', state = 'normal', part = 'center') {
  const key = `kai-upholstery:${variant}:${state}:${part}`;
  return makeCanvasTex(key, 512, 512, (ctx, w, h) => {
    const palettes = {
      maroon: {
        normal: ['#7E3647', '#662837', '#4D1B27', '#914658'],
        highlighted: ['#5C2230', '#451823', '#300E16', '#6E2D3D'],
        selected: ['#1E9E52', '#147A3D', '#0C5429', '#34B869'],
        disabled: ['#B0B4BC', '#989CA5', '#7E828B', '#C0C4CC']
      },
      blue: {
        normal: ['#4A6294', '#384C76', '#273759', '#5B74A8'],
        highlighted: ['#354870', '#263554', '#1A253D', '#435884'],
        selected: ['#1E9E52', '#147A3D', '#0C5429', '#34B869'],
        disabled: ['#B0B4BC', '#989CA5', '#7E828B', '#C0C4CC']
      },
      blueDualTone: {
        normal: ['#1F3864', '#16294B', '#0E1C36', '#C49C68'],
        highlighted: ['#162848', '#101D36', '#0A1324', '#A68252'],
        selected: ['#1E9E52', '#147A3D', '#0C5429', '#34B869'],
        disabled: ['#B0B4BC', '#989CA5', '#7E828B', '#C0C4CC']
      },
      eksekutifDualTone: {
        normal: ['#CFCBC2', '#0E86B0', '#8E8A80', '#DBD7CE'],
        highlighted: ['#B2AEA6', '#0A698A', '#706C64', '#C0BCB4'],
        selected: ['#1E9E52', '#147A3D', '#0C5429', '#34B869'],
        disabled: ['#B8BBC2', '#989CA5', '#82858C', '#C4C7CE']
      },
      premium: {
        normal: ['#AA9787', '#8F7D6E', '#6E5E51', '#B8A697'],
        highlighted: ['#8A796B', '#716255', '#54483E', '#99887A'],
        selected: ['#1E9E52', '#147A3D', '#0C5429', '#34B869'],
        disabled: ['#B6B9C0', '#9EA1A9', '#848790', '#C4C7CE']
      },
      ekoTosca: {
        normal: ['#2CA8C2', '#218DA4', '#166B7D', '#3CB8D2'],
        highlighted: ['#21869C', '#186E80', '#10505E', '#2CA0B8'],
        selected: ['#1E9E52', '#147A3D', '#0C5429', '#34B869'],
        disabled: ['#B4B8C0', '#9CA0A8', '#848890', '#C2C6CE']
      },
      eko23: {
        normal: ['#C2B69C', '#AA9E84', '#8C816A', '#CEC2A9'],
        highlighted: ['#A39880', '#8B816B', '#706754', '#B2A78F'],
        selected: ['#1E9E52', '#147A3D', '#0C5429', '#34B869'],
        disabled: ['#B8BBC2', '#A0A3AA', '#888B92', '#C6C9D0']
      }
    };

    const pal = (palettes[variant] || palettes.maroon)[state] || palettes.maroon.normal;
    const isDualToneEks = variant === 'eksekutifDualTone';
    const baseColor = part === 'bolster' ? pal[1] : pal[0];
    const topStopColor =
      part === 'bolster'
        ? isDualToneEks
          ? '#1698C4'
          : pal[0]
        : pal[3];
    const botStopColor =
      part === 'bolster'
        ? isDualToneEks
          ? '#096B8E'
          : pal[1]
        : isDualToneEks
        ? '#B8B4AA'
        : pal[1];

    const grad = ctx.createLinearGradient(0, 0, 0, h);
    grad.addColorStop(0, topStopColor);
    grad.addColorStop(0.25, baseColor);
    grad.addColorStop(0.85, baseColor);
    grad.addColorStop(1, botStopColor);
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, w, h);

    // Soft pillowed cushion edge vignette
    const sideVignette = ctx.createLinearGradient(0, 0, w, 0);
    sideVignette.addColorStop(0, 'rgba(0,0,0,0.22)');
    sideVignette.addColorStop(0.12, 'rgba(0,0,0,0.03)');
    sideVignette.addColorStop(0.5, 'rgba(255,255,255,0.04)');
    sideVignette.addColorStop(0.88, 'rgba(0,0,0,0.03)');
    sideVignette.addColorStop(1, 'rgba(0,0,0,0.22)');
    ctx.fillStyle = sideVignette;
    ctx.fillRect(0, 0, w, h);

    // Fine leather pore micro-texture
    for (let i = 0; i < 3200; i++) {
      const rx = (i * 131 + (i % 7) * 19) % w;
      const ry = (i * 73 + (i % 13) * 11) % h;
      ctx.fillStyle = i % 2 === 0 ? 'rgba(255,255,255,0.025)' : 'rgba(0,0,0,0.03)';
      ctx.fillRect(rx, ry, 2, 2);
    }

    if (part === 'center') {
      if (variant === 'maroon' || variant === 'blue') {
        // Subtle batik floral diamond motif on upper backrest of Blue Ekonomi New Gen (matching reference photo!)
        if (variant === 'blue' && state === 'normal') {
          ctx.strokeStyle = 'rgba(28, 40, 68, 0.26)';
          ctx.lineWidth = 1.6;
          for (let y = 38; y < 190; y += 34) {
            for (let x = 44; x < w - 44; x += 34) {
              ctx.beginPath();
              ctx.moveTo(x, y - 11);
              ctx.lineTo(x + 11, y);
              ctx.lineTo(x, y + 11);
              ctx.lineTo(x - 11, y);
              ctx.closePath();
              ctx.stroke();
              ctx.beginPath();
              ctx.arc(x, y, 3, 0, Math.PI * 2);
              ctx.stroke();
            }
          }
        }

        // Headrest lower seam
        ctx.strokeStyle = pal[2];
        ctx.lineWidth = 4.5;
        ctx.beginPath();
        ctx.moveTo(14, 195);
        ctx.lineTo(w - 14, 195);
        ctx.stroke();

        // 2 sets of 4 horizontal ribbed grooves on lumbar & cushion (exact match to Maroon & Blue photos!)
        const ribYList = [228, 243, 258, 273, 326, 341, 356, 371];
        for (const ry of ribYList) {
          ctx.strokeStyle = pal[2];
          ctx.lineWidth = 4;
          ctx.beginPath();
          ctx.moveTo(18, ry);
          ctx.lineTo(w - 18, ry);
          ctx.stroke();

          ctx.strokeStyle = 'rgba(255,255,255,0.10)';
          ctx.lineWidth = 2;
          ctx.beginPath();
          ctx.moveTo(18, ry + 3);
          ctx.lineTo(w - 18, ry + 3);
          ctx.stroke();
        }
      } else if (variant === 'blueDualTone') {
        // Ekonomi New Gen Dual-Tone: Warm Tan/Camel upper headrest insert (top 40% of backrest center!)
        const tanGrad = ctx.createLinearGradient(0, 0, 0, 205);
        tanGrad.addColorStop(0, pal[3]);
        tanGrad.addColorStop(1, state === 'normal' ? '#AD8552' : pal[3]);
        ctx.fillStyle = tanGrad;
        ctx.fillRect(0, 0, w, 205);

        ctx.strokeStyle = 'rgba(70, 45, 20, 0.38)';
        ctx.lineWidth = 3.5;
        ctx.beginPath();
        ctx.moveTo(64, 10);
        ctx.lineTo(64, 202);
        ctx.moveTo(w - 64, 10);
        ctx.lineTo(w - 64, 202);
        ctx.stroke();

        ctx.strokeStyle = pal[2];
        ctx.lineWidth = 5;
        ctx.beginPath();
        ctx.moveTo(8, 205);
        ctx.lineTo(w - 8, 205);
        ctx.stroke();

        for (const ry of [285, 365, 445]) {
          ctx.strokeStyle = pal[2];
          ctx.lineWidth = 4.5;
          ctx.beginPath();
          ctx.moveTo(16, ry);
          ctx.lineTo(w - 16, ry);
          ctx.stroke();
        }
      } else if (variant === 'eksekutifDualTone') {
        // Eksekutif Dual-Tone (Cream/Light-Grey 4-segment plush center + Tosca bolsters)
        for (const ry of [145, 255, 365, 455]) {
          ctx.strokeStyle = pal[2];
          ctx.lineWidth = 5;
          ctx.beginPath();
          ctx.moveTo(12, ry);
          ctx.lineTo(w - 12, ry);
          ctx.stroke();

          ctx.strokeStyle = 'rgba(255,255,255,0.35)';
          ctx.lineWidth = 2.5;
          ctx.beginPath();
          ctx.moveTo(12, ry + 4);
          ctx.lineTo(w - 12, ry + 4);
          ctx.stroke();
        }
      } else if (variant === 'ekoTosca') {
        // Ekonomi 2-3 Modifikasi (Tosca Scalloped): 3 center horizontal pads + diagonal V bolster seams!
        ctx.strokeStyle = pal[2];
        ctx.lineWidth = 4.5;
        ctx.beginPath();
        ctx.moveTo(88, 25);
        ctx.lineTo(88, h - 25);
        ctx.moveTo(w - 88, 25);
        ctx.lineTo(w - 88, h - 25);
        ctx.stroke();

        for (const ry of [175, 285, 395]) {
          ctx.beginPath();
          ctx.moveTo(88, ry);
          ctx.lineTo(w - 88, ry);
          ctx.stroke();
        }

        ctx.beginPath();
        ctx.moveTo(10, 220);
        ctx.lineTo(88, 285);
        ctx.moveTo(w - 10, 220);
        ctx.lineTo(w - 88, 285);
        ctx.stroke();
      } else if (variant === 'premium') {
        // Ekonomi Premium: Vertical center seam on upper headrest + 3 horizontal lumbar cushion seams
        ctx.strokeStyle = pal[2];
        ctx.lineWidth = 5;
        ctx.beginPath();
        ctx.moveTo(w / 2, 14);
        ctx.lineTo(w / 2, 210);
        ctx.stroke();

        for (const ry of [210, 286, 362, 438]) {
          ctx.strokeStyle = pal[2];
          ctx.lineWidth = 5;
          ctx.beginPath();
          ctx.moveTo(14, ry);
          ctx.lineTo(w - 14, ry);
          ctx.stroke();

          ctx.strokeStyle = 'rgba(255,255,255,0.12)';
          ctx.lineWidth = 2;
          ctx.beginPath();
          ctx.moveTo(14, ry + 4);
          ctx.lineTo(w - 14, ry + 4);
          ctx.stroke();
        }
      } else if (variant === 'eko23') {
        // Ekonomi 2-3: Smooth bench vinyl with subtle horizontal crease at 28% from top
        ctx.strokeStyle = pal[2];
        ctx.lineWidth = 3.5;
        ctx.beginPath();
        ctx.moveTo(8, 145);
        ctx.lineTo(w - 8, 145);
        ctx.stroke();

        ctx.strokeStyle = 'rgba(255,255,255,0.12)';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(8, 149);
        ctx.lineTo(w - 8, 149);
        ctx.stroke();
      }
    }
  });
}

export function getKAIWoodTexture(variant = 'teak') {
  const key = `kai-wood:${variant}`;
  return makeCanvasTex(key, 256, 256, (ctx, w, h) => {
    const grad = ctx.createLinearGradient(0, 0, w, h);
    if (variant === 'teak') {
      grad.addColorStop(0, '#A8703E');
      grad.addColorStop(0.5, '#966132');
      grad.addColorStop(1, '#7E4F26');
    } else if (variant === 'mahogany') {
      grad.addColorStop(0, '#7C422B');
      grad.addColorStop(0.5, '#64321E');
      grad.addColorStop(1, '#4E2414');
    } else if (variant === 'burl') {
      grad.addColorStop(0, '#4A3020');
      grad.addColorStop(0.5, '#382216');
      grad.addColorStop(1, '#26160D');
    } else {
      grad.addColorStop(0, '#8C6240');
      grad.addColorStop(0.5, '#785234');
      grad.addColorStop(1, '#634228');
    }
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, w, h);

    ctx.strokeStyle = 'rgba(30, 14, 5, 0.28)';
    ctx.lineWidth = 2;
    for (let i = 0; i < 48; i++) {
      const y = (i * 6) % h;
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.bezierCurveTo(w * 0.33, y + 3, w * 0.66, y - 3, w, y + 1);
      ctx.stroke();
    }
  });
}

export function getPleatedCurtainTexture() {
  return makeCanvasTex('kai-blue-curtain', 256, 256, (ctx, w, h) => {
    for (let x = 0; x < w; x++) {
      const wave = Math.sin((x / w) * Math.PI * 14);
      const r = Math.round(24 + wave * 10);
      const g = Math.round(66 + wave * 18);
      const b = Math.round(182 + wave * 28);
      ctx.fillStyle = `rgb(${r},${g},${b})`;
      ctx.fillRect(x, 0, 1, h);
    }
  });
}

export function getSoftShadowTexture() {
  return makeCanvasTex('kai-soft-shadow', 256, 256, (ctx, w, h) => {
    ctx.clearRect(0, 0, w, h);
    const grad = ctx.createRadialGradient(w / 2, h / 2, 8, w / 2, h / 2, w * 0.46);
    grad.addColorStop(0, 'rgba(0, 0, 0, 0.34)');
    grad.addColorStop(0.55, 'rgba(0, 0, 0, 0.14)');
    grad.addColorStop(1, 'rgba(0, 0, 0, 0)');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, w, h);
  });
}

// ============================================================================
// Sculpted Geometry Helpers (Cached for Instantaneous <15ms Scene Creation!)
// ============================================================================
const roundedBoxCache = new Map();

function createRoundedBox(width, height, depth, radius = 0.022) {
  const key = `${width.toFixed(4)}:${height.toFixed(4)}:${depth.toFixed(4)}:${radius.toFixed(4)}`;
  if (roundedBoxCache.has(key)) return roundedBoxCache.get(key);

  const r = Math.min(radius, width * 0.45, height * 0.45, depth * 0.45);
  const shape = new THREE.Shape();
  const hw = width / 2 - r;
  const hh = height / 2 - r;
  shape.moveTo(-hw, -height / 2);
  shape.lineTo(hw, -height / 2);
  shape.quadraticCurveTo(width / 2, -height / 2, width / 2, -hh);
  shape.lineTo(width / 2, hh);
  shape.quadraticCurveTo(width / 2, height / 2, hw, height / 2);
  shape.lineTo(-hw, height / 2);
  shape.quadraticCurveTo(-width / 2, height / 2, -width / 2, hh);
  shape.lineTo(-width / 2, -hh);
  shape.quadraticCurveTo(-width / 2, -height / 2, -hw, -height / 2);

  const geo = new THREE.ExtrudeGeometry(shape, {
    depth: Math.max(depth - r * 2, 0.008),
    bevelEnabled: true,
    bevelSegments: 3,
    steps: 1,
    bevelSize: r,
    bevelThickness: r
  });
  geo.center();

  const pos = geo.attributes.position;
  const uv = geo.attributes.uv;
  for (let i = 0; i < pos.count; i++) {
    const u = (pos.getX(i) + width / 2) / width;
    const v = (pos.getY(i) + height / 2) / height;
    uv.setXY(i, Math.max(0, Math.min(1, u)), Math.max(0, Math.min(1, v)));
  }
  geo.computeVertexNormals();
  roundedBoxCache.set(key, geo);
  return geo;
}

function createUnavailableBadge() {
  const tex = makeCanvasTex('kai-unavail-badge', 128, 128, (ctx) => {
    ctx.clearRect(0, 0, 128, 128);
    ctx.strokeStyle = '#CB3A64';
    ctx.lineWidth = 14;
    ctx.beginPath();
    ctx.arc(64, 64, 46, 0, Math.PI * 2);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(32, 96);
    ctx.lineTo(96, 32);
    ctx.stroke();
  });
  const mat = new THREE.MeshBasicMaterial({
    map: tex,
    transparent: true,
    opacity: 0,
    depthWrite: false,
    side: THREE.DoubleSide
  });
  const mesh = new THREE.Mesh(new THREE.PlaneGeometry(0.27, 0.27), mat);
  mesh.rotation.x = -Math.PI / 3;
  mesh.position.set(0, 0.69, 0.08);
  return { mesh, mat };
}

// ============================================================================
// 1 & 2. KAI Next Gen Seat (Eksekutif Maroon 2-2 & Ekonomi New Gen Biru 2-2)
// ============================================================================
export function buildKAINextGenSeat(variant = 'maroon', isPairA = true, withShadowPlane = false) {
  const root = new THREE.Group();
  const centerMats = [];
  const bolsterMats = [];
  const stateNodes = [];

  const makeMat = (part = 'center') => {
    const tex = getKAILeatherTexture(variant, 'normal', part);
    const mat = createKAIMaterial({
      map: tex,
      roughness: 0.48,
      metalness: 0.06
    });
    if (part === 'bolster') bolsterMats.push(mat);
    else centerMats.push(mat);
    return mat;
  };

  if (withShadowPlane) {
    const sh = new THREE.Mesh(
      new THREE.PlaneGeometry(1.75, 1.75),
      new THREE.MeshBasicMaterial({
        map: getSoftShadowTexture(),
        transparent: true,
        depthWrite: false
      })
    );
    sh.rotation.x = -Math.PI / 2;
    sh.position.set(0, 0.002, 0);
    root.add(sh);
  }

  // Pedestal Base & Footrest
  const darkBaseMat = createKAIMaterial({ color: 0x22252d, roughness: 0.6, metalness: 0.25 });
  const ped = new THREE.Mesh(createRoundedBox(0.36, 0.2, 0.34, 0.015), darkBaseMat);
  ped.position.set(0, 0.1, -0.05);
  root.add(ped);

  const footRest = new THREE.Mesh(createRoundedBox(0.36, 0.036, 0.16, 0.01), makeMat('bolster'));
  footRest.position.set(0, 0.11, 0.2);
  root.add(footRest);

  // Contoured Seat Cushion (Center Ribbed Pad + Raised Side Thigh Bolsters)
  const cushionGroup = new THREE.Group();
  cushionGroup.position.set(0, 0.245, 0.03);

  const centerCushion = new THREE.Mesh(
    createRoundedBox(0.34, 0.46, 0.115, 0.032),
    makeMat(variant === 'blueDualTone' ? 'bolster' : 'center')
  );
  centerCushion.rotation.x = Math.PI / 2;
  cushionGroup.add(centerCushion);

  const thighBolsterGeo = createRoundedBox(0.095, 0.48, 0.132, 0.034);
  for (const side of [-1, 1]) {
    const tb = new THREE.Mesh(thighBolsterGeo, makeMat('bolster'));
    tb.rotation.x = Math.PI / 2;
    tb.position.set(side * 0.19, 0.014, 0);
    cushionGroup.add(tb);
  }
  root.add(cushionGroup);

  // Sculpted 3-Column Ergonomic Backrest + Organic Winged Headrest Ears ("Telinga" Sandaran)
  const backrestGroup = new THREE.Group();
  const baseBackPos = new THREE.Vector3(0, 0.295, -0.165);
  const normalQuat = new THREE.Quaternion().setFromEuler(new THREE.Euler(-0.15, 0, 0, 'ZYX'));
  const reclineQuat = new THREE.Quaternion().setFromEuler(new THREE.Euler(-0.42, 0, 0, 'ZYX'));
  backrestGroup.position.copy(baseBackPos);
  backrestGroup.quaternion.copy(normalQuat);

  const centerSpine = new THREE.Mesh(
    createRoundedBox(0.31, 0.77, 0.105, 0.036),
    makeMat('center')
  );
  centerSpine.position.set(0, 0.39, 0);
  backrestGroup.add(centerSpine);

  const backBolsterGeo = createRoundedBox(0.095, 0.75, 0.125, 0.036);
  for (const side of [-1, 1]) {
    const bb = new THREE.Mesh(backBolsterGeo, makeMat('bolster'));
    bb.position.set(side * 0.18, 0.385, 0.018);
    bb.rotation.y = -side * 0.14;
    backrestGroup.add(bb);
  }

  // Forward-Curving Winged Headrest Ears ("Telinga" Sandaran Kepala)
  const earGeo = createRoundedBox(0.095, 0.27, 0.165, 0.042);
  for (const side of [-1, 1]) {
    const ear = new THREE.Mesh(earGeo, makeMat('bolster'));
    ear.position.set(side * 0.205, 0.635, 0.068);
    ear.rotation.set(0.06, -side * 0.5, side * 0.09);
    backrestGroup.add(ear);
  }

  const topCrown = new THREE.Mesh(
    createRoundedBox(0.42, 0.085, 0.11, 0.035),
    makeMat('bolster')
  );
  topCrown.position.set(0, 0.765, 0.01);
  backrestGroup.add(topCrown);

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

  // Side Armrest Shell + Curved Wooden Top/Front Trim Rail + Silver Recline Button
  const woodVariant =
    variant === 'maroon'
      ? 'teak'
      : variant === 'blueDualTone'
      ? 'mahogany'
      : variant === 'eksekutifDualTone'
      ? 'burl'
      : 'walnut';
  const woodMat = createKAIMaterial({
    map: getKAIWoodTexture(woodVariant),
    roughness: variant === 'eksekutifDualTone' ? 0.25 : 0.38,
    metalness: 0.08
  });
  const shellColor =
    variant === 'maroon'
      ? 0x9aa3b2
      : variant === 'eksekutifDualTone'
      ? 0xdcd9cf
      : 0xc2c8d2;
  const recessColor =
    variant === 'maroon'
      ? 0x828b9a
      : variant === 'eksekutifDualTone'
      ? 0xc8c4ba
      : 0xacb2bd;
  const shellMat = createKAIMaterial({
    color: shellColor,
    roughness: 0.45,
    metalness: 0.15
  });
  const recessMat = createKAIMaterial({
    color: recessColor,
    roughness: 0.5,
    metalness: 0.12
  });
  const chromeMat = createKAIMaterial({
    color: 0xe4eaf2,
    roughness: 0.2,
    metalness: 0.8
  });

  const buildSidePanel = (sideSign) => {
    const g = new THREE.Group();
    const px = sideSign * 0.258;
    const shell = new THREE.Mesh(createRoundedBox(0.052, 0.35, 0.51, 0.022), shellMat);
    shell.position.set(px, 0.31, -0.01);
    g.add(shell);

    const recess = new THREE.Mesh(createRoundedBox(0.056, 0.21, 0.35, 0.016), recessMat);
    recess.position.set(px + sideSign * 0.002, 0.3, -0.01);
    g.add(recess);

    const woodTop = new THREE.Mesh(createRoundedBox(0.065, 0.044, 0.51, 0.016), woodMat);
    woodTop.position.set(px, 0.492, -0.005);
    g.add(woodTop);

    if (variant !== 'blueDualTone') {
      const woodFront = new THREE.Mesh(
        createRoundedBox(0.065, variant === 'eksekutifDualTone' ? 0.11 : 0.27, 0.054, 0.016),
        woodMat
      );
      woodFront.position.set(px, variant === 'eksekutifDualTone' ? 0.445 : 0.365, 0.232);
      g.add(woodFront);
    }

    if (variant === 'eksekutifDualTone') {
      // Silver recline lever plate embedded on top-front of dark burl-wood armrest (Image 3!)
      const topLever = new THREE.Mesh(createRoundedBox(0.042, 0.012, 0.065, 0.003), chromeMat);
      topLever.position.set(px, 0.515, 0.18);
      g.add(topLever);
    } else {
      const btn = new THREE.Mesh(createRoundedBox(0.028, 0.042, 0.016, 0.004), chromeMat);
      btn.position.set(px, 0.34, 0.26);
      g.add(btn);
    }

    return g;
  };

  if (withShadowPlane) {
    root.add(buildSidePanel(1));
    root.add(buildSidePanel(-1));
  } else {
    const outerSide = isPairA ? 1 : -1;
    root.add(buildSidePanel(outerSide));
    if (isPairA) {
      if (variant === 'blueDualTone' || variant === 'eksekutifDualTone') {
        // Fold-down center wooden-topped armrest between paired seats (Image 1 & Image 3!)
        const centerArmGroup = new THREE.Group();
        const armBase = new THREE.Mesh(createRoundedBox(0.044, 0.065, 0.42, 0.014), shellMat);
        armBase.position.set(-0.295, 0.44, 0.01);
        const armWoodCap = new THREE.Mesh(createRoundedBox(0.052, 0.032, 0.44, 0.012), woodMat);
        armWoodCap.position.set(-0.295, 0.482, 0.015);
        centerArmGroup.add(armBase, armWoodCap);
        root.add(centerArmGroup);
      } else {
        const divMat = createKAIMaterial({
          color: variant === 'maroon' ? 0xb8cbe0 : 0xe4e9f2,
          roughness: 0.4,
          metalness: 0.15
        });
        const divPaddle = new THREE.Mesh(
          createRoundedBox(0.036, 0.24, 0.26, 0.014),
          divMat
        );
        divPaddle.position.set(-0.295, 0.51, -0.08);
        divPaddle.rotation.x = -0.2;
        root.add(divPaddle);
      }
    }
  }

  const unavail = createUnavailableBadge();
  root.add(unavail.mesh);

  const applyCustomState = (state) => {
    const cTex = getKAILeatherTexture(variant, state, 'center');
    const bTex = getKAILeatherTexture(variant, state, 'bolster');
    centerMats.forEach((m) => {
      m.uniforms.uMap.value = cTex;
    });
    bolsterMats.forEach((m) => {
      m.uniforms.uMap.value = bTex;
    });
    unavail.mat.opacity = state === 'disabled' ? 1 : 0;
  };

  return { root, stateNodes, applyCustomState };
}

// ============================================================================
// 3. KAI Ekonomi Premium Seat (Taupe/Tan 2-2 + Open Curved Chrome Armrests)
// ============================================================================
export function buildKAIEkonomiPremiumSeat(isPairA = true, withShadowPlane = false) {
  const root = new THREE.Group();
  const centerMats = [];
  const bolsterMats = [];
  const stateNodes = [];

  const makeMat = (part = 'center') => {
    const tex = getKAILeatherTexture('premium', 'normal', part);
    const mat = createKAIMaterial({
      map: tex,
      roughness: 0.5,
      metalness: 0.05
    });
    if (part === 'bolster') bolsterMats.push(mat);
    else centerMats.push(mat);
    return mat;
  };

  if (withShadowPlane) {
    const sh = new THREE.Mesh(
      new THREE.PlaneGeometry(1.75, 1.75),
      new THREE.MeshBasicMaterial({
        map: getSoftShadowTexture(),
        transparent: true,
        depthWrite: false
      })
    );
    sh.rotation.x = -Math.PI / 2;
    sh.position.set(0, 0.002, 0);
    root.add(sh);
  }

  const chromeMat = createKAIMaterial({ color: 0xcfd6e0, roughness: 0.22, metalness: 0.78 });
  const darkMetalMat = createKAIMaterial({ color: 0x262930, roughness: 0.55, metalness: 0.3 });
  const espressoMat = createKAIMaterial({ color: 0x33251f, roughness: 0.42, metalness: 0.08 });

  const baseFrame = new THREE.Mesh(createRoundedBox(0.4, 0.18, 0.34, 0.015), darkMetalMat);
  baseFrame.position.set(0, 0.09, -0.04);
  root.add(baseFrame);

  // Plump Taupe/Tan Seat Cushion
  const cushionGroup = new THREE.Group();
  cushionGroup.position.set(0, 0.24, 0.03);
  const centerPad = new THREE.Mesh(
    createRoundedBox(0.35, 0.47, 0.12, 0.032),
    makeMat('center')
  );
  centerPad.rotation.x = Math.PI / 2;
  cushionGroup.add(centerPad);

  const sideBolsterGeo = createRoundedBox(0.09, 0.48, 0.135, 0.034);
  for (const side of [-1, 1]) {
    const sb = new THREE.Mesh(sideBolsterGeo, makeMat('bolster'));
    sb.rotation.x = Math.PI / 2;
    sb.position.set(side * 0.19, 0.012, 0);
    cushionGroup.add(sb);
  }
  root.add(cushionGroup);

  // High Flat-Top Contoured Backrest (Vertical Top Seam + 3 Lumbar Cushions, NO side ears!)
  const backrestGroup = new THREE.Group();
  const baseBackPos = new THREE.Vector3(0, 0.29, -0.17);
  const normalQuat = new THREE.Quaternion().setFromEuler(new THREE.Euler(-0.14, 0, 0, 'ZYX'));
  const reclineQuat = new THREE.Quaternion().setFromEuler(new THREE.Euler(-0.36, 0, 0, 'ZYX'));
  backrestGroup.position.copy(baseBackPos);
  backrestGroup.quaternion.copy(normalQuat);

  const centerBack = new THREE.Mesh(
    createRoundedBox(0.34, 0.79, 0.105, 0.036),
    makeMat('center')
  );
  centerBack.position.set(0, 0.4, 0);
  backrestGroup.add(centerBack);

  const backBolsterGeo = createRoundedBox(0.095, 0.79, 0.125, 0.036);
  for (const side of [-1, 1]) {
    const bb = new THREE.Mesh(backBolsterGeo, makeMat('bolster'));
    bb.position.set(side * 0.19, 0.4, 0.015);
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

  // Open Curved Armrests on Chrome Metal Support Posts + Round Recline Knob
  const buildOpenArmrest = (xPos) => {
    const g = new THREE.Group();
    g.position.set(xPos, 0, 0);

    const rearPost = new THREE.Mesh(createRoundedBox(0.026, 0.24, 0.044, 0.006), chromeMat);
    rearPost.position.set(0, 0.34, -0.15);
    g.add(rearPost);

    const frontPost = new THREE.Mesh(createRoundedBox(0.026, 0.24, 0.04, 0.006), chromeMat);
    frontPost.position.set(0, 0.33, 0.19);
    frontPost.rotation.x = 0.22;
    g.add(frontPost);

    const topPad = new THREE.Mesh(createRoundedBox(0.052, 0.042, 0.44, 0.015), espressoMat);
    topPad.position.set(0, 0.465, 0.02);
    g.add(topPad);

    const frontTip = new THREE.Mesh(createRoundedBox(0.052, 0.09, 0.05, 0.015), espressoMat);
    frontTip.position.set(0, 0.43, 0.22);
    frontTip.rotation.x = 0.35;
    g.add(frontTip);

    const knob = new THREE.Mesh(new THREE.CylinderGeometry(0.022, 0.022, 0.045, 14), darkMetalMat);
    knob.rotation.z = Math.PI / 2;
    knob.position.set(0, 0.31, 0.16);
    g.add(knob);

    return g;
  };

  if (withShadowPlane) {
    root.add(buildOpenArmrest(0.26));
    root.add(buildOpenArmrest(-0.26));
  } else if (isPairA) {
    root.add(buildOpenArmrest(0.26));
    root.add(buildOpenArmrest(-0.295));
  } else {
    root.add(buildOpenArmrest(-0.26));
  }

  const unavail = createUnavailableBadge();
  root.add(unavail.mesh);

  const applyCustomState = (state) => {
    const cTex = getKAILeatherTexture('premium', state, 'center');
    const bTex = getKAILeatherTexture('premium', state, 'bolster');
    centerMats.forEach((m) => {
      m.uniforms.uMap.value = cTex;
    });
    bolsterMats.forEach((m) => {
      m.uniforms.uMap.value = bTex;
    });
    unavail.mat.opacity = state === 'disabled' ? 1 : 0;
  };

  return { root, stateNodes, applyCustomState };
}

// ============================================================================
// 4. KAI Ekonomi 2-3 Bench Seat (Upright ~90° Cream Bench + Round Tubular Pipe Frame)
// ============================================================================
export function buildKAIEkonomi23Seat(seatRole = 'b', withShadowPlane = false) {
  const root = new THREE.Group();
  const vinylMats = [];

  const makeVinylMat = () => {
    const tex = getKAILeatherTexture('eko23', 'normal', 'center');
    const mat = createKAIMaterial({
      map: tex,
      roughness: 0.46,
      metalness: 0.04
    });
    vinylMats.push(mat);
    return mat;
  };

  if (withShadowPlane) {
    const sh = new THREE.Mesh(
      new THREE.PlaneGeometry(1.75, 1.75),
      new THREE.MeshBasicMaterial({
        map: getSoftShadowTexture(),
        transparent: true,
        depthWrite: false
      })
    );
    sh.rotation.x = -Math.PI / 2;
    sh.position.set(0, 0.002, 0);
    root.add(sh);
  }

  const pipeMat = createKAIMaterial({ color: 0xd0d7e0, roughness: 0.2, metalness: 0.82 });
  const blackArmMat = createKAIMaterial({ color: 0x24211f, roughness: 0.48, metalness: 0.08 });
  const w = withShadowPlane ? 0.92 : 0.495;

  // Flat Continuous Bench Cushion
  const cushion = new THREE.Mesh(
    createRoundedBox(w, 0.45, 0.11, 0.026),
    makeVinylMat()
  );
  cushion.rotation.x = Math.PI / 2;
  cushion.position.set(0, 0.25, 0.04);
  root.add(cushion);

  // Upright (~90°) Flat Bench Backrest (Cream/Khaki Vinyl)
  const backrest = new THREE.Mesh(
    createRoundedBox(w, 0.72, 0.09, 0.03),
    makeVinylMat()
  );
  backrest.position.set(0, 0.64, -0.14);
  backrest.rotation.x = -0.04;
  root.add(backrest);

  // Continuous Round Tubular Stainless-Steel Pipe Frame around Top & Outer Sides
  const pipeRadius = 0.014;
  const topPipe = new THREE.Mesh(
    new THREE.CylinderGeometry(pipeRadius, pipeRadius, w + 0.02, 16),
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

    const vPipe = new THREE.Mesh(
      new THREE.CylinderGeometry(pipeRadius, pipeRadius, 0.98, 16),
      pipeMat
    );
    vPipe.position.set(xEdge, 0.53, -0.155);
    g.add(vPipe);

    const frontLeg = new THREE.Mesh(
      new THREE.CylinderGeometry(pipeRadius, pipeRadius, 0.24, 16),
      pipeMat
    );
    frontLeg.position.set(xEdge, 0.12, 0.2);
    g.add(frontLeg);

    const bottomRunner = new THREE.Mesh(
      new THREE.CylinderGeometry(pipeRadius, pipeRadius, 0.36, 16),
      pipeMat
    );
    bottomRunner.rotation.x = Math.PI / 2;
    bottomRunner.position.set(xEdge, 0.02, 0.02);
    g.add(bottomRunner);

    const armFrontSupport = new THREE.Mesh(
      new THREE.CylinderGeometry(0.011, 0.011, 0.22, 14),
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

  const unavail = createUnavailableBadge();
  root.add(unavail.mesh);

  const applyCustomState = (state) => {
    const tex = getKAILeatherTexture('eko23', state, 'center');
    vinylMats.forEach((m) => {
      m.uniforms.uMap.value = tex;
    });
    unavail.mat.opacity = state === 'disabled' ? 1 : 0;
  };

  return { root, stateNodes: [], applyCustomState };
}

// ============================================================================
// 4B. KAI Ekonomi 2-3 Modifikasi (Turquoise/Tosca Scalloped 3-2 + Grey Box Base + Chrome Grab Handle)
// ============================================================================
export function buildKAIEkonomiTosca23Seat(seatRole = 'b', withShadowPlane = false) {
  const root = new THREE.Group();
  const leatherMats = [];

  const makeToscaMat = (part = 'center') => {
    const tex = getKAILeatherTexture('ekoTosca', 'normal', part);
    const mat = createKAIMaterial({
      map: tex,
      roughness: 0.44,
      metalness: 0.05
    });
    leatherMats.push({ mat, part });
    return mat;
  };

  if (withShadowPlane) {
    const sh = new THREE.Mesh(
      new THREE.PlaneGeometry(1.75, 1.75),
      new THREE.MeshBasicMaterial({
        map: getSoftShadowTexture(),
        transparent: true,
        depthWrite: false
      })
    );
    sh.rotation.x = -Math.PI / 2;
    sh.position.set(0, 0.002, 0);
    root.add(sh);
  }

  const greyBoxMat = createKAIMaterial({ color: 0x5c626b, roughness: 0.5, metalness: 0.25 });
  const blackBracketMat = createKAIMaterial({ color: 0x1d2026, roughness: 0.45, metalness: 0.4 });
  const chromeMat = createKAIMaterial({ color: 0xdce2ea, roughness: 0.18, metalness: 0.85 });

  const buildSingleScallopedSeat = (xOffset, showLeftBox, showRightBox, showLeftGrab, showRightGrab) => {
    const g = new THREE.Group();
    g.position.set(xOffset, 0, 0);
    const sw = 0.485;

    // 1. Plump Turquoise Seat Cushion
    const cushion = new THREE.Mesh(
      createRoundedBox(sw, 0.46, 0.12, 0.03),
      makeToscaMat('center')
    );
    cushion.rotation.x = Math.PI / 2;
    cushion.position.set(0, 0.25, 0.04);
    g.add(cushion);

    // 2. Scalloped Arched Backrest (Main body + Rounded Scalloped Crown at Top!)
    const backMain = new THREE.Mesh(
      createRoundedBox(sw, 0.64, 0.105, 0.032),
      makeToscaMat('center')
    );
    backMain.position.set(0, 0.58, -0.14);
    backMain.rotation.x = -0.08;
    g.add(backMain);

    const scallopedCrown = new THREE.Mesh(
      createRoundedBox(sw * 0.84, 0.22, 0.102, 0.075),
      makeToscaMat('bolster')
    );
    scallopedCrown.position.set(0, 0.91, -0.165);
    scallopedCrown.rotation.x = -0.08;
    g.add(scallopedCrown);

    // 3. Dark-Grey Rectangular Side Box Armrest/Base + Black Pivot Hinge Bracket with 2 Silver Bolts (Image 2!)
    const addSideBox = (sideSign) => {
      const bx = sideSign * (sw / 2 + 0.022);
      const box = new THREE.Mesh(createRoundedBox(0.052, 0.21, 0.49, 0.015), greyBoxMat);
      box.position.set(bx, 0.21, 0.02);
      g.add(box);

      const bracket = new THREE.Mesh(createRoundedBox(0.058, 0.14, 0.065, 0.008), blackBracketMat);
      bracket.position.set(bx, 0.29, -0.15);
      g.add(bracket);

      for (const by of [0.26, 0.31]) {
        const bolt = new THREE.Mesh(new THREE.CylinderGeometry(0.009, 0.009, 0.066, 10), chromeMat);
        bolt.rotation.z = Math.PI / 2;
        bolt.position.set(bx, by, -0.15);
        g.add(bolt);
      }
    };

    if (showLeftBox) addSideBox(-1);
    if (showRightBox) addSideBox(1);

    // 4. Curved Chrome Corner Grab Handle on Top Aisle Corner of Backrest (Image 2!)
    const addCornerGrab = (sideSign) => {
      const torus = new THREE.Mesh(
        new THREE.TorusGeometry(0.068, 0.011, 12, 20, Math.PI * 1.15),
        chromeMat
      );
      torus.position.set(sideSign * (sw * 0.38), 0.96, -0.165);
      torus.rotation.z = sideSign === -1 ? Math.PI * 0.35 : -Math.PI * 0.45;
      g.add(torus);
    };

    if (showLeftGrab) addCornerGrab(-1);
    if (showRightGrab) addCornerGrab(1);

    return g;
  };

  if (withShadowPlane) {
    // Standalone 3D preview shows a 2-seat Scalloped Tosca unit with side boxes & chrome grab handle
    root.add(buildSingleScallopedSeat(-0.245, true, false, true, false));
    root.add(buildSingleScallopedSeat(0.245, false, true, false, true));
  } else {
    const hasLeftEnd = seatRole === 'c' || seatRole === 'e';
    const hasRightEnd = seatRole === 'a' || seatRole === 'd';
    const hasLeftGrab = seatRole === 'c';
    const hasRightGrab = seatRole === 'd';
    root.add(
      buildSingleScallopedSeat(0, hasLeftEnd, hasRightEnd, hasLeftGrab, hasRightGrab)
    );
  }

  const unavail = createUnavailableBadge();
  root.add(unavail.mesh);

  const applyCustomState = (state) => {
    const cTex = getKAILeatherTexture('ekoTosca', state, 'center');
    const bTex = getKAILeatherTexture('ekoTosca', state, 'bolster');
    leatherMats.forEach(({ mat, part }) => {
      mat.uniforms.uMap.value = part === 'bolster' ? bTex : cTex;
    });
    unavail.mat.opacity = state === 'disabled' ? 1 : 0;
  };

  return { root, stateNodes: [], applyCustomState };
}

// ============================================================================
// 5. Pure KAI 3D Cabin Sections, Panoramic Windows, Overhead Racks & Bulkheads
// (Replaces 100% of Shinkansen .scn cabin walls, windows, floors & partitions!)
// ============================================================================
export function buildKAICabinSection(modelName) {
  const group = new THREE.Group();
  const isOrd23 = modelName.startsWith('e7-ordinary-');
  const isTosca23 = modelName.startsWith('kai-tosca-');
  const isBlue = modelName.startsWith('kai-blue-') || modelName.startsWith('e7-green-');
  const isPrem = modelName.startsWith('kai-prem-');
  const bayLen = isOrd23 || isTosca23 ? 1.04 : 1.175;

  const floorColors = isOrd23
    ? { side: 0x7ea06e, aisle: 0x84a674, led: 0xf4f7f2 }
    : isTosca23
    ? { side: 0x767b82, aisle: 0x848990, led: 0xe8edf2 }
    : isBlue
    ? { side: 0x8d949e, aisle: 0x9da4ae, led: 0xfffce0 }
    : isPrem
    ? { side: 0x5c5552, aisle: 0x69615d, led: 0xc4f5ae }
    : { side: 0x626770, aisle: 0x747a84, led: 0xdffbe4 };

  const sideFloorMat = createKAIMaterial({ color: floorColors.side, roughness: 0.7, metalness: 0.05 });
  const aisleFloorMat = createKAIMaterial({ color: floorColors.aisle, roughness: 0.55, metalness: 0.08 });
  const wallCreamMat = createKAIMaterial({ color: 0xeae6df, roughness: 0.6, metalness: 0.04 });
  const extSteelMat = createKAIMaterial({ color: 0xc4c8d0, roughness: 0.35, metalness: 0.55 });
  const winFrameMat = isTosca23
    ? createKAIMaterial({ map: getKAIWoodTexture('teak'), roughness: 0.4, metalness: 0.08 })
    : createKAIMaterial({ color: 0x262a32, roughness: 0.5, metalness: 0.25 });
  const glassMat = new THREE.MeshBasicMaterial({
    color: 0x242c38,
    transparent: true,
    opacity: 0.24,
    depthWrite: false,
    side: THREE.DoubleSide
  });

  // 1. Floor (Under-seat left/right + central aisle + glowing LED aisle strips)
  const aisleW = isOrd23 || isTosca23 ? 0.46 : 0.52;
  const sideW = (3.08 - aisleW) / 2;

  for (const side of [-1, 1]) {
    const fSide = new THREE.Mesh(new THREE.BoxGeometry(sideW, 0.06, bayLen), sideFloorMat);
    fSide.position.set(side * (aisleW / 2 + sideW / 2), 1.3, 0);
    group.add(fSide);
  }
  const fAisle = new THREE.Mesh(new THREE.BoxGeometry(aisleW, 0.06, bayLen), aisleFloorMat);
  fAisle.position.set(0, 1.3, 0);
  group.add(fAisle);

  const ledGeo = new THREE.PlaneGeometry(0.028, bayLen);
  const ledMat = new THREE.MeshBasicMaterial({ color: floorColors.led, side: THREE.DoubleSide });
  for (const side of [-1, 1]) {
    const led = new THREE.Mesh(ledGeo, ledMat);
    led.rotation.x = -Math.PI / 2;
    led.position.set(side * (aisleW / 2), 1.332, 0);
    group.add(led);
  }

  // 2. KAI Cabin Side Walls + Wide Rectangular Panoramic Windows (NOT Shinkansen oval windows!)
  for (const side of [-1, 1]) {
    const wallX = side * 1.56;
    const extX = side * 1.66;

    // Lower wall below window (in Ekonomi 2-3, brushed stainless-steel wainscoting!)
    const lowerWallMat = isOrd23
      ? createKAIMaterial({ color: 0xbac2cc, roughness: 0.3, metalness: 0.65 })
      : wallCreamMat;
    const lowerWall = new THREE.Mesh(new THREE.BoxGeometry(0.08, 0.48, bayLen), lowerWallMat);
    lowerWall.position.set(wallX, 1.54, 0);
    group.add(lowerWall);

    // Upper cutaway wall header above window + dark top rail
    const upperWall = new THREE.Mesh(new THREE.BoxGeometry(0.11, 0.22, bayLen), wallCreamMat);
    upperWall.position.set(wallX, 2.54, 0);
    group.add(upperWall);

    const topCutawayCap = new THREE.Mesh(new THREE.BoxGeometry(0.18, 0.04, bayLen), winFrameMat);
    topCutawayCap.position.set(wallX, 2.66, 0);
    group.add(topCutawayCap);

    // Window Pillars (left & right of the wide rectangular KAI panoramic window)
    const pillarW = 0.14;
    for (const pz of [-bayLen / 2 + pillarW / 2, bayLen / 2 - pillarW / 2]) {
      const pillar = new THREE.Mesh(new THREE.BoxGeometry(0.11, 0.66, pillarW), wallCreamMat);
      pillar.position.set(wallX, 2.11, pz);
      group.add(pillar);
    }

    // Wide Rectangular KAI Panoramic Window Frame + Glass Sill
    const winLen = bayLen - pillarW * 2;
    const frameTop = new THREE.Mesh(new THREE.BoxGeometry(0.13, 0.045, winLen), winFrameMat);
    frameTop.position.set(wallX, 2.41, 0);
    const frameBot = new THREE.Mesh(new THREE.BoxGeometry(0.14, 0.05, winLen), winFrameMat);
    frameBot.position.set(wallX, 1.79, 0);
    group.add(frameTop, frameBot);

    const glass = new THREE.Mesh(new THREE.PlaneGeometry(winLen, 0.58), glassMat);
    glass.rotation.y = Math.PI / 2;
    glass.position.set(wallX, 2.1, 0);
    group.add(glass);

    // Class-specific window & wall accessories
    if (isOrd23) {
      // Bright Royal-Blue Pleated Curtain + White Folding Wall Table (Image 3!)
      const curtainMat = createKAIMaterial({
        map: getPleatedCurtainTexture(),
        roughness: 0.65,
        metalness: 0.02
      });
      const curtain = new THREE.Mesh(new THREE.BoxGeometry(0.045, 0.62, winLen * 0.85), curtainMat);
      curtain.position.set(side * 1.5, 2.12, 0);
      group.add(curtain);

      const miniTable = new THREE.Mesh(
        createRoundedBox(0.14, 0.028, 0.32, 0.008),
        createKAIMaterial({ color: 0xf2f4f7, roughness: 0.4 })
      );
      miniTable.position.set(side * 1.46, 1.74, 0);
      group.add(miniTable);
    } else if (isPrem) {
      // Ekonomi Premium: White dual-socket power outlet shelf under window (Image 2!)
      const socketShelf = new THREE.Mesh(
        createRoundedBox(0.08, 0.075, 0.24, 0.01),
        createKAIMaterial({ color: 0xe2e6ee, roughness: 0.4 })
      );
      socketShelf.position.set(side * 1.49, 1.75, 0);
      group.add(socketShelf);
    }

    // Exterior Corrugated Stainless Steel Coach Shell + Argo Bromo Anggrek Livery Stripe
    const extWall = new THREE.Mesh(new THREE.BoxGeometry(0.06, 1.5, bayLen), extSteelMat);
    extWall.position.set(extX, 1.35, 0);
    group.add(extWall);

    const stripeColor = isOrd23 ? 0xf37021 : 0xd82b79;
    const stripe = new THREE.Mesh(
      new THREE.PlaneGeometry(bayLen, 0.22),
      new THREE.MeshBasicMaterial({ color: stripeColor, side: THREE.DoubleSide })
    );
    stripe.rotation.y = Math.PI / 2;
    stripe.position.set(side * 1.695, 1.02, 0);
    group.add(stripe);
  }

  return group;
}

export function buildKAIPartitionBulkhead(modelName) {
  const group = new THREE.Group();
  const isOrd23 = modelName.startsWith('e7-ordinary-');
  const wallMat = createKAIMaterial({ color: 0xe6e2da, roughness: 0.58 });
  const extSteelMat = createKAIMaterial({ color: 0xc4c8d0, roughness: 0.35, metalness: 0.55 });
  const darkFrameMat = createKAIMaterial({ color: 0x1e222a, roughness: 0.4, metalness: 0.3 });

  // Outer stainless steel ring
  const outerBox = new THREE.Mesh(new THREE.BoxGeometry(3.36, 2.15, 0.12), extSteelMat);
  outerBox.position.set(0, 1.68, 0);
  group.add(outerBox);

  // Left & Right Interior Bulkhead Walls (leaving center doorway open)
  for (const side of [-1, 1]) {
    const wPanel = new THREE.Mesh(new THREE.BoxGeometry(1.18, 1.42, 0.14), wallMat);
    wPanel.position.set(side * 0.94, 2.02, 0);
    group.add(wPanel);
  }
  const topHeader = new THREE.Mesh(new THREE.BoxGeometry(0.76, 0.32, 0.14), wallMat);
  topHeader.position.set(0, 2.57, 0);
  group.add(topHeader);

  // Automatic Sliding Door Frame + Glass + Yellow Safety Decal
  const doorFrame = new THREE.Mesh(new THREE.BoxGeometry(0.68, 1.36, 0.15), darkFrameMat);
  doorFrame.position.set(0, 1.99, 0);
  group.add(doorFrame);

  const doorGlass = new THREE.Mesh(
    new THREE.BoxGeometry(0.44, 0.92, 0.16),
    new THREE.MeshBasicMaterial({ color: 0x384657 })
  );
  doorGlass.position.set(0, 2.06, 0);
  group.add(doorGlass);

  const yellowDecal = new THREE.Mesh(
    new THREE.BoxGeometry(0.09, 0.28, 0.165),
    new THREE.MeshBasicMaterial({ color: 0xf2c935 })
  );
  yellowDecal.position.set(0, 2.08, 0);
  group.add(yellowDecal);

  // Left & Right PIDS LCD Monitors + Top Digital LED Running Text Board
  if (!isOrd23) {
    const bezelMat = createKAIMaterial({ color: 0xc8c4ba, roughness: 0.45 });
    for (const side of [-1, 1]) {
      const bezel = new THREE.Mesh(new THREE.BoxGeometry(0.6, 0.4, 0.155), bezelMat);
      bezel.position.set(side * 0.88, 2.26, 0);
      group.add(bezel);

      const scrColor = side === -1 ? 0x1254a1 : 0x5c8a66;
      const scr = new THREE.Mesh(
        new THREE.BoxGeometry(0.5, 0.3, 0.162),
        new THREE.MeshBasicMaterial({ color: scrColor })
      );
      scr.position.set(side * 0.88, 2.26, 0);
      group.add(scr);
    }
  }

  const ledBoard = new THREE.Mesh(
    new THREE.BoxGeometry(1.38, 0.15, 0.16),
    new THREE.MeshBasicMaterial({ color: 0x14161c })
  );
  ledBoard.position.set(0, 2.62, 0);
  group.add(ledBoard);

  const ledTextLine = new THREE.Mesh(
    new THREE.BoxGeometry(0.92, 0.045, 0.166),
    new THREE.MeshBasicMaterial({ color: isOrd23 ? 0xff453a : 0x35e06c })
  );
  ledTextLine.position.set(0, 2.62, 0);
  group.add(ledTextLine);

  return group;
}

export function buildKAIVestibuleOrGangway(modelName) {
  const group = new THREE.Group();
  const extSteelMat = createKAIMaterial({ color: 0xc4c8d0, roughness: 0.35, metalness: 0.55 });
  const floorMat = createKAIMaterial({ color: 0x5d626b, roughness: 0.65 });
  const darkRubberMat = createKAIMaterial({ color: 0x262930, roughness: 0.75 });
  const yellowTactileMat = createKAIMaterial({ color: 0xe5c138, roughness: 0.5 });

  if (modelName === 'e7-gangway') {
    // KAI Rubber Accordion Diaphragm Gangway (Bordes Sambungan Antargerbong)
    const gangwayBox = new THREE.Mesh(new THREE.BoxGeometry(2.6, 2.1, 1.35), darkRubberMat);
    gangwayBox.position.set(0, 1.65, 0);
    group.add(gangwayBox);
    const bridgeFloor = new THREE.Mesh(new THREE.BoxGeometry(1.2, 0.08, 1.35), floorMat);
    bridgeFloor.position.set(0, 1.3, 0);
    group.add(bridgeFloor);
    return group;
  }

  const len = modelName.includes('multipurpose') ? 1.8 : 1.15;
  const fMesh = new THREE.Mesh(new THREE.BoxGeometry(3.12, 0.06, len), floorMat);
  fMesh.position.set(0, 1.3, 0);
  group.add(fMesh);

  if (modelName.includes('entrance')) {
    for (const side of [-1, 1]) {
      const matPlate = new THREE.Mesh(new THREE.BoxGeometry(0.55, 0.065, 0.8), yellowTactileMat);
      matPlate.position.set(side * 1.22, 1.305, 0);
      group.add(matPlate);
    }
  }

  for (const side of [-1, 1]) {
    const wall = new THREE.Mesh(new THREE.BoxGeometry(0.1, 1.45, len), extSteelMat);
    wall.position.set(side * 1.61, 1.98, 0);
    group.add(wall);
  }

  return group;
}

export function buildKAIMainFloorShadow() {
  const group = new THREE.Group();
  const shTex = makeCanvasTex('kai-train-strip-shadow', 256, 64, (ctx, w, h) => {
    const grad = ctx.createLinearGradient(0, 0, w, 0);
    grad.addColorStop(0, 'rgba(0,0,0,0)');
    grad.addColorStop(0.28, 'rgba(0,0,0,0.06)');
    grad.addColorStop(0.38, 'rgba(0,0,0,0.28)');
    grad.addColorStop(0.5, 'rgba(0,0,0,0.35)');
    grad.addColorStop(0.62, 'rgba(0,0,0,0.28)');
    grad.addColorStop(0.72, 'rgba(0,0,0,0.06)');
    grad.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, w, h);
  });
  const mat = new THREE.MeshBasicMaterial({
    map: shTex,
    transparent: true,
    depthWrite: false
  });
  const plane = new THREE.Mesh(new THREE.PlaneGeometry(7.2, 225), mat);
  plane.rotation.x = -Math.PI / 2;
  plane.position.set(0, 0.01, -100);
  group.add(plane);
  return group;
}

export function buildKAICoachEndChassis() {
  const group = new THREE.Group();
  const bodyMat = createKAIMaterial({ color: 0xc4c8cf, roughness: 0.35, metalness: 0.6 });
  const roofMat = createKAIMaterial({ color: 0xb4b8c0, roughness: 0.45, metalness: 0.45 });
  const darkBandMat = createKAIMaterial({ color: 0x23262e, roughness: 0.5 });
  const magentaMat = new THREE.MeshBasicMaterial({ color: 0xd82b79, side: THREE.DoubleSide });
  const bogieMat = createKAIMaterial({ color: 0x2c3038, roughness: 0.6, metalness: 0.3 });

  const bodyBox = new THREE.Mesh(new THREE.BoxGeometry(3.36, 1.5, 8.2), bodyMat);
  bodyBox.position.set(0, 1.38, -3.5);
  group.add(bodyBox);

  const roofBox = new THREE.Mesh(createRoundedBox(3.32, 0.36, 8.2, 0.12), roofMat);
  roofBox.position.set(0, 2.3, -3.5);
  group.add(roofBox);

  for (const acZ of [-1.2, -3.5, -5.8]) {
    const acPod = new THREE.Mesh(createRoundedBox(1.85, 0.24, 1.45, 0.05), bodyMat);
    acPod.position.set(0, 2.55, acZ);
    group.add(acPod);
  }

  for (const side of [-1, 1]) {
    const winBand = new THREE.Mesh(new THREE.PlaneGeometry(7.8, 0.52), darkBandMat);
    winBand.rotation.y = side * (Math.PI / 2);
    winBand.position.set(side * 1.685, 1.62, -3.5);
    group.add(winBand);

    const magStripe = new THREE.Mesh(new THREE.PlaneGeometry(7.8, 0.22), magentaMat);
    magStripe.rotation.y = side * (Math.PI / 2);
    magStripe.position.set(side * 1.685, 1.02, -3.5);
    group.add(magStripe);
  }

  for (const bz of [-1.5, -5.5]) {
    const bogie = new THREE.Mesh(new THREE.BoxGeometry(2.8, 0.42, 1.8), bogieMat);
    bogie.position.set(0, 0.28, bz);
    group.add(bogie);
  }

  return group;
}
