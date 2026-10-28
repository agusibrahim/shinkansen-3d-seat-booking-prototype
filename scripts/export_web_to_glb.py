#!/usr/bin/env python3
"""
Exports the 100% authentic KAI 3D models & Canvas textures from
web/js/kai-models.js and web/assets/data/SeatMap.json into compact,
instanced glTF 2.0 Binary (.glb) files in flutter/assets/models/ for
interactive_3d (Google Filament on Android + Apple SceneKit on iOS).
"""
import base64
import http.server
import socketserver
import threading
from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT_DIR = Path(__file__).resolve().parent.parent
WEB_DIR = ROOT_DIR / "web"
OUT_DIR = ROOT_DIR / "flutter" / "assets" / "models"
OUT_DIR.mkdir(parents=True, exist_ok=True)


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(WEB_DIR), **kwargs)

    def log_message(self, format, *args):
        pass


JS_EXPORTER = r"""
async () => {
  const THREE = await import('/js/vendor/three.module.min.js');
  const KAI = await import('/js/kai-models.js');
  const seatMapResp = await fetch('/assets/data/SeatMap.json');
  const seatMap = await seatMapResp.json();

  function createSeatByModelName(modelName) {
    if (
      modelName === 'kai-maroon-seat-a' ||
      modelName === 'kai-maroon-seat-b' ||
      modelName === '_kai_maroon_seat_complete'
    ) {
      return KAI.buildKAINextGenSeat('maroon', modelName.endsWith('-a'), modelName.endsWith('_complete'));
    }
    if (
      modelName === 'kai-eks-dualtone-seat-a' ||
      modelName === 'kai-eks-dualtone-seat-b' ||
      modelName === '_kai_eks_dualtone_seat_complete'
    ) {
      return KAI.buildKAINextGenSeat('eksekutifDualTone', modelName.endsWith('-a'), modelName.endsWith('_complete'));
    }
    if (
      modelName === 'kai-blue-dualtone-seat-a' ||
      modelName === 'kai-blue-dualtone-seat-b' ||
      modelName === '_kai_blue_dualtone_seat_complete'
    ) {
      return KAI.buildKAINextGenSeat('blueDualTone', modelName.endsWith('-a'), modelName.endsWith('_complete'));
    }
    if (
      modelName === 'kai-blue-seat-a' ||
      modelName === 'kai-blue-seat-b' ||
      modelName === 'e7-green-seat-a' ||
      modelName === 'e7-green-seat-b' ||
      modelName === '_kai_blue_seat_complete'
    ) {
      return KAI.buildKAINextGenSeat('blue', modelName.endsWith('-a'), modelName.endsWith('_complete'));
    }
    if (
      modelName === 'kai-prem-seat-a' ||
      modelName === 'kai-prem-seat-b' ||
      modelName === '_kai_prem_seat_complete'
    ) {
      return KAI.buildKAIEkonomiPremiumSeat(modelName.endsWith('-a'), modelName.endsWith('_complete'));
    }
    if (
      modelName.startsWith('kai-tosca-seat-') ||
      modelName === '_kai_tosca_seat_complete'
    ) {
      const role = modelName.endsWith('_complete') ? 'a' : modelName.slice(-1);
      return KAI.buildKAIEkonomiTosca23Seat(role, modelName.endsWith('_complete'));
    }
    if (
      modelName.startsWith('e7-ordinary-seat-') ||
      modelName === '_e7_ordinary_seat_complete'
    ) {
      const role = modelName.endsWith('_complete') ? 'a' : modelName.slice(-1);
      return KAI.buildKAIEkonomi23Seat(role, modelName.endsWith('_complete'));
    }
    return null;
  }

  function createStaticByModelName(modelName) {
    if (
      modelName === 'e7-main-shadow' ||
      modelName === 'e7-train-head-inside' ||
      modelName.includes('-separator') ||
      modelName.startsWith('leg-')
    ) {
      return new THREE.Group();
    }
    if (modelName === 'e7-train-head-chasis') {
      return KAI.buildKAICoachEndChassis();
    }
    if (modelName.includes('-section') || modelName.includes('-window') || modelName.includes('-wall')) {
      return KAI.buildKAICabinSection(modelName);
    }
    if (modelName.includes('-partition-')) {
      return KAI.buildKAIPartitionBulkhead(modelName);
    }
    if (
      modelName === 'e7-gangway' ||
      modelName.includes('entrance') ||
      modelName.includes('alley') ||
      modelName.includes('multipurpose') ||
      modelName.includes('lavatory')
    ) {
      return KAI.buildKAIVestibuleOrGangway(modelName);
    }
    return new THREE.Group();
  }

  // Downscale canvas textures to 256x256 PNG so GLBs stay super fast & lightweight (~300KB)
  function canvasToPngDataUrl(img) {
    if (!img || !img.toDataURL) return null;
    if (img._cached256Url) return img._cached256Url;
    const c = document.createElement('canvas');
    c.width = Math.min(img.width || 256, 256);
    c.height = Math.min(img.height || 256, 256);
    const ctx = c.getContext('2d');
    ctx.drawImage(img, 0, 0, c.width, c.height);
    img._cached256Url = c.toDataURL('image/png');
    return img._cached256Url;
  }

  function extractMatDesc(mat) {
    let r = 1, g = 1, b = 1, a = 1;
    let roughness = 0.52, metalness = 0.06;
    let mapTex = null;
    if (mat.uniforms) {
      if (mat.uniforms.uColor && mat.uniforms.uColor.value) {
        r = mat.uniforms.uColor.value.x;
        g = mat.uniforms.uColor.value.y;
        b = mat.uniforms.uColor.value.z;
      }
      if (mat.uniforms.uOpacity !== undefined) a = mat.uniforms.uOpacity.value;
      if (mat.uniforms.uRoughness !== undefined) roughness = mat.uniforms.uRoughness.value;
      if (mat.uniforms.uMetalness !== undefined) metalness = mat.uniforms.uMetalness.value;
      if (mat.uniforms.uHasMap && mat.uniforms.uHasMap.value && mat.uniforms.uMap) {
        mapTex = mat.uniforms.uMap.value;
      }
    } else {
      if (mat.color) {
        r = mat.color.r;
        g = mat.color.g;
        b = mat.color.b;
      }
      if (mat.opacity !== undefined) a = mat.opacity;
      if (mat.map) mapTex = mat.map;
    }
    const dataUrl = mapTex && mapTex.image ? canvasToPngDataUrl(mapTex.image) : null;
    // Detect if this mesh uses an upholstery leather/fabric texture (has 512x512 mapTex)
    const isUpholstery = Boolean(mapTex && mapTex.image && mapTex.image.width === 512);
    const key = `${r.toFixed(3)},${g.toFixed(3)},${b.toFixed(3)},${a.toFixed(3)},${roughness.toFixed(2)},${metalness.toFixed(2)},${dataUrl ? dataUrl.length + ':' + dataUrl.slice(-40) : 'nomap'}`;
    return { key, r, g, b, a, roughness, metalness, dataUrl, isUpholstery };
  }

  class GLBBuilder {
    constructor() {
      this.binChunks = [];
      this.binByteLength = 0;
      this.bufferViews = [];
      this.accessors = [];
      this.images = [];
      this.textures = [];
      this.materials = [];
      this.meshes = [];
      this.nodes = [];
      this.texByDataUrl = new Map();
      this.matByKey = new Map();
      this.meshCache = new Map();
    }

    appendBin(typedArr, target = undefined) {
      const u8 = new Uint8Array(typedArr.buffer, typedArr.byteOffset, typedArr.byteLength);
      const pad = (4 - (u8.byteLength % 4)) % 4;
      const offset = this.binByteLength;
      this.binChunks.push(u8);
      this.binByteLength += u8.byteLength;
      if (pad > 0) {
        this.binChunks.push(new Uint8Array(pad));
        this.binByteLength += pad;
      }
      const bvIdx = this.bufferViews.length;
      const bv = {
        buffer: 0,
        byteOffset: offset,
        byteLength: u8.byteLength
      };
      if (target !== undefined) bv.target = target;
      this.bufferViews.push(bv);
      return bvIdx;
    }

    getOrCreateMaterial(matDesc) {
      if (this.matByKey.has(matDesc.key)) return this.matByKey.get(matDesc.key);
      let texIndex = null;
      if (matDesc.dataUrl) {
        if (this.texByDataUrl.has(matDesc.dataUrl)) {
          texIndex = this.texByDataUrl.get(matDesc.dataUrl);
        } else {
          const base64 = matDesc.dataUrl.split(',')[1];
          const raw = atob(base64);
          const bytes = new Uint8Array(raw.length);
          for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
          const bvIdx = this.appendBin(bytes);
          const imgIdx = this.images.length;
          this.images.push({ bufferView: bvIdx, mimeType: 'image/png' });
          texIndex = this.textures.length;
          this.textures.push({ source: imgIdx });
          this.texByDataUrl.set(matDesc.dataUrl, texIndex);
        }
      }
      const pbr = {
        baseColorFactor: [matDesc.r, matDesc.g, matDesc.b, matDesc.a],
        metallicFactor: matDesc.metalness,
        roughnessFactor: matDesc.roughness
      };
      if (texIndex !== null) {
        pbr.baseColorTexture = { index: texIndex };
      }
      const matIdx = this.materials.length;
      const gltfMat = {
        pbrMetallicRoughness: pbr,
        doubleSided: true
      };
      if (matDesc.a < 0.995) {
        gltfMat.alphaMode = 'BLEND';
      }
      this.materials.push(gltfMat);
      this.matByKey.set(matDesc.key, matIdx);
      return matIdx;
    }

    // Builds a single glTF Mesh from a Map<matKey, { matDesc, items: [{ geo, matrix }] }>
    buildMesh(meshName, matMap, cacheKey = null) {
      if (cacheKey && this.meshCache.has(cacheKey)) {
        return this.meshCache.get(cacheKey);
      }
      const primitives = [];
      const vTmp = new THREE.Vector3();
      const nTmp = new THREE.Vector3();
      const normalMat = new THREE.Matrix3();

      for (const [, group] of matMap.entries()) {
        // Use indexed geometry when possible to cut vertex count by 60%!
        let totalVerts = 0;
        let totalIndices = 0;
        const parts = [];

        for (const item of group.items) {
          const g = item.geo;
          const posAttr = g.attributes.position;
          if (!posAttr || posAttr.count === 0) continue;
          if (!g.attributes.normal) g.computeVertexNormals();
          const normAttr = g.attributes.normal;
          const uvAttr = g.attributes.uv;
          const idxAttr = g.index;
          const idxCount = idxAttr ? idxAttr.count : posAttr.count;
          parts.push({ posAttr, normAttr, uvAttr, idxAttr, matrix: item.matrix, vCount: posAttr.count, iCount: idxCount });
          totalVerts += posAttr.count;
          totalIndices += idxCount;
        }
        if (totalVerts === 0) continue;

        const posArr = new Float32Array(totalVerts * 3);
        const normArr = new Float32Array(totalVerts * 3);
        const uvArr = new Float32Array(totalVerts * 2);
        const useU32 = totalVerts > 65535;
        const idxArr = useU32 ? new Uint32Array(totalIndices) : new Uint16Array(totalIndices);

        let minX = Infinity, minY = Infinity, minZ = Infinity;
        let maxX = -Infinity, maxY = -Infinity, maxZ = -Infinity;
        let vOff = 0;
        let iOff = 0;

        for (const p of parts) {
          normalMat.getNormalMatrix(p.matrix);
          for (let i = 0; i < p.vCount; i++) {
            vTmp.fromBufferAttribute(p.posAttr, i).applyMatrix4(p.matrix);
            nTmp.fromBufferAttribute(p.normAttr, i).applyMatrix3(normalMat).normalize();
            const px = vTmp.x, py = vTmp.y, pz = vTmp.z;
            if (px < minX) minX = px;
            if (py < minY) minY = py;
            if (pz < minZ) minZ = pz;
            if (px > maxX) maxX = px;
            if (py > maxY) maxY = py;
            if (pz > maxZ) maxZ = pz;

            const k3 = (vOff + i) * 3;
            posArr[k3] = px;
            posArr[k3 + 1] = py;
            posArr[k3 + 2] = pz;
            normArr[k3] = nTmp.x;
            normArr[k3 + 1] = nTmp.y;
            normArr[k3 + 2] = nTmp.z;

            const k2 = (vOff + i) * 2;
            if (p.uvAttr) {
              uvArr[k2] = p.uvAttr.getX(i);
              uvArr[k2 + 1] = 1.0 - p.uvAttr.getY(i);
            } else {
              uvArr[k2] = 0.5;
              uvArr[k2 + 1] = 0.5;
            }
          }
          if (p.idxAttr) {
            for (let j = 0; j < p.iCount; j++) {
              idxArr[iOff + j] = vOff + p.idxAttr.getX(j);
            }
          } else {
            for (let j = 0; j < p.iCount; j++) {
              idxArr[iOff + j] = vOff + j;
            }
          }
          vOff += p.vCount;
          iOff += p.iCount;
        }

        const posBv = this.appendBin(posArr, 34962);
        const posAcc = this.accessors.length;
        this.accessors.push({
          bufferView: posBv,
          componentType: 5126,
          count: totalVerts,
          type: 'VEC3',
          min: [minX, minY, minZ],
          max: [maxX, maxY, maxZ]
        });

        const normBv = this.appendBin(normArr, 34962);
        const normAcc = this.accessors.length;
        this.accessors.push({
          bufferView: normBv,
          componentType: 5126,
          count: totalVerts,
          type: 'VEC3'
        });

        const uvBv = this.appendBin(uvArr, 34962);
        const uvAcc = this.accessors.length;
        this.accessors.push({
          bufferView: uvBv,
          componentType: 5126,
          count: totalVerts,
          type: 'VEC2'
        });

        const idxBv = this.appendBin(idxArr, 34963);
        const idxAcc = this.accessors.length;
        this.accessors.push({
          bufferView: idxBv,
          componentType: useU32 ? 5125 : 5123,
          count: totalIndices,
          type: 'SCALAR'
        });

        const matIdx = this.getOrCreateMaterial(group.matDesc);
        primitives.push({
          attributes: {
            POSITION: posAcc,
            NORMAL: normAcc,
            TEXCOORD_0: uvAcc
          },
          indices: idxAcc,
          material: matIdx,
          mode: 4
        });
      }

      if (primitives.length === 0) return null;
      const meshIdx = this.meshes.length;
      this.meshes.push({ name: meshName, primitives });
      if (cacheKey) this.meshCache.set(cacheKey, meshIdx);
      return meshIdx;
    }

    addNode(name, meshIdx, position = null, euler = null) {
      if (meshIdx === null || meshIdx === undefined) return;
      const node = { name, mesh: meshIdx };
      if (position && (position.x !== 0 || position.y !== 0 || position.z !== 0)) {
        node.translation = [position.x, position.y, position.z];
      }
      if (euler && (euler.x !== 0 || euler.y !== 0 || euler.z !== 0)) {
        const q = new THREE.Quaternion().setFromEuler(new THREE.Euler(euler.x || 0, euler.y || 0, euler.z || 0, 'XYZ'));
        node.rotation = [q.x, q.y, q.z, q.w];
      }
      this.nodes.push(node);
    }

    toBase64GLB() {
      const gltf = {
        asset: { version: '2.0', generator: 'KAI-Web-to-GLB-Instanced' },
        scene: 0,
        scenes: [{ nodes: this.nodes.map((_, idx) => idx) }],
        nodes: this.nodes,
        meshes: this.meshes,
        materials: this.materials,
        textures: this.textures,
        images: this.images,
        accessors: this.accessors,
        bufferViews: this.bufferViews,
        buffers: [{ byteLength: this.binByteLength }]
      };

      const jsonStr = JSON.stringify(gltf);
      const jsonBytes = new TextEncoder().encode(jsonStr);
      const jsonPad = (4 - (jsonBytes.byteLength % 4)) % 4;
      const jsonChunkLen = jsonBytes.byteLength + jsonPad;
      const totalLen = 12 + 8 + jsonChunkLen + 8 + this.binByteLength;

      const glb = new Uint8Array(totalLen);
      const dv = new DataView(glb.buffer);
      dv.setUint32(0, 0x46546C67, true);
      dv.setUint32(4, 2, true);
      dv.setUint32(8, totalLen, true);
      dv.setUint32(12, jsonChunkLen, true);
      dv.setUint32(16, 0x4E4F534A, true);
      glb.set(jsonBytes, 20);
      for (let i = 0; i < jsonPad; i++) glb[20 + jsonBytes.byteLength + i] = 0x20;

      const binHeaderOff = 20 + jsonChunkLen;
      dv.setUint32(binHeaderOff, this.binByteLength, true);
      dv.setUint32(binHeaderOff + 4, 0x004E4942, true);
      let ptr = binHeaderOff + 8;
      for (const chunk of this.binChunks) {
        glb.set(chunk, ptr);
        ptr += chunk.byteLength;
      }

      let binary = '';
      const step = 0x8000;
      for (let i = 0; i < glb.length; i += step) {
        binary += String.fromCharCode.apply(null, glb.subarray(i, i + step));
      }
      return btoa(binary);
    }
  }

  function collectMatMap(obj3d, filterPred = null) {
    obj3d.updateMatrixWorld(true);
    const matMap = new Map();
    obj3d.traverse((child) => {
      if (!child.isMesh || !child.geometry || !child.visible) return;
      const mat = child.material;
      if (!mat) return;
      if (mat.opacity !== undefined && mat.opacity <= 0.01) return;
      if (mat.uniforms && mat.uniforms.uOpacity && mat.uniforms.uOpacity.value <= 0.01) return;
      const desc = extractMatDesc(mat);
      if (filterPred && !filterPred(desc, child)) return;
      if (!matMap.has(desc.key)) {
        matMap.set(desc.key, { matDesc: desc, items: [] });
      }
      matMap.get(desc.key).items.push({
        geo: child.geometry,
        matrix: child.matrixWorld.clone()
      });
    });
    return matMap;
  }

  const results = {};

  // 1. Export the 7 standalone complete seats (for Confirmation & Design System)
  const seatClasses = [
    { key: 'granClass', model: '_kai_maroon_seat_complete' },
    { key: 'eksekutifDualTone', model: '_kai_eks_dualtone_seat_complete' },
    { key: 'green', model: '_kai_blue_seat_complete' },
    { key: 'ekonomiNewGenDual', model: '_kai_blue_dualtone_seat_complete' },
    { key: 'ekonomiPremium', model: '_kai_prem_seat_complete' },
    { key: 'ekonomiTosca', model: '_kai_tosca_seat_complete' },
    { key: 'ordinary', model: '_e7_ordinary_seat_complete' }
  ];

  for (const sc of seatClasses) {
    const builder = new GLBBuilder();
    const built = createSeatByModelName(sc.model);
    built.root.children = built.root.children.filter(
      (c) => !(c.isMesh && c.geometry.type === 'PlaneGeometry' && c.position.y < 0.05)
    );
    const wrapper = new THREE.Group();
    built.root.rotation.y = -Math.PI / 6;
    wrapper.add(built.root);
    const matMap = collectMatMap(wrapper);
    const meshIdx = builder.buildMesh(`seat_${sc.key}`, matMap);
    builder.addNode(`seat_${sc.key}`, meshIdx);
    results[`seat_${sc.key}.glb`] = builder.toBase64GLB();
  }

  // 2. Export the 7 Coach Interior scenes (car_<class>.glb) using glTF Mesh Instancing!
  for (const sce of seatMap.seatClassEntities) {
    const className = sce.seatClass;
    const lowerZ = sce.viewableRange[0].z;
    const upperZ = sce.viewableRange[1].z;
    const coachMinWorldZ = -upperZ - 14.0;
    const coachMaxWorldZ = -lowerZ + 14.0;

    const builder = new GLBBuilder();
    const staticCombineGroup = new THREE.Group();

    // Global static entities (gangways, head chassis) near this coach
    let stCounter = 0;
    for (const tme of seatMap.transformedModelEntities) {
      const wz = tme.position.z;
      if (wz < coachMinWorldZ || wz > coachMaxWorldZ) continue;
      const mKey = tme.modelEntity;
      const protoG = createStaticByModelName(mKey);
      const stMap = collectMatMap(protoG);
      const stMeshIdx = builder.buildMesh(`st_${mKey}`, stMap, `st:${mKey}`);
      builder.addNode(`global_st_${stCounter++}`, stMeshIdx, tme.position, tme.rotation);
    }

    for (const otherSce of seatMap.seatClassEntities) {
      const isCurrent = otherSce.seatClass === className;
      for (const st of otherSce.transformedModelEntities) {
        const wz = st.position.z;
        if (wz < coachMinWorldZ || wz > coachMaxWorldZ) continue;
        const mKey = st.modelEntity;
        const protoG = createStaticByModelName(mKey);
        const stMap = collectMatMap(protoG);
        const stMeshIdx = builder.buildMesh(`st_${mKey}`, stMap, `st:${mKey}`);
        builder.addNode(`car_st_${stCounter++}`, stMeshIdx, st.position, st.rotation);
      }

      for (const rev of otherSce.reservableEntities) {
        const pos = rev.transformedModelEntity.position;
        const rot = rev.transformedModelEntity.rotation || { x: 0, y: 0, z: 0 };
        const wz = pos.z;
        if (wz < coachMinWorldZ || wz > coachMaxWorldZ) continue;
        const modelKey = rev.transformedModelEntity.modelEntity;
        const isAvail = rev.isAvailable && isCurrent;
        const stateKey = isAvail ? 'normal' : 'disabled';

        // Build/fetch cached instanced mesh for this (modelKey, stateKey)!
        const protoSeat = createSeatByModelName(modelKey);
        if (!protoSeat) continue;
        protoSeat.applyCustomState(stateKey);

        if (isAvail) {
          // Separate upholstery (selectable node `seat_<id>`) from static frame/armrest (`frame_<id>`)
          const uphMap = collectMatMap(protoSeat.root, (desc) => desc.isUpholstery);
          const uphMeshIdx = builder.buildMesh(
            `uph_${modelKey}_${stateKey}`,
            uphMap,
            `uph:${modelKey}:${stateKey}`
          );
          builder.addNode(`seat_${rev.id}`, uphMeshIdx, pos, rot);

          const frmMap = collectMatMap(protoSeat.root, (desc) => !desc.isUpholstery);
          const frmMeshIdx = builder.buildMesh(
            `frm_${modelKey}`,
            frmMap,
            `frm:${modelKey}`
          );
          builder.addNode(`frame_${rev.id}`, frmMeshIdx, pos, rot);
        } else {
          // Unavailable or adjacent car seat: instanced as non-selectable static node
          const disMap = collectMatMap(protoSeat.root);
          const disMeshIdx = builder.buildMesh(
            `dis_${modelKey}`,
            disMap,
            `dis:${modelKey}`
          );
          builder.addNode(`unavail_${rev.id}`, disMeshIdx, pos, rot);
        }
      }
    }

    results[`car_${className}.glb`] = builder.toBase64GLB();
  }

  return results;
}
"""


def main():
    with socketserver.TCPServer(("127.0.0.1", 0), QuietHandler) as httpd:
        port = httpd.server_address[1]
        thread = threading.Thread(target=httpd.serve_forever, daemon=True)
        thread.start()

        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            page = browser.new_page()
            page.goto(f"http://127.0.0.1:{port}/index.html", wait_until="domcontentloaded")
            glb_map = page.evaluate(JS_EXPORTER)
            browser.close()

        httpd.shutdown()

    for filename, b64_data in glb_map.items():
        raw = base64.b64decode(b64_data)
        out_path = OUT_DIR / filename
        out_path.write_bytes(raw)
        print(f"Exported {out_path.name}: {len(raw) / 1024:.1f} KB")


if __name__ == "__main__":
    main()
