import 'package:flutter/material.dart';

class SkeletonOrder extends StatelessWidget {
  const SkeletonOrder({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row([
                  _pill(width: 78),
                  _pill(width: 84),
                  _pill(width: 74),
                  _box(width: 50, height: 10),
                ]),
                const SizedBox(height: 12),
                _row([
                  _box(width: 36, height: 36, radius: 12),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _box(width: 140, height: 12),
                        const SizedBox(height: 6),
                        _box(width: 120, height: 10),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _box(width: 60, height: 14),
                ]),
                const SizedBox(height: 12),
                _row([
                  _pill(width: 54),
                  _pill(width: 54),
                  _box(width: 70, height: 26, radius: 10),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(18),
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

  Widget _row(List<Widget> children) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: children,
    );
  }

  Widget _box({
    required double width,
    required double height,
    double radius = 10,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _pill({required double width}) {
    return Container(
      width: width,
      height: 22,
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
