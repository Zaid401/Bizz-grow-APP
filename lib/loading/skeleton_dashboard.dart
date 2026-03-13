import 'package:flutter/material.dart';

class SkeletonDashboard extends StatelessWidget {
  const SkeletonDashboard({super.key});

  static const Color _bg = Color(0xFFF2EEF9);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _divider = Color(0xFFE9E2F6);
  static const Color _skeleton = Color(0xFFEDE9FE);

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _sectionHeader(),
              const SizedBox(height: 12),
              _card(height: 150),
              const SizedBox(height: 20),
              _sectionHeader(),
              const SizedBox(height: 12),
              _statsGrid(),
              const SizedBox(height: 20),
              _sectionHeader(),
              const SizedBox(height: 12),
              _card(height: 170),
              const SizedBox(height: 20),
              _sectionHeader(),
              const SizedBox(height: 12),
              _card(height: 220),
              const SizedBox(height: 20),
              _sectionHeader(),
              const SizedBox(height: 12),
              _card(height: 200),
              const SizedBox(height: 20),
              _sectionHeader(),
              const SizedBox(height: 12),
              _statsGrid(),
              const SizedBox(height: 20),
              _sectionHeader(),
              const SizedBox(height: 12),
              _card(height: 160),
              const SizedBox(height: 20),
              _sectionHeader(),
              const SizedBox(height: 12),
              _card(height: 220),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader() {
    return Row(
      children: [
        _box(width: 28, height: 28, radius: 9),
        const SizedBox(width: 10),
        Expanded(child: _line(widthFactor: 0.35)),
        const SizedBox(width: 12),
        Expanded(child: _line(widthFactor: 0.55, height: 1)),
      ],
    );
  }

  Widget _statsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(
            4,
            (_) => SizedBox(width: w, child: _card(height: 92, compact: true)),
          ),
        );
      },
    );
  }

  Widget _card({required double height, bool compact = false}) {
    final padding = compact ? 12.0 : 16.0;
    final box = compact ? 32.0 : 44.0;
    final gap1 = compact ? 8.0 : 12.0;
    final gap2 = compact ? 6.0 : 8.0;
    final line1 = compact ? 10.0 : 12.0;
    final line2 = compact ? 8.0 : 12.0;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _divider),
      ),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _box(width: box, height: box, radius: 12),
            SizedBox(height: gap1),
            _line(widthFactor: 0.55, height: line1),
            SizedBox(height: gap2),
            _line(widthFactor: 0.35, height: line2),
          ],
        ),
      ),
    );
  }

  Widget _line({double widthFactor = 1, double height = 12}) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: _box(height: height, radius: 8),
    );
  }

  Widget _box({double? width, required double height, double radius = 10}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _skeleton,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
