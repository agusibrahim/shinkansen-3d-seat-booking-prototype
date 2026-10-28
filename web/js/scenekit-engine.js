import * as THREE from './vendor/three.module.min.js';
import {
  buildKAINextGenSeat,
  buildKAIEkonomiPremiumSeat,
  buildKAIEkonomi23Seat,
  buildKAIEkonomiTosca23Seat,
  buildKAICabinSection,
  buildKAIPartitionBulkhead,
  buildKAIVestibuleOrGangway,
  buildKAIMainFloorShadow,
  buildKAICoachEndChassis
} from './kai-models.js';

// Shared Texture Cache (with SceneKit top-left UV convention: flipY = false)
const textureCache = new Map();

// 1x1 white canvas so textures are white (1,1,1,1) before async image load finishes
const placeholderCanvas = document.createElement('canvas');
placeholderCanvas.width = 1;
placeholderCanvas.height = 1;
const pCtx = placeholderCanvas.getContext('2d');
pCtx.fillStyle = '#ffffff';
pCtx.fillRect(0, 0, 1, 1);

function getTexture(path) {
  if (!path) return null;
  if (textureCache.has(path)) return textureCache.get(path);
  const tex = new THREE.Texture(placeholderCanvas);
  tex.flipY = false;
  tex.colorSpace = THREE.LinearSRGBColorSpace;
  tex.wrapS = THREE.ClampToEdgeWrapping;
  tex.wrapT = THREE.ClampToEdgeWrapping;
  tex.minFilter = THREE.LinearMipmapLinearFilter;
  tex.magFilter = THREE.LinearFilter;
  tex.needsUpdate = true;

  const loadImg = (attempt = 0) => {
    const img = new Image();
    img.onload = () => {
      tex.image = img;
      tex.needsUpdate = true;
    };
    img.onerror = () => {
      if (attempt < 2) {
        setTimeout(() => loadImg(attempt + 1), 150);
      }
    };
    img.src = path;
  };
  loadImg();

  textureCache.set(path, tex);
  return tex;
}

// White 1x1 fallback texture
const whiteData = new Uint8Array([255, 255, 255, 255]);
const whiteTexture = new THREE.DataTexture(whiteData, 1, 1, THREE.RGBAFormat);
whiteTexture.needsUpdate = true;

// SceneKit Constant Lighting Shader Material
const SCN_VERTEX_SHADER = `
  varying vec2 vUv;
  void main() {
    vUv = uv;
    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
  }
`;

const SCN_FRAGMENT_SHADER = `
  uniform vec4 uDiffuseColor;
  uniform sampler2D uMultiplyMap;
  uniform bool uHasMultiplyMap;
  uniform vec4 uMultiplyColor;
  uniform float uMultiplyIntensity;
  uniform sampler2D uTransparentMap;
  uniform bool uHasTransparentMap;
  uniform float uTransparency;
  uniform int uTransparencyMode;
  uniform int uBlendMode;

  varying vec2 vUv;

  void main() {
    vec4 diff = uDiffuseColor;
    vec3 multSample = uHasMultiplyMap ? texture2D(uMultiplyMap, vUv).rgb : uMultiplyColor.rgb;
    vec3 multFactor = mix(vec3(1.0), multSample, uMultiplyIntensity);
    vec3 finalRgb = diff.rgb * multFactor;

    float alpha = 1.0;
    if (uTransparencyMode == 0) {
      // SCNTransparencyModeAOne
      alpha = diff.a * uTransparency;
    } else {
      // SCNTransparencyModeRGBZero
      if (uHasTransparentMap) {
        vec3 tc = texture2D(uTransparentMap, vUv).rgb;
        float lum = dot(tc, vec3(0.2126, 0.7152, 0.0722));
        alpha = clamp((1.0 - lum) * uTransparency, 0.0, 1.0);
      } else {
        alpha = clamp(1.0 - uTransparency, 0.0, 1.0);
      }
    }

    if (uBlendMode == 3) {
      // SCNBlendModeMultiply: output factor to multiply with destination
      gl_FragColor = vec4(finalRgb, 1.0);
      return;
    }

    if (alpha <= 0.001) discard;
    gl_FragColor = vec4(finalRgb, alpha);
  }
`;

function createSCNShaderMaterial(matDef) {
  const diffColor = matDef.diffuse?.type === 'color' ? matDef.diffuse.color : [1, 1, 1, 1];
  const hasMultMap = matDef.multiply?.type === 'texture';
  const multTex = hasMultMap ? getTexture(matDef.multiply.path) : whiteTexture;
  const multColor = matDef.multiply?.type === 'color' ? matDef.multiply.color : [1, 1, 1, 1];
  const hasTransMap = matDef.transparent?.type === 'texture';
  const transTex = hasTransMap ? getTexture(matDef.transparent.path) : whiteTexture;

  const isMultiplyBlend = matDef.blendMode === 3;
  const isTransparent =
    isMultiplyBlend ||
    hasTransMap ||
    (matDef.transparencyMode === 0 && matDef.transparency < 0.999) ||
    (matDef.transparencyMode === 1 && !hasTransMap && matDef.transparency > 0.001);

  const mat = new THREE.ShaderMaterial({
    vertexShader: SCN_VERTEX_SHADER,
    fragmentShader: SCN_FRAGMENT_SHADER,
    uniforms: {
      uDiffuseColor: { value: new THREE.Vector4(diffColor[0], diffColor[1], diffColor[2], diffColor[3]) },
      uMultiplyMap: { value: multTex },
      uHasMultiplyMap: { value: hasMultMap },
      uMultiplyColor: { value: new THREE.Vector4(multColor[0], multColor[1], multColor[2], multColor[3]) },
      uMultiplyIntensity: { value: matDef.multiplyIntensity ?? 1.0 },
      uTransparentMap: { value: transTex },
      uHasTransparentMap: { value: hasTransMap },
      uTransparency: { value: matDef.transparency ?? 1.0 },
      uTransparencyMode: { value: matDef.transparencyMode ?? 0 },
      uBlendMode: { value: matDef.blendMode ?? 0 }
    },
    side: matDef.isDoubleSided ? THREE.DoubleSide : THREE.FrontSide,
    transparent: isTransparent,
    depthWrite: isMultiplyBlend ? false : !isTransparent,
    depthTest: matDef.readsFromDepthBuffer !== false
  });

  if (isMultiplyBlend) {
    mat.blending = THREE.CustomBlending;
    mat.blendEquation = THREE.AddEquation;
    mat.blendSrc = THREE.ZeroFactor;
    mat.blendDst = THREE.SrcColorFactor;
    mat.polygonOffset = true;
    mat.polygonOffsetFactor = -1;
    mat.polygonOffsetUnits = -1;
  }

  return mat;
}

