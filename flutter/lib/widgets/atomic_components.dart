import 'package:flutter/material.dart';
import '../models/booking_models.dart';
import '../theme/design_system.dart';

// ============================================================================
// Button & InitialViewButton (Button.swift & InitialViewButton.swift)
// ============================================================================
enum ButtonVariant { contained, outlined, text, initialContained, initialText }

class AppButton extends StatefulWidget {
  final String title;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final bool expand;

  const AppButton({
    super.key,
    required this.title,
    this.onPressed,
    this.variant = ButtonVariant.contained,
    this.expand = true,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _highlighted = false;

  @override
  Widget build(BuildContext context) {
    final ds = DesignSystem.instance;
    final enabled = widget.onPressed != null;

    Color bgColor;
    Color textColor;
    Border? border;
    EdgeInsets padding;
    double radius = DesignSystem.radiusButton;
    double opacity = 1.0;

    switch (widget.variant) {
      case ButtonVariant.contained:
        bgColor = !enabled
            ? ds.callToActionDisabled
            : _highlighted
                ? ds.callToActionHighlighted
                : ds.callToAction;
        textColor = ds.contentOnCallToAction;
        padding = const EdgeInsets.all(18);
        break;
      case ButtonVariant.outlined:
        bgColor = Colors.transparent;
        final strokeCol = enabled ? ds.callToAction : ds.callToActionDisabled;
        textColor = strokeCol;
        border = Border.all(color: strokeCol, width: 1);
        padding = const EdgeInsets.symmetric(vertical: 8, horizontal: 20);
        radius = 999;
        opacity = _highlighted ? DesignSystem.alphaHighlighted : 1.0;
        break;
      case ButtonVariant.text:
        bgColor = Colors.transparent;
        textColor = enabled ? ds.callToAction : ds.callToActionDisabled;
        padding = const EdgeInsets.all(18);
        opacity = _highlighted ? DesignSystem.alphaHighlighted : 1.0;
        break;
      case ButtonVariant.initialContained:
        bgColor = _highlighted
            ? DesignSystem.accentLight
            : DesignSystem.basicWhite;
        textColor = DesignSystem.accentMain;
        padding = const EdgeInsets.all(18);
        break;
      case ButtonVariant.initialText:
        bgColor = Colors.transparent;
        textColor = DesignSystem.basicWhite;
        padding = const EdgeInsets.all(12);
        opacity = _highlighted ? DesignSystem.alphaHighlighted : 1.0;
        break;
    }

    final textStyle = widget.variant == ButtonVariant.outlined
        ? DesignSystem.outlinedButton(color: textColor)
        : DesignSystem.button(color: textColor);

    final child = AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: opacity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: const Cubic(0.2, 0, 0, 1),
        width: widget.expand ? double.infinity : null,
        padding: padding,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(radius),
          border: border,
        ),
        alignment: Alignment.center,
        child: Text(
          widget.title,
          style: textStyle,
          textAlign: TextAlign.center,
        ),
      ),
    );

    if (!enabled) return child;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _highlighted = true),
      onTapUp: (_) {
        setState(() => _highlighted = false);
        widget.onPressed?.call();
      },
      onTapCancel: () => setState(() => _highlighted = false),
      child: child,
    );
  }
}

// ============================================================================
// CardControl (CardControl.swift)
// ============================================================================
enum CardType { regular, regularAlternative, large }

class CardControl extends StatefulWidget {
  final Widget child;
  final CardType type;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final bool enabled;

  const CardControl({
    super.key,
    required this.child,
    this.type = CardType.regular,
    this.onTap,
    this.padding,
    this.enabled = true,
  });

  @override
  State<CardControl> createState() => _CardControlState();
}

class _CardControlState extends State<CardControl> {
  bool _highlighted = false;

  @override
  Widget build(BuildContext context) {
    final ds = DesignSystem.instance;
    final radius = widget.type == CardType.large
        ? DesignSystem.radiusLargeCard
        : DesignSystem.radiusCard;
    final defaultPad = widget.type == CardType.large
        ? const EdgeInsets.symmetric(vertical: 20, horizontal: 16)
        : const EdgeInsets.symmetric(vertical: 12, horizontal: 16);

    final bgColor = !widget.enabled
        ? ds.cardDisabledBackground
        : widget.type == CardType.regularAlternative
            ? ds.cardAltBackground
            : ds.cardBackground;

    final shadows = !widget.enabled
        ? DesignSystem.cardDisabledShadow
        : _highlighted
            ? DesignSystem.cardHighlightedShadow
            : DesignSystem.cardNormalShadow;

    final card = AnimatedScale(
      scale: _highlighted ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: const Cubic(0.2, 0, 0, 1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: const Cubic(0.2, 0, 0, 1),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: shadows,
        ),
        clipBehavior: Clip.antiAlias,
        padding: widget.padding ?? defaultPad,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _highlighted ? DesignSystem.alphaHighlighted : 1.0,
          child: widget.child,
        ),
      ),
    );

    if (widget.onTap == null || !widget.enabled) return card;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _highlighted = true),
      onTapUp: (_) {
        setState(() => _highlighted = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _highlighted = false),
      child: card,
    );
  }
}

