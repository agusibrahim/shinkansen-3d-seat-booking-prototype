import 'dart:async';
import 'dart:io' show File;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'engine/kai_3d_engine.dart';
import 'models/booking_models.dart';
import 'screens/design_system_modal.dart';
import 'theme/design_system.dart';
import 'widgets/atomic_components.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KAI3DSeatBookingApp());
}

class KAI3DSeatBookingApp extends StatefulWidget {
  const KAI3DSeatBookingApp({super.key});

  @override
  State<KAI3DSeatBookingApp> createState() => _KAI3DSeatBookingAppState();
}

class _KAI3DSeatBookingAppState extends State<KAI3DSeatBookingApp> {
  @override
  void initState() {
    super.initState();
    DesignSystem.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    DesignSystem.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ds = DesignSystem.instance;
    return MaterialApp(
      title: 'KAI 3D Seat Booking Prototype',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: ds.isDark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: ds.background,
        fontFamily: '.SF Pro Text',
      ),
      home: const RootPrototypeContainer(),
    );
  }
}

enum PrototypeStep {
  initial,
  criteria,
  trainSelection,
  seatClassSelection,
  seatMapSelection,
  confirmation,
}

class RootPrototypeContainer extends StatefulWidget {
  const RootPrototypeContainer({super.key});

  @override
  State<RootPrototypeContainer> createState() => _RootPrototypeContainerState();
}

class _RootPrototypeContainerState extends State<RootPrototypeContainer> {
  PrototypeStep _step = PrototypeStep.initial;
  bool _showDesignSystem = false;

  TrainCriteriaModel? _trainCriteria;
  SeatMapModel? _seatMap;

  int _dateSelectedIndex = 0; // 0: Today, 1: Tomorrow, 2: Pick a Date
  int _timeSelectedIndex = 0; // 0: Morning, 1: Afternoon, 2: Evening
  int _dateOffsetSec = 0;
  int _timeOffsetSec = 0;

  late BookingHeaderInformation _headerInfo;
  List<TrainScheduleModel> _filteredSchedules = [];
  TrainScheduleModel? _selectedSchedule;
  SeatClassModel? _selectedSeatClass;
  SeatClassEntity? _selectedSeatClassEntity;
  ReservableEntity? _selectedReservableEntity;

  String? _errorMessage;
  Timer? _errorTimer;

  String _badgeMessage = '';
  bool _badgeVisible = false;
  Timer? _badgeTimer;
  double _seatMapOverscrollY = 0.0;