function applyMaterialDefToShader(shaderMat, matDef, animateDuration = 0) {
  const diffColor = matDef.diffuse?.type === 'color' ? matDef.diffuse.color : [1, 1, 1, 1];
  const hasMultMap = matDef.multiply?.type === 'texture';
  const multTex = hasMultMap ? getTexture(matDef.multiply.path) : whiteTexture;
  const hasTransMap = matDef.transparent?.type === 'texture';
  const transTex = hasTransMap ? getTexture(matDef.transparent.path) : whiteTexture;

  shaderMat.uniforms.uMultiplyMap.value = multTex;
  shaderMat.uniforms.uHasMultiplyMap.value = hasMultMap;
  shaderMat.uniforms.uMultiplyIntensity.value = matDef.multiplyIntensity ?? 1.0;
  shaderMat.uniforms.uTransparentMap.value = transTex;
  shaderMat.uniforms.uHasTransparentMap.value = hasTransMap;
  shaderMat.uniforms.uTransparencyMode.value = matDef.transparencyMode ?? 0;
  shaderMat.uniforms.uBlendMode.value = matDef.blendMode ?? 0;

  const isMultiplyBlend = matDef.blendMode === 3;
  const targetTrans = matDef.transparency ?? 1.0;
  const isTransparent =
    isMultiplyBlend ||
    hasTransMap ||
    (matDef.transparencyMode === 0 && targetTrans < 0.999) ||
    (matDef.transparencyMode === 1 && !hasTransMap && targetTrans > 0.001);

  shaderMat.transparent = isTransparent;
  shaderMat.depthWrite = isMultiplyBlend ? false : !isTransparent;

  if (animateDuration > 0) {
    const startColor = shaderMat.uniforms.uDiffuseColor.value.clone();
    const endColor = new THREE.Vector4(diffColor[0], diffColor[1], diffColor[2], diffColor[3]);
    const startTrans = shaderMat.uniforms.uTransparency.value;
    const startTime = performance.now();
    const durMs = animateDuration * 1000;

    const tick = (now) => {
      const t = Math.min((now - startTime) / durMs, 1);
      shaderMat.uniforms.uDiffuseColor.value.lerpVectors(startColor, endColor, t);
      shaderMat.uniforms.uTransparency.value = startTrans + (targetTrans - startTrans) * t;
      if (t < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  } else {
    shaderMat.uniforms.uDiffuseColor.value.set(diffColor[0], diffColor[1], diffColor[2], diffColor[3]);
    shaderMat.uniforms.uTransparency.value = targetTrans;
  }
}

// DecayFunction.swift port
export const DecayFunction = {
  timeToHalt(velocity) {
    const fps = 1 / 60;
    let i = 0;
    let v = { x: velocity.x, y: velocity.y };
    while (Math.abs(v.x) > 0.1 || Math.abs(v.y) > 0.1) {
      v = this.step(fps, v).velocity;
      i++;
      if (i > 600) break;
    }
    return i / 60;
  },
  step(timeElapsed, velocity) {
    const deceleration = 0.996;
    const dt = timeElapsed * 1000.0;
    const kv = Math.pow(deceleration, dt);
    const kx = (deceleration * (1 - kv)) / (1 - deceleration);
    const v0x = velocity.x / 1000.0;
    const v0y = velocity.y / 1000.0;
    const vx = v0x * kv * 1000.0;
    const vy = v0y * kv * 1000.0;
    return {
      velocity: { x: vx, y: vy },
      displacement: { x: v0x * kx, y: v0y * kx }
    };
  }
};

// Cubic-bezier evaluator for SceneKitAnimator timing functions
export function cubicBezier(p1x, p1y, p2x, p2y) {
  return function (x) {
    if (x <= 0) return 0;
    if (x >= 1) return 1;
    let t = x;
    for (let i = 0; i < 8; i++) {
      const cx = 3 * p1x;
      const bx = 3 * (p2x - p1x) - cx;
      const ax = 1 - cx - bx;
      const currentX = ((ax * t + bx) * t + cx) * t - x;
      if (Math.abs(currentX) < 1e-5) break;
      const dx = (3 * ax * t + 2 * bx) * t + cx;
      if (Math.abs(dx) < 1e-6) break;
      t -= currentX / dx;
    }
    const cy = 3 * p1y;
    const by = 3 * (p2y - p1y) - cy;
    const ay = 1 - cy - by;
    return ((ay * t + by) * t + cy) * t;
  };
}

export const TimingFunctions = {
  linear: (t) => t,
  easeIn: cubicBezier(0.9, 0, 0.9, 1),
  easeOut: cubicBezier(0.1, 0, 0.1, 1),
  easeInOut: cubicBezier(0.45, 0, 0.55, 1),
  explodingEaseOut: cubicBezier(0, 0, 0, 1),
  default: cubicBezier(0, 0, 0.2, 1),
  summaryBounceEnd: cubicBezier(0.33, 0, 0.33, 1)
};

// NodeFactory.swift port
export class NodeFactory {
  static shared = null;

  constructor() {
    this.isLoaded = false;
    this.modelsMeta = null;
    this.binaryBuffer = null;
    this.geometryCache = new Map();
    this.callbacks = [];
  }

  async load() {
    if (this.isLoaded) return;
    // 100% Pure Procedural KAI 3D Models — Zero Shinkansen .scn binary or texture files loaded!
    this.modelsMeta = {
      '_kai_maroon_seat_complete': {
        rootNode: { name: 'kai-eksekutif-next-gen-maroon' },
        boundingSphere: { center: [0, 0.55, 0], radius: 1.45 }
      },
      '_kai_eks_dualtone_seat_complete': {
        rootNode: { name: 'kai-eksekutif-new-image-dualtone' },
        boundingSphere: { center: [0, 0.55, 0], radius: 1.45 }
      },
      '_kai_blue_seat_complete': {
        rootNode: { name: 'kai-ekonomi-new-gen-biru' },
        boundingSphere: { center: [0, 0.55, 0], radius: 1.45 }
      },
      '_kai_blue_dualtone_seat_complete': {
        rootNode: { name: 'kai-ekonomi-new-gen-dualtone-biru-tan' },
        boundingSphere: { center: [0, 0.55, 0], radius: 1.45 }
      },
      '_kai_prem_seat_complete': {
        rootNode: { name: 'kai-ekonomi-premium-tan' },
        boundingSphere: { center: [0, 0.55, 0], radius: 1.45 }
      },
      '_kai_tosca_seat_complete': {
        rootNode: { name: 'kai-ekonomi-modifikasi-tosca-2-3' },
        boundingSphere: { center: [0, 0.55, 0], radius: 1.55 }
      },
      '_e7_ordinary_seat_complete': {
        rootNode: { name: 'kai-ekonomi-reguler-krem-2-3' },
        boundingSphere: { center: [0, 0.55, 0], radius: 1.55 }
      },
      'kai-maroon-section': {
        rootNode: { name: 'kai-eksekutif-cabin-section' },
        boundingSphere: { center: [0, 1.8, 0], radius: 2.5 }
      },
      'kai-blue-section': {
        rootNode: { name: 'kai-ekonomi-new-gen-cabin-section' },
        boundingSphere: { center: [0, 1.8, 0], radius: 2.5 }
      },
      'kai-prem-section': {
        rootNode: { name: 'kai-ekonomi-premium-cabin-section' },
        boundingSphere: { center: [0, 1.8, 0], radius: 2.5 }
      },
      'kai-tosca-section': {
        rootNode: { name: 'kai-ekonomi-tosca-cabin-section' },
        boundingSphere: { center: [0, 1.8, 0], radius: 2.5 }
      },
      'e7-ordinary-seat-section': {
        rootNode: { name: 'kai-ekonomi-2-3-cabin-section' },
        boundingSphere: { center: [0, 1.8, 0], radius: 2.5 }
      },
      'kai-maroon-partition-a': {
        rootNode: { name: 'kai-pids-bulkhead-partition' },
        boundingSphere: { center: [0, 1.9, 0], radius: 2.2 }
      },
      'e7-train-head-chasis': {
        rootNode: { name: 'kai-stainless-steel-coach-body' },
        boundingSphere: { center: [0, 1.5, -3.5], radius: 5.5 }
      }
    };
    this.isLoaded = true;
    const cbs = this.callbacks.splice(0);
    cbs.forEach((cb) => cb());
  }

  onComplete(cb) {
    if (this.isLoaded) {
      cb();
    } else {
      this.callbacks.push(cb);
    }
  }

  getBufferGeometry(nodeKey, geoDef) {
    if (this.geometryCache.has(nodeKey)) {
      return this.geometryCache.get(nodeKey);
    }
    const geom = new THREE.BufferGeometry();
    if (geoDef.vertex) {
      const posArr = new Float32Array(
        this.binaryBuffer,
        geoDef.vertex.byteOffset,
        geoDef.vertex.count * 3
      );
      geom.setAttribute('position', new THREE.BufferAttribute(posArr, 3));
    }
    if (geoDef.normal) {
      const normArr = new Float32Array(
        this.binaryBuffer,
        geoDef.normal.byteOffset,
        geoDef.normal.count * 3
      );
      geom.setAttribute('normal', new THREE.BufferAttribute(normArr, 3));
    }
    if (geoDef.texcoord) {
      const uvArr = new Float32Array(
        this.binaryBuffer,
        geoDef.texcoord.byteOffset,
        geoDef.texcoord.count * 2
      );
      geom.setAttribute('uv', new THREE.BufferAttribute(uvArr, 2));
    }

    // Combine element index buffers into a single index buffer with groups
    let totalIndices = 0;
    const elemArrays = geoDef.elements.map((el) => {
      const count = el.primitiveCount * 3;
      totalIndices += count;
      if (el.bytesPerIndex === 1) {
        return new Uint8Array(this.binaryBuffer, el.byteOffset, count);
      } else if (el.bytesPerIndex === 2) {
        // Ensure 2-byte alignment
        if (el.byteOffset % 2 === 0) {
          return new Uint16Array(this.binaryBuffer, el.byteOffset, count);
        } else {
          const slice = this.binaryBuffer.slice(el.byteOffset, el.byteOffset + el.byteLength);
          return new Uint16Array(slice);
        }
      } else {
        const slice = this.binaryBuffer.slice(el.byteOffset, el.byteOffset + el.byteLength);
        return new Uint32Array(slice);
      }
    });

    const combinedIndices = new Uint32Array(totalIndices);
    let offset = 0;
    elemArrays.forEach((arr, groupIdx) => {
      combinedIndices.set(arr, offset);
      geom.addGroup(offset, arr.length, groupIdx);
      offset += arr.length;
    });
    geom.setIndex(new THREE.BufferAttribute(combinedIndices, 1));

    this.geometryCache.set(nodeKey, geom);
    return geom;
  }

  buildThreeNode(nodeDef, modelName, pathPrefix = 'root', collector = { geoNodes: [], stateNodes: [] }) {
    const nodePath = `${modelName}:${pathPrefix}:${nodeDef.name}`;
    let obj;

    if (nodeDef.geometry) {
      const geom = this.getBufferGeometry(nodePath, nodeDef.geometry);
      const baseNames = nodeDef.geometry.baseMaterialNames || [];
      const allMats = nodeDef.geometry.allMaterials || [];
      const stateSet = new Set(['normal', 'highlighted', 'selected', 'disabled', 'focus']);
      const normalMaterials = allMats.filter((m) => {
        const name = (m.name || '').trim();
        if (name.includes('-')) {
          const parts = name.split('-');
          const last = parts[parts.length - 1];
          if (stateSet.has(last) && parts.length > 1) {
            return last === 'normal';
          }
        }
        return true;
      });
      const materials = nodeDef.geometry.elements.map((_, idx) => {
        const normalMatDef = normalMaterials[idx] || allMats[idx] || allMats[0];
        return createSCNShaderMaterial(normalMatDef);
      });
      obj = new THREE.Mesh(geom, materials);
      if (modelName === 'e7-main-shadow') {
        obj.renderOrder = 1;
      }
      collector.geoNodes.push({
        mesh: obj,
        baseMaterialNames: baseNames,
        normalMaterials,
        allMaterials: allMats
      });
    } else {
      obj = new THREE.Group();
    }

    obj.name = nodeDef.name || '';
    obj.position.set(nodeDef.position[0], nodeDef.position[1], nodeDef.position[2]);
    obj.quaternion.set(
      nodeDef.quaternion[0],
      nodeDef.quaternion[1],
      nodeDef.quaternion[2],
      nodeDef.quaternion[3]
    );
    obj.scale.set(nodeDef.scale[0], nodeDef.scale[1], nodeDef.scale[2]);

    if (nodeDef.stateTransforms) {
      collector.stateNodes.push({
        object: obj,
        original: {
          position: new THREE.Vector3(...nodeDef.position),
          quaternion: new THREE.Quaternion(...nodeDef.quaternion),
          scale: new THREE.Vector3(...nodeDef.scale)
        },
        stateTransforms: nodeDef.stateTransforms
      });
    }

    if (nodeDef.children) {
      nodeDef.children.forEach((childDef, idx) => {
        const childObj = this.buildThreeNode(childDef, modelName, `${pathPrefix}.${idx}`, collector);
        obj.add(childObj);
      });
    }

    return obj;
  }

  createInstance(modelName) {
    // 1. Custom Authentic Indonesian KAI 3D Seat & Coach Models (No Shinkansen shapes!)
    if (
      modelName === 'kai-maroon-seat-a' ||
      modelName === 'kai-maroon-seat-b' ||
      modelName === '_kai_maroon_seat_complete'
    ) {
      const built = buildKAINextGenSeat(
        'maroon',
        modelName.endsWith('-a'),
        modelName.endsWith('_complete')
      );
      const inst = new SCNModelInstance(
        modelName,
        built.root,
        { geoNodes: [], stateNodes: built.stateNodes },
        this.modelsMeta?.[modelName] || { rootNode: { name: modelName } }
      );
      inst.customStateHandler = built.applyCustomState;
      return inst;
    }

    if (
      modelName === 'kai-eks-dualtone-seat-a' ||
      modelName === 'kai-eks-dualtone-seat-b' ||
      modelName === '_kai_eks_dualtone_seat_complete'
    ) {
      const built = buildKAINextGenSeat(
        'eksekutifDualTone',
        modelName.endsWith('-a'),
        modelName.endsWith('_complete')
      );
      const inst = new SCNModelInstance(
        modelName,
        built.root,
        { geoNodes: [], stateNodes: built.stateNodes },
        this.modelsMeta?.[modelName] || { rootNode: { name: modelName } }
      );
      inst.customStateHandler = built.applyCustomState;
      return inst;
    }

    if (
      modelName === 'kai-blue-dualtone-seat-a' ||
      modelName === 'kai-blue-dualtone-seat-b' ||
      modelName === '_kai_blue_dualtone_seat_complete'
    ) {
      const built = buildKAINextGenSeat(
        'blueDualTone',
        modelName.endsWith('-a'),
        modelName.endsWith('_complete')
      );
      const inst = new SCNModelInstance(
        modelName,
        built.root,
        { geoNodes: [], stateNodes: built.stateNodes },
        this.modelsMeta?.[modelName] || { rootNode: { name: modelName } }
      );
      inst.customStateHandler = built.applyCustomState;
      return inst;
    }

    if (
      modelName === 'kai-blue-seat-a' ||
      modelName === 'kai-blue-seat-b' ||
      modelName === 'e7-green-seat-a' ||
      modelName === 'e7-green-seat-b' ||
      modelName === '_kai_blue_seat_complete' ||
      modelName === '_e7_green_seat_complete'
    ) {
      const built = buildKAINextGenSeat(
        'blue',
        modelName.endsWith('-a'),
        modelName.endsWith('_complete')
      );
      const inst = new SCNModelInstance(
        modelName,
        built.root,
        { geoNodes: [], stateNodes: built.stateNodes },
        this.modelsMeta?.[modelName] || { rootNode: { name: modelName } }
      );
      inst.customStateHandler = built.applyCustomState;
      return inst;
    }

    if (
      modelName === 'kai-prem-seat-a' ||
      modelName === 'kai-prem-seat-b' ||
      modelName === '_kai_prem_seat_complete'
    ) {
      const built = buildKAIEkonomiPremiumSeat(
        modelName.endsWith('-a'),
        modelName.endsWith('_complete')
      );
      const inst = new SCNModelInstance(
        modelName,
        built.root,
        { geoNodes: [], stateNodes: built.stateNodes },
        this.modelsMeta?.[modelName] || { rootNode: { name: modelName } }
      );
      inst.customStateHandler = built.applyCustomState;
      return inst;
    }

    if (
      modelName === 'kai-tosca-seat-a' ||
      modelName === 'kai-tosca-seat-b' ||
      modelName === 'kai-tosca-seat-c' ||
      modelName === 'kai-tosca-seat-d' ||
      modelName === 'kai-tosca-seat-e' ||
      modelName === '_kai_tosca_seat_complete'
    ) {
      const role = modelName.endsWith('_complete') ? 'a' : modelName.slice(-1);
      const built = buildKAIEkonomiTosca23Seat(role, modelName.endsWith('_complete'));
      const inst = new SCNModelInstance(
        modelName,
        built.root,
        { geoNodes: [], stateNodes: built.stateNodes },
        this.modelsMeta?.[modelName] || { rootNode: { name: modelName } }
      );
      inst.customStateHandler = built.applyCustomState;
      return inst;
    }

    if (
      modelName === 'e7-ordinary-seat-a' ||
      modelName === 'e7-ordinary-seat-b' ||
      modelName === 'e7-ordinary-seat-c' ||
      modelName === 'e7-ordinary-seat-d' ||
      modelName === 'e7-ordinary-seat-e' ||
      modelName === '_e7_ordinary_seat_complete'
    ) {
      const role = modelName.endsWith('_complete') ? 'a' : modelName.slice(-1);
      const built = buildKAIEkonomi23Seat(role, modelName.endsWith('_complete'));
      const inst = new SCNModelInstance(
        modelName,
        built.root,
        { geoNodes: [], stateNodes: built.stateNodes },
        this.modelsMeta?.[modelName] || { rootNode: { name: modelName } }
      );
      inst.customStateHandler = built.applyCustomState;
      return inst;
    }

    if (modelName === 'e7-ordinary-leg-a-to-c' || modelName === 'e7-ordinary-leg-d-to-e') {
      return null;
    }

    if (modelName === 'e7-train-head-chasis') {
      const coachGroup = buildKAICoachEndChassis();
      return new SCNModelInstance(
        modelName,
        coachGroup,
        { geoNodes: [], stateNodes: [] },
        this.modelsMeta?.[modelName] || { rootNode: { name: modelName } }
      );
    }

    if (modelName === 'e7-main-shadow') {
      const shGroup = buildKAIMainFloorShadow();
      return new SCNModelInstance(
        modelName,
        shGroup,
        { geoNodes: [], stateNodes: [] },
        { rootNode: { name: modelName } }
      );
    }

    if (modelName === 'e7-train-head-inside' || modelName.includes('-separator')) {
      return null;
    }

    if (modelName.includes('-partition-')) {
      const partGroup = buildKAIPartitionBulkhead(modelName);
      return new SCNModelInstance(
        modelName,
        partGroup,
        { geoNodes: [], stateNodes: [] },
        this.modelsMeta?.[modelName] || { rootNode: { name: modelName } }
      );
    }

    if (
      modelName === 'e7-gangway' ||
      modelName.includes('entrance') ||
      modelName.includes('alley') ||
      modelName.includes('multipurpose')
    ) {
      const vestGroup = buildKAIVestibuleOrGangway(modelName);
      return new SCNModelInstance(
        modelName,
        vestGroup,
        { geoNodes: [], stateNodes: [] },
        { rootNode: { name: modelName } }
      );
    }

    if (modelName.includes('-section')) {
      const secGroup = buildKAICabinSection(modelName);
      return new SCNModelInstance(
        modelName,
        secGroup,
        { geoNodes: [], stateNodes: [] },
        this.modelsMeta?.[modelName] || { rootNode: { name: modelName } }
      );
    }

    return null;
  }

  attachKAICustom3DDetails(modelName, rootGroup, collector) {
    // 1A. Eksekutif Maroon 2-2 & Ekonomi New Gen Biru 2-2 (Winged Headrest + 4 Horizontal Ribs + Center Divider)
    const isMaroonSeat =
      modelName.startsWith('kai-maroon-seat-') || modelName === '_kai_maroon_seat_complete';
    const isBlueSeat =
      modelName.startsWith('kai-blue-seat-') ||
      modelName.startsWith('e7-green-seat-') ||
      modelName === '_kai_blue_seat_complete' ||
      modelName === '_e7_green_seat_complete';
    const isPremSeat =
      modelName.startsWith('kai-prem-seat-') || modelName === '_kai_prem_seat_complete';
    const isEko23Seat =
      modelName.startsWith('e7-ordinary-seat-') || modelName === '_e7_ordinary_seat_complete';
    const isCompleteSeat = modelName.endsWith('_complete');

    if (isMaroonSeat || isBlueSeat || isPremSeat || isEko23Seat) {
      let backrestObj = null;
      let seatBaseObj = null;
      rootGroup.traverse((ch) => {
        if (
          ch.name === 'seat-rest' ||
          ch.name.startsWith('ordinary-backrest') ||
          ch.name === 'e7-seat-green-with-shadow-plane' ||
          ch.name === 'e7-seat-ordinary-with-shadow-plane'
        ) {
          backrestObj = ch;
        }
        if (ch.name === 'seat' || ch.name.startsWith('ordinary-seat-')) {
          seatBaseObj = ch;
        }
      });

      if (backrestObj && (isMaroonSeat || isBlueSeat)) {
        const wingNormalColor = isMaroonSeat ? [0.467, 0.2, 0.263, 1.0] : [0.278, 0.369, 0.545, 1.0];
        const wingHiColor = isMaroonSeat ? [0.345, 0.133, 0.184, 1.0] : [0.196, 0.267, 0.412, 1.0];
        const ribNormalColor = isMaroonSeat ? [0.35, 0.13, 0.18, 1.0] : [0.18, 0.25, 0.4, 1.0];
        const ribHiColor = isMaroonSeat ? [0.25, 0.08, 0.12, 1.0] : [0.12, 0.18, 0.3, 1.0];

        const wingMatDefList = [
          {
            name: 'kai-wing-normal',
            diffuse: { type: 'color', color: wingNormalColor },
            multiply: { type: 'color', color: [1, 1, 1, 1] },
            multiplyIntensity: 1,
            transparency: 1,
            transparencyMode: 0,
            blendMode: 0
          },
          {
            name: 'kai-wing-highlighted',
            diffuse: { type: 'color', color: wingHiColor },
            multiply: { type: 'color', color: [1, 1, 1, 1] },
            multiplyIntensity: 1,
            transparency: 1,
            transparencyMode: 0,
            blendMode: 0
          },
          {
            name: 'kai-wing-selected',
            diffuse: { type: 'color', color: [0.176, 0.667, 0.384, 1.0] },
            multiply: { type: 'color', color: [1, 1, 1, 1] },
            multiplyIntensity: 1,
            transparency: 1,
            transparencyMode: 0,
            blendMode: 0
          },
          {
            name: 'kai-wing-disabled',
            diffuse: { type: 'color', color: [0.675, 0.682, 0.71, 1.0] },
            multiply: { type: 'color', color: [1, 1, 1, 1] },
            multiplyIntensity: 1,
            transparency: 1,
            transparencyMode: 0,
            blendMode: 0
          }
        ];

        const ribMatDefList = [
          {
            name: 'kai-rib-normal',
            diffuse: { type: 'color', color: ribNormalColor },
            multiply: { type: 'color', color: [1, 1, 1, 1] },
            multiplyIntensity: 1,
            transparency: 1,
            transparencyMode: 0,
            blendMode: 0
          },
          {
            name: 'kai-rib-highlighted',
            diffuse: { type: 'color', color: ribHiColor },
            multiply: { type: 'color', color: [1, 1, 1, 1] },
            multiplyIntensity: 1,
            transparency: 1,
            transparencyMode: 0,
            blendMode: 0
          },
          {
            name: 'kai-rib-selected',
            diffuse: { type: 'color', color: [0.0, 0.48, 0.21, 1.0] },
            multiply: { type: 'color', color: [1, 1, 1, 1] },
            multiplyIntensity: 1,
            transparency: 1,
            transparencyMode: 0,
            blendMode: 0
          },
          {
            name: 'kai-rib-disabled',
            diffuse: { type: 'color', color: [0.58, 0.59, 0.62, 1.0] },
            multiply: { type: 'color', color: [1, 1, 1, 1] },
            multiplyIntensity: 1,
            transparency: 1,
            transparencyMode: 0,
            blendMode: 0
          }
        ];

        const yBase = isCompleteSeat ? 980 : 695;
        const zWing = isCompleteSeat ? -195 : 115;
        const zRib = isCompleteSeat ? -215 : 108;
        const yRibStart = isCompleteSeat ? 580 : 255;

        const wingGeo = new THREE.BoxGeometry(82, 225, 145);
        for (const side of [-1, 1]) {
          const wMat = createSCNShaderMaterial(wingMatDefList[0]);
          const wingMesh = new THREE.Mesh(wingGeo, wMat);
          wingMesh.position.set(side * 238, yBase, zWing);
          wingMesh.rotation.set(0.08, -side * 0.42, side * 0.12);
          backrestObj.add(wingMesh);
          collector.geoNodes.push({
            mesh: wingMesh,
            baseMaterialNames: ['kai-wing'],
            normalMaterials: [wingMatDefList[0]],
            allMaterials: wingMatDefList
          });
        }

        const ribGeo = new THREE.BoxGeometry(310, 10, 18);
        for (let r = 0; r < 4; r++) {
          const rMat = createSCNShaderMaterial(ribMatDefList[0]);
          const ribMesh = new THREE.Mesh(ribGeo, rMat);
          ribMesh.position.set(0, yRibStart + r * 58, zRib - r * 7);
          backrestObj.add(ribMesh);
          collector.geoNodes.push({
            mesh: ribMesh,
            baseMaterialNames: ['kai-rib'],
            normalMaterials: [ribMatDefList[0]],
            allMaterials: ribMatDefList
          });
        }

        if (seatBaseObj && modelName.endsWith('-a')) {
          const divGeo = new THREE.BoxGeometry(28, 195, 220);
          const divMat = new THREE.MeshBasicMaterial({
            color: isMaroonSeat ? 0xb8c7dc : 0xe2e6ee
          });
          const divMesh = new THREE.Mesh(divGeo, divMat);
          divMesh.position.set(-306, 515, -145);
          divMesh.rotation.x = -0.18;
          seatBaseObj.add(divMesh);
        }
      }

      // 1B. Ekonomi Premium (Taupe/Tan 2-2): Vertical Center Seam + Horizontal Lumbar Seams + Chrome Armrest Frame
      if (backrestObj && isPremSeat) {
        const seamMatDefList = [
          {
            name: 'kai-seam-normal',
            diffuse: { type: 'color', color: [0.45, 0.38, 0.33, 1.0] },
            multiply: { type: 'color', color: [1, 1, 1, 1] },
            multiplyIntensity: 1,
            transparency: 1,
            transparencyMode: 0,
            blendMode: 0
          },
          {
            name: 'kai-seam-highlighted',
            diffuse: { type: 'color', color: [0.32, 0.27, 0.23, 1.0] },
            multiply: { type: 'color', color: [1, 1, 1, 1] },
            multiplyIntensity: 1,
            transparency: 1,
            transparencyMode: 0,
            blendMode: 0
          },
          {
            name: 'kai-seam-selected',
            diffuse: { type: 'color', color: [0.0, 0.48, 0.21, 1.0] },
            multiply: { type: 'color', color: [1, 1, 1, 1] },
            multiplyIntensity: 1,
            transparency: 1,
            transparencyMode: 0,
            blendMode: 0
          },
          {
            name: 'kai-seam-disabled',
            diffuse: { type: 'color', color: [0.58, 0.59, 0.62, 1.0] },
            multiply: { type: 'color', color: [1, 1, 1, 1] },
            multiplyIntensity: 1,
            transparency: 1,
            transparencyMode: 0,
            blendMode: 0
          }
        ];
        const zRib = isCompleteSeat ? -215 : 108;
        const yRibStart = isCompleteSeat ? 590 : 265;
        const ribGeo = new THREE.BoxGeometry(320, 9, 16);
        for (let r = 0; r < 3; r++) {
          const rMat = createSCNShaderMaterial(seamMatDefList[0]);
          const ribMesh = new THREE.Mesh(ribGeo, rMat);
          ribMesh.position.set(0, yRibStart + r * 85, zRib - r * 8);
          backrestObj.add(ribMesh);
          collector.geoNodes.push({
            mesh: ribMesh,
            baseMaterialNames: ['kai-seam'],
            normalMaterials: [seamMatDefList[0]],
            allMaterials: seamMatDefList
          });
        }
        // Vertical center seam on upper backrest (Image 2 of new batch)
        const vSeamGeo = new THREE.BoxGeometry(10, 260, 16);
        const vMat = createSCNShaderMaterial(seamMatDefList[0]);
        const vSeam = new THREE.Mesh(vSeamGeo, vMat);
        vSeam.position.set(0, isCompleteSeat ? 960 : 640, isCompleteSeat ? -235 : 88);
        backrestObj.add(vSeam);
        collector.geoNodes.push({
          mesh: vSeam,
          baseMaterialNames: ['kai-seam'],
          normalMaterials: [seamMatDefList[0]],
          allMaterials: seamMatDefList
        });
      }

      // 1C. Ekonomi 2-3 (Cream Bench 3-2): Tubular Stainless-Steel Pipe Frame around Top & Sides of Backrest!
      if (backrestObj && isEko23Seat) {
        const pipeMat = new THREE.MeshBasicMaterial({ color: 0xc8d0d8 });
        const topY = isCompleteSeat ? 1105 : 725;
        const midY = isCompleteSeat ? 780 : 400;
        const pipeZ = isCompleteSeat ? -180 : 0;

        // Top horizontal stainless steel bar
        const topBar = new THREE.Mesh(new THREE.BoxGeometry(440, 24, 24), pipeMat);
        topBar.position.set(0, topY, pipeZ);
        backrestObj.add(topBar);

        // Left & right vertical stainless steel side bars
        const sideBarGeo = new THREE.BoxGeometry(22, 650, 24);
        for (const side of [-1, 1]) {
          const sBar = new THREE.Mesh(sideBarGeo, pipeMat);
          sBar.position.set(side * 222, midY, pipeZ);
          backrestObj.add(sBar);
        }
      }
    }

    // 2. Cabin Sections: Aisle LED Strips, Ekonomi Premium Wall Sockets, & Ekonomi 2-3 Blue Window Curtains
    if (
      modelName.includes('-section') &&
      !modelName.includes('entrance') &&
      !modelName.includes('multipurpose')
    ) {
      const isOrd23Section = modelName.startsWith('e7-ordinary-seat-section');
      const isBlueSection = modelName.startsWith('kai-blue-') || modelName.startsWith('e7-green-seat-section');
      const isPremSection = modelName.startsWith('kai-prem-');

      const ledColor = isOrd23Section
        ? 0xf4f7f2
        : isBlueSection
        ? 0xfffce0
        : isPremSection
        ? 0xc4f5ae
        : 0xdffbe4;
      const aisleX = isOrd23Section ? 0.22 : 0.255;

      const ledGeo = new THREE.PlaneGeometry(0.028, 1.18);
      const ledMat = new THREE.MeshBasicMaterial({
        color: ledColor,
        side: THREE.DoubleSide
      });
      for (const side of [-1, 1]) {
        const ledMesh = new THREE.Mesh(ledGeo, ledMat);
        ledMesh.rotation.x = -Math.PI / 2;
        ledMesh.position.set(side * aisleX, 1.334, 0);
        rootGroup.add(ledMesh);
      }

      // Ekonomi 2-3: Iconic Bright Royal-Blue Pleated Window Curtains & White Mini-Table (Image 3)
      if (isOrd23Section) {
        const curtainGeo = new THREE.BoxGeometry(0.04, 0.68, 0.72);
        const curtainMat = new THREE.MeshBasicMaterial({ color: 0x1b45b8 });
        const tableGeo = new THREE.BoxGeometry(0.14, 0.03, 0.34);
        const tableMat = new THREE.MeshBasicMaterial({ color: 0xf2f4f7 });
        for (const side of [-1, 1]) {
          const curtain = new THREE.Mesh(curtainGeo, curtainMat);
          curtain.position.set(side * 1.51, 2.16, 0);
          rootGroup.add(curtain);

          const miniTable = new THREE.Mesh(tableGeo, tableMat);
          miniTable.position.set(side * 1.46, 1.74, 0);
          rootGroup.add(miniTable);
        }
      }

      // Ekonomi Premium: Wall Power Socket Shelf under Windows (Image 2)
      if (isPremSection) {
        const socketGeo = new THREE.BoxGeometry(0.08, 0.08, 0.24);
        const socketMat = new THREE.MeshBasicMaterial({ color: 0xdfe3ea });
        for (const side of [-1, 1]) {
          const sock = new THREE.Mesh(socketGeo, socketMat);
          sock.position.set(side * 1.49, 1.76, 0);
          rootGroup.add(sock);
        }
      }

      // Exterior Argo Bromo Anggrek / KAI Livery Stripe
      const stripeGeo = new THREE.PlaneGeometry(1.18, 0.22);
      const stripeMat = new THREE.MeshBasicMaterial({
        color: isOrd23Section ? 0xf37021 : 0xd82b79,
        side: THREE.DoubleSide
      });
      for (const side of [-1, 1]) {
        const stripe = new THREE.Mesh(stripeGeo, stripeMat);
        stripe.rotation.y = Math.PI / 2;
        stripe.position.set(side * 1.715, 0.98, 0);
        rootGroup.add(stripe);
      }
    }

    // 3. KAI Partition Bulkhead (Sliding Glass Door + PIDS LCDs + Top LED Matrix Display)
    if (modelName.includes('-partition-')) {
      const zFace = modelName.endsWith('-a') ? -0.042 : 0.042;
      const bulkhead = new THREE.Group();
      bulkhead.position.set(0, 0, zFace);
      if (modelName.endsWith('-b')) {
        bulkhead.rotation.y = Math.PI;
      }

      const doorFrame = new THREE.Mesh(
        new THREE.PlaneGeometry(0.58, 1.32),
        new THREE.MeshBasicMaterial({ color: 0x1e222a, side: THREE.DoubleSide })
      );
      doorFrame.position.set(0, 2.0, 0);
      bulkhead.add(doorFrame);

      const doorGlass = new THREE.Mesh(
        new THREE.PlaneGeometry(0.42, 0.92),
        new THREE.MeshBasicMaterial({ color: 0x3b4859, side: THREE.DoubleSide })
      );
      doorGlass.position.set(0, 2.08, 0.003);
      bulkhead.add(doorGlass);

      const yellowDecal = new THREE.Mesh(
        new THREE.PlaneGeometry(0.09, 0.28),
        new THREE.MeshBasicMaterial({ color: 0xf2c935, side: THREE.DoubleSide })
      );
      yellowDecal.position.set(0, 2.1, 0.006);
      bulkhead.add(yellowDecal);

      const bezelGeo = new THREE.PlaneGeometry(0.62, 0.42);
      const bezelMat = new THREE.MeshBasicMaterial({ color: 0xc8c4ba, side: THREE.DoubleSide });
      for (const side of [-1, 1]) {
        const bezel = new THREE.Mesh(bezelGeo, bezelMat);
        bezel.position.set(side * 0.88, 2.28, 0);
        bulkhead.add(bezel);

        const screenColor = side === -1 ? 0x1254a1 : 0x5c8a66;
        const screen = new THREE.Mesh(
          new THREE.PlaneGeometry(0.52, 0.31),
          new THREE.MeshBasicMaterial({ color: screenColor, side: THREE.DoubleSide })
        );
        screen.position.set(side * 0.88, 2.28, 0.003);
        bulkhead.add(screen);
      }

      const ledBoard = new THREE.Mesh(
        new THREE.PlaneGeometry(1.42, 0.16),
        new THREE.MeshBasicMaterial({ color: 0x14161c, side: THREE.DoubleSide })
      );
      ledBoard.position.set(0, 2.63, 0.003);
      bulkhead.add(ledBoard);

      const ledAccent = new THREE.Mesh(
        new THREE.PlaneGeometry(0.95, 0.05),
        new THREE.MeshBasicMaterial({ color: 0x35e06c, side: THREE.DoubleSide })
      );
      ledAccent.position.set(0, 2.63, 0.006);
      bulkhead.add(ledAccent);

      rootGroup.add(bulkhead);
    }
  }
}

// Represents StaticNode / InteractiveNode / SeatNode
export class SCNModelInstance {
  constructor(name, group, collector, meta) {
    this.name = name;
    this.group = group;
    this.geoNodes = collector.geoNodes;
    this.stateNodes = collector.stateNodes;
    this.meta = meta;
    this.isEnabled = true;
    this.isHighlighted = false;
    this.isSelected = false;
    this.state = 'normal';
    this.reservableEntity = null;
    this.transformedModelEntity = null;

    // Tag all meshes with reference to this SCNModelInstance for raycasting
    this.group.traverse((child) => {
      if (child.isMesh) {
        child.userData.scnInstance = this;
      }
    });
  }

  setTransformedModelEntity(entity) {
    this.transformedModelEntity = entity;
    if (!entity) return;
    this.group.position.set(entity.position.x, entity.position.y, entity.position.z);
    // SceneKit eulerAngles order is ZYX
    const euler = new THREE.Euler(entity.rotation.x, entity.rotation.y, entity.rotation.z, 'ZYX');
    this.group.quaternion.setFromEuler(euler);
  }

  setReservableEntity(entity) {
    this.reservableEntity = entity;
    if (entity?.transformedModelEntity) {
      this.setTransformedModelEntity(entity.transformedModelEntity);
    }
  }

  setStaticEnabled(enabled) {
    this.isEnabled = enabled;
    const targetState = enabled ? 'normal' : 'disabled';
    this.applyState(targetState, false);
  }

  updateInteractiveState(animated = true) {
    const newState = !this.isEnabled
      ? 'disabled'
      : this.isHighlighted
      ? 'highlighted'
      : this.isSelected
      ? 'selected'
      : 'normal';

    if (newState !== this.state || !animated) {
      this.state = newState;
      this.applyState(newState, animated);
    }
  }

  applyState(state, animated = false) {
    const dur = animated ? 0.35 / 4 : 0;

    if (this.customStateHandler) {
      this.customStateHandler(state);
    }

    // 1. Update materials (StaticNode.updateMaterial & InteractiveNode.updateMaterial)
    for (const gNode of this.geoNodes) {
      const { mesh, baseMaterialNames, normalMaterials, allMaterials } = gNode;
      const mats = Array.isArray(mesh.material) ? mesh.material : [mesh.material];
      mats.forEach((shaderMat, idx) => {
        const baseName = baseMaterialNames[idx] ?? '';
        const fallbackNormal = normalMaterials?.[idx] || allMaterials[idx] || allMaterials[0];
        const matchMat =
          state === 'normal'
            ? fallbackNormal
            : allMaterials.find((m) => m.name.trim() === `${baseName}-${state}`) || fallbackNormal;
        if (matchMat) {
          applyMaterialDefToShader(shaderMat, matchMat, dur);
        }
      });
    }

    // 2. Update child transforms (InteractiveNode.updateTransfrom)
    for (const sNode of this.stateNodes) {
      const { object, original, stateTransforms } = sNode;
      const st = stateTransforms[state];
      const targetPos = st ? new THREE.Vector3(...st.position) : original.position;
      const targetQuat = st ? new THREE.Quaternion(...st.quaternion) : original.quaternion;
      const targetScale = st ? new THREE.Vector3(...st.scale) : original.scale;

      if (dur > 0) {
        const startPos = object.position.clone();
        const startQuat = object.quaternion.clone();
        const startScale = object.scale.clone();
        const startTime = performance.now();
        const durMs = dur * 1000;

        const tick = (now) => {
          const t = Math.min((now - startTime) / durMs, 1);
          object.position.lerpVectors(startPos, targetPos, t);
          object.quaternion.slerpQuaternions(startQuat, targetQuat, t);
          object.scale.lerpVectors(startScale, targetScale, t);
          if (t < 1) requestAnimationFrame(tick);
        };
        requestAnimationFrame(tick);
      } else {
        object.position.copy(targetPos);
        object.quaternion.copy(targetQuat);
        object.scale.copy(targetScale);
      }
    }
  }
}

// TextNode.swift port: 3D flat text on XZ plane matching SceneKit's SCNText layout
export function createTextNode({
  text = '',
  fontSize = 0.2,
  fontWeight = '900',
  textAlignment = 'center',
  color = '#909095',
  position = { x: 0, y: 0, z: 0 },
  rotation = { x: 0, y: 0, z: 0 }
}) {
  const group = new THREE.Group();
  group.position.set(position.x, position.y, position.z);
  const euler = new THREE.Euler(rotation.x, rotation.y, rotation.z, 'ZYX');
  group.quaternion.setFromEuler(euler);

  const canvas = document.createElement('canvas');
  const ctx = canvas.getContext('2d');
  const pxPerUnit = 360;
  // In SceneKit SCNText, pointSize 0.2 produces capHeight ~0.142 world units (0.71 * fontSize)
  const effectiveSize = fontSize * 0.72;
  const fontPx = Math.max(Math.round(effectiveSize * pxPerUnit), 16);
  const fontSpec = `${fontWeight} ${fontPx}px -apple-system, BlinkMacSystemFont, "SF Pro Display", "Helvetica Neue", sans-serif`;
  ctx.font = fontSpec;
  const metrics = ctx.measureText(text);
  const padPx = Math.ceil(fontPx * 0.15);
  const textWidthPx = Math.ceil(metrics.width) + padPx * 2;
  const textHeightPx = Math.ceil(fontPx * 1.25);

  canvas.width = Math.max(textWidthPx, 16);
  canvas.height = Math.max(textHeightPx, 16);

  function drawText(fillColor) {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.font = fontSpec;
    ctx.fillStyle = fillColor;
    ctx.textBaseline = 'middle';
    if (textAlignment === 'left') {
      ctx.textAlign = 'left';
      ctx.fillText(text, padPx, canvas.height / 2);
    } else if (textAlignment === 'right') {
      ctx.textAlign = 'right';
      ctx.fillText(text, canvas.width - padPx, canvas.height / 2);
    } else {
      ctx.textAlign = 'center';
      ctx.fillText(text, canvas.width / 2, canvas.height / 2);
    }
  }

  drawText(color);

  const tex = new THREE.CanvasTexture(canvas);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.minFilter = THREE.LinearFilter;
  tex.magFilter = THREE.LinearFilter;

  const worldW = canvas.width / pxPerUnit;
  const worldH = canvas.height / pxPerUnit;

  const planeGeo = new THREE.PlaneGeometry(worldW, worldH);
  const planeMat = new THREE.MeshBasicMaterial({
    map: tex,
    transparent: true,
    depthWrite: false,
    side: THREE.DoubleSide
  });

  const mesh = new THREE.Mesh(planeGeo, planeMat);
  mesh.rotation.x = -Math.PI / 2;

  if (textAlignment === 'left') {
    mesh.position.x = worldW / 2;
  } else if (textAlignment === 'right') {
    mesh.position.x = -worldW / 2;
  } else {
    mesh.position.x = 0;
  }

  group.add(mesh);

  group.userData.setColor = (newColor) => {
    drawText(newColor);
    tex.needsUpdate = true;
  };

  return group;
}

// ============================================================================
// SeatMapSceneView.swift Port
// ============================================================================
export class SeatMapSceneView {
  constructor(containerEl, callbacks = {}) {
    this.container = containerEl;
    this.onSeatSelected = callbacks.onSeatSelected || (() => {});
    this.onOverscrollUpper = callbacks.onOverscrollUpper || (() => {});
    this.onBadgeUpdate = callbacks.onBadgeUpdate || (() => {});

    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0xffffff);

    // CameraNode.swift
    this.cameraContainer = new THREE.Group();
    const cameraPosition = { x: 0, y: 7.2, z: 5 };
    const offsetPosition = { x: 0, y: 2, z: 1.5 };

    this.camera = new THREE.PerspectiveCamera(64, 1, 1, 100);
    this.camera.position.set(
      0,
      cameraPosition.y - offsetPosition.y,
      cameraPosition.z - offsetPosition.z
    );
    this.camera.rotation.set(-0.9638087153434753, 0, 0, 'ZYX');

    this.cameraContainer.add(this.camera);
    this.cameraContainer.position.set(0, offsetPosition.y, -cameraPosition.z + offsetPosition.z);
    this.scene.add(this.cameraContainer);

    // ContentNode
    this.contentNode = new THREE.Group();
    this.scene.add(this.contentNode);

    // Mathematical HitTestFloorNode at y = 1.3 (HitTestFloorNode.swift)
    this.hitTestPlane = new THREE.Plane(new THREE.Vector3(0, 1, 0), -1.3);
    this.raycaster = new THREE.Raycaster();

    this.renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false, powerPreference: 'high-performance' });
    this.renderer.outputColorSpace = THREE.LinearSRGBColorSpace;
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    this.container.appendChild(this.renderer.domElement);

    this.contentZPositionLimit = { lower: 0, upper: 1 };
    this.currentContentZ = 0;
    this.centerScreenZ = 0;
    this.perspectiveVelocity = 0;

    this.interactiveSeatMeshes = [];
    this.highlightedSeatNode = null;
    this.selectedSeatNode = null;
    this.seatNavigationState = 'hide';
    this.textNodes = [];
    this.stationDirectionNode = null;

    this.activeAnimCancel = null;
    this.isDisposed = false;

    this.setupResizeObserver();
    this.setupInteraction();
    this.startRenderLoop();
  }

  setupResizeObserver() {
    this.updateSize = () => {
      if (this.isDisposed) return;
      const rect = this.container.getBoundingClientRect();
      if (rect.width < 2 || rect.height < 2) return;
      const w = rect.width;
      const h = rect.height;
      this.camera.aspect = w / h;
      this.camera.updateProjectionMatrix();
      this.renderer.setSize(w, h, false);
      const midHit = this.positionOfFloorHitTest(w / 2, h / 2);
      if (midHit) this.centerScreenZ = midHit.z;
    };
    this.resizeObserver = new ResizeObserver(this.updateSize);
    this.resizeObserver.observe(this.container);
    this.updateSize();
  }

  setTheme(isDark) {
    if (isDark) {
      this.scene.background = new THREE.Color().setRGB(46 / 255, 46 / 255, 46 / 255, THREE.LinearSRGBColorSpace);
    } else {
      this.scene.background = new THREE.Color().setRGB(1, 1, 1, THREE.LinearSRGBColorSpace);
    }
    const textColor = '#909095';
    if (this.stationDirectionNode?.userData?.setColor) {
      this.stationDirectionNode.userData.setColor(textColor);
    }
  }

  positionOfFloorHitTest(localX, localY) {
    const rect = this.renderer.domElement.getBoundingClientRect();
    const w = Math.max(rect.width, 1);
    const h = Math.max(rect.height, 1);
    const ndc = new THREE.Vector2((localX / w) * 2 - 1, -(localY / h) * 2 + 1);
    this.raycaster.setFromCamera(ndc, this.camera);
    const target = new THREE.Vector3();
    const hit = this.raycaster.ray.intersectPlane(this.hitTestPlane, target);
    return hit ? target : null;
  }

  zPositionClamp(value) {
    const { lower, upper } = this.contentZPositionLimit;
    let trimmedMax = value;
    if (value > upper) {
      const ratio = upper !== 0 ? Math.max(value / upper, 1) : 1 + (value - upper);
      trimmedMax = upper !== 0 ? upper * (1 + Math.log10(ratio)) : Math.log10(ratio);
    }
    if (trimmedMax < lower) {
      if (lower > 0) {
        const ratio = Math.max(trimmedMax / lower, 0.01);
        return lower * (1 + Math.log10(ratio));
      } else {
        const excess = lower - trimmedMax;
        return lower - Math.log10(1 + excess) * 2;
      }
    }
    return trimmedMax;
  }

  setCurrentContentZ(newZ, reportOverscroll = true) {
    const oldZ = this.currentContentZ;
    this.currentContentZ = newZ;
    this.contentNode.position.z = newZ;
    this.perspectiveVelocity = (newZ - oldZ) / (1 / 60);

    if (reportOverscroll) {
      const upperBoundLimitOffsetY = this.contentZPositionLimit.upper - newZ;
      this.onOverscrollUpper({ x: 0, y: upperBoundLimitOffsetY / 0.04 });
    }

    if (this.centerScreenZ === 0) {
      const rect = this.renderer.domElement.getBoundingClientRect();
      const midHit = this.positionOfFloorHitTest(rect.width / 2, rect.height / 2);
      if (midHit) this.centerScreenZ = midHit.z;
    }

    if (this.selectedSeatNode && this.centerScreenZ !== 0) {
      const seatZ = this.selectedSeatNode.group.position.z;
      let nextNavState = 'hide';
      if (seatZ > this.centerScreenZ - newZ + 3) {
        nextNavState = 'bottom';
      } else if (seatZ < this.centerScreenZ - newZ - 4) {
        nextNavState = 'top';
      }
      if (nextNavState !== this.seatNavigationState) {
        this.seatNavigationState = nextNavState;
        const seatName = this.selectedSeatNode.reservableEntity?.name || 'selected';
        if (nextNavState === 'top') {
          this.onBadgeUpdate({
            type: 'nav',
            message: `↑ Your ${seatName} seat is up there.`,
            visible: true
          });
        } else if (nextNavState === 'bottom') {
          this.onBadgeUpdate({
            type: 'nav',
            message: `↓ Your ${seatName} seat is down there.`,
            visible: true
          });
        } else {
          this.onBadgeUpdate({ type: 'nav', visible: false });
        }
      }
    }
  }

  animateContentZ(targetZ, durationSec, timingFn = TimingFunctions.easeOut, reportOverscroll = true) {
    if (this.activeAnimCancel) this.activeAnimCancel();
    const startZ = this.currentContentZ;
    const startTime = performance.now();
    const durMs = Math.max(durationSec * 1000, 16);
    let cancelled = false;
    this.activeAnimCancel = () => {
      cancelled = true;
    };

    const step = (now) => {
      if (cancelled || this.isDisposed) return;
      const rawT = Math.min((now - startTime) / durMs, 1);
      const easedT = timingFn(rawT);
      const z = startZ + (targetZ - startZ) * easedT;
      this.setCurrentContentZ(z, reportOverscroll);
      if (rawT < 1) {
        requestAnimationFrame(step);
      } else {
        this.activeAnimCancel = null;
      }
    };
    requestAnimationFrame(step);
  }

  scrollToSelectedSeat() {
    if (!this.selectedSeatNode) return;
    this.animateContentNodeToZPosition(this.selectedSeatNode.group.position.z);
  }

  animateContentNodeToZPosition(seatZ) {
    const rect = this.renderer.domElement.getBoundingClientRect();
    const centerHit = this.positionOfFloorHitTest(rect.width / 2, rect.height / 2);
    const centerZ = centerHit ? centerHit.z : -5.0;
    const targetZ = Math.max(
      this.contentZPositionLimit.lower,
      Math.min(this.contentZPositionLimit.upper, -seatZ + centerZ)
    );
    this.animateContentZ(targetZ, 0.7, TimingFunctions.easeOut);
  }

  setupContent(seatMap, currentEntity, fromStation, toStation) {
    const factory = NodeFactory.shared;
    if (!factory || !factory.isLoaded) return;

    // Clear previous content
    while (this.contentNode.children.length > 0) {
      this.contentNode.remove(this.contentNode.children[0]);
    }
    if (this.stationDirectionNode) {
      this.scene.remove(this.stationDirectionNode);
      this.stationDirectionNode = null;
    }
    this.interactiveSeatMeshes = [];
    this.selectedSeatNode = null;
    this.highlightedSeatNode = null;
    this.seatNavigationState = 'hide';

    // 1. Place global static nodes (SeatMap.transformedModelEntities)
    for (const tme of seatMap.transformedModelEntities) {
      const inst = factory.createInstance(tme.modelEntity);
      if (inst) {
        inst.setTransformedModelEntity(tme);
        inst.setStaticEnabled(true);
        this.contentNode.add(inst.group);
      }
    }

    // 2. Place SeatClassEntities (current entity first)
    const entities = [...seatMap.seatClassEntities];
    const currentIdx = entities.findIndex((e) => e.seatClass === currentEntity.seatClass);
    if (currentIdx > 0) {
      const [curr] = entities.splice(currentIdx, 1);
      entities.unshift(curr);
    }

    for (const sce of entities) {
      const isCurrent = sce.seatClass === currentEntity.seatClass;
      if (isCurrent) {
        const r0 = sce.viewableRange[0].z;
        const r1 = sce.viewableRange[1].z;
        this.contentZPositionLimit = {
          lower: Math.min(r0, r1),
          upper: Math.max(r0, r1)
        };
      }

      // Static sections for this car
      for (const tme of sce.transformedModelEntities) {
        const inst = factory.createInstance(tme.modelEntity);
        if (inst) {
          inst.setTransformedModelEntity(tme);
          inst.setStaticEnabled(isCurrent);
          this.contentNode.add(inst.group);
        }
      }

      // Reservable seats for this car
      for (const rev of sce.reservableEntities) {
        const inst = factory.createInstance(rev.transformedModelEntity.modelEntity);
        if (inst) {
          inst.setReservableEntity(rev);
          inst.isEnabled = Boolean(rev.isAvailable && isCurrent);
          inst.updateInteractiveState(false);
          this.contentNode.add(inst.group);

          if (inst.isEnabled) {
            inst.group.traverse((ch) => {
              if (ch.isMesh) this.interactiveSeatMeshes.push(ch);
            });
          }
        }
      }
    }

    // 3. Place 3D row number TextNodes
    for (const tNode of seatMap.transformedTextModelEntities) {
      const group = createTextNode({
        text: tNode.text,
        fontSize: tNode.font?.size || 0.2,
        fontWeight: '800',
        textAlignment: tNode.textAlignment || 'center',
        color: '#909095',
        position: tNode.position,
        rotation: tNode.rotation
      });
      this.contentNode.add(group);
      this.textNodes.push(group);
    }

    // 4. Station direction label node in scene root
    const dirText = `${toStation ? `← ${toStation}` : ''}${fromStation ? `     ${fromStation} →` : ''}`;
    this.stationDirectionNode = createTextNode({
      text: dirText,
      fontSize: 0.5,
      fontWeight: '300',
      textAlignment: 'right',
      color: '#909095',
      position: { x: -3.15, y: 1.2, z: -13 },
      rotation: { x: 0, y: Math.PI / 2, z: 0 }
    });
    this.scene.add(this.stationDirectionNode);

    // 5. Play initial animation (SeatMapSceneView.playInitialAnimation)
    const { lower, upper } = this.contentZPositionLimit;
    this.setCurrentContentZ(lower, false);
    const duration = Math.min((Math.abs(upper) - Math.abs(lower)) / 180 + 0.5, 0.9);
    const targetZ = lower + Math.min((upper - lower) / 3, 6.5);
    this.animateContentZ(targetZ, duration, TimingFunctions.explodingEaseOut, false);
  }

  hitTestSeat(localX, localY) {
    const rect = this.renderer.domElement.getBoundingClientRect();
    const w = Math.max(rect.width, 1);
    const h = Math.max(rect.height, 1);
    const ndc = new THREE.Vector2((localX / w) * 2 - 1, -(localY / h) * 2 + 1);
    this.raycaster.setFromCamera(ndc, this.camera);
    const hits = this.raycaster.intersectObjects(this.interactiveSeatMeshes, false);
    if (hits.length > 0) {
      const inst = hits[0].object.userData.scnInstance;
      if (inst && inst.isEnabled) return inst;
    }
    return null;
  }

  setupInteraction() {
    const dom = this.renderer.domElement;
    let isPointerDown = false;
    let startClientX = 0;
    let startClientY = 0;
    let isDragging = false;
    let hitStart = null;
    let contentZStart = 0;

    const getLocalCoords = (e) => {
      const rect = dom.getBoundingClientRect();
      return {
        x: e.clientX - rect.left,
        y: e.clientY - rect.top
      };
    };

    dom.addEventListener('pointerdown', (e) => {
      if (e.button !== undefined && e.button !== 0) return;
      if (this.activeAnimCancel) {
        this.activeAnimCancel();
        this.activeAnimCancel = null;
      }
      isPointerDown = true;
      isDragging = false;
      startClientX = e.clientX;
      startClientY = e.clientY;
      dom.setPointerCapture?.(e.pointerId);

      const local = getLocalCoords(e);
      hitStart = this.positionOfFloorHitTest(local.x, local.y);
      contentZStart = this.currentContentZ;

      const seatInst = this.hitTestSeat(local.x, local.y);
      if (seatInst) {
        this.highlightedSeatNode = seatInst;
        seatInst.isHighlighted = true;
        seatInst.updateInteractiveState(true);
      }
    });

    dom.addEventListener('pointermove', (e) => {
      if (!isPointerDown) return;
      const dx = e.clientX - startClientX;
      const dy = e.clientY - startClientY;
      if (!isDragging && Math.hypot(dx, dy) > 6) {
        isDragging = true;
        if (this.highlightedSeatNode) {
          this.highlightedSeatNode.isHighlighted = false;
          this.highlightedSeatNode.updateInteractiveState(true);
          this.highlightedSeatNode = null;
        }
      }

      if (isDragging && hitStart) {
        const local = getLocalCoords(e);
        const hitNow = this.positionOfFloorHitTest(local.x, local.y);
        if (hitNow) {
          const zPos = this.zPositionClamp(hitNow.z - hitStart.z + contentZStart);
          this.setCurrentContentZ(zPos, true);
        }
      }
    });

    const endPointer = (e) => {
      if (!isPointerDown) return;
      isPointerDown = false;
      try {
        dom.releasePointerCapture?.(e.pointerId);
      } catch (_) {}

      if (!isDragging && this.highlightedSeatNode) {
        const picked = this.highlightedSeatNode;
        picked.isHighlighted = false;
        this.highlightedSeatNode = null;

        const prevSelected = this.selectedSeatNode;
        if (prevSelected && prevSelected !== picked) {
          prevSelected.isSelected = false;
          prevSelected.updateInteractiveState(true);
        }
        this.selectedSeatNode = picked;
        picked.isSelected = true;
        picked.updateInteractiveState(true);

        if (picked.reservableEntity) {
          this.onSeatSelected(picked.reservableEntity);
          if (prevSelected !== picked) {
            const msg = `Seat ${picked.reservableEntity.name} in ${picked.reservableEntity.carNumber.toLowerCase()} has been selected.`;
            this.onBadgeUpdate({
              type: 'selected',
              message: msg,
              visible: true,
              autoHideMs: 4000
            });
          }
        }
        this.animateContentNodeToZPosition(picked.group.position.z);
        return;
      }

      if (this.highlightedSeatNode) {
        this.highlightedSeatNode.isHighlighted = false;
        this.highlightedSeatNode.updateInteractiveState(true);
        this.highlightedSeatNode = null;
      }

      // Inertia drift (DecayFunction.swift)
      let currentVelocity = { x: 0, y: this.perspectiveVelocity || 0 };
      const totalDuration = DecayFunction.timeToHalt(currentVelocity);
      if (totalDuration > 0.02) {
        let lastTime = performance.now();
        let cancelled = false;
        this.activeAnimCancel = () => {
          cancelled = true;
        };
        const driftTick = (now) => {
          if (cancelled || this.isDisposed) return;
          const dt = Math.min((now - lastTime) / 1000, 0.05);
          lastTime = now;
          const stepRes = DecayFunction.step(dt, currentVelocity);
          currentVelocity = stepRes.velocity;
          const newZ = this.currentContentZ + stepRes.displacement.y;
          const clampedAvg = (newZ + this.zPositionClamp(newZ)) / 2;
          this.setCurrentContentZ(clampedAvg, true);

          if (Math.abs(currentVelocity.y) > 0.15) {
            requestAnimationFrame(driftTick);
          } else {
            this.snapBackIfNeeded();
          }
        };
        requestAnimationFrame(driftTick);
      } else {
        this.snapBackIfNeeded();
      }
    };

    dom.addEventListener('pointerup', endPointer);
    dom.addEventListener('pointercancel', endPointer);

    // Wheel support for desktop trackpads/mice
    dom.addEventListener(
      'wheel',
      (e) => {
        e.preventDefault();
        if (this.activeAnimCancel) {
          this.activeAnimCancel();
          this.activeAnimCancel = null;
        }
        const deltaZ = e.deltaY * 0.03;
        const { lower, upper } = this.contentZPositionLimit;
        const nextZ = Math.max(lower, Math.min(upper, this.currentContentZ + deltaZ));
        this.setCurrentContentZ(nextZ, false);
      },
      { passive: false }
    );
  }

  snapBackIfNeeded() {
    const { lower, upper } = this.contentZPositionLimit;
    if (this.currentContentZ < lower || this.currentContentZ > upper) {
      const target = Math.max(lower, Math.min(upper, this.currentContentZ));
      this.animateContentZ(target, 0.3, TimingFunctions.easeOut, true);
    } else {
      this.onOverscrollUpper({ x: 0, y: 0 });
    }
  }

  startRenderLoop() {
    const render = () => {
      if (this.isDisposed) return;
      this.renderer.render(this.scene, this.camera);
      requestAnimationFrame(render);
    };
    requestAnimationFrame(render);
  }

  dispose() {
    this.isDisposed = true;
    this.resizeObserver?.disconnect();
  }
}

