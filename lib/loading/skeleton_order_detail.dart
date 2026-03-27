import 'package:flutter/material.dart';

const Color _skeletonBase = Color(0xFFEAE5F3);
const Color _skeletonHighlight = Color(0xFFF6F2FC);
const Color _skeletonCard = Color(0xFFFFFFFF);
const Color _skeletonDivider = Color(0xFFE9E2F6);

class OrderDetailSkeleton extends StatefulWidget {
  const OrderDetailSkeleton({super.key});

  @override
  State<OrderDetailSkeleton> createState() => _OrderDetailSkeletonState();
}

class _OrderDetailSkeletonState extends State<OrderDetailSkeleton>
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
      children: [
        _Shimmer(
          animation: _controller,
          base: _skeletonBase,
          highlight: _skeletonHighlight,
          child: _buildHeader(),
        ),
        const SizedBox(height: 16),
        _Shimmer(
          animation: _controller,
          base: _skeletonBase,
          highlight: _skeletonHighlight,
          child: _buildChipRow(),
        ),
        const SizedBox(height: 18),
        _Shimmer(
          animation: _controller,
          base: _skeletonBase,
          highlight: _skeletonHighlight,
          child: _buildCard(height: 96),
        ),
        const SizedBox(height: 18),
        _Shimmer(
          animation: _controller,
          base: _skeletonBase,
          highlight: _skeletonHighlight,
          child: _buildCard(height: 170),
        ),
        const SizedBox(height: 18),
        _Shimmer(
          animation: _controller,
          base: _skeletonBase,
          highlight: _skeletonHighlight,
          child: _buildCard(height: 140),
        ),
        const SizedBox(height: 18),
        _Shimmer(
          animation: _controller,
          base: _skeletonBase,
          highlight: _skeletonHighlight,
          child: _buildCard(height: 110),
        ),
        const SizedBox(height: 18),
        _Shimmer(
          animation: _controller,
          base: _skeletonBase,
          highlight: _skeletonHighlight,
          child: _buildCard(height: 120),
        ),
        const SizedBox(height: 18),
        _Shimmer(
          animation: _controller,
          base: _skeletonBase,
          highlight: _skeletonHighlight,
          child: _buildFooterButton(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        _SkeletonBox(width: 36, height: 36, radius: 10),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _SkeletonBox(width: 140, height: 12, radius: 6),
              SizedBox(height: 6),
              _SkeletonBox(width: 90, height: 10, radius: 6),
            ],
          ),
        ),
        _SkeletonBox(width: 70, height: 22, radius: 12),
      ],
    );
  }

  Widget _buildChipRow() {
    return Row(
      children: const [
        _SkeletonBox(width: 80, height: 24, radius: 16),
        SizedBox(width: 8),
        _SkeletonBox(width: 90, height: 24, radius: 16),
        SizedBox(width: 8),
        _SkeletonBox(width: 80, height: 24, radius: 16),
      ],
    );
  }

  Widget _buildCard({required double height}) {
    return Container(
      height: height,
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
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonBox(width: 160, height: 12, radius: 6),
            SizedBox(height: 10),
            _SkeletonBox(width: double.infinity, height: 10, radius: 6),
            SizedBox(height: 6),
            _SkeletonBox(width: 220, height: 10, radius: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterButton() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: _skeletonCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _skeletonDivider),
      ),
      child: const Center(
        child: _SkeletonBox(width: 160, height: 12, radius: 6),
      ),
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