  final GlobalKey<SeatMap3DViewState> _seatMapKey =
      GlobalKey<SeatMap3DViewState>();
  Timer? _simPollTimer;
  String _lastSimCmd = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _headerInfo = BookingHeaderInformation(
      dayOfWeek: KAIFormatters.formatWeekday(now),
      date: KAIFormatters.formatFullDate(now),
      fromStation: 'Gambir',
      toStation: 'Surabaya',
    );
    _preloadData();
    assert(() {
      _simPollTimer = Timer.periodic(const Duration(milliseconds: 350), (_) {
        _checkSimStepFile();
      });
      return true;
    }());
  }

  @override
  void dispose() {
    _simPollTimer?.cancel();
    _errorTimer?.cancel();
    _badgeTimer?.cancel();
    super.dispose();
  }

  void _checkSimStepFile() {
    if (_trainCriteria == null || _seatMap == null) return;
    try {
      final f = File('/tmp/kai_sim_step.txt');
      if (!f.existsSync()) return;
      final cmd = f.readAsStringSync().trim();
      if (cmd.isNotEmpty && cmd != _lastSimCmd) {
        _lastSimCmd = cmd;
        _applySimStep(cmd);
      }
    } catch (_) {}
  }

  Future<void> _preloadData() async {
    final results = await Future.wait([
      TrainCriteriaModel.loadFromAssets(),
      SeatMapModel.loadFromAssets(),
    ]);
    if (!mounted) return;
    setState(() {
      _trainCriteria = results[0] as TrainCriteriaModel;
      _seatMap = results[1] as SeatMapModel;
    });
    _checkSimStepFile();
  }

  void _applySimStep(String stepCmd) {
    if (stepCmd == 'initial') {
      setState(() => _step = PrototypeStep.initial);
      return;
    }
    _dateSelectedIndex = 1; // Tomorrow
    _timeSelectedIndex = 0; // Morning
    _handleSearchTickets();
    if (stepCmd == 'criteria') {
      setState(() => _step = PrototypeStep.criteria);
      return;
    }
    if (stepCmd == 'trains') {
      setState(() => _step = PrototypeStep.trainSelection);
      return;
    }
    final sched = _filteredSchedules.first;
    _selectedSchedule = sched;
    _headerInfo.fromTime = '06:12';
    _headerInfo.toTime = '06:38';
    _headerInfo.trainNumber = sched.trainNumber;
    _headerInfo.trainName = sched.trainName;
    if (stepCmd == 'classes') {
      setState(() => _step = PrototypeStep.seatClassSelection);
      return;
    }
    final classIdx = int.tryParse(stepCmd.split(':').last) ?? 0;
    final sc = sched.seatClasses[classIdx.clamp(0, sched.seatClasses.length - 1)];
    final entity = _seatMap!.seatClassEntities.firstWhere(
      (e) => e.seatClass == sc.seatClass,
      orElse: () => _seatMap!.seatClassEntities.first,
    );
    _selectedSeatClass = sc;
    _selectedSeatClassEntity = entity;
    _headerInfo.carNumber = entity.carNumber;
    _headerInfo.className = sc.name;
    _headerInfo.price = KAIFormatters.formatRupiah(sc.price);

    if (stepCmd.startsWith('seatmap:')) {
      final pickSeat = entity.reservableEntities.firstWhere(
        (r) => r.isAvailable && r.name.startsWith('5'),
        orElse: () => entity.reservableEntities.firstWhere((r) => r.isAvailable),
      );
      _selectedReservableEntity = pickSeat;
      _headerInfo.carNumber = pickSeat.carNumber;
      _badgeMessage =
          'Seat ${pickSeat.name} in ${pickSeat.carNumber.toLowerCase()} has been selected.';
      _badgeVisible = true;
      setState(() => _step = PrototypeStep.seatMapSelection);
    } else if (stepCmd.startsWith('confirm:')) {
      final pickSeat = entity.reservableEntities.firstWhere(
        (r) => r.isAvailable && r.name.startsWith('6'),
        orElse: () => entity.reservableEntities.firstWhere((r) => r.isAvailable),
      );
      _selectedReservableEntity = pickSeat;
      _headerInfo.seatNumber = pickSeat.name;
      _headerInfo.carNumber = pickSeat.carNumber;
      setState(() => _step = PrototypeStep.confirmation);
    }
  }

  void _showError(String msg) {
    _errorTimer?.cancel();
    setState(() {
      _errorMessage = msg;
    });
    _errorTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }
    });
  }

  void _updateBadge({
    required String message,
    required bool visible,
    int autoHideMs = 0,
  }) {
    _badgeTimer?.cancel();
    if (!visible) {
      setState(() {
        _badgeVisible = false;
      });
      return;
    }
    setState(() {
      _badgeMessage = message;
      _badgeVisible = true;
    });
    if (autoHideMs > 0) {
      _badgeTimer = Timer(Duration(milliseconds: autoHideMs), () {
        if (mounted) {
          setState(() {
            _badgeVisible = false;
          });
        }
      });
    }
  }

  void _popStep() {
    setState(() {
      switch (_step) {
        case PrototypeStep.confirmation:
          _step = PrototypeStep.seatMapSelection;
          break;
        case PrototypeStep.seatMapSelection:
          _step = PrototypeStep.seatClassSelection;
          break;
        case PrototypeStep.seatClassSelection:
          _step = PrototypeStep.trainSelection;
          break;
        case PrototypeStep.trainSelection:
          _step = PrototypeStep.criteria;
          break;
        default:
          break;
      }
    });
  }

  void _showExitActionSheet({bool isEndOfPrototype = false}) {
    final title = isEndOfPrototype
        ? "You're about to exit the Prototype."
        : 'This is the end of this prototype.';
    final message = isEndOfPrototype
        ? 'Are you sure you want to proceed this action?'
        : 'Are you sure you want to exit the prototype?';

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(title),
        message: Text(message),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _step = PrototypeStep.initial;
              });
            },
            child: const Text('Exit'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ds = DesignSystem.instance;
    final statusStyle = _step == PrototypeStep.initial
        ? SystemUiOverlayStyle.light
        : ds.isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: statusStyle,
      child: Scaffold(
        backgroundColor:
            _step == PrototypeStep.initial ? DesignSystem.accentMain : ds.background,
        body: Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              switchInCurve: const Cubic(0.2, 0, 0, 1),
              switchOutCurve: const Cubic(0.2, 0, 0, 1),
              child: _buildCurrentStep(ds),
            ),

            // Top Error Banner (BookingViewController.showErrorMessage)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: const Cubic(0.2, 0, 0, 1),
              top: _errorMessage != null ? 0 : -120,
              left: 0,
              right: 0,
              child: Container(
                color: ds.errorBackground,
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.of(context).padding.top + 8,
                  20,
                  14,
                ),
                child: Text(
                  _errorMessage ?? '',
                  textAlign: TextAlign.center,
                  style: DesignSystem.caption1(color: ds.primaryText),
                ),
              ),
            ),

            // DesignSystemViewController Modal Sheet
            if (_showDesignSystem)
              Positioned.fill(
                child: DesignSystemModal(
                  onClose: () => setState(() => _showDesignSystem = false),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep(DesignSystem ds) {
    switch (_step) {
      case PrototypeStep.initial:
        return _buildInitialScreen(ds);
      case PrototypeStep.criteria:
        return _buildCriteriaScreen(ds);
      case PrototypeStep.trainSelection:
        return _buildTrainSelectionScreen(ds);
      case PrototypeStep.seatClassSelection:
        return _buildSeatClassSelectionScreen(ds);
      case PrototypeStep.seatMapSelection:
        return _buildSeatMapSelectionScreen(ds);
      case PrototypeStep.confirmation:
        return _buildConfirmationScreen(ds);
    }
  }

  // ==========================================================================
  // 1. PrototypeInitialViewController
  // ==========================================================================
  Widget _buildInitialScreen(DesignSystem ds) {
    return Container(
      key: const ValueKey('step-initial'),
      color: DesignSystem.accentMain,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'Welcome to 3D Seat Booking Prototype!',
                        style: DesignSystem.largeTitle(
                          color: DesignSystem.basicWhite,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ...[
                        'Thank you for your interest in this prototype!',
                        'This prototype shows the potential usage of 3D visualization capability in interactive booking products.',
                        "As this is a prototype, the information showing is mock data which statically stores in the app. That means the information doesn't obtain from or send back to the server, and many functionalities don't fully work. (Particularly, the route picker and date picker in the first view.)",
                        'To start the prototype, please tap on "Start the Prototype" button, and to exit the prototype in the middle of the flow, tap Purchase at the end of the flow.',
                        'This prototype includes the complete Indonesian KAI (Kereta Api Indonesia) 7-class 3D seat & cabin fleet.',
                      ].map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            p,
                            style: DesignSystem.body(
                              color: DesignSystem.basicWhite,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // InitialViewColorThemeSegmentedControl
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                decoration: BoxDecoration(
                  color: DesignSystem.accentLight,
                  borderRadius: BorderRadius.circular(DesignSystem.radiusCard),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildThemeOption(
                      title: 'Light Mode',
                      selected: !ds.isDark,
                      isDarkOption: false,
                      onTap: () => ds.setTheme(AppColorTheme.light),
                    ),
                    const SizedBox(width: 40),
                    _buildThemeOption(
                      title: 'Dark Mode',
                      selected: ds.isDark,
                      isDarkOption: true,
                      onTap: () => ds.setTheme(AppColorTheme.dark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppButton(
                title: 'GitHub Repository',
                variant: ButtonVariant.initialText,
                onPressed: () {
                  _showError(
                    'Repository: github.com/agusibrahim/shinkansen-3d-seat-booking-prototype',
                  );
                },
              ),
              const SizedBox(height: 4),
              AppButton(
                title: 'Explore Design System',
                variant: ButtonVariant.initialText,
                onPressed: () => setState(() => _showDesignSystem = true),
              ),
              const SizedBox(height: 8),
              AppButton(
                title: 'Start the Prototype',
                variant: ButtonVariant.initialContained,
                onPressed: () {
                  setState(() {
                    _step = PrototypeStep.criteria;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required String title,
    required bool selected,
    required bool isDarkOption,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: selected ? 1.0 : 0.82,
            duration: const Duration(milliseconds: 150),
            child: Opacity(
              opacity: selected ? 1.0 : DesignSystem.alphaDisabled,
              child: Container(
                width: 40,
                height: 64,
                decoration: BoxDecoration(
                  color: isDarkOption
                      ? DesignSystem.accentMain
                      : DesignSystem.basicWhite,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: DesignSystem.basicWhite, width: 1),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/icons/colorThemeModeIcon.png',
                    width: 28,
                    height: 48,
                    color: isDarkOption
                        ? DesignSystem.basicWhite
                        : DesignSystem.accentMain,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Opacity(
            opacity: selected ? 1.0 : DesignSystem.alphaDisabled,
            child: Text(
              title,
              style: DesignSystem.caption1(color: DesignSystem.basicWhite),
            ),
          ),
          const SizedBox(height: 6),
          Image.asset(
            selected
                ? 'assets/images/icons/iconCheckedSymbol.png'
                : 'assets/images/icons/iconUncheckedSymbol.png',
            width: 22,
            height: 22,
            color: DesignSystem.basicWhite,
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 2. BookingCriteriaViewController
  // ==========================================================================
  Widget _buildCriteriaScreen(DesignSystem ds) {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));

    final dateItems = [
      SegmentedItemData(
        title: 'Today',
        subtitle: KAIFormatters.formatFullDate(now),
      ),
      SegmentedItemData(
        title: 'Tomorrow',
        subtitle: KAIFormatters.formatFullDate(tomorrow),
      ),
      const SegmentedItemData(
        title: 'Pick a Date',
        subtitle: ' ',
      ),
    ];

    final isToday = _dateSelectedIndex == 0;
    final morningEnabled = !isToday || now.hour < 12;
    final afternoonEnabled = !isToday || now.hour < 18;
    const eveningEnabled = true;

    final timeItems = [
      SegmentedItemData(
        title: 'Morning',
        subtitle: '6:00 - 12:00',
        isEnabled: morningEnabled,
      ),
      SegmentedItemData(
        title: 'Afternoon',
        subtitle: '12:00 - 18:00',
        isEnabled: afternoonEnabled,
      ),
      const SegmentedItemData(
        title: 'Evening',
        subtitle: '18:00 - 0:00',
        isEnabled: eveningEnabled,
      ),
    ];

    if (!timeItems[_timeSelectedIndex].isEnabled) {
      final firstValid = timeItems.indexWhere((e) => e.isEnabled);
      _timeSelectedIndex = firstValid != -1 ? firstValid : 2;
    }

    void triggerStationError() {
      _showError(
        "Oops! Changing station feature doesn't work as this prototype doesn't have it implemented yet.",
      );
    }

    return Container(
      key: const ValueKey('step-criteria'),
      color: ds.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reserve \nKAI Train \nTickets',
                            style: DesignSystem.largeTitle(
                              color: ds.callToAction,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Image.asset(
                              'assets/images/icons/logo_kai.png',
                              width: 68,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 36),
                      // From -> Destination Station Cards
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'FROM',
                                  style: DesignSystem.footnote(
                                    color: ds.secondaryText,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                CardControl(
                                  onTap: triggerStationError,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 8,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: Column(
                                      children: [
                                        Text(
                                          'GMR',
                                          style: DesignSystem.title1(
                                            color: ds.callToAction,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Gambir',
                                          style: DesignSystem.caption1Alt(
                                            color: ds.callToAction,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 24,
                            ),
                            child: Image.asset(
                              'assets/images/icons/icon_arrow_right.png',
                              width: 24,
                              height: 24,
                              color: ds.callToAction,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'DESTINATION',
                                  style: DesignSystem.footnote(
                                    color: ds.secondaryText,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                CardControl(
                                  onTap: triggerStationError,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 8,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: Column(
                                      children: [
                                        Text(
                                          'SBI',
                                          style: DesignSystem.title1(
                                            color: ds.callToAction,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Surabaya Ps. Turi',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: DesignSystem.caption1Alt(
                                            color: ds.callToAction,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'DATE',
                        style: DesignSystem.footnote(color: ds.secondaryText),
                      ),
                      const SizedBox(height: 10),
                      AppSegmentedControl(
                        items: dateItems,
                        selectedIndex: _dateSelectedIndex,
                        onChanged: (idx) {
                          setState(() {
                            _dateSelectedIndex = idx;
                          });
                          if (idx == 2) {
                            _showError(
                              "Oops! Picking a particular date feature doesn't work as this prototype doesn't have it implemented yet.",
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'TIME',
                        style: DesignSystem.footnote(color: ds.secondaryText),
                      ),
                      const SizedBox(height: 10),
                      AppSegmentedControl(
                        items: timeItems,
                        selectedIndex: _timeSelectedIndex,
                        onChanged: (idx) {
                          setState(() {
                            _timeSelectedIndex = idx;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              AppButton(
                title: 'Search for Tickets',
                onPressed: _handleSearchTickets,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSearchTickets() {
    _dateOffsetSec = _dateSelectedIndex == 0
        ? 0
        : _dateSelectedIndex == 1
            ? 86400
            : 86400 * 2;
    _timeOffsetSec = _timeSelectedIndex == 0
        ? 0
        : _timeSelectedIndex == 1
            ? 6 * 3600
            : 12 * 3600;

    final targetDate = DateTime.now().add(Duration(seconds: _dateOffsetSec));
    _headerInfo = BookingHeaderInformation(
      dayOfWeek: KAIFormatters.formatWeekday(targetDate),
      date: KAIFormatters.formatFullDate(targetDate),
      fromStation: 'Gambir',
      toStation: 'Surabaya',
    );

    final all = _trainCriteria?.trainSchedules ?? [];
    final now = DateTime.now();
    var filtered = all.where((s) {
      final comp = KAIFormatters.getJSTComponents(s.fromTime);
      final dt = DateTime(
        now.year,
        now.month,
        now.day,
        comp.hour,
        comp.minute,
        comp.second,
      ).add(Duration(seconds: _dateOffsetSec + _timeOffsetSec));
      return now.isBefore(dt);
    }).toList();

    if (filtered.isEmpty && all.isNotEmpty) {
      filtered = all;
    }

    setState(() {
      _filteredSchedules = filtered;
      _step = PrototypeStep.trainSelection;
    });
  }

  // ==========================================================================
  // 3. TrainSelectionViewController
  // ==========================================================================
  Widget _buildTrainSelectionScreen(DesignSystem ds) {
    return Container(
      key: const ValueKey('step-train-selection'),
      color: ds.background,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  SizedBox(
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Transform.translate(
                            offset: const Offset(-10, 0),
                            child: BackButtonControl(onPressed: _popStep),
                          ),
                        ),
                        Text(
                          '${_headerInfo.dayOfWeek}, ${_headerInfo.date}',
                          style: DesignSystem.headline(color: ds.primaryText),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  HeaderRouteInformationView(info: _headerInfo),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: _filteredSchedules.length,
                itemBuilder: (ctx, idx) {
                  final sched = _filteredSchedules[idx];
                  return TrainScheduleCell(
                    schedule: sched,
                    timeOffsetSec: _timeOffsetSec,
                    onTap: () {
                      setState(() {
                        _selectedSchedule = sched;
                        _headerInfo.fromTime = KAIFormatters.formatTimeWithOffset(
                          sched.fromTime,
                          _timeOffsetSec,
                        );
                        _headerInfo.toTime = KAIFormatters.formatTimeWithOffset(
                          sched.toTime,
                          _timeOffsetSec,
                        );
                        _headerInfo.trainNumber = sched.trainNumber;
                        _headerInfo.trainName = sched.trainName;
                        _headerInfo.carNumber = null;
                        _headerInfo.className = null;
                        _headerInfo.seatNumber = null;
                        _headerInfo.price = null;
                        _step = PrototypeStep.seatClassSelection;
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // 4. SeatClassSelectionViewController
  // ==========================================================================
  Widget _buildSeatClassSelectionScreen(DesignSystem ds) {
    final classes = _selectedSchedule?.seatClasses ?? [];
    final trainImg = _selectedSchedule != null
        ? 'assets/images/trains/${_selectedSchedule!.trainImageName}.png'
        : null;

    return Container(
      key: const ValueKey('step-seat-class'),
      color: ds.background,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  SizedBox(
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Transform.translate(
                            offset: const Offset(-10, 0),
                            child: BackButtonControl(onPressed: _popStep),
                          ),
                        ),
                        Text(
                          '${_headerInfo.dayOfWeek}, ${_headerInfo.date}',
                          style: DesignSystem.headline(color: ds.primaryText),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  HeaderRouteInformationView(
                    info: _headerInfo,
                    trainImageAsset: trainImg,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: classes.length,
                itemBuilder: (ctx, idx) {
                  final sc = classes[idx];
                  return SeatClassCell(
                    seatClass: sc,
                    onTap: () {
                      final entity = _seatMap?.seatClassEntities.firstWhere(
                        (e) => e.seatClass == sc.seatClass,
                        orElse: () => _seatMap!.seatClassEntities.first,
                      );
                      setState(() {
                        _selectedSeatClass = sc;
                        _selectedSeatClassEntity = entity;
                        _selectedReservableEntity = null;
                        _badgeVisible = false;
                        _seatMapOverscrollY = 0;
                        _headerInfo.carNumber = entity?.carNumber ?? 'Eks 1';
                        _headerInfo.className = sc.name;
                        _headerInfo.price = KAIFormatters.formatRupiah(sc.price);
                        _headerInfo.seatNumber = null;
                        _step = PrototypeStep.seatMapSelection;
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // 5. SeatMapSelectionViewController (3D Seat Map)
  // ==========================================================================
  Widget _buildSeatMapSelectionScreen(DesignSystem ds) {
    final seatMap = _seatMap;
    final currentEntity = _selectedSeatClassEntity;
    final clampedOverscroll = _seatMapOverscrollY < 0
        ? _seatMapOverscrollY.clamp(-70.0, 0.0)
        : 0.0;

    return Container(
      key: const ValueKey('step-seat-map'),
      color: ds.background,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 44,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Transform.translate(
                                offset: const Offset(-10, 0),
                                child: BackButtonControl(onPressed: _popStep),
                              ),
                            ),
                            Text(
                              '${_headerInfo.dayOfWeek}, ${_headerInfo.date}',
                              style: DesignSystem.headline(
                                color: ds.primaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      HeaderRouteInformationView(
                        info: _headerInfo,
                        rubberBandOffset: clampedOverscroll,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Transform.translate(
                    offset: Offset(0, -clampedOverscroll),
                    child: Container(
                      decoration: BoxDecoration(
                        color: ds.cardBackground,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(DesignSystem.radiusLargeCard),
                        ),
                        boxShadow: DesignSystem.cardNormalShadow,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          if (seatMap != null && currentEntity != null)
                            Positioned.fill(
                              child: SeatMap3DView(
                                key: _seatMapKey,
                                seatMap: seatMap,
                                currentEntity: currentEntity,
                                initialSelectedSeat: _selectedReservableEntity,
                                fromStation: _headerInfo.fromStation,
                                toStation: _headerInfo.toStation,
                                onSeatSelected: (rev) {
                                  setState(() {
                                    _selectedReservableEntity = rev;
                                    _headerInfo.carNumber = rev.carNumber;
                                  });
                                },
                                onOverscrollUpper: (offsetY) {
                                  setState(() {
                                    _seatMapOverscrollY = offsetY;
                                  });
                                },
                                onBadgeUpdate: _updateBadge,
                              ),
                            ),

                          // HeadsUpBadgeControl
                          Positioned(
                            top: 20,
                            left: 20,
                            right: 20,
                            child: Center(
                              child: AnimatedSlide(
                                offset: Offset(0, _badgeVisible ? 0 : -2.2),
                                duration: const Duration(milliseconds: 280),
                                curve: const Cubic(0.2, 0, 0, 1),
                                child: AnimatedOpacity(
                                  opacity: _badgeVisible ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 240),
                                  child: GestureDetector(
                                    onTap: () => _seatMapKey.currentState
                                        ?.scrollToSelectedSeat(),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ds.cardAltBackground,
                                        borderRadius: BorderRadius.circular(
                                          DesignSystem.radiusCard,
                                        ),
                                        boxShadow: DesignSystem.cardNormalShadow,
                                      ),
                                      child: Text(
                                        _badgeMessage,
                                        style: DesignSystem.caption1(
                                          color: ds.secondaryText,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Bottom Call To Action Button
            Positioned(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).padding.bottom + 16,
              child: AppButton(
                title: _selectedReservableEntity != null
                    ? 'Continue with seat ${_selectedReservableEntity!.name}'
                    : 'Please Select a Seat',
                onPressed: _selectedReservableEntity != null
                    ? () {
                        setState(() {
                          _headerInfo.seatNumber =
                              _selectedReservableEntity!.name;
                          _headerInfo.carNumber =
                              _selectedReservableEntity!.carNumber;
                          _step = PrototypeStep.confirmation;
                        });
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // 6. BookingConfirmationViewController (3D Seat Summary Preview)
  // ==========================================================================
  Widget _buildConfirmationScreen(DesignSystem ds) {
    final seatClassType =
        _selectedSeatClassEntity?.seatClass ??
        _selectedSeatClass?.seatClass ??
        'granClass';

    return Container(
      key: const ValueKey('step-confirmation'),
      color: ds.background,
      child: Column(
        children: [
          // Large Top 3D Card (SummaryPreviewView)
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: ds.cardBackground,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(DesignSystem.radiusLargeCard),
                ),
                boxShadow: DesignSystem.cardNormalShadow,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 20,
                      ),
                      child: SummaryPreview3DView(
                        seatClassType: seatClassType,
                      ),
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 4,
                    left: 10,
                    child: BackButtonControl(onPressed: _popStep),
                  ),
                ],
              ),
            ),
          ),

          // Ticket Summary Details & Purchase CTA
          Expanded(
            flex: 4,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  children: [
                    Text(
                      '${_headerInfo.dayOfWeek}, ${_headerInfo.date}',
                      style: DesignSystem.headline(color: ds.primaryText),
                    ),
                    const SizedBox(height: 20),
                    HeaderRouteInformationView(info: _headerInfo),
                    const Spacer(),
                    AppButton(
                      title: 'Purchase this Ticket—${_headerInfo.price ?? ''}',
                      onPressed: () =>
                          _showExitActionSheet(isEndOfPrototype: true),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