// ============================================================================
// SummaryPreviewView.swift Port (BookingConfirmationViewController)
// ============================================================================
export class SummaryPreviewView {
  constructor(containerEl) {
    this.container = containerEl;
    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0xffffff);

    // setupCamera() from SummaryPreviewView.swift
    this.cameraControlNode = new THREE.Group();
    this.cameraControlNode.position.set(0, 0.75, 0);

    this.camera = new THREE.PerspectiveCamera(16, 1, 0.5, 50);
    this.camera.position.set(0, 0.25, 8);
    this.camera.rotation.set(-0.0312398336827755, 0, 0, 'ZYX');

    this.cameraControlNode.add(this.camera);
    this.scene.add(this.cameraControlNode);

    this.contentNode = new THREE.Group();
    this.scene.add(this.contentNode);

    this.renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false });
    this.renderer.outputColorSpace = THREE.LinearSRGBColorSpace;
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    this.container.appendChild(this.renderer.domElement);

    this.isDisposed = false;
    this.setupResizeObserver();
    this.setupGesture();
    this.startRenderLoop();
  }

  setupResizeObserver() {
    this.updateSize = () => {
      if (this.isDisposed) return;
      const rect = this.container.getBoundingClientRect();
      if (rect.width < 2 || rect.height < 2) return;
      const w = rect.width;
      const h = rect.height;
      this.camera.aspect = w / h;
      this.camera.updateProjectionMatrix();
      this.renderer.setSize(w, h, false);
    };
    this.resizeObserver = new ResizeObserver(this.updateSize);
    this.resizeObserver.observe(this.container);
    this.updateSize();
  }

  setTheme(isDark) {
    if (isDark) {
      this.scene.background = new THREE.Color().setRGB(46 / 255, 46 / 255, 46 / 255, THREE.LinearSRGBColorSpace);
    } else {
      this.scene.background = new THREE.Color().setRGB(1, 1, 1, THREE.LinearSRGBColorSpace);
    }
  }

  setupContent(seatClassType) {
    while (this.contentNode.children.length > 0) {
      this.contentNode.remove(this.contentNode.children[0]);
    }
    const completeMap = {
      granClass: '_kai_maroon_seat_complete',
      eksekutifDualTone: '_kai_eks_dualtone_seat_complete',
      green: '_kai_blue_seat_complete',
      ekonomiNewGenDual: '_kai_blue_dualtone_seat_complete',
      ekonomiPremium: '_kai_prem_seat_complete',
      ekonomiTosca: '_kai_tosca_seat_complete',
      ordinary: '_e7_ordinary_seat_complete'
    };
    const modelName = completeMap[seatClassType] || '_e7_ordinary_seat_complete';
    const inst = NodeFactory.shared?.createInstance(modelName);
    if (inst) {
      inst.group.position.set(0, 0, 0);
      inst.group.rotation.set(0, -Math.PI / 6, 0, 'ZYX');
      this.contentNode.add(inst.group);
    }
    this.playInitialAnimation();
  }

  playInitialAnimation() {
    this.contentNode.scale.set(0.1, 0.1, 0.1);
    this.contentNode.rotation.set(0, Math.PI * 1.5, 0);

    const dur1 = 0.35 * 1.5 * 1000;
    const dur2 = (0.35 / 1.5) * 1000;
    const t0 = performance.now();

    const step1 = (now) => {
      if (this.isDisposed) return;
      const p = Math.min((now - t0) / dur1, 1);
      const e = TimingFunctions.explodingEaseOut(p);
      const s = 0.1 + (1.066 - 0.1) * e;
      const ry = Math.PI * 1.5 + (Math.PI * -0.066 - Math.PI * 1.5) * e;
      this.contentNode.scale.set(s, s, s);
      this.contentNode.rotation.y = ry;
      if (p < 1) {
        requestAnimationFrame(step1);
      } else {
        const t1 = performance.now();
        const step2 = (now2) => {
          if (this.isDisposed) return;
          const p2 = Math.min((now2 - t1) / dur2, 1);
          const e2 = TimingFunctions.summaryBounceEnd(p2);
          const s2 = 1.066 + (1.0 - 1.066) * e2;
          const ry2 = Math.PI * -0.066 * (1 - e2);
          this.contentNode.scale.set(s2, s2, s2);
          this.contentNode.rotation.y = ry2;
          if (p2 < 1) requestAnimationFrame(step2);
        };
        requestAnimationFrame(step2);
      }
    };
    requestAnimationFrame(step1);
  }

  setupGesture() {
    const dom = this.renderer.domElement;
    let isDown = false;
    let startX = 0;

    dom.addEventListener('pointerdown', (e) => {
      isDown = true;
      startX = e.clientX;
      dom.setPointerCapture?.(e.pointerId);
    });

    dom.addEventListener('pointermove', (e) => {
      if (!isDown) return;
      const rect = dom.getBoundingClientRect();
      const maxDim = Math.max(rect.width, rect.height, 1);
      const translatePercentage = (e.clientX - startX) / maxDim;
      this.contentNode.rotation.y = translatePercentage * (Math.PI / 2);
    });

    const onEnd = (e) => {
      if (!isDown) return;
      isDown = false;
      try {
        dom.releasePointerCapture?.(e.pointerId);
      } catch (_) {}
      const startRy = this.contentNode.rotation.y;
      const durMs = Math.max((Math.abs(startRy) / Math.PI) * 1000, 120);
      const t0 = performance.now();
      const springBack = (now) => {
        if (this.isDisposed || isDown) return;
        const p = Math.min((now - t0) / durMs, 1);
        const e = TimingFunctions.default(p);
        this.contentNode.rotation.y = startRy * (1 - e);
        if (p < 1) requestAnimationFrame(springBack);
      };
      requestAnimationFrame(springBack);
    };

    dom.addEventListener('pointerup', onEnd);
    dom.addEventListener('pointercancel', onEnd);
  }

  startRenderLoop() {
    const render = () => {
      if (this.isDisposed) return;
      this.renderer.render(this.scene, this.camera);
      requestAnimationFrame(render);
    };
    requestAnimationFrame(render);
  }
}

