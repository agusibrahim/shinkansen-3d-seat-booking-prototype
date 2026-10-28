import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_scene/scene.dart' as fs;
import 'package:vector_math/vector_math.dart' as vm32;
import 'package:vector_math/vector_math_64.dart' as vm;
import '../models/booking_models.dart';
import '../theme/design_system.dart';

// ============================================================================
// 100% Native Dart/Flutter 3D Mesh Engine (Zero WebView!)
// Uses Impeller/Skia Canvas.drawVertices with 3-Point Studio Lighting & Z-Sort
// ============================================================================

class TriFace {
  final vm.Vector3 v0;
  final vm.Vector3 v1;
  final vm.Vector3 v2;
  final vm.Vector3 n0;
  final vm.Vector3 n1;
  final vm.Vector3 n2;
  final Offset uv0;
  final Offset uv1;
  final Offset uv2;
  final double ao0;
  final double ao1;
  final double ao2;
  final vm.Vector3 sortCenter;
  final vm.Vector3 normal;
  final Color color;
  final double roughness;
  final double metalness;
  final bool unlit;

  const TriFace({
    required this.v0,
    required this.v1,
    required this.v2,
    required this.n0,
    required this.n1,
    required this.n2,
    this.uv0 = const Offset(448.0, 448.0),
    this.uv1 = const Offset(448.0, 448.0),
    this.uv2 = const Offset(448.0, 448.0),
    this.ao0 = 1.0,
    this.ao1 = 1.0,
    this.ao2 = 1.0,
    required this.sortCenter,
    required this.normal,
    required this.color,
    this.roughness = 0.5,
    this.metalness = 0.05,
    this.unlit = false,
  });
}

class MeshPart {
  final List<TriFace> faces;
  final String role; // 'center', 'bolster', 'headInsert', 'seam', 'static', 'unavail'
  final bool reclines;

  const MeshPart({
    required this.faces,
    this.role = 'static',
    this.reclines = false,
  });
}

class KAIGeometryBuilder {
  static final Map<String, List<MeshPart>> _seatPrototypeCache = {};
  static final Map<String, List<TriFace>> _staticSectionCache = {};
  static final Map<String, fs.Mesh> _flutterSceneMeshCache = {};
  static ui.ImageShader? _atlasShader;
  static bool flutterSceneAvailable = false;
  static bool _flutterSceneInitAttempted = false;

  /// Generates a 512x512 HD Procedural Material Texture Atlas synchronously:
  /// - Quadrant 0 (0..256, 0..256): Plush Woven Jacquard / Twill Fabric + Pillowed Vignette + Quilted Stitch Seams
  /// - Quadrant 1 (256..512, 0..256): Bolster & Diamond Jacquard Woven Fabric + Pillowed Edge Vignette
  /// - Quadrant 2 (0..256, 256..512): Natural Wood Grain (Teak / Mahogany / Burl)
  /// - Quadrant 3 (256..512, 256..512): Brushed Satin Metal + Solid White (448,448) for Cabin Architecture
  static ui.ImageShader getAtlasShader() {
    if (_atlasShader != null) return _atlasShader!;
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder, const Rect.fromLTWH(0, 0, 512, 512));

    // Base fill
    c.drawRect(
      const Rect.fromLTWH(0, 0, 512, 512),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    void drawFabricQuadrant(double ox, double oy, {required bool isCenterPad}) {
      final rect = Rect.fromLTWH(ox, oy, 256, 256);
      c.save();
      c.clipRect(rect);

      // 1. Vertical cushion crown gradient
      c.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(ox, oy),
            Offset(ox, oy + 256),
            const [
              Color(0xFFFFFFFF),
              Color(0xFFF6F6F9),
              Color(0xFFEBEBF0),
              Color(0xFFD8D8E0),
            ],
            const [0.0, 0.25, 0.80, 1.0],
          ),
      );

