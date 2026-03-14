import 'package:flutter/material.dart';

class SkeletonAnalytics extends StatelessWidget {
  const SkeletonAnalytics({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _card(
          child: Column(
            children: [
              _row([_box(width: 110, height: 12), _box(width: 36, height: 12)]),
              const SizedBox(height: 14),
              _grid(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _box(width: 140, height: 12),
              const SizedBox(height: 12),
              _box(width: 220, height: 12),
              const SizedBox(height: 16),
              _box(width: double.infinity, height: 160),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _box(width: 140, height: 12),
              const SizedBox(height: 12),
              _box(width: 180, height: 12),
              const SizedBox(height: 16),
              _row([
                _box(width: 110, height: 12),
                _box(width: 110, height: 12),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE9E2F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _grid() {
    return LayoutBuilder(
      builder: (_, constraints) {
        final w = (constraints.maxWidth - 14) / 2;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: List.generate(
            4,
            (_) => Container(
              width: w,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE9E2F6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(width: 90, height: 12),
                  const SizedBox(height: 10),
                  _box(width: 70, height: 18),
                  const SizedBox(height: 8),
                  _box(width: 110, height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _row(List<Widget> children) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: children,
    );
  }

  Widget _box({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}