// ============================================================================
// DesignSystemModel3DContentView.swift Port
// ============================================================================
export class DesignSystem3DView {
  constructor(containerEl, onLabelChange) {
    this.container = containerEl;
    this.onLabelChange = onLabelChange || (() => {});
    this.scene = new THREE.Scene();

    this.camera = new THREE.PerspectiveCamera(45, 1, 0.1, 100);
    this.contentNode = new THREE.Group();
    this.scene.add(this.contentNode);

    this.renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    this.renderer.outputColorSpace = THREE.LinearSRGBColorSpace;
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    this.container.appendChild(this.renderer.domElement);

    this.availableModels = [];
    this.currentIndex = 0;
    this.currentInstance = null;
    this.currentState = 'normal';
    this.orbitAngles = { yaw: 0, pitch: 0 };
    this.targetCenter = new THREE.Vector3();
    this.baseCamOffset = new THREE.Vector3(0, 1, 3);

    this.setupResizeObserver();
    this.setupOrbitGesture();
    this.startRenderLoop();
  }

  setupResizeObserver() {
    this.updateSize = () => {
      const rect = this.container.getBoundingClientRect();
      if (rect.width < 2 || rect.height < 2) return;
      const w = rect.width;
      const h = rect.height;
      this.camera.aspect = w / h;
      this.camera.updateProjectionMatrix();
      this.renderer.setSize(w, h, false);
    };
    this.resizeObserver = new ResizeObserver(this.updateSize);
    this.resizeObserver.observe(this.container);
    this.updateSize();
  }