      // 2. Soft pillowed left-to-right cushion edge vignette
      c.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(ox, oy),
            Offset(ox + 256, oy),
            const [
              Color(0x3D000000),
              Color(0x0A000000),
              Color(0x00000000),
              Color(0x0A000000),
              Color(0x3D000000),
            ],
            const [0.0, 0.14, 0.50, 0.86, 1.0],
          ),
      );

      // 3. Dense woven fabric threads (warp & weft twill micro-weave)
      final warpLight = Paint()
        ..color = const Color(0x24FFFFFF)
        ..strokeWidth = 1.2;
      final weftDark = Paint()
        ..color = const Color(0x1F000000)
        ..strokeWidth = 1.1;
      for (double y = 0; y < 256; y += 3.0) {
        c.drawLine(Offset(ox, oy + y), Offset(ox + 256, oy + y), warpLight);
        c.drawLine(
          Offset(ox, oy + y + 1.5),
          Offset(ox + 256, oy + y + 1.5),
          weftDark,
        );
      }
      for (double x = 0; x < 256; x += 3.0) {
        c.drawLine(Offset(ox + x, oy), Offset(ox + x, oy + 256), warpLight);
        c.drawLine(
          Offset(ox + x + 1.5, oy),
          Offset(ox + x + 1.5, oy + 256),
          weftDark,
        );
      }
      // Diagonal twill fabric texture lines
      final twillPaint = Paint()
        ..color = const Color(0x16000000)
        ..strokeWidth = 1.0;
      for (double d = -256; d < 512; d += 5.0) {
        c.drawLine(
          Offset(ox + d, oy),
          Offset(ox + d + 256, oy + 256),
          twillPaint,
        );
      }

      // 4. Tactile cloth fiber micro-speckle
      final lightDot = Paint()..color = const Color(0x18FFFFFF);
      final darkDot = Paint()..color = const Color(0x1A000000);
      for (int i = 0; i < 1800; i++) {
        final rx = ox + ((i * 131 + (i % 7) * 19) % 254);
        final ry = oy + ((i * 73 + (i % 13) * 11) % 254);
        c.drawRect(
          Rect.fromLTWH(rx, ry, 1.8, 1.8),
          i.isEven ? lightDot : darkDot,
        );
      }

      if (isCenterPad) {
        // 5a. Quilted horizontal upholstery seams + double-stitch marks
        final seamDark = Paint()
          ..color = const Color(0x46000000)
          ..strokeWidth = 2.8;
        final seamHi = Paint()
          ..color = const Color(0x36FFFFFF)
          ..strokeWidth = 1.6;
        final stitchPaint = Paint()
          ..color = const Color(0x38FFFFFF)
          ..strokeWidth = 1.2;

        for (final sy in [68.0, 122.0, 174.0, 218.0]) {
          c.drawLine(
            Offset(ox + 14, oy + sy),
            Offset(ox + 242, oy + sy),
            seamDark,
          );
          c.drawLine(
            Offset(ox + 14, oy + sy + 2.5),
            Offset(ox + 242, oy + sy + 2.5),
            seamHi,
          );
          for (double sx = 18; sx < 238; sx += 7.0) {
            c.drawLine(
              Offset(ox + sx, oy + sy - 3.0),
              Offset(ox + sx + 3.5, oy + sy - 3.0),
              stitchPaint,
            );
          }
        }
      } else {
        // 5b. Subtle embossed jacquard diamond weave on headrest/bolsters
        final jacquardDark = Paint()
          ..color = const Color(0x1E000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3;
        for (double y = 28; y < 228; y += 28) {
          for (double x = 28; x < 228; x += 28) {
            final p = Path()
              ..moveTo(ox + x, oy + y - 9)
              ..lineTo(ox + x + 9, oy + y)
              ..lineTo(ox + x, oy + y + 9)
              ..lineTo(ox + x - 9, oy + y)
              ..close();
            c.drawPath(p, jacquardDark);
          }
        }
      }

      // Outer upholstery piping stitch border
      final borderStitch = Paint()
        ..color = const Color(0x2E000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(ox + 10, oy + 10, 236, 236),
          const Radius.circular(18),
        ),
        borderStitch,
      );
      c.restore();
    }

    // Quadrant 0: Center Cushion Woven Fabric
    drawFabricQuadrant(0, 0, isCenterPad: true);
    // Quadrant 1: Bolster / Headrest Jacquard Woven Fabric
    drawFabricQuadrant(256, 0, isCenterPad: false);

    // Quadrant 2 (0..256, 256..512): Natural Wood Grain
    final woodRect = const Rect.fromLTWH(0, 256, 256, 256);
    c.save();
    c.clipRect(woodRect);
    c.drawRect(
      woodRect,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 256),
          const Offset(256, 512),
          const [Color(0xFFFFFFFF), Color(0xFFEDE4DA), Color(0xFFD6C8B8)],
          const [0.0, 0.5, 1.0],
        ),
    );
    final grainDark = Paint()
      ..color = const Color(0x361E0E05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final grainLight = Paint()
      ..color = const Color(0x24FFF8EE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (int i = 0; i < 48; i++) {
      final y = 256.0 + (i * 5.5) % 256.0;
      final p = Path()
        ..moveTo(0, y)
        ..cubicTo(85, y + 4, 170, y - 4, 256, y + 1.5);
      c.drawPath(p, grainDark);
      c.drawPath(p.shift(const Offset(0, 1.8)), grainLight);
    }
    c.restore();

    // Quadrant 3 (256..512, 256..384): Brushed Satin Metal
    final metalRect = const Rect.fromLTWH(256, 256, 256, 128);
    c.save();
    c.clipRect(metalRect);
    c.drawRect(
      metalRect,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(256, 256),
          const Offset(512, 384),
          const [Color(0xFFFFFFFF), Color(0xFFECEFF4), Color(0xFFDCE1E8)],
          const [0.0, 0.5, 1.0],
        ),
    );
    final brushDark = Paint()
      ..color = const Color(0x16000000)
      ..strokeWidth = 1.0;
    for (double y = 256; y < 384; y += 2.5) {
      c.drawLine(Offset(256, y), Offset(512, y), brushDark);
    }
    c.restore();

    final picture = recorder.endRecording();
    final img = picture.toImageSync(512, 512);
    _atlasShader = ui.ImageShader(
      img,
      TileMode.clamp,
      TileMode.clamp,
      Float64List.fromList([
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
      ]),
    );
    return _atlasShader!;
  }

  /// Initializes `flutter_scene` GPU shader library & IBL environment when supported by the runtime engine.
  static Future<void> ensureFlutterSceneInitialized() async {
    if (_flutterSceneInitAttempted) return;
    _flutterSceneInitAttempted = true;
    try {
      await fs.Scene.initializeStaticResources();
      flutterSceneAvailable = true;
    } catch (_) {
      flutterSceneAvailable = false;
    }
  }

  /// Converts a list of [TriFace] into a `flutter_scene` [fs.Mesh] with [fs.MeshGeometry.fromArrays] and [fs.PhysicallyBasedMaterial].
  static fs.Mesh buildFlutterSceneMesh(String cacheKey, List<TriFace> faces) {
    return _flutterSceneMeshCache.putIfAbsent(cacheKey, () {
      final vCount = faces.length * 3;
      final positions = Float32List(vCount * 3);
      final normals = Float32List(vCount * 3);
      final colors = Float32List(vCount * 4);
      final indices = List<int>.generate(vCount, (i) => i);

      int pIdx = 0;
      int nIdx = 0;
      int cIdx = 0;
      for (final f in faces) {
        for (final v in [f.v0, f.v1, f.v2]) {
          positions[pIdx++] = v.x;
          positions[pIdx++] = v.y;
          positions[pIdx++] = v.z;
          normals[nIdx++] = f.normal.x;
          normals[nIdx++] = f.normal.y;
          normals[nIdx++] = f.normal.z;
          colors[cIdx++] = f.color.r;
          colors[cIdx++] = f.color.g;
          colors[cIdx++] = f.color.b;
          colors[cIdx++] = f.color.a;
        }
      }

      final geo = fs.MeshGeometry.fromArrays(
        positions: positions,
        normals: normals,
        colors: colors,
        indices: indices,
      );
      final mat = fs.PhysicallyBasedMaterial()
        ..baseColorFactor = vm32.Vector4(1, 1, 1, 1)
        ..vertexColorWeight = 1.0
        ..roughnessFactor = 0.48
        ..metallicFactor = 0.08;
      return fs.Mesh(geo, mat);
    });
  }

  static void addBox(
    List<TriFace> out, {
    required vm.Vector3 center,
    required vm.Vector3 size,
    required Color color,
    Color? topColor,
    Color? frontColor,
    double rx = 0,
    double ry = 0,
    double rz = 0,
    double roughness = 0.5,
    double metalness = 0.05,
    bool unlit = false,
  }) {
    final hx = size.x * 0.5;
    final hy = size.y * 0.5;
    final hz = size.z * 0.5;

    final rot = vm.Matrix3.identity();
    if (rz != 0) rot.multiply(vm.Matrix3.rotationZ(rz));
    if (ry != 0) rot.multiply(vm.Matrix3.rotationY(ry));
    if (rx != 0) rot.multiply(vm.Matrix3.rotationX(rx));

    vm.Vector3 tr(double x, double y, double z) {
      final v = rot.transformed(vm.Vector3(x, y, z));
      return v + center;
    }

    final p000 = tr(-hx, -hy, -hz);
    final p100 = tr(hx, -hy, -hz);
    final p110 = tr(hx, hy, -hz);
    final p010 = tr(-hx, hy, -hz);
    final p001 = tr(-hx, -hy, hz);
    final p101 = tr(hx, -hy, hz);
    final p111 = tr(hx, hy, hz);
    final p011 = tr(-hx, hy, hz);

    void quad(
      vm.Vector3 a,
      vm.Vector3 b,
      vm.Vector3 c,
      vm.Vector3 d,
      vm.Vector3 localN,
      Color faceCol,
    ) {
      final n = rot.transformed(localN).normalized();
      final qCenter = (a + b + c + d) * 0.25;
      out.add(TriFace(
        v0: a,
        v1: b,
        v2: c,
        n0: n,
        n1: n,
        n2: n,
        sortCenter: qCenter,
        normal: n,
        color: faceCol,
        roughness: roughness,
        metalness: metalness,
        unlit: unlit,
      ));
      out.add(TriFace(
        v0: a,
        v1: c,
        v2: d,
        n0: n,
        n1: n,
        n2: n,
        sortCenter: qCenter,
        normal: n,
        color: faceCol,
        roughness: roughness,
        metalness: metalness,
        unlit: unlit,
      ));
    }

    // Front (+Z)
    quad(p001, p101, p111, p011, vm.Vector3(0, 0, 1), frontColor ?? color);
    // Back (-Z)
    quad(p100, p000, p010, p110, vm.Vector3(0, 0, -1), color);
    // Top (+Y)
    quad(p011, p111, p110, p010, vm.Vector3(0, 1, 0), topColor ?? color);
    // Bottom (-Y)
    quad(p000, p100, p101, p001, vm.Vector3(0, -1, 0), color);
    // Right (+X)
    quad(p101, p100, p110, p111, vm.Vector3(1, 0, 0), color);
    // Left (-X)
    quad(p000, p001, p011, p010, vm.Vector3(-1, 0, 0), color);
  }

  /// Builds a smooth, rounded, contoured 3D cushion/shell mesh with analytical smooth
  /// per-vertex normals, pillow crown puffiness, waterfall edge, and UV atlas mapping!
  static void addRoundedBox(
    List<TriFace> out, {
    required vm.Vector3 center,
    required vm.Vector3 size,
    required Color color,
    double radius = 0.030,
    double puff = 0.010,
    double taperTopX = 1.0,
    double curveZByY = 0.0,
    double waterfallFront = 0.0,
    double aoBottom = 0.80,
    int uvQuadrant = 0, // 0: Center Fabric, 1: Bolster Fabric, 2: Wood, 3: Metal, 4: Solid
    int subdiv = 4,
    double rx = 0,
    double ry = 0,
    double rz = 0,
    double roughness = 0.62,
    double metalness = 0.04,
  }) {
    final hx = size.x * 0.5;
    final hy = size.y * 0.5;
    final hz = size.z * 0.5;
    final r = math.min(radius, math.min(hx, math.min(hy, hz)) * 0.88);
    final cx = math.max(0.0001, hx - r);
    final cy = math.max(0.0001, hy - r);
    final cz = math.max(0.0001, hz - r);

    final rot = vm.Matrix3.identity();
    if (rz != 0) rot.multiply(vm.Matrix3.rotationZ(rz));
    if (ry != 0) rot.multiply(vm.Matrix3.rotationY(ry));
    if (rx != 0) rot.multiply(vm.Matrix3.rotationX(rx));

    final List<double> stops = subdiv >= 5
        ? const [-1.0, -0.86, -0.52, 0.0, 0.52, 0.86, 1.0]
        : const [-1.0, -0.76, 0.0, 0.76, 1.0];

    double uMin = 12, uSpan = 232, vMin = 12, vSpan = 232;
    if (uvQuadrant == 1) {
      uMin = 268;
      uSpan = 232;
      vMin = 12;
      vSpan = 232;
    } else if (uvQuadrant == 2) {
      uMin = 12;
      uSpan = 232;
      vMin = 268;
      vSpan = 232;
    } else if (uvQuadrant == 3) {
      uMin = 268;
      uSpan = 232;
      vMin = 268;
      vSpan = 104;
    } else if (uvQuadrant == 4) {
      uMin = 448;
      uSpan = 0;
      vMin = 448;
      vSpan = 0;
    }

    final isHoriz = size.z > size.y * 1.45;

    ({vm.Vector3 p, vm.Vector3 n, Offset uv, double ao}) eval(
      double ux,
      double uy,
      double uz,
    ) {
      final bx = ux * hx;
      final by = uy * hy;
      final bz = uz * hz;
      final qx = bx.clamp(-cx, cx);
      final qy = by.clamp(-cy, cy);
      final qz = bz.clamp(-cz, cz);
      double dx = bx - qx;
      double dy = by - qy;
      double dz = bz - qz;
      final len = math.sqrt(dx * dx + dy * dy + dz * dz);
      double nx = len > 1e-6 ? dx / len : ux;
      double ny = len > 1e-6 ? dy / len : uy;
      double nz = len > 1e-6 ? dz / len : uz;

      double px = qx + nx * r;
      double py = qy + ny * r;
      double pz = qz + nz * r;

      if (puff != 0.0) {
        final r2 = (ux * ux + uy * uy + uz * uz) - 1.0;
        final crown = puff * math.max(0.0, 1.0 - 0.45 * r2);
        px += nx * crown;
        py += ny * crown;
        pz += nz * crown;
      }

      if (taperTopX != 1.0) {
        final ty = (uy + 1.0) * 0.5;
        px *= 1.0 + (taperTopX - 1.0) * ty;
      }

      if (curveZByY != 0.0) {
        pz += curveZByY * math.sin(uy * math.pi * 0.5);
      }

      if (waterfallFront != 0.0 && uz > 0.15 && uy > -0.2) {
        final wf = (uz - 0.15) / 0.85;
        py -= waterfallFront * wf * wf;
        ny -= wf * 0.25;
        nz += wf * 0.20;
      }

      final wp = rot.transformed(vm.Vector3(px, py, pz)) + center;
      final wn = rot.transformed(vm.Vector3(nx, ny, nz)).normalized();

      final uNorm = ((ux + 1.0) * 0.5).clamp(0.0, 1.0);
      final vNorm = isHoriz
          ? ((uz + 1.0) * 0.5).clamp(0.0, 1.0)
          : (1.0 - (uy + 1.0) * 0.5).clamp(0.0, 1.0);
      final uv = Offset(uMin + uNorm * uSpan, vMin + vNorm * vSpan);

      final edgeFactor = 1.0 - 0.14 * (ux * ux * uz * uz);
      final yFactor = aoBottom + (1.02 - aoBottom) * ((uy + 1.0) * 0.5);
      final ao = (yFactor * edgeFactor).clamp(0.62, 1.05);

      return (p: wp, n: wn, uv: uv, ao: ao);
    }

    void emitPatch(
      ({vm.Vector3 p, vm.Vector3 n, Offset uv, double ao}) Function(double u, double v) fn,
      bool flipWinding,
    ) {
      final n = stops.length - 1;
      for (int i = 0; i < n; i++) {
        final u0 = stops[i];
        final u1 = stops[i + 1];
        for (int j = 0; j < n; j++) {
          final v0 = stops[j];
          final v1 = stops[j + 1];
          final a = fn(u0, v0);
          final b = flipWinding ? fn(u0, v1) : fn(u1, v0);
          final c = fn(u1, v1);
          final d = flipWinding ? fn(u1, v0) : fn(u0, v1);

          final qCenter = (a.p + b.p + c.p + d.p) * 0.25;
          final faceN = (a.n + b.n + c.n + d.n).normalized();

          out.add(TriFace(
            v0: a.p,
            v1: b.p,
            v2: c.p,
            n0: a.n,
            n1: b.n,
            n2: c.n,
            uv0: a.uv,
            uv1: b.uv,
            uv2: c.uv,
            ao0: a.ao,
            ao1: b.ao,
            ao2: c.ao,
            sortCenter: qCenter,
            normal: faceN,
            color: color,
            roughness: roughness,
            metalness: metalness,
          ));
          out.add(TriFace(
            v0: a.p,
            v1: c.p,
            v2: d.p,
            n0: a.n,
            n1: c.n,
            n2: d.n,
            uv0: a.uv,
            uv1: c.uv,
            uv2: d.uv,
            ao0: a.ao,
            ao1: c.ao,
            ao2: d.ao,
            sortCenter: qCenter,
            normal: faceN,
            color: color,
            roughness: roughness,
            metalness: metalness,
          ));
        }
      }
    }

    // +Z (Front) and -Z (Back)
    emitPatch((u, v) => eval(u, v, 1.0), false);
    emitPatch((u, v) => eval(u, v, -1.0), true);
    // +Y (Top) and -Y (Bottom)
    emitPatch((u, v) => eval(u, 1.0, v), true);
    emitPatch((u, v) => eval(u, -1.0, v), false);
    // +X (Right) and -X (Left)
    emitPatch((u, v) => eval(1.0, v, u), true);
    emitPatch((u, v) => eval(-1.0, v, u), false);
  }

  /// Builds a smooth cylindrical tube with radial smooth normals for metal pipes, knobs, & frames.
  static void addCylinder(
    List<TriFace> out, {
    required vm.Vector3 center,
    required double radius,
    required double length,
    required Color color,
    int segments = 12,
    double rx = 0,
    double ry = 0,
    double rz = 0,
    double roughness = 0.22,
    double metalness = 0.80,
  }) {
    final rot = vm.Matrix3.identity();
    if (rz != 0) rot.multiply(vm.Matrix3.rotationZ(rz));
    if (ry != 0) rot.multiply(vm.Matrix3.rotationY(ry));
    if (rx != 0) rot.multiply(vm.Matrix3.rotationX(rx));

    final halfL = length * 0.5;
    const uvMetal = Offset(340.0, 320.0);

    for (int i = 0; i < segments; i++) {
      final a0 = (i / segments) * math.pi * 2.0;
      final a1 = ((i + 1) / segments) * math.pi * 2.0;
      final c0 = math.cos(a0), s0 = math.sin(a0);
      final c1 = math.cos(a1), s1 = math.sin(a1);

      final n0 = rot.transformed(vm.Vector3(c0, 0, s0)).normalized();
      final n1 = rot.transformed(vm.Vector3(c1, 0, s1)).normalized();
      final faceN = (n0 + n1).normalized();

      final p00 = rot.transformed(vm.Vector3(c0 * radius, -halfL, s0 * radius)) + center;
      final p10 = rot.transformed(vm.Vector3(c1 * radius, -halfL, s1 * radius)) + center;
      final p11 = rot.transformed(vm.Vector3(c1 * radius, halfL, s1 * radius)) + center;
      final p01 = rot.transformed(vm.Vector3(c0 * radius, halfL, s0 * radius)) + center;
      final qCenter = (p00 + p10 + p11 + p01) * 0.25;

      out.add(TriFace(
        v0: p00,
        v1: p11,
        v2: p10,
        n0: n0,
        n1: n1,
        n2: n1,
        uv0: uvMetal,
        uv1: uvMetal,
        uv2: uvMetal,
        sortCenter: qCenter,
        normal: faceN,
        color: color,
        roughness: roughness,
        metalness: metalness,
      ));
      out.add(TriFace(
        v0: p00,
        v1: p01,
        v2: p11,
        n0: n0,
        n1: n0,
        n2: n1,
        uv0: uvMetal,
        uv1: uvMetal,
        uv2: uvMetal,
        sortCenter: qCenter,
        normal: faceN,
        color: color,
        roughness: roughness,
        metalness: metalness,
      ));
    }
  }

  // Build authentic 3D seat parts for any of the 7 KAI seat variants
  static List<MeshPart> getSeatPrototype(String modelName) {
    return _seatPrototypeCache.putIfAbsent(modelName, () {
      if (modelName.contains('prem')) {
        return _buildEkonomiPremiumSeat(
          isPairA: modelName.endsWith('-a'),
          standalone: modelName.endsWith('_complete'),
        );
      } else if (modelName.contains('tosca')) {
        final role = modelName.endsWith('_complete')
            ? 'a'
            : modelName.substring(modelName.length - 1);
        return _buildEkonomiTosca23Seat(
          role: role,
          standalone: modelName.endsWith('_complete'),
        );
      } else if (modelName.contains('ordinary')) {
        final role = modelName.endsWith('_complete')
            ? 'a'
            : modelName.substring(modelName.length - 1);
        return _buildEkonomi23RegulerSeat(
          role: role,
          standalone: modelName.endsWith('_complete'),
        );
      } else {
        String variant = 'maroon';
        if (modelName.contains('eks-dualtone') || modelName.contains('eks_dualtone')) {
          variant = 'eksekutifDualTone';
        } else if (modelName.contains('blue-dualtone') || modelName.contains('blue_dualtone')) {
          variant = 'blueDualTone';
        } else if (modelName.contains('blue') || modelName.contains('green')) {
          variant = 'blue';
        }
        return _buildNextGenSeat(
          variant: variant,
          isPairA: modelName.endsWith('-a'),
          standalone: modelName.endsWith('_complete'),
        );
      }
    });
  }

  static ({Color center, Color bolster, Color headInsert, Color seam})
      getSeatStatePalette(String modelName, String state) {
    if (state == 'selected') {
      return (
        center: const Color(0xFF1E9E52),
        bolster: const Color(0xFF147A3D),
        headInsert: const Color(0xFF34B869),
        seam: const Color(0xFF0B4F26),
      );
    }
    if (state == 'disabled') {
      return (
        center: const Color(0xFFB0B4BC),
        bolster: const Color(0xFF989CA5),
        headInsert: const Color(0xFFA6AAB2),
        seam: const Color(0xFF7E828B),
      );
    }
    final hi = state == 'highlighted';
    if (modelName.contains('eks-dualtone') || modelName.contains('eks_dualtone')) {
      return (
        center: hi ? const Color(0xFFB2AEA6) : const Color(0xFFD2CEC5),
        bolster: hi ? const Color(0xFF0A698A) : const Color(0xFF0E86B0),
        headInsert: hi ? const Color(0xFFB2AEA6) : const Color(0xFFD2CEC5),
        seam: const Color(0xFF8A867D),
      );
    }
    if (modelName.contains('blue-dualtone') || modelName.contains('blue_dualtone')) {
      return (
        center: hi ? const Color(0xFF162848) : const Color(0xFF1F3864),
        bolster: hi ? const Color(0xFF101D36) : const Color(0xFF172A4D),
        headInsert: hi ? const Color(0xFFA68252) : const Color(0xFFC49C68),
        seam: const Color(0xFF0D1A33),
      );
    }
    if (modelName.contains('blue') || modelName.contains('green')) {
      return (
        center: hi ? const Color(0xFF354870) : const Color(0xFF4A6294),
        bolster: hi ? const Color(0xFF263554) : const Color(0xFF384C76),
        headInsert: hi ? const Color(0xFF354870) : const Color(0xFF526B9E),
        seam: const Color(0xFF243352),
      );
    }
    if (modelName.contains('prem')) {
      return (
        center: hi ? const Color(0xFF8A796B) : const Color(0xFFAA9787),
        bolster: hi ? const Color(0xFF716255) : const Color(0xFF8F7D6E),
        headInsert: hi ? const Color(0xFF8A796B) : const Color(0xFFAA9787),
        seam: const Color(0xFF665649),
      );
    }
    if (modelName.contains('tosca')) {
      return (
        center: hi ? const Color(0xFF21869C) : const Color(0xFF2CA8C2),
        bolster: hi ? const Color(0xFF186E80) : const Color(0xFF218DA4),
        headInsert: hi ? const Color(0xFF21869C) : const Color(0xFF35B4CE),
        seam: const Color(0xFF156475),
      );
    }
    if (modelName.contains('ordinary')) {
      return (
        center: hi ? const Color(0xFFA39880) : const Color(0xFFC2B69C),
        bolster: hi ? const Color(0xFF8B816B) : const Color(0xFFAA9E84),
        headInsert: hi ? const Color(0xFFA39880) : const Color(0xFFC2B69C),
        seam: const Color(0xFF8C816A),
      );
    }
    // Default: Maroon Eksekutif Next Gen
    return (
      center: hi ? const Color(0xFF5C2230) : const Color(0xFF7E3647),
      bolster: hi ? const Color(0xFF451823) : const Color(0xFF662837),
      headInsert: hi ? const Color(0xFF5C2230) : const Color(0xFF883C4E),
      seam: const Color(0xFF4A1925),
    );
  }

  // 1, 2, 3, 4: KAI Next Gen / Dual-Tone 2-2 Smooth Sculpted Seat Builder
  static List<MeshPart> _buildNextGenSeat({
    required String variant,
    required bool isPairA,
    required bool standalone,
  }) {
    final staticFaces = <TriFace>[];
    final centerFaces = <TriFace>[];
    final bolsterFaces = <TriFace>[];
    final reclineCenterFaces = <TriFace>[];
    final reclineBolsterFaces = <TriFace>[];
    final reclineHeadInsertFaces = <TriFace>[];
    final subdiv = standalone ? 5 : 4;

    // Smooth cylindrical pedestal base + beveled floor flange
    addCylinder(
      staticFaces,
      center: vm.Vector3(0, 0.10, -0.05),
      radius: 0.11,
      length: 0.18,
      color: const Color(0xFF22252D),
      roughness: 0.52,
      metalness: 0.32,
    );
    addRoundedBox(
      staticFaces,
      center: vm.Vector3(0, 0.025, -0.04),
      size: vm.Vector3(0.32, 0.04, 0.30),
      radius: 0.018,
      puff: 0.0,
      uvQuadrant: 3,
      subdiv: 4,
      color: const Color(0xFF22252D),
      roughness: 0.55,
      metalness: 0.30,
    );

    // Ergonomic Footrest + Twin Chrome Support Struts
    for (final sx in [-0.13, 0.13]) {
      addCylinder(
        staticFaces,
        center: vm.Vector3(sx, 0.125, 0.12),
        radius: 0.011,
        length: 0.18,
        rx: 1.15,
        color: const Color(0xFFBCC4D0),
        roughness: 0.25,
        metalness: 0.75,
      );
    }
    addRoundedBox(
      bolsterFaces,
      center: vm.Vector3(0, 0.105, 0.21),
      size: vm.Vector3(0.35, 0.036, 0.15),
      radius: 0.016,
      puff: 0.005,
      rx: 0.18,
      uvQuadrant: 1,
      subdiv: 4,
      color: Colors.white,
    );

    // Plush Contoured Seat Pan Cushion (Waterfall front edge + pillow crown)
    addRoundedBox(
      variant == 'blueDualTone' ? bolsterFaces : centerFaces,
      center: vm.Vector3(0, 0.245, 0.03),
      size: vm.Vector3(0.35, 0.118, 0.46),
      radius: 0.044,
      puff: 0.015,
      waterfallFront: 0.026,
      uvQuadrant: 0,
      subdiv: subdiv,
      color: Colors.white,
    );

    // Sculpted Left & Right Thigh Bolsters
    for (final side in [-1.0, 1.0]) {
      addRoundedBox(
        bolsterFaces,
        center: vm.Vector3(side * 0.188, 0.264, 0.03),
        size: vm.Vector3(0.102, 0.134, 0.475),
        radius: 0.044,
        puff: 0.012,
        waterfallFront: 0.022,
        ry: -side * 0.04,
        rz: -side * 0.08,
        uvQuadrant: 1,
        subdiv: subdiv,
        color: Colors.white,
      );
    }

    // Ergonomic S-Curve Backrest:
    // 1. Quilted Lumbar & Mid-Back Cushion (3 softly pillowed segments along S-curve)
    addRoundedBox(
      reclineCenterFaces,
      center: vm.Vector3(0, 0.525, -0.195),
      size: vm.Vector3(0.315, 0.47, 0.112),
      radius: 0.042,
      puff: 0.016,
      taperTopX: 0.95,
      curveZByY: 0.018,
      rx: -0.15,
      uvQuadrant: 0,
      subdiv: subdiv,
      color: Colors.white,
    );

    // 2. Plush Upper Headrest Insert Cushion (Jacquard diamond fabric weave)
    addRoundedBox(
      reclineHeadInsertFaces,
      center: vm.Vector3(0, 0.865, -0.250),
      size: vm.Vector3(0.305, 0.30, 0.115),
      radius: 0.044,
      puff: 0.018,
      taperTopX: 0.92,
      rx: -0.15,
      uvQuadrant: 1,
      subdiv: subdiv,
      color: Colors.white,
    );

    // 3. Soft Contoured Neck Pillow Bolster
    addRoundedBox(
      reclineHeadInsertFaces,
      center: vm.Vector3(0, 0.84, -0.205),
      size: vm.Vector3(0.24, 0.125, 0.055),
      radius: 0.026,
      puff: 0.010,
      rx: -0.15,
      uvQuadrant: 1,
      subdiv: 4,
      color: Colors.white,
    );

    // 4. Sculpted Lateral Backrest Bolsters & Forward-Curving Winged Headrest Ears
    for (final side in [-1.0, 1.0]) {
      addRoundedBox(
        reclineBolsterFaces,
        center: vm.Vector3(side * 0.178, 0.655, -0.202),
        size: vm.Vector3(0.102, 0.73, 0.132),
        radius: 0.045,
        puff: 0.012,
        taperTopX: 0.88,
        curveZByY: 0.015,
        rx: -0.15,
        ry: -side * 0.16,
        uvQuadrant: 1,
        subdiv: subdiv,
        color: Colors.white,
      );

      // Organic Forward-Curving Winged Headrest Ears ("Telinga" Sandaran Kepala)
      addRoundedBox(
        reclineBolsterFaces,
        center: vm.Vector3(side * 0.202, 0.915, -0.172),
        size: vm.Vector3(0.092, 0.265, 0.168),
        radius: 0.042,
        puff: 0.012,
        taperTopX: 0.82,
        rx: -0.08,
        ry: -side * 0.46,
        rz: side * 0.09,
        uvQuadrant: 1,
        subdiv: subdiv,
        color: Colors.white,
      );
    }

    // 5. Smooth Rounded Top Headrest Crown
    addRoundedBox(
      reclineBolsterFaces,
      center: vm.Vector3(0, 1.032, -0.265),
      size: vm.Vector3(0.39, 0.082, 0.112),
      radius: 0.038,
      puff: 0.010,
      taperTopX: 0.86,
      rx: -0.15,
      uvQuadrant: 1,
      subdiv: 4,
      color: Colors.white,
    );

    // Sleek Contoured Side Armrest Shell + Curved Natural Wood Cap + Chrome Recline Button
    final woodColor = variant == 'maroon'
        ? const Color(0xFFA46E3D)
        : variant == 'blueDualTone'
            ? const Color(0xFF753F28)
            : variant == 'eksekutifDualTone'
                ? const Color(0xFF42281B)
                : const Color(0xFF845B3A);
    final shellColor = variant == 'maroon'
        ? const Color(0xFF9EA7B6)
        : variant == 'eksekutifDualTone'
            ? const Color(0xFFDCD9CF)
            : const Color(0xFFC2C8D2);

    void addSidePanel(double sideSign) {
      final px = sideSign * 0.268;
      addRoundedBox(
        staticFaces,
        center: vm.Vector3(px, 0.315, -0.02),
        size: vm.Vector3(0.052, 0.33, 0.45),
        radius: 0.024,
        puff: 0.004,
        taperTopX: 1.08,
        uvQuadrant: 3,
        subdiv: subdiv,
        color: shellColor,
        roughness: 0.42,
        metalness: 0.22,
      );
      addRoundedBox(
        staticFaces,
        center: vm.Vector3(px, 0.488, 0.00),
        size: vm.Vector3(0.064, 0.044, 0.50),
        radius: 0.020,
        puff: 0.005,
        waterfallFront: 0.020,
        uvQuadrant: 2,
        subdiv: subdiv,
        color: woodColor,
        roughness: 0.28,
        metalness: 0.10,
      );
      if (variant != 'blueDualTone') {
        addRoundedBox(
          staticFaces,
          center: vm.Vector3(
            px,
            variant == 'eksekutifDualTone' ? 0.44 : 0.365,
            0.228,
          ),
          size: vm.Vector3(
            0.062,
            variant == 'eksekutifDualTone' ? 0.11 : 0.25,
            0.050,
          ),
          radius: 0.020,
          puff: 0.003,
          uvQuadrant: 2,
          subdiv: subdiv,
          color: woodColor,
          roughness: 0.28,
          metalness: 0.10,
        );
      }
      addCylinder(
        staticFaces,
        center: vm.Vector3(
          px + sideSign * 0.018,
          variant == 'eksekutifDualTone' ? 0.508 : 0.35,
          variant == 'eksekutifDualTone' ? 0.17 : 0.24,
        ),
        radius: 0.014,
        length: 0.032,
        rz: math.pi * 0.5,
        color: const Color(0xFFE6ECF5),
        roughness: 0.18,
        metalness: 0.85,
      );
    }

    if (standalone) {
      addSidePanel(1);
      addSidePanel(-1);
    } else {
      addSidePanel(isPairA ? 1 : -1);
      if (isPairA) {
        if (variant == 'blueDualTone' || variant == 'eksekutifDualTone') {
          addRoundedBox(
            staticFaces,
            center: vm.Vector3(-0.295, 0.44, 0.01),
            size: vm.Vector3(0.044, 0.065, 0.42),
            radius: 0.018,
            uvQuadrant: 3,
            subdiv: 4,
            color: shellColor,
            roughness: 0.42,
            metalness: 0.22,
          );
          addRoundedBox(
            staticFaces,
            center: vm.Vector3(-0.295, 0.482, 0.015),
            size: vm.Vector3(0.054, 0.034, 0.44),
            radius: 0.015,
            waterfallFront: 0.015,
            uvQuadrant: 2,
            subdiv: 4,
            color: woodColor,
            roughness: 0.28,
            metalness: 0.10,
          );
        } else {
          addRoundedBox(
            staticFaces,
            center: vm.Vector3(-0.295, 0.51, -0.08),
            size: vm.Vector3(0.036, 0.24, 0.26),
            radius: 0.016,
            rx: -0.2,
            uvQuadrant: 3,
            subdiv: 4,
            color: variant == 'maroon'
                ? const Color(0xFFB8CBE0)
                : const Color(0xFFE4E9F2),
            roughness: 0.38,
            metalness: 0.18,
          );
        }
      }
    }

    return [
      MeshPart(faces: staticFaces, role: 'static'),
      MeshPart(faces: centerFaces, role: 'center'),
      MeshPart(faces: bolsterFaces, role: 'bolster'),
      MeshPart(faces: reclineCenterFaces, role: 'center', reclines: true),
      MeshPart(faces: reclineBolsterFaces, role: 'bolster', reclines: true),
      MeshPart(faces: reclineHeadInsertFaces, role: 'headInsert', reclines: true),
      MeshPart(faces: _buildUnavailFaces(), role: 'unavail'),
    ];
  }

  // 5. KAI Ekonomi Premium (Smooth Tan/Taupe 2-2 + Open Curved Chrome Armrests)
  static List<MeshPart> _buildEkonomiPremiumSeat({
    required bool isPairA,
    required bool standalone,
  }) {
    final staticFaces = <TriFace>[];
    final centerFaces = <TriFace>[];
    final bolsterFaces = <TriFace>[];
    final reclineCenterFaces = <TriFace>[];
    final reclineBolsterFaces = <TriFace>[];
    final subdiv = standalone ? 5 : 4;

    addCylinder(
      staticFaces,
      center: vm.Vector3(0, 0.095, -0.04),
      radius: 0.11,
      length: 0.17,
      color: const Color(0xFF262930),
      roughness: 0.50,
      metalness: 0.30,
    );

    // Plush Seat Cushion
    addRoundedBox(
      centerFaces,
      center: vm.Vector3(0, 0.24, 0.03),
      size: vm.Vector3(0.35, 0.12, 0.47),
      radius: 0.044,
      puff: 0.015,
      waterfallFront: 0.025,
      uvQuadrant: 0,
      subdiv: subdiv,
      color: Colors.white,
    );
    for (final side in [-1.0, 1.0]) {
      addRoundedBox(
        bolsterFaces,
        center: vm.Vector3(side * 0.188, 0.256, 0.03),
        size: vm.Vector3(0.096, 0.135, 0.48),
        radius: 0.044,
        puff: 0.012,
        waterfallFront: 0.022,
        rz: -side * 0.07,
        uvQuadrant: 1,
        subdiv: subdiv,
        color: Colors.white,
      );
    }

    // Flat-Top High Contoured Backrest + Integrated Headrest Pad
    addRoundedBox(
      reclineCenterFaces,
      center: vm.Vector3(0, 0.54, -0.195),
      size: vm.Vector3(0.34, 0.50, 0.11),
      radius: 0.042,
      puff: 0.016,
      curveZByY: 0.016,
      rx: -0.14,
      uvQuadrant: 0,
      subdiv: subdiv,
      color: Colors.white,
    );
    addRoundedBox(
      reclineCenterFaces,
      center: vm.Vector3(0, 0.89, -0.245),
      size: vm.Vector3(0.33, 0.30, 0.115),
      radius: 0.044,
      puff: 0.018,
      taperTopX: 0.90,
      rx: -0.14,
      uvQuadrant: 1,
      subdiv: subdiv,
      color: Colors.white,
    );
    for (final side in [-1.0, 1.0]) {
      addRoundedBox(
        reclineBolsterFaces,
        center: vm.Vector3(side * 0.186, 0.68, -0.195),
        size: vm.Vector3(0.098, 0.78, 0.128),
        radius: 0.044,
        puff: 0.012,
        taperTopX: 0.86,
        curveZByY: 0.014,
        rx: -0.14,
        ry: -side * 0.12,
        uvQuadrant: 1,
        subdiv: subdiv,
        color: Colors.white,
      );
    }

    // Open Curved Armrests on Chrome Metal Support Tubes
    void addOpenArmrest(double xPos) {
      addCylinder(
        staticFaces,
        center: vm.Vector3(xPos, 0.34, -0.15),
        radius: 0.014,
        length: 0.24,
        color: const Color(0xFFCFD6E0),
        roughness: 0.20,
        metalness: 0.82,
      );
      addCylinder(
        staticFaces,
        center: vm.Vector3(xPos, 0.33, 0.19),
        radius: 0.014,
        length: 0.24,
        rx: 0.22,
        color: const Color(0xFFCFD6E0),
        roughness: 0.20,
        metalness: 0.82,
      );
      addRoundedBox(
        staticFaces,
        center: vm.Vector3(xPos, 0.465, 0.02),
        size: vm.Vector3(0.054, 0.042, 0.44),
        radius: 0.018,
        puff: 0.004,
        waterfallFront: 0.018,
        uvQuadrant: 2,
        subdiv: 4,
        color: const Color(0xFF33251F),
        roughness: 0.35,
        metalness: 0.08,
      );
      addCylinder(
        staticFaces,
        center: vm.Vector3(xPos, 0.31, 0.16),
        radius: 0.022,
        length: 0.045,
        rz: math.pi * 0.5,
        color: const Color(0xFF262930),
        roughness: 0.45,
        metalness: 0.35,
      );
    }

    if (standalone) {
      addOpenArmrest(0.26);
      addOpenArmrest(-0.26);
    } else if (isPairA) {
      addOpenArmrest(0.26);
      addOpenArmrest(-0.295);
    } else {
      addOpenArmrest(-0.26);
    }

    return [
      MeshPart(faces: staticFaces, role: 'static'),
      MeshPart(faces: centerFaces, role: 'center'),
      MeshPart(faces: bolsterFaces, role: 'bolster'),
      MeshPart(faces: reclineCenterFaces, role: 'center', reclines: true),
      MeshPart(faces: reclineBolsterFaces, role: 'bolster', reclines: true),
      MeshPart(faces: _buildUnavailFaces(), role: 'unavail'),
    ];
  }

  // 6. KAI Ekonomi Modif Tosca 2-3 (Smooth Scalloped Arched Crown + Chrome Grab Handle)
  static List<MeshPart> _buildEkonomiTosca23Seat({
    required String role,
    required bool standalone,
  }) {
    final staticFaces = <TriFace>[];
    final centerFaces = <TriFace>[];
    final bolsterFaces = <TriFace>[];
    final subdiv = standalone ? 5 : 4;

    void addSingleScalloped(
      double xOff,
      bool leftBox,
      bool rightBox,
      bool leftGrab,
      bool rightGrab,
    ) {
      const sw = 0.485;
      addRoundedBox(
        centerFaces,
        center: vm.Vector3(xOff, 0.25, 0.04),
        size: vm.Vector3(sw * 0.96, 0.12, 0.46),
        radius: 0.042,
        puff: 0.015,
        waterfallFront: 0.024,
        uvQuadrant: 0,
        subdiv: subdiv,
        color: Colors.white,
      );
      addRoundedBox(
        centerFaces,
        center: vm.Vector3(xOff, 0.535, -0.132),
        size: vm.Vector3(sw * 0.94, 0.50, 0.108),
        radius: 0.042,
        puff: 0.016,
        taperTopX: 0.94,
        curveZByY: 0.014,
        rx: -0.08,
        uvQuadrant: 0,
        subdiv: subdiv,
        color: Colors.white,
      );
      addRoundedBox(
        bolsterFaces,
        center: vm.Vector3(xOff, 0.895, -0.162),
        size: vm.Vector3(sw * 0.82, 0.22, 0.105),
        radius: 0.046,
        puff: 0.018,
        taperTopX: 0.84,
        rx: -0.08,
        uvQuadrant: 1,
        subdiv: subdiv,
        color: Colors.white,
      );

      void addSideBox(double sideSign) {
        final bx = xOff + sideSign * (sw * 0.5 + 0.018);
        addRoundedBox(
          staticFaces,
          center: vm.Vector3(bx, 0.22, 0.02),
          size: vm.Vector3(0.052, 0.22, 0.48),
          radius: 0.020,
          uvQuadrant: 3,
          subdiv: 4,
          color: const Color(0xFF5C626B),
          roughness: 0.45,
          metalness: 0.20,
        );
        addRoundedBox(
          staticFaces,
          center: vm.Vector3(bx, 0.34, 0.00),
          size: vm.Vector3(0.058, 0.042, 0.42),
          radius: 0.018,
          waterfallFront: 0.015,
          uvQuadrant: 2,
          subdiv: 4,
          color: const Color(0xFF23272F),
          roughness: 0.35,
          metalness: 0.12,
        );
      }

      if (leftBox) addSideBox(-1);
      if (rightBox) addSideBox(1);

      void addGrabHandle(double sideSign) {
        addCylinder(
          staticFaces,
          center: vm.Vector3(xOff + sideSign * (sw * 0.38), 0.96, -0.165),
          radius: 0.014,
          length: 0.11,
          rz: sideSign * 0.65,
          color: const Color(0xFFDCE2EA),
          roughness: 0.18,
          metalness: 0.85,
        );
      }

      if (leftGrab) addGrabHandle(-1);
      if (rightGrab) addGrabHandle(1);
    }

    if (standalone) {
      addSingleScalloped(-0.245, true, false, true, false);
      addSingleScalloped(0.245, false, true, false, true);
    } else {
      final hasLeft = role == 'c' || role == 'e';
      final hasRight = role == 'a' || role == 'd';
      addSingleScalloped(0, hasLeft, hasRight, role == 'c', role == 'd');
    }

    return [
      MeshPart(faces: staticFaces, role: 'static'),
      MeshPart(faces: centerFaces, role: 'center'),
      MeshPart(faces: bolsterFaces, role: 'bolster'),
      MeshPart(faces: _buildUnavailFaces(), role: 'unavail'),
    ];
  }

  // 7. KAI Ekonomi Reguler 2-3 (Plush Cream Bench + Cylindrical Tubular Stainless Pipe Frame)
  static List<MeshPart> _buildEkonomi23RegulerSeat({
    required String role,
    required bool standalone,
  }) {
    final staticFaces = <TriFace>[];
    final centerFaces = <TriFace>[];
    final bolsterFaces = <TriFace>[];
    final w = standalone ? 0.92 : 0.495;
    final subdiv = standalone ? 5 : 4;

    addRoundedBox(
      centerFaces,
      center: vm.Vector3(0, 0.25, 0.04),
      size: vm.Vector3(w, 0.115, 0.45),
      radius: 0.042,
      puff: 0.015,
      waterfallFront: 0.022,
      uvQuadrant: 0,
      subdiv: subdiv,
      color: Colors.white,
    );

    addRoundedBox(
      centerFaces,
      center: vm.Vector3(0, 0.56, -0.135),
      size: vm.Vector3(w, 0.54, 0.098),
      radius: 0.040,
      puff: 0.014,
      rx: -0.04,
      uvQuadrant: 0,
      subdiv: subdiv,
      color: Colors.white,
    );
    addRoundedBox(
      bolsterFaces,
      center: vm.Vector3(0, 0.89, -0.15),
      size: vm.Vector3(w * 0.98, 0.21, 0.102),
      radius: 0.042,
      puff: 0.016,
      rx: -0.04,
      uvQuadrant: 1,
      subdiv: subdiv,
      color: Colors.white,
    );

    const pipeColor = Color(0xFFD0D7E0);
    addCylinder(
      staticFaces,
      center: vm.Vector3(0, 1.03, -0.155),
      radius: 0.015,
      length: w + 0.02,
      rz: math.pi * 0.5,
      color: pipeColor,
      roughness: 0.18,
      metalness: 0.85,
    );

    void addPipeEnd(double sideSign) {
      final xEdge = sideSign * (w * 0.5);
      addCylinder(
        staticFaces,
        center: vm.Vector3(xEdge, 0.53, -0.155),
        radius: 0.015,
        length: 0.98,
        color: pipeColor,
        roughness: 0.18,
        metalness: 0.85,
      );
      addCylinder(
        staticFaces,
        center: vm.Vector3(xEdge, 0.23, 0.19),
        radius: 0.014,
        length: 0.42,
        color: pipeColor,
        roughness: 0.18,
        metalness: 0.85,
      );
      addRoundedBox(
        staticFaces,
        center: vm.Vector3(xEdge, 0.45, 0.02),
        size: vm.Vector3(0.048, 0.038, 0.38),
        radius: 0.016,
        waterfallFront: 0.014,
        uvQuadrant: 2,
        subdiv: 4,
        color: const Color(0xFF24211F),
        roughness: 0.38,
        metalness: 0.10,
      );
    }

    final hasLeft = standalone || role == 'c' || role == 'e';
    final hasRight = standalone || role == 'a' || role == 'd';
    if (hasLeft) addPipeEnd(-1);
    if (hasRight) addPipeEnd(1);

    return [
      MeshPart(faces: staticFaces, role: 'static'),
      MeshPart(faces: centerFaces, role: 'center'),
      MeshPart(faces: bolsterFaces, role: 'bolster'),
      MeshPart(faces: _buildUnavailFaces(), role: 'unavail'),
    ];
  }

  static List<TriFace> _buildUnavailFaces() {
    final faces = <TriFace>[];
    addBox(
      faces,
      center: vm.Vector3(0, 0.69, 0.08),
      size: vm.Vector3(0.22, 0.02, 0.22),
      rx: 0.45,
      color: const Color(0xFFCB3A64),
      unlit: true,
    );
    return faces;
  }

  // Build Static Cabin Section, Bulkhead Partition, Gangway, or Coach End
  static List<TriFace> getStaticModelFaces(String modelName) {
    return _staticSectionCache.putIfAbsent(modelName, () {
      final faces = <TriFace>[];
      if (modelName == 'e7-main-shadow' ||
          modelName == 'e7-train-head-inside' ||
          modelName.contains('-separator') ||
          modelName.contains('leg-')) {
        return faces;
      }

      if (modelName == 'e7-train-head-chasis') {
        addBox(
          faces,
          center: vm.Vector3(0, 1.38, -3.5),
          size: vm.Vector3(3.36, 1.5, 8.2),
          color: const Color(0xFFC4C8CF),
        );
        addBox(
          faces,
          center: vm.Vector3(0, 2.30, -3.5),
          size: vm.Vector3(3.32, 0.36, 8.2),
          color: const Color(0xFFB4B8C0),
        );
        return faces;
      }

      if (modelName.contains('-partition-')) {
        final isOrd23 = modelName.startsWith('e7-ordinary-');
        for (final side in [-1.0, 1.0]) {
          addBox(
            faces,
            center: vm.Vector3(side * 0.97, 2.005, 0),
            size: vm.Vector3(1.24, 1.35, 0.10),
            color: const Color(0xFFE6E2DA),
          );
          if (!isOrd23) {
            addBox(
              faces,
              center: vm.Vector3(side * 0.88, 2.24, 0),
              size: vm.Vector3(0.54, 0.34, 0.15),
              color: side == -1
                  ? const Color(0xFF1254A1)
                  : const Color(0xFF5C8A66),
              unlit: true,
            );
          }
        }
        // Center sliding door + yellow decal + top LED board
        addBox(
          faces,
          center: vm.Vector3(0, 2.005, 0),
          size: vm.Vector3(0.70, 1.35, 0.12),
          color: const Color(0xFF1E222A),
        );
        addBox(
          faces,
          center: vm.Vector3(0, 2.06, 0),
          size: vm.Vector3(0.09, 0.28, 0.16),
          color: const Color(0xFFF2C935),
          unlit: true,
        );
        addBox(
          faces,
          center: vm.Vector3(0, 2.60, 0),
          size: vm.Vector3(1.38, 0.14, 0.15),
          color: const Color(0xFF14161C),
          unlit: true,
        );
        addBox(
          faces,
          center: vm.Vector3(0, 2.60, 0),
          size: vm.Vector3(0.92, 0.045, 0.17),
          color: const Color(0xFF35E06C),
          unlit: true,
        );
        return faces;
      }

      if (modelName == 'e7-gangway' ||
          modelName.contains('entrance') ||
          modelName.contains('alley') ||
          modelName.contains('multipurpose')) {
        final len = modelName.contains('multipurpose') ? 1.55 : 0.75;
        addBox(
          faces,
          center: vm.Vector3(0, 1.298, 0),
          size: vm.Vector3(3.08, 0.056, len),
          color: const Color(0xFF5D626B),
        );
        for (final side in [-1.0, 1.0]) {
          addBox(
            faces,
            center: vm.Vector3(side * 1.61, 1.99, 0),
            size: vm.Vector3(0.10, 1.36, len),
            color: const Color(0xFFC4C8D0),
          );
        }
        return faces;
      }

      if (modelName.contains('-section')) {
        final isOrd23 = modelName.startsWith('e7-ordinary-');
        final isTosca23 = modelName.startsWith('kai-tosca-');
        final isBlue =
            modelName.startsWith('kai-blue-') || modelName.startsWith('e7-green-');
        final isPrem = modelName.startsWith('kai-prem-');
        final isCar7 = modelName.startsWith('kai-maroon-');

        final basePitch = isCar7 ? 1.17206 : 1.03289;
        double zStart = -basePitch * 0.5;
        double zEnd = basePitch * 0.5;
        if (modelName.endsWith('-ending-a')) {
          zEnd = isCar7 ? 1.318 : 0.79;
        } else if (modelName.endsWith('-ending-b')) {
          zStart = isCar7 ? -0.746 : -0.79;
        }
        final spanLen = (zEnd - zStart) - 0.002;
        final centerZ = (zStart + zEnd) * 0.5;

        final sideFloorCol = isOrd23
            ? const Color(0xFF7EA06E)
            : isTosca23
                ? const Color(0xFF767B82)
                : isBlue
                    ? const Color(0xFF8D949E)
                    : isPrem
                        ? const Color(0xFF5C5552)
                        : const Color(0xFF626770);
        final aisleFloorCol = isOrd23
            ? const Color(0xFF84A674)
            : isTosca23
                ? const Color(0xFF848990)
                : isBlue
                    ? const Color(0xFF9DA4AE)
                    : isPrem
                        ? const Color(0xFF69615D)
                        : const Color(0xFF747A84);
        final ledCol = isOrd23
            ? const Color(0xFFF4F7F2)
            : isTosca23
                ? const Color(0xFFE8EDF2)
                : isBlue
                    ? const Color(0xFFFFFCE0)
                    : isPrem
                        ? const Color(0xFFC4F5AE)
                        : const Color(0xFFDFFBE4);
        final railCol = isTosca23
            ? const Color(0xFF9E6B3B)
            : const Color(0xFF262A32);

        final aisleW = (isOrd23 || isTosca23) ? 0.46 : 0.52;
        final sideW = (3.08 - aisleW) * 0.5;

        for (final side in [-1.0, 1.0]) {
          addBox(
            faces,
            center: vm.Vector3(side * (aisleW * 0.5 + sideW * 0.5), 1.30, centerZ),
            size: vm.Vector3(sideW - 0.002, 0.06, spanLen),
            color: sideFloorCol,
          );
          addBox(
            faces,
            center: vm.Vector3(side * (aisleW * 0.5), 1.335, centerZ),
            size: vm.Vector3(0.028, 0.008, zEnd - zStart),
            color: ledCol,
            unlit: true,
          );

          final wallX = side * 1.56;
          addBox(
            faces,
            center: vm.Vector3(wallX, 1.53, centerZ),
            size: vm.Vector3(0.08, 0.46, spanLen),
            color: isOrd23
                ? const Color(0xFFBAC2CC)
                : const Color(0xFFEAE6DF),
          );
          addBox(
            faces,
            center: vm.Vector3(wallX, 1.785, centerZ),
            size: vm.Vector3(0.13, 0.04, spanLen),
            color: railCol,
          );
          addBox(
            faces,
            center: vm.Vector3(wallX, 2.415, centerZ),
            size: vm.Vector3(0.13, 0.04, spanLen),
            color: railCol,
          );
          addBox(
            faces,
            center: vm.Vector3(wallX, 2.535, centerZ),
            size: vm.Vector3(0.11, 0.19, spanLen),
            color: const Color(0xFFEAE6DF),
          );
          addBox(
            faces,
            center: vm.Vector3(wallX, 2.655, centerZ),
            size: vm.Vector3(0.17, 0.04, spanLen),
            color: railCol,
          );

          if (isOrd23) {
            addBox(
              faces,
              center: vm.Vector3(side * 1.50, 2.10, 0),
              size: vm.Vector3(0.045, 0.54, basePitch * 0.65),
              color: const Color(0xFF1D48B8),
            );
            addBox(
              faces,
              center: vm.Vector3(side * 1.46, 1.72, 0),
              size: vm.Vector3(0.14, 0.028, 0.30),
              color: const Color(0xFFF2F4F7),
            );
          }
        }
        addBox(
          faces,
          center: vm.Vector3(0, 1.30, centerZ),
          size: vm.Vector3(aisleW - 0.002, 0.06, spanLen),
          color: aisleFloorCol,
        );
      }

      return faces;
    });
  }
}