// ============================================================================
// SegmentedControl & SegmentedItemControl (SegmentedControl.swift)
// ============================================================================
class SegmentedItemData {
  final String title;
  final String subtitle;
  final bool isEnabled;

  const SegmentedItemData({
    required this.title,
    required this.subtitle,
    this.isEnabled = true,
  });
}

class AppSegmentedControl extends StatelessWidget {
  final List<SegmentedItemData> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const AppSegmentedControl({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ds = DesignSystem.instance;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: ds.cardDisabledBackground,
        borderRadius: BorderRadius.circular(DesignSystem.radiusSegmentedControl),
        boxShadow: DesignSystem.cardDisabledShadow,
      ),
      child: Row(
        children: List.generate(items.length, (idx) {
          final item = items[idx];
          final isSelected = idx == selectedIndex && item.isEnabled;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: idx == 0 ? 0 : DesignSystem.cardGutter * 0.5,
                right: idx == items.length - 1 ? 0 : DesignSystem.cardGutter * 0.5,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: item.isEnabled ? () => onChanged(idx) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: const Cubic(0.2, 0, 0, 1),
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? ds.cardBackground : Colors.transparent,
                    borderRadius: BorderRadius.circular(
                      DesignSystem.radiusSegmentedItem,
                    ),
                    boxShadow:
                        isSelected ? DesignSystem.cardNormalShadow : const [],
                  ),
                  child: Center(
                    child: isSelected
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DesignSystem.headline(
                                  color: ds.callToAction,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DesignSystem.caption2(
                                  color: ds.secondaryText,
                                ),
                              ),
                            ],
                          )
                        : Transform.scale(
                            scale: 0.88,
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DesignSystem.headline(
                                color: ds.secondaryText,
                              ).copyWith(
                                decoration: item.isEnabled
                                    ? TextDecoration.none
                                    : TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ============================================================================
// BackButtonControl (BackButtonControl.swift)
// ============================================================================
class BackButtonControl extends StatefulWidget {
  final VoidCallback onPressed;

  const BackButtonControl({super.key, required this.onPressed});

  @override
  State<BackButtonControl> createState() => _BackButtonControlState();
}

class _BackButtonControlState extends State<BackButtonControl> {
  bool _highlighted = false;

  @override
  Widget build(BuildContext context) {
    final ds = DesignSystem.instance;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _highlighted = true),
      onTapUp: (_) {
        setState(() => _highlighted = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _highlighted = false),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: AnimatedSlide(
            offset: Offset(_highlighted ? 0.2 : 0, 0),
            duration: const Duration(milliseconds: 125),
            child: AnimatedOpacity(
              opacity: _highlighted ? DesignSystem.alphaHighlighted : 1.0,
              duration: const Duration(milliseconds: 125),
              child: CustomPaint(
                size: const Size(24, 24),
                painter: _BackArrowPainter(
                  color: ds.callToAction,
                  pulledBack: _highlighted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackArrowPainter extends CustomPainter {
  final Color color;
  final bool pulledBack;

  _BackArrowPainter({required this.color, required this.pulledBack});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    if (pulledBack) {
      path.moveTo(8, 12);
      path.lineTo(20, 12);
      path.moveTo(12, 4);
      path.lineTo(8, 12);
      path.lineTo(12, 20);
    } else {
      path.moveTo(4, 12);
      path.lineTo(20, 12);
      path.moveTo(10, 6);
      path.lineTo(4, 12);
      path.lineTo(10, 18);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BackArrowPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.pulledBack != pulledBack;
  }
}

// ============================================================================
// SeatClassIconView (SeatClassIconImageView.swift)
// ============================================================================
class SeatClassIconView extends StatelessWidget {
  final String seatClass;
  final double size;
  final bool isAvailable;

  const SeatClassIconView({
    super.key,
    required this.seatClass,
    this.size = 16.0,
    this.isAvailable = true,
  });

  String get _iconAsset {
    if (seatClass == 'granClass') {
      return 'assets/images/icons/icon_gran.png';
    } else if (seatClass == 'ordinary' || seatClass == 'ekonomiTosca') {
      return 'assets/images/icons/icon_ordinary.png';
    } else {
      return 'assets/images/icons/icon_green_car.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ds = DesignSystem.instance;
    final tint = isAvailable
        ? ds.seatClassColor(seatClass)
        : ds.callToActionDisabled;
    return Opacity(
      opacity: isAvailable ? 1.0 : DesignSystem.alphaDisabled,
      child: Image.asset(
        _iconAsset,
        width: size,
        height: size,
        color: tint,
        colorBlendMode: BlendMode.srcIn,
      ),
    );
  }
}

// ============================================================================
// HeaderRouteInformationView (HeaderRouteInformationView.swift)
// ============================================================================
class HeaderRouteInformationView extends StatelessWidget {
  final BookingHeaderInformation info;
  final String? trainImageAsset;
  final double rubberBandOffset;

  const HeaderRouteInformationView({
    super.key,
    required this.info,
    this.trainImageAsset,
    this.rubberBandOffset = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final ds = DesignSystem.instance;
    final hasTimes = info.fromTime != null || info.toTime != null;
    final hasDesc = info.trainNumber != null ||
        info.trainName != null ||
        info.carNumber != null ||
        info.className != null ||
        info.seatNumber != null ||
        info.price != null;

    final pullY = rubberBandOffset < 0 ? -rubberBandOffset : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // StationPairView
        Transform.translate(
          offset: Offset(0, pullY * 0.25),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.fromStation,
                    style: DesignSystem.largeTitle(color: ds.primaryText),
                  ),
                  if (hasTimes) ...[
                    const SizedBox(height: 2),
                    Text(
                      info.fromTime ?? '',
                      style: DesignSystem.subheadline(color: ds.primaryText),
                    ),
                  ],
                ],
              ),
              Text(
                'to',
                style: DesignSystem.subheadline(color: ds.secondaryText),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    info.toStation,
                    style: DesignSystem.largeTitle(color: ds.primaryText),
                  ),
                  if (hasTimes) ...[
                    const SizedBox(height: 2),
                    Text(
                      info.toTime ?? '',
                      style: DesignSystem.subheadline(color: ds.primaryText),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (hasDesc) ...[
          const SizedBox(height: 20),
          Transform.translate(
            offset: Offset(0, pullY * 0.65),
            child: trainImageAsset != null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            info.trainNumber ?? '',
                            style: DesignSystem.headline(color: ds.primaryText),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            info.trainName ?? '',
                            style: DesignSystem.caption1(color: ds.secondaryText),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: Image.asset(
                            trainImageAsset!,
                            height: 36,
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomLeft,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            info.trainNumber ?? '',
                            style: DesignSystem.headline(color: ds.primaryText),
                          ),
                          if (info.carNumber != null)
                            Text(
                              info.carNumber!,
                              style: DesignSystem.headline(color: ds.primaryText),
                            ),
                          if (info.seatNumber != null)
                            Text(
                              info.seatNumber!,
                              style: DesignSystem.headline(color: ds.primaryText),
                            ),
                          if (info.price != null)
                            Text(
                              info.price!,
                              style: DesignSystem.headline(color: ds.primaryText),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              info.trainName ?? '',
                              style: DesignSystem.caption1(color: ds.secondaryText),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (info.className != null) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                info.className!,
                                style: DesignSystem.caption1(color: ds.secondaryText),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          const SizedBox(width: 48),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ],
    );
  }
}

// ============================================================================
// TrainScheduleTableViewCell & SeatClassTableViewCell
// ============================================================================
class TrainScheduleCell extends StatelessWidget {
  final TrainScheduleModel schedule;
  final int timeOffsetSec;
  final VoidCallback onTap;

  const TrainScheduleCell({
    super.key,
    required this.schedule,
    required this.timeOffsetSec,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ds = DesignSystem.instance;
    final fromStr =
        KAIFormatters.formatTimeWithOffset(schedule.fromTime, timeOffsetSec);
    final toStr =
        KAIFormatters.formatTimeWithOffset(schedule.toTime, timeOffsetSec);
    final durStr = KAIFormatters.formatDurationOffset(
      schedule.fromTime,
      schedule.toTime,
    );

    final prices = schedule.seatClasses.map((e) => e.price).toList();
    prices.sort();
    final cheapestStr = prices.isNotEmpty
        ? 'from ${KAIFormatters.formatRupiah(prices.first)}'
        : '-';

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: CardControl(
        onTap: onTap,
        padding: EdgeInsets.zero,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$fromStr – $toStr',
                            style: DesignSystem.headline(color: ds.primaryText),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            durStr,
                            style: DesignSystem.caption2(
                              color: ds.secondaryText,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            schedule.trainNumber,
                            style: DesignSystem.caption1(color: ds.primaryText),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            schedule.trainName,
                            style: DesignSystem.caption2(
                              color: ds.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 6,
                    children: schedule.seatClasses
                        .take(5)
                        .map(
                          (sc) => SeatClassIconView(
                            seatClass: sc.seatClass,
                            size: 16,
                            isAvailable: sc.isAvailable,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cheapestStr,
                    style: DesignSystem.caption2(color: ds.secondaryText),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 145,
              bottom: 10,
              child: IgnorePointer(
                child: Image.asset(
                  'assets/images/trains/${schedule.trainImageName}.png',
                  height: 42,
                  width: 252,
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomLeft,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SeatClassCell extends StatelessWidget {
  final SeatClassModel seatClass;
  final VoidCallback onTap;

  const SeatClassCell({
    super.key,
    required this.seatClass,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ds = DesignSystem.instance;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: CardControl(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 10),
              child: SeatClassIconView(
                seatClass: seatClass.seatClass,
                size: 24,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    seatClass.name,
                    style: DesignSystem.headline(color: ds.primaryText),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    KAIFormatters.formatRupiah(seatClass.price),
                    style: DesignSystem.caption2(color: ds.secondaryText),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    seatClass.description,
                    style: DesignSystem.caption1(color: ds.secondaryText),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Image.asset(
              seatClass.imageAsset,
              height: 92,
              width: 74,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }
}
