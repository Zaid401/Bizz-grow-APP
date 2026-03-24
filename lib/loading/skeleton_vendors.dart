import 'package:flutter/material.dart';

enum SkeletonVendorsTab { vendors, purchases, payments }

class SkeletonVendors extends StatelessWidget {
  const SkeletonVendors({super.key, required this.tab});

  final SkeletonVendorsTab tab;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (tab == SkeletonVendorsTab.vendors)
          _vendorsList()
        else if (tab == SkeletonVendorsTab.purchases)
          _purchasesList()
        else
          _paymentsList(),
      ],
    );
  }

  Widget _vendorsList() {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _card(
            child: Row(
              children: [
                _box(width: 52, height: 52, radius: 14),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _box(width: 140, height: 12),
                      const SizedBox(height: 8),
                      _box(width: 90, height: 10),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _box(width: 70, height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _purchasesList() {
    return Column(
      children: List.generate(
        2,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row([
                  _box(width: 120, height: 12),
                  _box(width: 60, height: 12),
                ]),
                const SizedBox(height: 10),
                _box(width: 170, height: 10),
                const SizedBox(height: 12),
                _row([
                  _box(width: 90, height: 22, radius: 999),
                  _box(width: 90, height: 22, radius: 999),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _paymentsList() {
    return Column(
      children: List.generate(
        2,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row([
                  _box(width: 120, height: 12),
                  _box(width: 70, height: 12),
                ]),
                const SizedBox(height: 10),
                _box(width: 150, height: 10),
                const SizedBox(height: 12),
                _row([
                  _box(width: 90, height: 22, radius: 999),
                  _box(width: 70, height: 22, radius: 999),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9E2F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
}
