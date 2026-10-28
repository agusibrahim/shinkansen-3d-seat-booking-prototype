import SceneKit
import UIKit

/// Loads 3D models into a SceneKit scene and manages scene lifecycle.
///
/// Includes a zero-dependency native Swift glTF 2.0 Binary (.glb) parser for
/// SceneKit (supporting instanced meshes, PBR materials, PNG textures, normals,
/// UVs, and SeatMap camera positioning) as well as SCNSceneSource fallback.
class SceneManager {

    private weak var scnView: SCNView?
    var cameraNode: SCNNode?
    var useSolidBackground = false
    var seatMapMode = false

    /// Node opacity tracking for part group visibility.
    var nodeOpacities: [SCNNode: CGFloat] = [:]

    init(scnView: SCNView) {
        self.scnView = scnView
    }

    /// Removes all nodes, geometry, materials, and textures from the current
    /// scene to prevent memory accumulation across model loads.
    func cleanupPreviousModel() {
        nodeOpacities.removeAll()

        if let scene = scnView?.scene {
            scene.rootNode.enumerateChildNodes { (node, _) in
                if let geometry = node.geometry {
                    for material in geometry.materials {
                        material.diffuse.contents = nil
                        material.normal.contents = nil
                        material.emission.contents = nil
                        material.multiply.contents = nil
                        material.specular.contents = nil
                        material.roughness.contents = nil
                        material.metalness.contents = nil
                        material.ambientOcclusion.contents = nil
                    }
                    geometry.materials = []
                    node.geometry = nil
                }
                node.removeFromParentNode()
            }
            scene.background.contents = nil
            scene.lightingEnvironment.contents = nil
        }

        SCNTransaction.flush()
        cameraNode = nil
        homePose = nil
    }

    /// Loads a GLB/glTF model from raw bytes into the scene view.
    func loadModel(modelBytes: Data, name: String, resources: [String: Data]) throws {
        cleanupPreviousModel()

        let scene: SCNScene
        if modelBytes.count >= 12 && Self.readUInt32LE(modelBytes, at: 0) == 0x46546C67 {
            scene = try loadGLB(modelBytes: modelBytes)
        } else {
            let sceneSource = SCNSceneSource(data: modelBytes, options: [
                SCNSceneSource.LoadingOption.createNormalsIfAbsent: true,
                SCNSceneSource.LoadingOption.checkConsistency: true
            ])
            guard let loadedScene = sceneSource?.scene(options: nil) else {
                throw NSError(domain: "SceneManager", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "SCNSceneSource failed"])
            }
            scene = loadedScene
        }

        if !hasLightNodes(in: scene.rootNode) {
            addDefaultLighting(to: scene)
        }