// ============================================================================
// 3-Point Oren-Nayar + Velvet Sheen Fabric Studio Lighting & Gouraud Renderer
// ============================================================================
class ProjectedTri {
  final double x0, y0, x1, y1, x2, y2;
  final Offset uv0, uv1, uv2;
  final int layer;
  final double depth;
  final int argb0, argb1, argb2;

  const ProjectedTri(
    this.x0,
    this.y0,
    this.x1,
    this.y1,
    this.x2,
    this.y2,
    this.uv0,
    this.uv1,
    this.uv2,
    this.layer,
    this.depth,
    this.argb0,
    this.argb1,
    this.argb2,
  );
}

class KAI3DRenderer {
  static final vm.Vector3 _l1 = vm.Vector3(-0.45, 0.82, 0.55)..normalize();
  static final vm.Vector3 _l2 = vm.Vector3(0.65, 0.45, 0.35)..normalize();
  static final vm.Vector3 _l3 = vm.Vector3(0.0, 0.65, -0.75)..normalize();
  static final vm.Vector3 _viewRef = vm.Vector3(0.0, 0.45, 0.89)..normalize();

  static int computeLitColor(
    Color base,
    vm.Vector3 worldN,
    double ao,
    double roughness,
    double metalness,
    bool unlit,
  ) {
    if (unlit) return base.toARGB32();
    final nx = worldN.x, ny = worldN.y, nz = worldN.z;
    final ndotl1 = nx * _l1.x + ny * _l1.y + nz * _l1.z;
    final ndotl2 = nx * _l2.x + ny * _l2.y + nz * _l2.z;
    final ndotl3 = nx * _l3.x + ny * _l3.y + nz * _l3.z;

    // Oren-Nayar soft wrap-around diffuse for plush woven fabric
    final wrap = roughness > 0.5 ? 0.36 : 0.12;
    final d1 = math.max(0.0, (ndotl1 + wrap) / (1.0 + wrap));
    final d2 = math.max(0.0, (ndotl2 + wrap) / (1.0 + wrap));
    final d3 = math.max(0.0, (ndotl3 + wrap) / (1.0 + wrap));

    final hemi = 0.5 + 0.5 * ny;
    final amb = (0.58 + 0.38 * hemi) * 0.66;
    final diff = (amb + d1 * 0.48 + d2 * 0.22 + d3 * 0.16) * ao;

    // Charlie / Fresnel microfiber velvet rim sheen for fabric cushions
    final ndotv = math.max(0.0, nx * _viewRef.x + ny * _viewRef.y + nz * _viewRef.z);
    final rimSheen = roughness > 0.5
        ? math.pow(1.0 - ndotv, 2.6).toDouble() * 24.0 * ao
        : 0.0;

    // Blinn-Phong specular highlight (soft broad sheen for fabric, crisp for wood/metal)
    final specExp = roughness > 0.5 ? 10.0 : 24.0;
    final specPow = math.pow(math.max(0.0, ndotl1), specExp).toDouble();
    final spec = (0.04 + 0.42 * metalness) * (1.0 - roughness * 0.62) * specPow * 255.0;

    final extra = rimSheen + spec;
    final r = ((base.r * 255.0) * diff + extra).round().clamp(0, 255);
    final g = ((base.g * 255.0) * diff + extra).round().clamp(0, 255);
    final b = ((base.b * 255.0) * diff + extra).round().clamp(0, 255);
    final a = (base.a * 255.0).round().clamp(0, 255);
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  static vm.Vector3? projectPoint(
    vm.Vector3 worldPt,
    vm.Matrix4 viewMatrix,
    double f,
    double aspect,
    double halfW,
    double halfH,
  ) {
    final m = viewMatrix.storage;
    final vx = m[0] * worldPt.x + m[4] * worldPt.y + m[8] * worldPt.z + m[12];
    final vy = m[1] * worldPt.x + m[5] * worldPt.y + m[9] * worldPt.z + m[13];
    final vz = m[2] * worldPt.x + m[6] * worldPt.y + m[10] * worldPt.z + m[14];
    if (vz >= -0.6) return null;
    final invZ = -1.0 / vz;
    final ndcX = (vx * (f / aspect)) * invZ;
    final ndcY = (vy * f) * invZ;
    final sx = (ndcX + 1.0) * halfW;
    final sy = (1.0 - ndcY) * halfH;
    return vm.Vector3(sx, sy, -vz);
  }

  static void flushTriangles(Canvas canvas, List<ProjectedTri> tris) {
    if (tris.isEmpty) return;
    tris.sort((a, b) {
      final lc = a.layer.compareTo(b.layer);
      if (lc != 0) return lc;
      return b.depth.compareTo(a.depth);
    });
    final count = tris.length;
    final positions = Float32List(count * 6);
    final texCoords = Float32List(count * 6);
    final colors = Int32List(count * 3);
    int pi = 0;
    int ti = 0;
    int ci = 0;
    for (int i = 0; i < count; i++) {
      final t = tris[i];
      positions[pi++] = t.x0;
      positions[pi++] = t.y0;
      positions[pi++] = t.x1;
      positions[pi++] = t.y1;
      positions[pi++] = t.x2;
      positions[pi++] = t.y2;
      texCoords[ti++] = t.uv0.dx;
      texCoords[ti++] = t.uv0.dy;
      texCoords[ti++] = t.uv1.dx;
      texCoords[ti++] = t.uv1.dy;
      texCoords[ti++] = t.uv2.dx;
      texCoords[ti++] = t.uv2.dy;
      colors[ci++] = t.argb0;
      colors[ci++] = t.argb1;
      colors[ci++] = t.argb2;
    }
    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: texCoords,
      colors: colors,
    );
    final paint = Paint()
      ..shader = KAIGeometryBuilder.getAtlasShader()
      ..filterQuality = FilterQuality.medium;
    canvas.drawVertices(vertices, BlendMode.modulate, paint);
  }
}