  initModels() {
    const factory = NodeFactory.shared;
    if (!factory || !factory.isLoaded) return;
    this.availableModels = Object.keys(factory.modelsMeta).sort();
    this.showModelAtIndex(0);
  }

  showModelAtIndex(idx) {
    if (this.availableModels.length === 0) return;
    if (idx >= this.availableModels.length) idx = 0;
    if (idx < 0) idx = this.availableModels.length - 1;
    this.currentIndex = idx;

    while (this.contentNode.children.length > 0) {
      this.contentNode.remove(this.contentNode.children[0]);
    }

    const name = this.availableModels[idx];
    const inst = NodeFactory.shared.createInstance(name);
    if (!inst) return;
    this.currentInstance = inst;
    this.applyStateToCurrent(false);
    this.contentNode.add(inst.group);

    const firstChildName = inst.meta?.rootNode?.name || name;
    this.onLabelChange(firstChildName);

    const bs = inst.meta?.boundingSphere || { center: [0, 0.5, 0], radius: 1.5 };
    const center = new THREE.Vector3(...bs.center);
    const radius = Math.max(bs.radius, 0.5);
    this.targetCenter.copy(center);
    this.baseCamOffset.set(-radius * 0.75, radius, radius * 3);
    this.orbitAngles = { yaw: 0, pitch: 0 };
    this.updateOrbitCamera();
  }