        scnView?.scene = scene
    }

    /// Positions the camera at (0, 7.2, cameraZ) with 64-deg vertical FOV & -0.9638 rad pitch
    /// matching CameraNode.swift from the Xcode project.
    func setSeatMapCamera(_ cameraZ: Float) {
        guard let view = scnView, let scene = view.scene else { return }
        seatMapMode = true
        view.allowsCameraControl = false
        let pov = view.pointOfView ?? makeCamera(in: scene)
        pov.camera?.fieldOfView = 64.0
        pov.camera?.projectionDirection = .vertical
        pov.camera?.zNear = 0.4
        pov.camera?.zFar = 80.0
        pov.camera?.automaticallyAdjustsZRange = false
        pov.position = SCNVector3(0.0, 7.2, cameraZ)
        pov.eulerAngles = SCNVector3(-0.9638087, 0.0, 0.0)
        view.setNeedsDisplay()
    }

    /// Positions the camera in Confirmation preview mode at horizontal [yaw] and [scale].
    func setPreviewPose(yaw: Float, scale: Float) {
        guard let view = scnView, let scene = view.scene else { return }
        seatMapMode = false
        view.allowsCameraControl = false
        let s = max(0.08, min(scale, 2.5))
        let dist: Float = 6.2 / s
        let target = simd_float3(0.0, 0.50, 0.0)
        let eyeX = dist * sin(-yaw)
        let eyeY: Float = 0.50 + (0.76 / s)
        let eyeZ = dist * cos(-yaw)
        let pov = view.pointOfView ?? makeCamera(in: scene)
        pov.camera?.fieldOfView = 16.0
        pov.camera?.projectionDirection = .vertical
        pov.camera?.zNear = 0.4
        pov.camera?.zFar = 60.0
        pov.camera?.automaticallyAdjustsZRange = false
        pov.simdWorldPosition = simd_float3(eyeX, eyeY, eyeZ)
        pov.simdLook(at: target, up: simd_float3(0, 1, 0), localFront: SCNNode.simdLocalFront)
        view.setNeedsDisplay()
    }

    /// Frames the model the way the Android renderer does at [zoomLevel].
    func setCameraZoomLevel(_ zoomLevel: Float) {
        seatMapMode = false
        scnView?.allowsCameraControl = true
        frame(zoom: zoomLevel, fromFront: false)
    }

    /// Returns to the view shown after load.
    func resetCamera(zoom: Float?) {
        guard let view = scnView else { return }
        view.defaultCameraController.stopInertia()
        if let zoom = zoom {
            frame(zoom: zoom, fromFront: true)
        } else if let home = homePose, let pov = view.pointOfView,
                  let scene = view.scene, let framing = framing(of: scene) {
            pov.simdWorldTransform = home.transform
            pov.camera?.fieldOfView = home.fieldOfView
            view.defaultCameraController.target = SCNVector3(framing.target)
            view.setNeedsDisplay()
        }
    }

    /// Adds [delta] to the zoom level read from the live camera.
    func zoomBy(_ delta: Float) {
        guard delta.isFinite, let view = scnView, let scene = view.scene,
              let pov = view.pointOfView, let camera = pov.camera,
              let framing = framing(of: scene) else { return }
        let distance = simd_distance(pov.simdWorldPosition, framing.target)
        guard distance > 0 else { return }
        let current = Self.zoomLevel(
            magnification: (framing.radius * Self.halfFovTan)
                / (distance * tan(Float(camera.fieldOfView) * .pi / 360)))
        let next = min(max(current + delta, min(current, 0.5)), max(current, 3.0))
        frame(zoom: next, fromFront: false, framing: framing)
    }

    func captureHomePose() -> Bool {
        if seatMapMode { return true }
        guard homePose == nil else { return true }
        guard let pov = scnView?.pointOfView, let camera = pov.camera else { return false }
        homePose = (pov.simdWorldTransform, camera.fieldOfView)
        return true
    }

    private var homePose: (transform: simd_float4x4, fieldOfView: CGFloat)?

    private func frame(
        zoom zoomLevel: Float, fromFront: Bool,
        framing known: (target: simd_float3, radius: Float)? = nil
    ) {
        guard let view = scnView, let scene = view.scene,
              zoomLevel.isFinite, zoomLevel > 0,
              let framing = known ?? framing(of: scene) else { return }
        let zoom = max(zoomLevel, 0.3)

        let existing = view.pointOfView
        let pov = existing ?? makeCamera(in: scene)
        var direction = simd_float3(0, 0, 1)
        if !fromFront, let current = existing?.simdWorldPosition {
            direction = current - framing.target
        }
        if simd_length(direction) < 1e-5 { direction = simd_float3(0, 0, 1) }
        pov.simdWorldPosition = framing.target + simd_normalize(direction) * (framing.radius / zoom)
        if fromFront {
            pov.simdLook(at: framing.target, up: simd_float3(0, 1, 0), localFront: SCNNode.simdLocalFront)
        } else {
            pov.simdLook(at: framing.target)
        }
        pov.camera?.fieldOfView = CGFloat(Self.baseFieldOfView / zoom)
        pov.camera?.projectionDirection = .vertical
        pov.camera?.automaticallyAdjustsZRange = true
        view.defaultCameraController.target = SCNVector3(framing.target)
        view.setNeedsDisplay()
    }

    private func framing(of scene: SCNScene) -> (target: simd_float3, radius: Float)? {
        guard let (lower, upper) = geometryBounds(of: scene) else { return nil }
        let maxHalfExtent = simd_reduce_max((upper - lower) / 2)
        guard maxHalfExtent > 0 else { return nil }
        let fitDistance = 2 / tan(Self.baseFieldOfView * .pi / 180 / 8)
        return ((lower + upper) / 2, fitDistance * 1.4 * maxHalfExtent / 2)
    }

    private static let halfFovTan = tan(baseFieldOfView * .pi / 360)

    private static func zoomLevel(magnification: Float) -> Float {
        func magnificationAt(_ zoom: Float) -> Float {
            zoom * halfFovTan / tan(baseFieldOfView * .pi / 360 / zoom)
        }
        var low: Float = 0.3, high: Float = 10
        let target = min(max(magnification, magnificationAt(low)), magnificationAt(high))
        for _ in 0..<40 {
            let mid = (low + high) / 2
            if magnificationAt(mid) < target { low = mid } else { high = mid }
        }
        return (low + high) / 2
    }

    private static let baseFieldOfView: Float = 45

    private func geometryBounds(of scene: SCNScene) -> (simd_float3, simd_float3)? {
        var lower = simd_float3(repeating: .infinity)
        var upper = simd_float3(repeating: -.infinity)
        scene.rootNode.enumerateHierarchy { node, _ in
            guard node.geometry != nil else { return }
            let (minBound, maxBound) = node.boundingBox
            for corner in 0..<8 {
                let local = simd_float3(
                    corner & 1 == 0 ? minBound.x : maxBound.x,
                    corner & 2 == 0 ? minBound.y : maxBound.y,
                    corner & 4 == 0 ? minBound.z : maxBound.z)
                let world = node.simdConvertPosition(local, to: nil)
                lower = simd_min(lower, world)
                upper = simd_max(upper, world)
            }
        }
        return lower.x.isFinite ? (lower, upper) : nil
    }

    private func makeCamera(in scene: SCNScene) -> SCNNode {
        let node = SCNNode()
        node.camera = SCNCamera()
        node.name = "interactive3d_camera"
        scene.rootNode.addChildNode(node)
        scnView?.pointOfView = node
        cameraNode = node
        return node
    }

    func loadHdrBackground(_ backgroundBytes: Data) throws {
        // Optional HDR environment
    }

    func setPartGroupVisibility(group: [String: Any], isVisible: Bool) {
        guard let scene = scnView?.scene,
              let names = group["names"] as? [String] else { return }

        let opacity: CGFloat = isVisible ? 1.0 : 0.0
        scene.rootNode.enumerateChildNodes { (node, _) in
            if let nodeName = node.name, names.contains(nodeName) {
                node.opacity = opacity
                node.isHidden = !isVisible
                self.nodeOpacities[node] = opacity

                node.enumerateChildNodes { (child, _) in
                    if child.geometry != nil {
                        child.opacity = opacity
                        child.isHidden = !isVisible
                        self.nodeOpacities[child] = opacity
                    }
                }
            }
        }
        scnView?.setNeedsDisplay()
    }

    func cleanup() {
        cleanupPreviousModel()
        scnView?.scene = nil
        SCNTransaction.flush()
    }

    // MARK: - Native Swift glTF 2.0 Binary (.glb) Parser

    private static func readUInt32LE(_ data: Data, at offset: Int) -> UInt32 {
        let base = data.startIndex + offset
        let b0 = UInt32(data[base])
        let b1 = UInt32(data[base + 1]) << 8
        let b2 = UInt32(data[base + 2]) << 16
        let b3 = UInt32(data[base + 3]) << 24
        return b0 | b1 | b2 | b3
    }

    private func loadGLB(modelBytes: Data) throws -> SCNScene {
        let jsonLen: UInt32 = Self.readUInt32LE(modelBytes, at: 12)
        let jsonStart = 20
        let jsonEnd = jsonStart + Int(jsonLen)
        guard jsonEnd <= modelBytes.count else {
            throw NSError(domain: "SceneManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid GLB JSON chunk"])
        }
        let jsonData = modelBytes.subdata(in: jsonStart..<jsonEnd)
        guard let gltf = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw NSError(domain: "SceneManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid GLB JSON"])
        }

        let binHeaderStart = jsonEnd
        var binData = Data()
        if binHeaderStart + 8 <= modelBytes.count {
            let binLen: UInt32 = Self.readUInt32LE(modelBytes, at: binHeaderStart)
            let binStart = binHeaderStart + 8
            let binEnd = min(binStart + Int(binLen), modelBytes.count)
            binData = Data(modelBytes[binStart..<binEnd])
        }

        let bufferViews = gltf["bufferViews"] as? [[String: Any]] ?? []
        let accessors = gltf["accessors"] as? [[String: Any]] ?? []
        let images = gltf["images"] as? [[String: Any]] ?? []
        let textures = gltf["textures"] as? [[String: Any]] ?? []
        let materialsJson = gltf["materials"] as? [[String: Any]] ?? []
        let meshesJson = gltf["meshes"] as? [[String: Any]] ?? []
        let nodesJson = gltf["nodes"] as? [[String: Any]] ?? []

        func sliceBufferView(_ bvIdx: Int) -> Data {
            guard bvIdx >= 0 && bvIdx < bufferViews.count else { return Data() }
            let bv = bufferViews[bvIdx]
            let offset = bv["byteOffset"] as? Int ?? 0
            let length = bv["byteLength"] as? Int ?? 0
            guard offset + length <= binData.count else { return Data() }
            let start = binData.startIndex + offset
            return Data(binData[start..<(start + length)])
        }

        // Decode embedded PNG textures
        var uiImages: [UIImage?] = []
        for imgDict in images {
            if let bvIdx = imgDict["bufferView"] as? Int {
                let data = sliceBufferView(bvIdx)
                uiImages.append(UIImage(data: data))
            } else {
                uiImages.append(nil)
            }
        }

        // Build SCNMaterials
        var scnMaterials: [SCNMaterial] = []
        for matDict in materialsJson {
            let m = SCNMaterial()
            m.lightingModel = .blinn
            m.isDoubleSided = (matDict["doubleSided"] as? Bool) ?? true
            if let pbr = matDict["pbrMetallicRoughness"] as? [String: Any] {
                var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1, a: CGFloat = 1
                if let bcf = pbr["baseColorFactor"] as? [Double], bcf.count >= 4 {
                    r = CGFloat(bcf[0])
                    g = CGFloat(bcf[1])
                    b = CGFloat(bcf[2])
                    a = CGFloat(bcf[3])
                }
                if let bct = pbr["baseColorTexture"] as? [String: Any],
                   let texIdx = bct["index"] as? Int,
                   texIdx >= 0 && texIdx < textures.count,
                   let srcIdx = textures[texIdx]["source"] as? Int,
                   srcIdx >= 0 && srcIdx < uiImages.count,
                   let uiImg = uiImages[srcIdx] {
                    m.diffuse.contents = uiImg
                    m.multiply.contents = UIColor(red: r, green: g, blue: b, alpha: a)
                } else {
                    m.diffuse.contents = UIColor(red: r, green: g, blue: b, alpha: a)
                }
                let roughness = CGFloat(pbr["roughnessFactor"] as? Double ?? 0.55)
                let metalness = CGFloat(pbr["metallicFactor"] as? Double ?? 0.08)
                m.shininess = max(4.0, (1.0 - roughness) * 48.0)
                m.specular.contents = UIColor(white: 0.12 + metalness * 0.45, alpha: 1.0)
                if a < 0.995 {
                    m.transparency = a
                    m.writesToDepthBuffer = false
                }
            }
            scnMaterials.append(m)
        }

        // Build prototype SCNGeometry array per glTF mesh
        var meshPrimitives: [[SCNGeometry]] = []
        for meshDict in meshesJson {
            let prims = meshDict["primitives"] as? [[String: Any]] ?? []
            var geoList: [SCNGeometry] = []
            for prim in prims {
                guard let attrs = prim["attributes"] as? [String: Any],
                      let posAccIdx = attrs["POSITION"] as? Int,
                      posAccIdx < accessors.count else { continue }

                let posAcc = accessors[posAccIdx]
                let vCount = posAcc["count"] as? Int ?? 0
                let posData = sliceBufferView(posAcc["bufferView"] as? Int ?? -1)
                var sources: [SCNGeometrySource] = [
                    SCNGeometrySource(
                        data: posData,
                        semantic: .vertex,
                        vectorCount: vCount,
                        usesFloatComponents: true,
                        componentsPerVector: 3,
                        bytesPerComponent: 4,
                        dataOffset: 0,
                        dataStride: 12
                    )
                ]

                if let normAccIdx = attrs["NORMAL"] as? Int, normAccIdx < accessors.count {
                    let normData = sliceBufferView(accessors[normAccIdx]["bufferView"] as? Int ?? -1)
                    sources.append(SCNGeometrySource(
                        data: normData,
                        semantic: .normal,
                        vectorCount: vCount,
                        usesFloatComponents: true,
                        componentsPerVector: 3,
                        bytesPerComponent: 4,
                        dataOffset: 0,
                        dataStride: 12
                    ))
                }

                if let uvAccIdx = attrs["TEXCOORD_0"] as? Int, uvAccIdx < accessors.count {
                    let uvData = sliceBufferView(accessors[uvAccIdx]["bufferView"] as? Int ?? -1)
                    sources.append(SCNGeometrySource(
                        data: uvData,
                        semantic: .texcoord,
                        vectorCount: vCount,
                        usesFloatComponents: true,
                        componentsPerVector: 2,
                        bytesPerComponent: 4,
                        dataOffset: 0,
                        dataStride: 8
                    ))
                }

                let element: SCNGeometryElement
                if let idxAccIdx = prim["indices"] as? Int, idxAccIdx < accessors.count {
                    let idxAcc = accessors[idxAccIdx]
                    let idxCount = idxAcc["count"] as? Int ?? 0
                    let compType = idxAcc["componentType"] as? Int ?? 5123
                    let bytesPerIndex = compType == 5125 ? 4 : 2
                    let idxData = sliceBufferView(idxAcc["bufferView"] as? Int ?? -1)
                    element = SCNGeometryElement(
                        data: idxData,
                        primitiveType: .triangles,
                        primitiveCount: idxCount / 3,
                        bytesPerIndex: bytesPerIndex
                    )
                } else {
                    var idxArr = [UInt32](repeating: 0, count: vCount)
                    for i in 0..<vCount { idxArr[i] = UInt32(i) }
                    let idxData = Data(bytes: idxArr, count: vCount * 4)
                    element = SCNGeometryElement(
                        data: idxData,
                        primitiveType: .triangles,
                        primitiveCount: vCount / 3,
                        bytesPerIndex: 4
                    )
                }

                let geo = SCNGeometry(sources: sources, elements: [element])
                if let matIdx = prim["material"] as? Int, matIdx >= 0 && matIdx < scnMaterials.count {
                    geo.materials = [scnMaterials[matIdx].copy() as! SCNMaterial]
                }
                geoList.append(geo)
            }
            meshPrimitives.append(geoList)
        }

        let scene = SCNScene()
        for (i, nodeDict) in nodesJson.enumerated() {
            let node = SCNNode()
            node.name = (nodeDict["name"] as? String) ?? "Node_\(i)"
            if let tr = nodeDict["translation"] as? [Double], tr.count >= 3 {
                node.position = SCNVector3(Float(tr[0]), Float(tr[1]), Float(tr[2]))
            }
            if let rot = nodeDict["rotation"] as? [Double], rot.count >= 4 {
                node.orientation = SCNQuaternion(Float(rot[0]), Float(rot[1]), Float(rot[2]), Float(rot[3]))
            }
            if let meshIdx = nodeDict["mesh"] as? Int, meshIdx >= 0 && meshIdx < meshPrimitives.count {
                let geos = meshPrimitives[meshIdx]
                if geos.count == 1 {
                    let cloned = geos[0].copy() as! SCNGeometry
                    cloned.materials = geos[0].materials.map { $0.copy() as! SCNMaterial }
                    node.geometry = cloned
                } else {
                    for (pIdx, g) in geos.enumerated() {
                        let child = SCNNode()
                        child.name = "Mesh.\(pIdx)"
                        let cloned = g.copy() as! SCNGeometry
                        cloned.materials = g.materials.map { $0.copy() as! SCNMaterial }
                        child.geometry = cloned
                        node.addChildNode(child)
                    }
                }
            }
            scene.rootNode.addChildNode(node)
        }

        return scene
    }

    private func hasLightNodes(in node: SCNNode) -> Bool {
        if node.light != nil { return true }
        return node.childNodes.contains { hasLightNodes(in: $0) }
    }

    private func addDefaultLighting(to scene: SCNScene) {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = UIColor(white: 0.72, alpha: 1.0)
        scene.rootNode.addChildNode(ambient)

        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.color = UIColor(white: 0.62, alpha: 1.0)
        keyLight.eulerAngles = SCNVector3(-0.95, 0.35, 0)
        scene.rootNode.addChildNode(keyLight)

        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .directional
        fillLight.light?.color = UIColor(white: 0.35, alpha: 1.0)
        fillLight.eulerAngles = SCNVector3(-0.65, -0.55, 0)
        scene.rootNode.addChildNode(fillLight)
    }
}
