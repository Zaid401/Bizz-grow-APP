import 'package:flutter/material.dart';

const Color _skeletonBase = Color(0xFFEAE5F3);
const Color _skeletonHighlight = Color(0xFFF6F2FC);
const Color _skeletonCard = Color(0xFFFFFFFF);
const Color _skeletonDivider = Color(0xFFE9E2F6);

class NotificationSkeletonList extends StatefulWidget {
  final int itemCount;

  const NotificationSkeletonList({super.key, this.itemCount = 6});

  @override
  State<NotificationSkeletonList> createState() =>
      _NotificationSkeletonListState();
}

class _NotificationSkeletonListState extends State<NotificationSkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: widget.itemCount,
      itemBuilder: (context, index) => _Shimmer(
        animation: _controller,
        base: _skeletonBase,
        highlight: _skeletonHighlight,
        child: _SkeletonCard(showLabel: index == 0 || index == 3),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final bool showLabel;

  const _SkeletonCard({required this.showLabel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 10),
            child: Row(
              children: [
                _SkeletonBox(width: 72, height: 18, radius: 10),
                const SizedBox(width: 8),
                Expanded(child: Container(height: 1, color: _skeletonDivider)),
              ],
            ),
          ),
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _skeletonCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _skeletonDivider),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonBox(width: 46, height: 46, radius: 14),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _SkeletonBox(
                            width: double.infinity,
                            height: 12,
                            radius: 6,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _SkeletonBox(width: 8, height: 8, radius: 4),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _SkeletonBox(width: double.infinity, height: 10, radius: 6),
                    const SizedBox(height: 6),
                    _SkeletonBox(width: 180, height: 10, radius: 6),
                    const SizedBox(height: 10),
                    _SkeletonBox(width: 90, height: 10, radius: 6),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _Shimmer extends StatelessWidget {
  final Animation<double> animation;
  final Color base;
  final Color highlight;
  final Widget child;

  const _Shimmer({
    required this.animation,
    required this.base,
    required this.highlight,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, highlight, base],
              stops: const [0.1, 0.5, 0.9],
              transform: _SlidingGradientTransform(animation.value * 2 - 1),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform(this.slidePercent);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}
