import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:interactive_3d/interactive_3d.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import '../models/booking_models.dart';
import '../theme/design_system.dart';

bool get _isFlutterTest => Platform.environment.containsKey('FLUTTER_TEST');

// ============================================================================
// 1. SeatMap3DView — Powered by interactive_3d (Google Filament on Android,
//    Apple SceneKit on iOS) using the exact .glb assets exported from Web!
// ============================================================================
class SeatMap3DView extends StatefulWidget {
  final SeatMapModel seatMap;
  final SeatClassEntity currentEntity;
  final ReservableEntity? initialSelectedSeat;
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
    this.initialSelectedSeat,
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
  final Interactive3dController _controller = Interactive3dController();

  late double _lowerZ;
  late double _upperZ;
  double _currentContentZ = 0;
  double _velocityZ = 0;
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
    return vm.Matrix4.inverted(camWorld);
  }

  @override
  void initState() {
    super.initState();
    _selectedSeat = widget.initialSelectedSeat;
    _ticker = createTicker(_onTick);
    _initEntityBounds(playEntrance: true);
  }

  @override
  void didUpdateWidget(covariant SeatMap3DView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentEntity.seatClass != widget.currentEntity.seatClass) {
      _selectedSeat = widget.initialSelectedSeat;
      _seatNavState = 'hide';
      _initEntityBounds(playEntrance: true);
    } else if (widget.initialSelectedSeat != null &&
        _selectedSeat?.id != widget.initialSelectedSeat?.id) {
      _selectedSeat = widget.initialSelectedSeat;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _initEntityBounds({bool playEntrance = false}) {
    _lowerZ = widget.currentEntity.lowerZ;
    _upperZ = widget.currentEntity.upperZ;
    double defaultTargetZ = _lowerZ + math.min((_upperZ - _lowerZ) / 3.0, 6.5);
    if (_selectedSeat != null) {
      final seatZ = _selectedSeat!.transformedModelEntity.position.z;
      const centerFloorZ = -4.92;
      defaultTargetZ = (-seatZ + centerFloorZ).clamp(_lowerZ, _upperZ);
    }
    if (playEntrance) {
      _currentContentZ = _lowerZ;
      final dur = ((defaultTargetZ - _lowerZ).abs() / 120.0 + 0.5)
          .clamp(0.45, 0.85);
      animateToZ(defaultTargetZ, durationSec: dur);
    } else {
      _currentContentZ = defaultTargetZ;
      _syncNativeCamera();
    }
  }

  void _syncNativeCamera() {
    if (_isFlutterTest) return;
    _controller.setSeatMapCamera(-_currentContentZ);
  }

  void scrollToSelectedSeat() {
    if (_selectedSeat == null) return;
    final seatZ = _selectedSeat!.transformedModelEntity.position.z;
    const centerFloorZ = -4.92;
    final targetZ = (-seatZ + centerFloorZ).clamp(_lowerZ, _upperZ);
    animateToZ(targetZ, durationSec: 0.70);
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
        ? 0.016
        : ((elapsed - _lastTick!).inMicroseconds / 1e6).clamp(0.001, 0.05);
    _lastTick = elapsed;

    if (_animTargetZ != null && _animStartZ != null) {
      _animProgress += dt / _animDuration;
      if (_animProgress >= 1.0) {
        _currentContentZ = _animTargetZ!;
        _animTargetZ = null;
        _animStartZ = null;
        _ticker.stop();
      } else {
        final t = Curves.easeOutCubic.transform(_animProgress.clamp(0.0, 1.0));
        _currentContentZ = _animStartZ! + (_animTargetZ! - _animStartZ!) * t;
      }
      _syncNativeCamera();
      _checkSelectedSeatVisibility();
      setState(() {});
      return;
    }

    if (_isDrifting) {
      _velocityZ *= math.pow(0.92, dt * 60.0);
      _currentContentZ += _velocityZ * dt * 60.0;
      if (_currentContentZ < _lowerZ) {
        _currentContentZ += (_lowerZ - _currentContentZ) * 0.22;
        _velocityZ *= 0.65;
      } else if (_currentContentZ > _upperZ) {
        _currentContentZ += (_upperZ - _currentContentZ) * 0.22;
        _velocityZ *= 0.65;
      }
      _syncNativeCamera();
      _checkSelectedSeatVisibility();
      setState(() {});

      if (_velocityZ.abs() < 0.003 &&
          _currentContentZ >= _lowerZ - 0.01 &&
          _currentContentZ <= _upperZ + 0.01) {
        _currentContentZ = _currentContentZ.clamp(_lowerZ, _upperZ);
        _isDrifting = false;
        _ticker.stop();
        _syncNativeCamera();
      }
    }
  }

  void _checkSelectedSeatVisibility() {
    if (_selectedSeat == null) return;
    final wz =
        _selectedSeat!.transformedModelEntity.position.z + _currentContentZ;
    String nextState = 'visible';
    if (wz < -10.5) {
      nextState = 'up';
    } else if (wz > -0.6) {
      nextState = 'down';
    }
    if (nextState != _seatNavState) {
      _seatNavState = nextState;
      final seatLabel =
          'Seat ${_selectedSeat!.name} in ${_selectedSeat!.carNumber.toLowerCase()}';
      if (nextState == 'up') {
        widget.onBadgeUpdate(
          message: '↑ $seatLabel is in the front',
          visible: true,
          autoHideMs: 0,
        );
      } else if (nextState == 'down') {
        widget.onBadgeUpdate(
          message: '↓ $seatLabel is in the back',
          visible: true,
          autoHideMs: 0,
        );
      } else {
        widget.onBadgeUpdate(message: '', visible: false, autoHideMs: 0);
      }
    }
  }

  double _rubberBand(double val, double minVal, double maxVal) {
    if (val >= minVal && val <= maxVal) return val;
    const c = 0.55;
    const dim = 10.0;
    if (val > maxVal) {
      final d = val - maxVal;
      return maxVal + (1.0 - (1.0 / ((d * c / dim) + 1.0))) * dim;
    } else {
      final d = minVal - val;
      return minVal - (1.0 - (1.0 / ((d * c / dim) + 1.0))) * dim;
    }
  }

  double? _raycastFloorZ(Offset localPt, Size size) {
    final w = math.max(size.width, 1.0);
    final h = math.max(size.height, 1.0);
    final aspect = w / h;
    final fovRad = 64.0 * math.pi / 180.0;
    final tanHalfFov = math.tan(fovRad * 0.5);
    final ndcX = (localPt.dx / w) * 2.0 - 1.0;
    final ndcY = 1.0 - (localPt.dy / h) * 2.0;

    final dirCam = vm.Vector3(
      ndcX * aspect * tanHalfFov,
      ndcY * tanHalfFov,
      -1.0,
    )..normalize();

    final camRot = vm.Matrix3.rotationX(-0.9638087153434753);
    final dirWorld = camRot.transformed(dirCam);
    if (dirWorld.y.abs() < 1e-5) return null;
    final t = (1.3 - 7.2) / dirWorld.y;
    if (t <= 0) return null;
    return dirWorld.z * t;
  }

  void _handleNativeSelectionChanged(List<EntityData> entities) {
    if (entities.isEmpty) return;
    final last = entities.last;
    if (!last.name.startsWith('seat_')) return;
    final idStr = last.name.substring(5);
    final seatId = int.tryParse(idStr);
    if (seatId == null) return;

    for (final rev in widget.currentEntity.reservableEntities) {
      if (rev.id == seatId && rev.isAvailable) {
        final isNewSelection = _selectedSeat?.id != rev.id;
        setState(() {
          _selectedSeat = rev;
          _seatNavState = 'visible';
        });
        HapticFeedback.lightImpact();
        widget.onSeatSelected(rev);
        if (isNewSelection) {
          widget.onBadgeUpdate(
            message:
                'Seat ${rev.name} in ${rev.carNumber.toLowerCase()} has been selected.',
            visible: true,
            autoHideMs: 4000,
          );
        }
        // Smoothly center the newly selected seat in the viewport (SeatMapSceneView.swift line 131)
        scrollToSelectedSeat();
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ds = DesignSystem.instance;
    final isDark = ds.isDark;
    final bgCol = isDark ? DesignSystem.basicDarkGray : DesignSystem.basicWhite;
    final bgRgba = isDark
        ? const [0.133, 0.145, 0.165, 1.0]
        : const [1.0, 1.0, 1.0, 1.0];
    final modelPath = 'assets/models/car_${widget.currentEntity.seatClass}.glb';

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            if (!_isFlutterTest) {
              _controller.triggerTap(
                details.localPosition.dx,
                details.localPosition.dy,
              );
            }
          },
          onPanStart: (details) {
            _ticker.stop();
            _isDrifting = false;
            _animTargetZ = null;
            _dragStartLocal = details.localPosition;
            _hitZAtTouchStart = _raycastFloorZ(details.localPosition, size);
            _contentZAtTouchStart = _currentContentZ;
            _isDragging = false;
            _velocityZ = 0;
          },
          onPanUpdate: (details) {
            if (_dragStartLocal != null &&
                (details.localPosition - _dragStartLocal!).distance > 6.0) {
              _isDragging = true;
            }
            if (_isDragging && _hitZAtTouchStart != null) {
              final curHitZ = _raycastFloorZ(details.localPosition, size);
              if (curHitZ != null) {
                final deltaZ = curHitZ - _hitZAtTouchStart!;
                final prevZ = _currentContentZ;
                final rawZ = _contentZAtTouchStart + deltaZ;
                _currentContentZ = _rubberBand(rawZ, _lowerZ, _upperZ);
                _velocityZ = (_currentContentZ - prevZ) * 0.85;
                if (rawZ > _upperZ) {
                  widget.onOverscrollUpper((rawZ - _upperZ) * -18.0);
                } else {
                  widget.onOverscrollUpper(0);
                }
                _syncNativeCamera();
                _checkSelectedSeatVisibility();
                setState(() {});
              }
            }
          },
          onPanEnd: (_) {
            widget.onOverscrollUpper(0);
            if (_currentContentZ < _lowerZ) {
              animateToZ(_lowerZ, durationSec: 0.45);
            } else if (_currentContentZ > _upperZ) {
              animateToZ(_upperZ, durationSec: 0.45);
            } else if (_velocityZ.abs() > 0.01) {
              _isDrifting = true;
              _lastTick = null;
              if (!_ticker.isActive) _ticker.start();
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_isFlutterTest)
                ColoredBox(color: bgCol)
              else
                Interactive3d(
                  key: ValueKey(modelPath),
                  controller: _controller,
                  modelPath: modelPath,
                  seatMapInitialZ: -_currentContentZ,
                  backgroundColor: bgCol,
                  solidBackgroundColor: bgRgba,
                  preselectedEntities: _selectedSeat != null
                      ? ['seat_${_selectedSeat!.id}']
                      : null,
                  selectionColor: const [0.14, 0.72, 0.38, 1.0],
                  onSelectionChanged: _handleNativeSelectionChanged,
                  onModelLoaded: _syncNativeCamera,
                ),
              IgnorePointer(
                child: CustomPaint(
                  size: size,
                  painter: _SeatMapLabelsOverlayPainter(
                    seatMap: widget.seatMap,
                    currentEntity: widget.currentEntity,
                    currentContentZ: _currentContentZ,
                    fromStation: widget.fromStation,
                    toStation: widget.toStation,
                    viewMatrix: _viewMatrix,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SeatMapLabelsOverlayPainter extends CustomPainter {
  final SeatMapModel seatMap;
  final SeatClassEntity currentEntity;
  final double currentContentZ;
  final String fromStation;
  final String toStation;
  final vm.Matrix4 viewMatrix;

  _SeatMapLabelsOverlayPainter({
    required this.seatMap,
    required this.currentEntity,
    required this.currentContentZ,
    required this.fromStation,
    required this.toStation,
    required this.viewMatrix,
  });

  static vm.Vector3? _projectPoint(
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

  @override
  void paint(Canvas canvas, Size size) {
    final w = math.max(size.width, 1.0);
    final h = math.max(size.height, 1.0);
    final aspect = w / h;
    const fovRad = 64.0 * math.pi / 180.0;
    final f = 1.0 / math.tan(fovRad * 0.5);
    final halfW = w * 0.5;
    final halfH = h * 0.5;

    // 1. Draw 3D-projected Row Numbers along left & right walls at (x = ±1.74, y = 2.65)
    for (final tn in seatMap.transformedTextModelEntities) {
      final wz = tn.position.z + currentContentZ;
      if (wz < -19.5 || wz > 1.0) continue;
      final rowX = tn.position.x < 0 ? -1.74 : 1.74;
      final worldPt = vm.Vector3(rowX, 2.65, wz);
      final proj = _projectPoint(worldPt, viewMatrix, f, aspect, halfW, halfH);
      if (proj == null) continue;
      final scale = (8.0 / proj.z).clamp(0.55, 1.35);
      final tp = TextPainter(
        text: TextSpan(
          text: tn.text,
          style: TextStyle(
            fontSize: 11.5 * scale,
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

    // 2. Draw Bold Station Direction Text on the same y = 2.65 plane at x = -2.16 (parallel ray outside row numbers -> ZERO overlap!)
    final dirStart = _projectPoint(
      vm.Vector3(-2.16, 2.65, -3.8),
      viewMatrix,
      f,
      aspect,
      halfW,
      halfH,
    );
    final dirEnd = _projectPoint(
      vm.Vector3(-2.16, 2.65, -8.2),
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
            fontWeight: FontWeight.w700,
            color: DesignSystem.basicGray,
            letterSpacing: 0.3,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      dirTp.paint(canvas, Offset(0, -dirTp.height * 0.5));
      canvas.restore();
    }

    // 3. Draw 3D-projected Coach Number Badges (e.g. "EKS 1", "EKS 2", "EKS 3") at the front/back of each coach
    final coachZBounds = <String, ({double minZ, double maxZ})>{};
    for (final rev in currentEntity.reservableEntities) {
      final cz = rev.transformedModelEntity.position.z;
      final prev = coachZBounds[rev.carNumber];
      if (prev == null) {
        coachZBounds[rev.carNumber] = (minZ: cz, maxZ: cz);
      } else {
        coachZBounds[rev.carNumber] = (
          minZ: math.min(prev.minZ, cz),
          maxZ: math.max(prev.maxZ, cz),
        );
      }
    }

    for (final entry in coachZBounds.entries) {
      final carLabel = entry.key.toUpperCase();
      // Place badge just before the front row and just after the back row of each coach
      for (final worldZ in [entry.value.maxZ + 1.15, entry.value.minZ - 1.15]) {
        final wz = worldZ + currentContentZ;
        if (wz < -21.0 || wz > 1.5) continue;
        final proj = _projectPoint(
          vm.Vector3(0.0, 1.35, wz),
          viewMatrix,
          f,
          aspect,
          halfW,
          halfH,
        );
        if (proj == null) continue;
        final scale = (8.0 / proj.z).clamp(0.65, 1.25);
        final tp = TextPainter(
          text: TextSpan(
            text: carLabel,
            style: TextStyle(
              fontSize: 10.5 * scale,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.6,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final bgRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(proj.x, proj.y),
            width: tp.width + 14.0 * scale,
            height: tp.height + 6.0 * scale,
          ),
          Radius.circular(6.0 * scale),
        );
        canvas.drawRRect(
          bgRect,
          Paint()..color = const Color(0xCC1E242E),
        );
        tp.paint(
          canvas,
          Offset(proj.x - tp.width * 0.5, proj.y - tp.height * 0.5),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SeatMapLabelsOverlayPainter oldDelegate) {
    return oldDelegate.currentContentZ != currentContentZ ||
        oldDelegate.fromStation != fromStation ||
        oldDelegate.toStation != toStation;
  }
}

// ============================================================================
// 2. SummaryPreview3DView — Exact port of SummaryPreviewView.swift:
//    - Plays 2-stage entrance spin + scale pop animation (0.1 -> 1.066 -> 1.0)
//    - Horizontal-only drag rotation (locked pitch)
//    - Smooth spring snap-back to yaw = 0 when finger is released!
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
    with TickerProviderStateMixin {
  final Interactive3dController _controller = Interactive3dController();
  late AnimationController _entranceCtrl;
  late AnimationController _snapBackCtrl;
  double _dragYaw = 0.0;
  double _snapStartYaw = 0.0;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    )..addListener(_syncPreviewCamera);

    _snapBackCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..addListener(() {
        final t = Curves.easeOutCubic.transform(_snapBackCtrl.value);
        _dragYaw = _snapStartYaw * (1.0 - t);
        _syncPreviewCamera();
      });
  }

  @override
  void didUpdateWidget(covariant SummaryPreview3DView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seatClassType != widget.seatClassType) {
      _dragYaw = 0.0;
      _snapBackCtrl.stop();
      _entranceCtrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _snapBackCtrl.dispose();
    super.dispose();
  }

  void _syncPreviewCamera() {
    if (_isFlutterTest) return;
    final t = _entranceCtrl.value;
    double scale;
    double entranceYaw;
    if (t < 0.68) {
      final p = Curves.easeOutCubic.transform((t / 0.68).clamp(0.0, 1.0));
      scale = 0.1 + (1.066 - 0.1) * p;
      entranceYaw =
          math.pi * 1.5 + (-0.066 * math.pi - math.pi * 1.5) * p;
    } else {
      final p =
          Curves.easeInOut.transform(((t - 0.68) / 0.32).clamp(0.0, 1.0));
      scale = 1.066 + (1.0 - 1.066) * p;
      entranceYaw = -0.066 * math.pi * (1.0 - p);
    }
    _controller.setPreviewPose(entranceYaw + _dragYaw, scale);
  }

  String get _glbAssetPath {
    switch (widget.seatClassType) {
      case 'granClass':
      case 'eksekutifDualTone':
      case 'green':
      case 'ekonomiNewGenDual':
      case 'ekonomiPremium':
      case 'ekonomiTosca':
      case 'ordinary':
        return 'assets/models/seat_${widget.seatClassType}.glb';
      default:
        return 'assets/models/seat_granClass.glb';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ds = DesignSystem.instance;
    final isDark = ds.isDark;
    final bgCol = ds.cardBackground;
    final bgRgba = isDark
        ? const [0.18, 0.19, 0.22, 1.0]
        : const [1.0, 1.0, 1.0, 1.0];

    if (_isFlutterTest) {
      return ColoredBox(color: bgCol);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDim = math.max(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) {
            _snapBackCtrl.stop();
          },
          onHorizontalDragUpdate: (details) {
            _dragYaw += (details.delta.dx / maxDim) * (math.pi * 0.65);
            _syncPreviewCamera();
          },
          onHorizontalDragEnd: (_) {
            _snapStartYaw = _dragYaw;
            final durMs =
                ((_dragYaw.abs() / math.pi) * 520.0).round().clamp(160, 440);
            _snapBackCtrl.duration = Duration(milliseconds: durMs);
            _snapBackCtrl.forward(from: 0.0);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Interactive3d(
                key: ValueKey(_glbAssetPath),
                controller: _controller,
                modelPath: _glbAssetPath,
                previewSnapMode: true,
                backgroundColor: bgCol,
                solidBackgroundColor: bgRgba,
                unselectableEntities: [
                  'seat_${widget.seatClassType}',
                ],
                onModelLoaded: () {
                  _entranceCtrl.forward(from: 0.0);
                },
              ),
              // Subtle ground contact shadow beneath the 3D seat
              IgnorePointer(
                child: Align(
                  alignment: const Alignment(0.0, 0.62),
                  child: Container(
                    width: constraints.maxWidth * 0.46,
                    height: 26,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                       gradient: RadialGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.16),
                          Colors.black.withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// 3. DesignSystem3DAssetView — Powered by interactive_3d (.glb from Web!)
// ============================================================================
class DesignSystem3DAssetView extends StatelessWidget {
  final String modelName;
  final String stateName;

  const DesignSystem3DAssetView({
    super.key,
    required this.modelName,
    required this.stateName,
  });

  String get _seatClassKey {
    if (modelName.contains('eks-dualtone') || modelName.contains('eks_dualtone')) {
      return 'eksekutifDualTone';
    }
    if (modelName.contains('blue-dualtone') || modelName.contains('blue_dualtone')) {
      return 'ekonomiNewGenDual';
    }
    if (modelName.contains('blue') || modelName.contains('green')) {
      return 'green';
    }
    if (modelName.contains('prem')) {
      return 'ekonomiPremium';
    }
    if (modelName.contains('tosca')) {
      return 'ekonomiTosca';
    }
    if (modelName.contains('ordinary')) {
      return 'ordinary';
    }
    return 'granClass';
  }

  @override
  Widget build(BuildContext context) {
    final ds = DesignSystem.instance;
    final isDark = ds.isDark;
    final bgCol = ds.cardBackground;
    final bgRgba = isDark
        ? const [0.18, 0.19, 0.22, 1.0]
        : const [1.0, 1.0, 1.0, 1.0];
    final glbPath = 'assets/models/seat_$_seatClassKey.glb';

    if (_isFlutterTest) {
      return ColoredBox(color: bgCol);
    }

    return Interactive3d(
      key: ValueKey('$glbPath:$stateName'),
      modelPath: glbPath,
      defaultZoom: 1.55,
      backgroundColor: bgCol,
      solidBackgroundColor: bgRgba,
      preselectedEntities:
          (stateName == 'selected' || stateName == 'highlighted')
              ? ['seat_$_seatClassKey']
              : null,
      selectionColor: stateName == 'selected'
          ? const [0.14, 0.72, 0.38, 1.0]
          : const [0.36, 0.13, 0.19, 1.0],
    );
  }
}