// ============================================================================
// 1. SeatMap3DView (Port of SeatMapSceneView.swift)
// ============================================================================
class SeatMap3DView extends StatefulWidget {
  final SeatMapModel seatMap;
  final SeatClassEntity currentEntity;
  final String fromStation;
  final String toStation;
  final ValueChanged<ReservableEntity> onSeatSelected;
  final ValueChanged<double> onOverscrollUpper;
  final void Function({
    required String message,
    required bool visible,
    int autoHideMs,
  }) onBadgeUpdate;

  const SeatMap3DView({
    super.key,
    required this.seatMap,
    required this.currentEntity,
    required this.fromStation,
    required this.toStation,
    required this.onSeatSelected,
    required this.onOverscrollUpper,
    required this.onBadgeUpdate,
  });

  @override
  State<SeatMap3DView> createState() => SeatMap3DViewState();
}

class SeatMap3DViewState extends State<SeatMap3DView>
    with SingleTickerProviderStateMixin {
  late double _lowerZ;
  late double _upperZ;
  double _currentContentZ = 0;
  double _velocityZ = 0;
  int? _highlightedSeatId;
  ReservableEntity? _selectedSeat;
  String _seatNavState = 'hide';

  Offset? _dragStartLocal;
  double? _hitZAtTouchStart;
  double _contentZAtTouchStart = 0;
  bool _isDragging = false;

  late Ticker _ticker;
  Duration? _lastTick;
  bool _isDrifting = false;
  double? _animStartZ;
  double? _animTargetZ;
  double _animProgress = 0;
  double _animDuration = 0.6;

  // CameraNode.swift: worldPos = (0, 7.2, 0), pitch = -0.9638087 rad, FOV = 64 deg
  static final vm.Matrix4 _viewMatrix = _buildSeatMapViewMatrix();

  static vm.Matrix4 _buildSeatMapViewMatrix() {
    final camWorld = vm.Matrix4.identity()
      ..setTranslationRaw(0.0, 7.2, 0.0)
      ..rotateX(-0.9638087153434753);
    final view = vm.Matrix4.inverted(camWorld);
    return view;
  }

  @override
  void initState() {
    super.initState();
    KAIGeometryBuilder.ensureFlutterSceneInitialized();
    _ticker = createTicker(_onTick);
    _initEntityBounds(playEntrance: true);
  }

  @override
  void didUpdateWidget(covariant SeatMap3DView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentEntity.seatClass != widget.currentEntity.seatClass) {
      _selectedSeat = null;
      _highlightedSeatId = null;
      _seatNavState = 'hide';
      _initEntityBounds(playEntrance: true);
    }
  }

  void _initEntityBounds({bool playEntrance = false}) {
    _lowerZ = widget.currentEntity.lowerZ;
    _upperZ = widget.currentEntity.upperZ;
    if (playEntrance) {
      _currentContentZ = _lowerZ;
      final targetZ = (_lowerZ * 2 + _upperZ) / 3;
      final dur = ((_upperZ.abs() - _lowerZ.abs()).abs() / 100.0 + 0.5).clamp(0.45, 0.9);
      animateToZ(targetZ, durationSec: dur);
    } else {
      _currentContentZ = (_lowerZ * 2 + _upperZ) / 3;
    }
  }

  void scrollToSelectedSeat() {
    if (_selectedSeat == null) return;
    final seatZ = _selectedSeat!.transformedModelEntity.position.z;
    const centerFloorZ = -4.92;
    final targetZ = (-seatZ + centerFloorZ).clamp(_lowerZ, _upperZ);
    animateToZ(targetZ, durationSec: 0.65);
  }

  void animateToZ(double targetZ, {double durationSec = 0.6}) {
    _isDrifting = false;
    _animStartZ = _currentContentZ;
    _animTargetZ = targetZ;
    _animProgress = 0;
    _animDuration = durationSec;
    _lastTick = null;
    if (!_ticker.isActive) _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final dt = _lastTick == null
        ? 1 / 60
        : ((elapsed - _lastTick!).inMicroseconds / 1e6).clamp(0.001, 0.05);
    _lastTick = elapsed;

    if (_animTargetZ != null && _animStartZ != null) {
      _animProgress = (_animProgress + dt / _animDuration).clamp(0.0, 1.0);
      // Exploding ease-out cubic curve
      final eased = 1.0 - math.pow(1.0 - _animProgress, 3.0);
      final nextZ = _animStartZ! + (_animTargetZ! - _animStartZ!) * eased;
      _setCurrentContentZ(nextZ, reportOverscroll: false);
      if (_animProgress >= 1.0) {
        _animTargetZ = null;
        _animStartZ = null;
        _ticker.stop();
      }
      return;
    }

    if (_isDrifting) {
      // DecayFunction.swift port (deceleration = 0.996)
      const decel = 0.996;
      final dtMs = dt * 1000.0;
      final kv = math.pow(decel, dtMs).toDouble();
      final kx = decel * (1.0 - kv) / (1.0 - decel);
      final v0 = _velocityZ / 1000.0;
      _velocityZ = v0 * kv * 1000.0;
      final disp = v0 * kx;
      final rawNext = _currentContentZ + disp;
      final clampedAvg = (rawNext + _zPositionClamp(rawNext)) * 0.5;
      _setCurrentContentZ(clampedAvg, reportOverscroll: true);

      if (_velocityZ.abs() < 0.18) {
        _isDrifting = false;
        if (_currentContentZ < _lowerZ || _currentContentZ > _upperZ) {
          animateToZ(_currentContentZ.clamp(_lowerZ, _upperZ), durationSec: 0.3);
        } else {
          widget.onOverscrollUpper(0);
          _ticker.stop();
        }
      }
      return;
    }

    _ticker.stop();
  }

  double _zPositionClamp(double value) {
    double trimmed = value;
    if (value > _upperZ) {
      final ratio = _upperZ != 0 ? math.max(value / _upperZ, 1.0) : 1.0 + (value - _upperZ);
      trimmed = _upperZ != 0
          ? _upperZ * (1.0 + math.log(ratio) / math.ln10)
          : math.log(ratio) / math.ln10;
    }
    if (trimmed < _lowerZ) {
      if (_lowerZ > 0) {
        final ratio = math.max(trimmed / _lowerZ, 0.01);
        return _lowerZ * (1.0 + math.log(ratio) / math.ln10);
      } else {
        final excess = _lowerZ - trimmed;
        return _lowerZ - (math.log(1.0 + excess) / math.ln10) * 2.0;
      }
    }
    return trimmed;
  }

  void _setCurrentContentZ(double nextZ, {bool reportOverscroll = true}) {
    final oldZ = _currentContentZ;
    setState(() {
      _currentContentZ = nextZ;
    });
    _velocityZ = (nextZ - oldZ) / (1 / 60);

    if (reportOverscroll) {
      final upperOffset = (_upperZ - nextZ) / 0.04;
      widget.onOverscrollUpper(upperOffset);
    }

    if (_selectedSeat != null) {
      const centerScreenZ = -4.92;
      final seatZ = _selectedSeat!.transformedModelEntity.position.z;
      String nextNav = 'hide';
      if (seatZ > centerScreenZ - nextZ + 3.0) {
        nextNav = 'bottom';
      } else if (seatZ < centerScreenZ - nextZ - 4.0) {
        nextNav = 'top';
      }
      if (nextNav != _seatNavState) {
        _seatNavState = nextNav;
        final sName = _selectedSeat!.name;
        if (nextNav == 'top') {
          widget.onBadgeUpdate(
            message: '↑ Your $sName seat is up there.',
            visible: true,
          );
        } else if (nextNav == 'bottom') {
          widget.onBadgeUpdate(
            message: '↓ Your $sName seat is down there.',
            visible: true,
          );
        } else {
          widget.onBadgeUpdate(message: '', visible: false);
        }
      }
    }
  }

  // HitTestFloorNode at y = 1.3
  double? _floorHitTestZ(Offset localPt, Size size) {
    final w = math.max(size.width, 1.0);
    final h = math.max(size.height, 1.0);
    final aspect = w / h;
    final fovRad = 64.0 * math.pi / 180.0;
    final f = 1.0 / math.tan(fovRad * 0.5);

    final ndcX = (localPt.dx / w) * 2.0 - 1.0;
    final ndcY = 1.0 - (localPt.dy / h) * 2.0;

    final dirCam = vm.Vector3(ndcX * aspect / f, ndcY / f, -1.0)..normalize();
    const pitch = -0.9638087153434753;
    final cosP = math.cos(pitch);
    final sinP = math.sin(pitch);
    final dy = dirCam.y * cosP - dirCam.z * sinP;
    final dz = dirCam.y * sinP + dirCam.z * cosP;
    if (dy.abs() < 1e-5) return null;
    final t = (1.3 - 7.2) / dy;
    if (t <= 0) return null;
    return dz * t;
  }

  ReservableEntity? _hitTestSeat(Offset localPt, Size size) {
    final w = math.max(size.width, 1.0);
    final h = math.max(size.height, 1.0);
    final aspect = w / h;
    final fovRad = 64.0 * math.pi / 180.0;
    final f = 1.0 / math.tan(fovRad * 0.5);
    final halfW = w * 0.5;
    final halfH = h * 0.5;

    ReservableEntity? bestHit;
    double bestDist = 36.0;

    for (final rev in widget.currentEntity.reservableEntities) {
      if (!rev.isAvailable) continue;
      final pos = rev.transformedModelEntity.position;
      final wz = pos.z + _currentContentZ;
      if (wz < -22.0 || wz > 2.0) continue;

      final seatCenterWorld = vm.Vector3(pos.x, pos.y + 0.48, wz);
      final proj = KAI3DRenderer.projectPoint(
        seatCenterWorld,
        _viewMatrix,
        f,
        aspect,
        halfW,
        halfH,
      );
      if (proj == null) continue;
      final dist = (Offset(proj.x, proj.y) - localPt).distance;
      if (dist < bestDist) {
        bestDist = dist;
        bestHit = rev;
      }
    }
    return bestHit;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (details) {
            _isDrifting = false;
            _animTargetZ = null;
            _ticker.stop();
            _dragStartLocal = details.localPosition;
            _isDragging = false;
            _hitZAtTouchStart = _floorHitTestZ(details.localPosition, size);
            _contentZAtTouchStart = _currentContentZ;

            final hitSeat = _hitTestSeat(details.localPosition, size);
            if (hitSeat != null) {
              setState(() {
                _highlightedSeatId = hitSeat.id;
              });
            }
          },
          onPanUpdate: (details) {
            if (_dragStartLocal != null &&
                (details.localPosition - _dragStartLocal!).distance > 6.0) {
              _isDragging = true;
              if (_highlightedSeatId != null) {
                setState(() {
                  _highlightedSeatId = null;
                });
              }
            }
            if (_isDragging && _hitZAtTouchStart != null) {
              final hitNow = _floorHitTestZ(details.localPosition, size);
              if (hitNow != null) {
                final rawZ = hitNow - _hitZAtTouchStart! + _contentZAtTouchStart;
                _setCurrentContentZ(_zPositionClamp(rawZ), reportOverscroll: true);
              }
            }
          },
          onPanEnd: (_) {
            if (!_isDragging && _highlightedSeatId != null) {
              final picked = widget.currentEntity.reservableEntities.firstWhere(
                (r) => r.id == _highlightedSeatId,
              );
              final isNew = _selectedSeat?.id != picked.id;
              setState(() {
                _highlightedSeatId = null;
                _selectedSeat = picked;
              });
              widget.onSeatSelected(picked);
              if (isNew) {
                widget.onBadgeUpdate(
                  message:
                      'Seat ${picked.name} in ${picked.carNumber.toLowerCase()} has been selected.',
                  visible: true,
                  autoHideMs: 4000,
                );
              }
              scrollToSelectedSeat();
              return;
            }
            if (_highlightedSeatId != null) {
              setState(() {
                _highlightedSeatId = null;
              });
            }
            if (_velocityZ.abs() > 0.4) {
              _isDrifting = true;
              _lastTick = null;
              if (!_ticker.isActive) _ticker.start();
            } else if (_currentContentZ < _lowerZ || _currentContentZ > _upperZ) {
              animateToZ(_currentContentZ.clamp(_lowerZ, _upperZ), durationSec: 0.3);
            } else {
              widget.onOverscrollUpper(0);
            }
          },
          onPanCancel: () {
            if (_highlightedSeatId != null) {
              setState(() {
                _highlightedSeatId = null;
              });
            }
          },
          child: CustomPaint(
            size: size,
            painter: _SeatMap3DPainter(
              seatMap: widget.seatMap,
              currentEntity: widget.currentEntity,
              currentContentZ: _currentContentZ,
              highlightedSeatId: _highlightedSeatId,
              selectedSeatId: _selectedSeat?.id,
              fromStation: widget.fromStation,
              toStation: widget.toStation,
              isDark: DesignSystem.instance.isDark,
              viewMatrix: _viewMatrix,
            ),
          ),
        );
      },
    );
  }
}