  updateOrbitCamera() {
    const offset = this.baseCamOffset.clone();
    const euler = new THREE.Euler(this.orbitAngles.pitch, this.orbitAngles.yaw, 0, 'YXZ');
    offset.applyEuler(euler);
    this.camera.position.copy(this.targetCenter).add(offset);
    this.camera.lookAt(this.targetCenter);
  }

  setState(stateName) {
    this.currentState = stateName;
    this.applyStateToCurrent(true);
  }

  applyStateToCurrent(animated = true) {
    if (!this.currentInstance) return;
    this.currentInstance.isEnabled = this.currentState !== 'disabled';
    this.currentInstance.isSelected = this.currentState === 'selected';
    this.currentInstance.isHighlighted = this.currentState === 'highlighted';
    this.currentInstance.updateInteractiveState(animated);
  }

  nextModel() {
    this.showModelAtIndex(this.currentIndex + 1);
  }

  prevModel() {
    this.showModelAtIndex(this.currentIndex - 1);
  }

  setupOrbitGesture() {
    const dom = this.renderer.domElement;
    let isDown = false;
    let lastX = 0;
    let lastY = 0;

    dom.addEventListener('pointerdown', (e) => {
      isDown = true;
      lastX = e.clientX;
      lastY = e.clientY;
      dom.setPointerCapture?.(e.pointerId);
    });

    dom.addEventListener('pointermove', (e) => {
      if (!isDown) return;
      const dx = e.clientX - lastX;
      const dy = e.clientY - lastY;
      lastX = e.clientX;
      lastY = e.clientY;
      this.orbitAngles.yaw -= dx * 0.01;
      this.orbitAngles.pitch = Math.max(-1.2, Math.min(1.2, this.orbitAngles.pitch - dy * 0.01));
      this.updateOrbitCamera();
    });

    const end = (e) => {
      isDown = false;
      try {
        dom.releasePointerCapture?.(e.pointerId);
      } catch (_) {}
    };
    dom.addEventListener('pointerup', end);
    dom.addEventListener('pointercancel', end);
  }

  startRenderLoop() {
    const render = () => {
      this.renderer.render(this.scene, this.camera);
      requestAnimationFrame(render);
    };
    requestAnimationFrame(render);
  }
}

