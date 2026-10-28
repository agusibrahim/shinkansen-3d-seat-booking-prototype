import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../engine/kai_3d_engine.dart';
import '../models/booking_models.dart';
import '../theme/design_system.dart';
import '../widgets/atomic_components.dart';

class DesignSystemModal extends StatefulWidget {
  final VoidCallback onClose;

  const DesignSystemModal({super.key, required this.onClose});

  @override
  State<DesignSystemModal> createState() => _DesignSystemModalState();
}

class _DesignSystemModalState extends State<DesignSystemModal> {
  int _selectedTab = 0;
  int _demoSegmentedIdx = 0;
  String _layerState = 'normal';
  String _model3DState = 'normal';
  int _model3DIndex = 0;

  static const List<(String, String)> _models3D = [
    ('_kai_maroon_seat_complete', 'kai-eksekutif-next-gen-maroon'),
    ('_kai_eks_dualtone_seat_complete', 'kai-eksekutif-new-image-dualtone'),
    ('_kai_blue_seat_complete', 'kai-ekonomi-new-gen-biru'),
    ('_kai_blue_dualtone_seat_complete', 'kai-ekonomi-new-gen-dualtone-biru-tan'),
    ('_kai_prem_seat_complete', 'kai-ekonomi-premium-tan'),
    ('_kai_tosca_seat_complete', 'kai-ekonomi-modifikasi-tosca-2-3'),
    ('_e7_ordinary_seat_complete', 'kai-ekonomi-reguler-krem-2-3'),
  ];