class _SeatMap3DPainter extends CustomPainter {
  final SeatMapModel seatMap;
  final SeatClassEntity currentEntity;
  final double currentContentZ;
  final int? highlightedSeatId;
  final int? selectedSeatId;
  final String fromStation;
  final String toStation;
  final bool isDark;
  final vm.Matrix4 viewMatrix;

  _SeatMap3DPainter({
    required this.seatMap,
    required this.currentEntity,
    required this.currentContentZ,
    required this.highlightedSeatId,
    required this.selectedSeatId,
    required this.fromStation,
    required this.toStation,
    required this.isDark,
    required this.viewMatrix,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = isDark ? DesignSystem.basicDarkGray : DesignSystem.basicWhite;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final w = math.max(size.width, 1.0);
    final h = math.max(size.height, 1.0);
    final aspect = w / h;
    final fovRad = 64.0 * math.pi / 180.0;
    final f = 1.0 / math.tan(fovRad * 0.5);
    final halfW = w * 0.5;
    final halfH = h * 0.5;

    final tris = <ProjectedTri>[];
    final unavailOverlayCenters = <Offset>[];

    void addFaceList(
      List<TriFace> faces,
      vm.Vector3 offset, {
      Color? overrideColor,
      double reclineDeltaRx = 0,
      bool isStatic = false,
    }) {
      for (int i = 0; i < faces.length; i++) {
        final face = faces[i];
        vm.Vector3 p0 = face.v0;
        vm.Vector3 p1 = face.v1;
        vm.Vector3 p2 = face.v2;
        vm.Vector3 vn0 = face.n0;
        vm.Vector3 vn1 = face.n1;
        vm.Vector3 vn2 = face.n2;
        vm.Vector3 sc = face.sortCenter;
        vm.Vector3 n = face.normal;

        if (reclineDeltaRx != 0) {
          final rot = vm.Matrix3.rotationX(reclineDeltaRx);
          final pivot = vm.Vector3(0, 0.30, -0.17);
          p0 = rot.transformed(p0 - pivot) + pivot;
          p1 = rot.transformed(p1 - pivot) + pivot;
          p2 = rot.transformed(p2 - pivot) + pivot;
          vn0 = rot.transformed(vn0);
          vn1 = rot.transformed(vn1);
          vn2 = rot.transformed(vn2);
          sc = rot.transformed(sc - pivot) + pivot;
          n = rot.transformed(n);
        }

        final w0 = p0 + offset;
        final w1 = p1 + offset;
        final w2 = p2 + offset;
        final wCenter = sc + offset;

        // Backface culling in world space against camera at (0, 7.2, 0)
        final vx = wCenter.x;
        final vy = wCenter.y - 7.2;
        final vz = wCenter.z;
        if (vx * n.x + vy * n.y + vz * n.z >= 0.0) continue;

        final pr0 = KAI3DRenderer.projectPoint(w0, viewMatrix, f, aspect, halfW, halfH);
        final pr1 = KAI3DRenderer.projectPoint(w1, viewMatrix, f, aspect, halfW, halfH);
        final pr2 = KAI3DRenderer.projectPoint(w2, viewMatrix, f, aspect, halfW, halfH);
        if (pr0 == null || pr1 == null || pr2 == null) continue;

        final sortDepth = math.sqrt(vx * vx + vy * vy + vz * vz);
        int layer = 10;
        if (isStatic) {
          final ly = face.sortCenter.y;
          final lx = face.sortCenter.x.abs();
          if (ly < -0.015) {
            layer = 0; // Subfloor
          } else if (ly <= 0.002 && n.y > 0.7) {
            layer = 1; // Main cabin floor
          } else if (ly <= 0.0055 && n.y > 0.7) {
            layer = 2; // Aisle runner
          } else if (ly <= 0.025 && n.y > 0.7) {
            layer = 3; // Aisle diamond accents & floor LED strips
          } else if (lx >= 1.595) {
            layer = 4; // Outer wall shell
          } else if (lx >= 1.572) {
            layer = 5; // Window glass
          } else if (lx >= 1.535) {
            layer = 6; // Inner wall & window frames
          } else {
            layer = 7; // Curtains, bulkheads, gangways
          }
        }

        final baseCol = overrideColor ?? face.color;
        final argb0 = KAI3DRenderer.computeLitColor(
          baseCol,
          vn0,
          face.ao0,
          face.roughness,
          face.metalness,
          face.unlit,
        );
        final argb1 = KAI3DRenderer.computeLitColor(
          baseCol,
          vn1,
          face.ao1,
          face.roughness,
          face.metalness,
          face.unlit,
        );
        final argb2 = KAI3DRenderer.computeLitColor(
          baseCol,
          vn2,
          face.ao2,
          face.roughness,
          face.metalness,
          face.unlit,
        );

        tris.add(ProjectedTri(
          pr0.x,
          pr0.y,
          pr1.x,
          pr1.y,
          pr2.x,
          pr2.y,
          face.uv0,
          face.uv1,
          face.uv2,
          layer,
          sortDepth,
          argb0,
          argb1,
          argb2,
        ));
      }
    }

    // 1. Render Global Static Models (Gangways / Coach Ends) within visible Z window
    for (final tme in seatMap.transformedModelEntities) {
      final wz = tme.position.z + currentContentZ;
      if (wz < -25.0 || wz > 6.0) continue;
      final faces = KAIGeometryBuilder.getStaticModelFaces(tme.modelEntity);
      addFaceList(faces, vm.Vector3(tme.position.x, tme.position.y, wz), isStatic: true);
    }

    // 2. Render SeatClassEntities within visible Z window [-24.0 .. +4.0]
    for (final sce in seatMap.seatClassEntities) {
      final isCurrent = sce.seatClass == currentEntity.seatClass;

      for (final st in sce.transformedModelEntities) {
        final wz = st.position.z + currentContentZ;
        if (wz < -24.0 || wz > 4.0) continue;
        final faces = KAIGeometryBuilder.getStaticModelFaces(st.modelEntity);
        addFaceList(
          faces,
          vm.Vector3(st.position.x, st.position.y, wz),
          overrideColor: isCurrent ? null : const Color(0xFFACB0B8),
          isStatic: true,
        );
      }

      for (final rev in sce.reservableEntities) {
        final pos = rev.transformedModelEntity.position;
        final wz = pos.z + currentContentZ;
        if (wz < -22.5 || wz > 3.0) continue;

        final modelName = rev.transformedModelEntity.modelEntity;
        final isEnabled = rev.isAvailable && isCurrent;
        final isHi = isEnabled && rev.id == highlightedSeatId;
        final isSel = isEnabled && rev.id == selectedSeatId;
        final state = !isEnabled
            ? 'disabled'
            : isHi
                ? 'highlighted'
                : isSel
                    ? 'selected'
                    : 'normal';

        final pal = KAIGeometryBuilder.getSeatStatePalette(modelName, state);
        final parts = KAIGeometryBuilder.getSeatPrototype(modelName);
        final offset = vm.Vector3(pos.x, pos.y, wz);
        final reclineAngle = (isHi || isSel) ? -0.24 : 0.0;

        for (final part in parts) {
          if (part.role == 'unavail') continue;
          Color? roleCol;
          if (part.role == 'center') {
            roleCol = pal.center;
          } else if (part.role == 'bolster') {
            roleCol = pal.bolster;
          } else if (part.role == 'headInsert') {
            roleCol = pal.headInsert;
          } else if (part.role == 'seam') {
            roleCol = pal.seam;
          } else if (!isCurrent) {
            roleCol = const Color(0xFF9EA2AA);
          }

          addFaceList(
            part.faces,
            offset,
            overrideColor: roleCol,
            reclineDeltaRx: part.reclines ? reclineAngle : 0.0,
          );
        }

        if (!rev.isAvailable && isCurrent) {
          final badgeWorld = vm.Vector3(pos.x, pos.y + 0.62, wz + 0.05);
          final proj = KAI3DRenderer.projectPoint(
            badgeWorld,
            viewMatrix,
            f,
            aspect,
            halfW,
            halfH,
          );
          if (proj != null) {
            unavailOverlayCenters.add(Offset(proj.x, proj.y));
          }
        }
      }
    }

    // Flush all depth-sorted 3D triangles via Impeller/Skia Canvas.drawVertices!
    KAI3DRenderer.flushTriangles(canvas, tris);

    // 3. Draw crisp 3D-projected Unavailable Badges (⊘)
    final unavailPaint = Paint()
      ..color = const Color(0xFFCB3A64)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    for (final c in unavailOverlayCenters) {
      canvas.drawOval(
        Rect.fromCenter(center: c, width: 17, height: 13),
        unavailPaint,
      );
      canvas.drawLine(
        c + const Offset(-5.5, 4.0),
        c + const Offset(5.5, -4.0),
        unavailPaint,
      );
    }

    // 4. Draw 3D-projected Row Numbers along left & right walls
    for (final tn in seatMap.transformedTextModelEntities) {
      final wz = tn.position.z + currentContentZ;
      if (wz < -19.5 || wz > 1.0) continue;
      final worldPt = vm.Vector3(tn.position.x, tn.position.y, wz);
      final proj = KAI3DRenderer.projectPoint(
        worldPt,
        viewMatrix,
        f,
        aspect,
        halfW,
        halfH,
      );
      if (proj == null) continue;
      final scale = (8.0 / proj.z).clamp(0.55, 1.35);
      final tp = TextPainter(
        text: TextSpan(
          text: tn.text,
          style: TextStyle(
            fontSize: 11.0 * scale,
            fontWeight: FontWeight.w800,
            color: DesignSystem.basicGray,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = tn.textAlignment == 'left'
          ? proj.x
          : tn.textAlignment == 'right'
              ? proj.x - tp.width
              : proj.x - tp.width * 0.5;
      tp.paint(canvas, Offset(dx, proj.y - tp.height * 0.5));
    }

    // 5. Draw Station Direction Text along left side ("← Surabaya     Gambir →")
    final dirStart = KAI3DRenderer.projectPoint(
      vm.Vector3(-2.35, 1.2, -7.8),
      viewMatrix,
      f,
      aspect,
      halfW,
      halfH,
    );
    final dirEnd = KAI3DRenderer.projectPoint(
      vm.Vector3(-2.35, 1.2, -13.5),
      viewMatrix,
      f,
      aspect,
      halfW,
      halfH,
    );
    if (dirStart != null && dirEnd != null) {
      final angle = math.atan2(dirEnd.y - dirStart.y, dirEnd.x - dirStart.x);
      canvas.save();
      canvas.translate(dirStart.x, dirStart.y);
      canvas.rotate(angle);
      final dirTp = TextPainter(
        text: TextSpan(
          text: '← $toStation     $fromStation →',
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w300,
            color: DesignSystem.basicGray,
            letterSpacing: 0.3,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      dirTp.paint(canvas, Offset(0, -dirTp.height * 0.5));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SeatMap3DPainter oldDelegate) {
    return oldDelegate.currentContentZ != currentContentZ ||
        oldDelegate.highlightedSeatId != highlightedSeatId ||
        oldDelegate.selectedSeatId != selectedSeatId ||
        oldDelegate.currentEntity.seatClass != currentEntity.seatClass ||
        oldDelegate.isDark != isDark;
  }
}

// ============================================================================
// 2. SummaryPreview3DView (Port of SummaryPreviewView.swift)
// ============================================================================
class SummaryPreview3DView extends StatefulWidget {
  final String seatClassType;

  const SummaryPreview3DView({
    super.key,
    required this.seatClassType,
  });

  @override
  State<SummaryPreview3DView> createState() => _SummaryPreview3DViewState();
}

class _SummaryPreview3DViewState extends State<SummaryPreview3DView>
    with SingleTickerProviderStateMixin {
  late AnimationController _entranceCtrl;
  double _dragYaw = 0.0;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant SummaryPreview3DView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seatClassType != widget.seatClassType) {
      _dragYaw = 0;
      _entranceCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  String get _completeModelName {
    switch (widget.seatClassType) {
      case 'granClass':
        return '_kai_maroon_seat_complete';
      case 'eksekutifDualTone':
        return '_kai_eks_dualtone_seat_complete';
      case 'green':
        return '_kai_blue_seat_complete';
      case 'ekonomiNewGenDual':
        return '_kai_blue_dualtone_seat_complete';
      case 'ekonomiPremium':
        return '_kai_prem_seat_complete';
      case 'ekonomiTosca':
        return '_kai_tosca_seat_complete';
      case 'ordinary':
      default:
        return '_e7_ordinary_seat_complete';
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final maxDim = math.max(size.width, size.height);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) {
            setState(() {
              _dragYaw += (details.delta.dx / maxDim) * (math.pi * 0.8);
            });
          },
          onHorizontalDragEnd: (_) {
            setState(() {
              _dragYaw = 0;
            });
          },
          child: AnimatedBuilder(
            animation: _entranceCtrl,
            builder: (context, _) {
              final t = _entranceCtrl.value;
              double scale;
              double entranceYaw;
              if (t < 0.7) {
                final p = Curves.easeOutCubic.transform((t / 0.7).clamp(0.0, 1.0));
                scale = 0.1 + (1.066 - 0.1) * p;
                entranceYaw = math.pi * 1.5 + (-0.066 * math.pi - math.pi * 1.5) * p;
              } else {
                final p = Curves.easeInOut.transform(((t - 0.7) / 0.3).clamp(0.0, 1.0));
                scale = 1.066 + (1.0 - 1.066) * p;
                entranceYaw = -0.066 * math.pi * (1.0 - p);
              }
              return CustomPaint(
                size: size,
                painter: _SingleSeat3DPainter(
                  modelName: _completeModelName,
                  state: 'normal',
                  yaw: -math.pi / 6 + entranceYaw + _dragYaw,
                  pitch: 0.0,
                  scale: scale,
                  isDark: DesignSystem.instance.isDark,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ============================================================================
// 3. DesignSystem3DAssetView (Port of DesignSystemModel3DContentView.swift)
// ============================================================================
class DesignSystem3DAssetView extends StatefulWidget {
  final String modelName;
  final String stateName;

  const DesignSystem3DAssetView({
    super.key,
    required this.modelName,
    required this.stateName,
  });

  @override
  State<DesignSystem3DAssetView> createState() => _DesignSystem3DAssetViewState();
}

class _DesignSystem3DAssetViewState extends State<DesignSystem3DAssetView> {
  double _yaw = -math.pi / 6;
  double _pitch = 0.08;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) {
            setState(() {
              _yaw += details.delta.dx * 0.012;
              _pitch = (_pitch + details.delta.dy * 0.008).clamp(-0.6, 0.6);
            });
          },
          child: CustomPaint(
            size: size,
            painter: _SingleSeat3DPainter(
              modelName: widget.modelName,
              state: widget.stateName,
              yaw: _yaw,
              pitch: _pitch,
              scale: 1.0,
              isDark: DesignSystem.instance.isDark,
            ),
          ),
        );
      },
    );
  }
}

class _SingleSeat3DPainter extends CustomPainter {
  final String modelName;
  final String state;
  final double yaw;
  final double pitch;
  final double scale;
  final bool isDark;

  _SingleSeat3DPainter({
    required this.modelName,
    required this.state,
    required this.yaw,
    required this.pitch,
    required this.scale,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = math.max(size.width, 1.0);
    final h = math.max(size.height, 1.0);
    final aspect = w / h;
    const fovRad = 18.0 * math.pi / 180.0;
    final f = 1.0 / math.tan(fovRad * 0.5);
    final halfW = w * 0.5;
    final halfH = h * 0.5;

    // Soft radial floor shadow beneath seat
    final shadowCenter = Offset(halfW, h * 0.77);
    final shadowRect = Rect.fromCenter(
      center: shadowCenter,
      width: w * 0.62 * scale,
      height: h * 0.12 * scale,
    );
    final shadowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.black.withValues(alpha: 0.25),
          Colors.black.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(shadowRect);
    canvas.drawOval(shadowRect, shadowPaint);

    // Camera at (0, 1.38, 6.4) looking down at (0, 0.53, 0) with flattering studio angle
    final camWorld = vm.Matrix4.identity()
      ..setTranslationRaw(0.0, 1.38, 6.4)
      ..rotateX(-0.145 - pitch);
    final viewMatrix = vm.Matrix4.inverted(camWorld);

    final rotMatrix = vm.Matrix3.identity()
      ..multiply(vm.Matrix3.rotationY(yaw));

    final tris = <ProjectedTri>[];
    final parts = KAIGeometryBuilder.getSeatPrototype(modelName);
    final pal = KAIGeometryBuilder.getSeatStatePalette(modelName, state);
    final reclineAngle = (state == 'highlighted' || state == 'selected') ? -0.24 : 0.0;

    for (final part in parts) {
      if (part.role == 'unavail') continue;
      Color? roleCol;
      if (part.role == 'center') {
        roleCol = pal.center;
      } else if (part.role == 'bolster') {
        roleCol = pal.bolster;
      } else if (part.role == 'headInsert') {
        roleCol = pal.headInsert;
      } else if (part.role == 'seam') {
        roleCol = pal.seam;
      }

      for (final face in part.faces) {
        vm.Vector3 p0 = face.v0;
        vm.Vector3 p1 = face.v1;
        vm.Vector3 p2 = face.v2;
        vm.Vector3 vn0 = face.n0;
        vm.Vector3 vn1 = face.n1;
        vm.Vector3 vn2 = face.n2;
        vm.Vector3 sc = face.sortCenter;
        vm.Vector3 n = face.normal;

        if (part.reclines && reclineAngle != 0) {
          final rMat = vm.Matrix3.rotationX(reclineAngle);
          final pivot = vm.Vector3(0, 0.30, -0.17);
          p0 = rMat.transformed(p0 - pivot) + pivot;
          p1 = rMat.transformed(p1 - pivot) + pivot;
          p2 = rMat.transformed(p2 - pivot) + pivot;
          vn0 = rMat.transformed(vn0);
          vn1 = rMat.transformed(vn1);
          vn2 = rMat.transformed(vn2);
          sc = rMat.transformed(sc - pivot) + pivot;
          n = rMat.transformed(n);
        }

        final w0 = rotMatrix.transformed(p0 * scale);
        final w1 = rotMatrix.transformed(p1 * scale);
        final w2 = rotMatrix.transformed(p2 * scale);
        final wn0 = rotMatrix.transformed(vn0);
        final wn1 = rotMatrix.transformed(vn1);
        final wn2 = rotMatrix.transformed(vn2);
        final wCenter = rotMatrix.transformed(sc * scale);
        final wn = rotMatrix.transformed(n);

        // Backface culling against camera at (0, 1.38, 6.4)
        final vx = wCenter.x;
        final vy = wCenter.y - 1.38;
        final vz = wCenter.z - 6.4;
        if (vx * wn.x + vy * wn.y + vz * wn.z >= 0.0) continue;

        final pr0 = KAI3DRenderer.projectPoint(w0, viewMatrix, f, aspect, halfW, halfH);
        final pr1 = KAI3DRenderer.projectPoint(w1, viewMatrix, f, aspect, halfW, halfH);
        final pr2 = KAI3DRenderer.projectPoint(w2, viewMatrix, f, aspect, halfW, halfH);
        if (pr0 == null || pr1 == null || pr2 == null) continue;

        final sortDepth = math.sqrt(vx * vx + vy * vy + vz * vz);
        final baseCol = roleCol ?? face.color;
        final argb0 = KAI3DRenderer.computeLitColor(
          baseCol,
          wn0,
          face.ao0,
          face.roughness,
          face.metalness,
          face.unlit,
        );
        final argb1 = KAI3DRenderer.computeLitColor(
          baseCol,
          wn1,
          face.ao1,
          face.roughness,
          face.metalness,
          face.unlit,
        );
        final argb2 = KAI3DRenderer.computeLitColor(
          baseCol,
          wn2,
          face.ao2,
          face.roughness,
          face.metalness,
          face.unlit,
        );
        tris.add(ProjectedTri(
          pr0.x,
          pr0.y,
          pr1.x,
          pr1.y,
          pr2.x,
          pr2.y,
          face.uv0,
          face.uv1,
          face.uv2,
          10,
          sortDepth,
          argb0,
          argb1,
          argb2,
        ));
      }
    }

    KAI3DRenderer.flushTriangles(canvas, tris);
  }

  @override
  bool shouldRepaint(covariant _SingleSeat3DPainter oldDelegate) {
    return oldDelegate.modelName != modelName ||
        oldDelegate.state != state ||
        oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.scale != scale ||
        oldDelegate.isDark != isDark;
  }
}

