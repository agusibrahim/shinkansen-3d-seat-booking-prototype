import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
    _ticker = createTicker(_onTick);
    _initEntityBounds(playEntrance: true);
  }

  @override
  void didUpdateWidget(covariant SeatMap3DView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentEntity.seatClass != widget.currentEntity.seatClass) {
      _selectedSeat = null;
      _seatNavState = 'hide';
      _initEntityBounds(playEntrance: true);
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
    if (playEntrance) {
      _currentContentZ = _lowerZ;
      final targetZ = (_lowerZ * 2 + _upperZ) / 3;
      final dur = ((_upperZ.abs() - _lowerZ.abs()).abs() / 100.0 + 0.5)
          .clamp(0.45, 0.9);
      animateToZ(targetZ, durationSec: dur);
    } else {
      _currentContentZ = (_lowerZ * 2 + _upperZ) / 3;
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
        setState(() {
          _selectedSeat = rev;
          _seatNavState = 'visible';
        });
        widget.onSeatSelected(rev);
        widget.onBadgeUpdate(
          message:
              'Seat ${rev.name} in ${rev.carNumber.toLowerCase()} has been selected.',
          visible: true,
          autoHideMs: 2200,
        );
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
                  selectionColor: const [0.118, 0.620, 0.322, 1.0],
                  onSelectionChanged: _handleNativeSelectionChanged,
                  onModelLoaded: _syncNativeCamera,
                ),
              IgnorePointer(
                child: CustomPaint(
                  size: size,
                  painter: _SeatMapLabelsOverlayPainter(
                    seatMap: widget.seatMap,
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
  final double currentContentZ;
  final String fromStation;
  final String toStation;
  final vm.Matrix4 viewMatrix;

  _SeatMapLabelsOverlayPainter({
    required this.seatMap,
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

    // 1. Draw 3D-projected Row Numbers along left & right walls
    for (final tn in seatMap.transformedTextModelEntities) {
      final wz = tn.position.z + currentContentZ;
      if (wz < -19.5 || wz > 1.0) continue;
      final worldPt = vm.Vector3(tn.position.x, tn.position.y, wz);
      final proj = _projectPoint(worldPt, viewMatrix, f, aspect, halfW, halfH);
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

    // 2. Draw Station Direction Text along left side ("← Surabaya     Gambir →")
    final dirStart = _projectPoint(
      vm.Vector3(-2.35, 1.2, -7.8),
      viewMatrix,
      f,
      aspect,
      halfW,
      halfH,
    );
    final dirEnd = _projectPoint(
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
  bool shouldRepaint(covariant _SeatMapLabelsOverlayPainter oldDelegate) {
    return oldDelegate.currentContentZ != currentContentZ ||
        oldDelegate.fromStation != fromStation ||
        oldDelegate.toStation != toStation;
  }
}

// ============================================================================
// 2. SummaryPreview3DView — Powered by interactive_3d (.glb from Web!)
// ============================================================================
class SummaryPreview3DView extends StatelessWidget {
  final String seatClassType;

  const SummaryPreview3DView({
    super.key,
    required this.seatClassType,
  });

  String get _glbAssetPath {
    switch (seatClassType) {
      case 'granClass':
      case 'eksekutifDualTone':
      case 'green':
      case 'ekonomiNewGenDual':
      case 'ekonomiPremium':
      case 'ekonomiTosca':
      case 'ordinary':
        return 'assets/models/seat_$seatClassType.glb';
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

    return Interactive3d(
      key: ValueKey(_glbAssetPath),
      modelPath: _glbAssetPath,
      defaultZoom: 1.55,
      backgroundColor: bgCol,
      solidBackgroundColor: bgRgba,
      unselectableEntities: [
        'seat_$seatClassType',
      ],
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
          ? const [0.118, 0.620, 0.322, 1.0]
          : const [0.36, 0.13, 0.19, 1.0],
    );
  }
}