  @override
  Widget build(BuildContext context) {
    final ds = DesignSystem.instance;
    final titles = [
      'Components',
      'Colors',
      'Text Styles',
      'Layer Styles',
      '3D Assets'
    ];

    return Container(
      color: ds.background,
      child: SafeArea(
        bottom: true,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 68, 8),
                  child: Text(
                    titles[_selectedTab],
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: ds.primaryText,
                    ),
                  ),
                ),
                Expanded(
                  child: _buildTabContent(ds),
                ),
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: ds.secondaryText.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(titles.length, (idx) {
                      final active = idx == _selectedTab;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _selectedTab = idx),
                        child: Opacity(
                          opacity: active ? 1.0 : 0.33,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              titles[idx],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: ds.callToAction,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 16,
              right: 20,
              child: GestureDetector(
                onTap: widget.onClose,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Image.asset(
                      'assets/images/icons/symbol-close-button.png',
                      width: 22,
                      height: 22,
                      color: ds.primaryText,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlock(String header, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            header,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFFAAAAAA),
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _buildTabContent(DesignSystem ds) {
    switch (_selectedTab) {
      case 0:
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _buildBlock(
              'Contained Button',
              Center(
                child: AppButton(
                  title: 'Lorem Ipsum',
                  expand: false,
                  onPressed: () {},
                ),
              ),
            ),
            _buildBlock(
              'Outlined Button',
              Center(
                child: AppButton(
                  title: 'Lorem Ipsum',
                  variant: ButtonVariant.outlined,
                  expand: false,
                  onPressed: () {},
                ),
              ),
            ),
            _buildBlock(
              'Card',
              CardControl(
                onTap: () {},
                child: const SizedBox(height: 88, width: double.infinity),
              ),
            ),
            _buildBlock(
              'Large Card',
              CardControl(
                type: CardType.large,
                onTap: () {},
                child: const SizedBox(height: 88, width: double.infinity),
              ),
            ),
            _buildBlock(
              'Segmented Card Control',
              AppSegmentedControl(
                items: const [
                  SegmentedItemData(title: 'Item 1', subtitle: 'Lorem Ipsum'),
                  SegmentedItemData(title: 'Item 2', subtitle: 'Lorem Ipsum'),
                  SegmentedItemData(title: 'Item 3', subtitle: 'Lorem Ipsum'),
                ],
                selectedIndex: _demoSegmentedIdx,
                onChanged: (i) => setState(() => _demoSegmentedIdx = i),
              ),
            ),
            _buildBlock(
              'Header Route Information View',
              HeaderRouteInformationView(
                info: BookingHeaderInformation(
                  dayOfWeek: 'Wednesday',
                  date: 'October 21, 2026',
                  fromStation: 'Gambir',
                  fromTime: '08:20',
                  toStation: 'Surabaya',
                  toTime: '18:55',
                  trainNumber: 'Argo Bromo 2',
                  trainName: 'Next Gen Stainless',
                  carNumber: 'Eks 1',
                  className: 'Eksekutif',
                  seatNumber: '6C',
                  price: 'Rp 650.000',
                ),
              ),
            ),
          ],
        );
      case 1:
        final colors = [
          ('Accent Main', DesignSystem.accentMain),
          ('Accent Dark', DesignSystem.accentDark),
          ('Accent Light', DesignSystem.accentLight),
          ('Basic Black', DesignSystem.basicBlack),
          ('Basic Off Black', DesignSystem.basicOffBlack),
          ('Basic Gray', DesignSystem.basicGray),
          ('Basic Off White', DesignSystem.basicOffWhite),
          ('Basic White', DesignSystem.basicWhite),
        ];
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: colors
              .map(
                (c) => _buildBlock(
                  c.$1,
                  Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: c.$2,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.black, width: 0.5),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      case 2:
        const dummy =
            'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.';
        final styles = [
          ('Large Title', DesignSystem.largeTitle(color: ds.primaryText)),
          ('Headline', DesignSystem.headline(color: ds.primaryText)),
          ('Subheadline', DesignSystem.subheadline(color: ds.primaryText)),
          ('Body', DesignSystem.body(color: ds.primaryText)),
          ('Button', DesignSystem.button(color: ds.primaryText)),
          ('Outlined Button', DesignSystem.outlinedButton(color: ds.primaryText)),
          ('Footnote', DesignSystem.footnote(color: ds.primaryText)),
          ('Caption 1', DesignSystem.caption1(color: ds.primaryText)),
          ('Caption 2', DesignSystem.caption2(color: ds.primaryText)),
        ];
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: styles
              .map((s) => _buildBlock(s.$1, Text(dummy, style: s.$2)))
              .toList(),
        );
      case 3:
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _buildBlock(
                    'Contained Button',
                    Container(
                      height: 96,
                      decoration: BoxDecoration(
                        color: _layerState == 'highlighted'
                            ? ds.callToActionHighlighted
                            : _layerState == 'disabled'
                                ? ds.callToActionDisabled
                                : ds.callToAction,
                        borderRadius: BorderRadius.circular(
                          DesignSystem.radiusButton,
                        ),
                      ),
                    ),
                  ),
                  _buildBlock(
                    'Outlined Button',
                    Opacity(
                      opacity: _layerState == 'highlighted'
                          ? DesignSystem.alphaHighlighted
                          : 1.0,
                      child: Container(
                        height: 96,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _layerState == 'disabled'
                                ? ds.callToActionDisabled
                                : ds.callToAction,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _buildBlock(
                    'Card',
                    Container(
                      height: 96,
                      decoration: BoxDecoration(
                        color: _layerState == 'disabled'
                            ? ds.cardDisabledBackground
                            : ds.cardBackground,
                        borderRadius: BorderRadius.circular(
                          DesignSystem.radiusCard,
                        ),
                        boxShadow: _layerState == 'highlighted'
                            ? DesignSystem.cardHighlightedShadow
                            : _layerState == 'disabled'
                                ? DesignSystem.cardDisabledShadow
                                : DesignSystem.cardNormalShadow,
                      ),
                    ),
                  ),
                  _buildBlock(
                    'Large Card',
                    Container(
                      height: 96,
                      decoration: BoxDecoration(
                        color: _layerState == 'disabled'
                            ? ds.cardDisabledBackground
                            : ds.cardBackground,
                        borderRadius: BorderRadius.circular(
                          DesignSystem.radiusLargeCard,
                        ),
                        boxShadow: _layerState == 'highlighted'
                            ? DesignSystem.cardHighlightedShadow
                            : _layerState == 'disabled'
                                ? DesignSystem.cardDisabledShadow
                                : DesignSystem.cardNormalShadow,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSegmentedControl<String>(
                  groupValue: _layerState,
                  selectedColor: ds.callToAction,
                  borderColor: ds.callToAction,
                  unselectedColor: Colors.transparent,
                  children: const {
                    'normal': Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('Normal', style: TextStyle(fontSize: 13)),
                    ),
                    'highlighted': Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('Highlighted', style: TextStyle(fontSize: 13)),
                    ),
                    'disabled': Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('Disabled', style: TextStyle(fontSize: 13)),
                    ),
                  },
                  onValueChanged: (v) => setState(() => _layerState = v),
                ),
              ),
            ),
          ],
        );
      case 4:
      default:
        final current3D = _models3D[_model3DIndex];
        return Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DesignSystem3DAssetView(
                      modelName: current3D.$1,
                      stateName: _model3DState,
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AppButton(
                          title: '←',
                          variant: ButtonVariant.outlined,
                          expand: false,
                          onPressed: () {
                            setState(() {
                              _model3DIndex = (_model3DIndex - 1 + _models3D.length) %
                                  _models3D.length;
                            });
                          },
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              current3D.$2,
                              textAlign: TextAlign.center,
                              style: DesignSystem.caption1(
                                color: ds.primaryText,
                              ),
                            ),
                          ),
                        ),
                        AppButton(
                          title: '→',
                          variant: ButtonVariant.outlined,
                          expand: false,
                          onPressed: () {
                            setState(() {
                              _model3DIndex =
                                  (_model3DIndex + 1) % _models3D.length;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSegmentedControl<String>(
                  groupValue: _model3DState,
                  selectedColor: ds.callToAction,
                  borderColor: ds.callToAction,
                  unselectedColor: Colors.transparent,
                  children: const {
                    'normal': Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('Normal', style: TextStyle(fontSize: 12)),
                    ),
                    'highlighted': Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('Highlighted', style: TextStyle(fontSize: 12)),
                    ),
                    'selected': Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('Selected', style: TextStyle(fontSize: 12)),
                    ),
                    'disabled': Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('Disabled', style: TextStyle(fontSize: 12)),
                    ),
                  },
                  onValueChanged: (v) => setState(() => _model3DState = v),
                ),
              ),
            ),
          ],
        );
    }
  }
}
