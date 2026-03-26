import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _client = Supabase.instance.client;

  final _storeCtrl = TextEditingController();
  final _ownerCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  late final PageController _pageController;
  Timer? _timer;
  int _carouselIndex = 0;

  int _step = 0;
  bool _sameWhatsapp = true;
  String? _state;
  String? _category;
  String? _businessMode;
  String? _plan;
  bool _submitting = false;

  final List<_Feature> _features = const [
    _Feature(
      icon: Icons.analytics_rounded,
      title: 'Smart Analytics',
      text: 'Track sales, bestsellers, and customer insights.',
    ),
    _Feature(
      icon: Icons.inventory_2_rounded,
      title: 'Inventory Management',
      text: 'Manage stock and products easily.',
    ),
    _Feature(
      icon: Icons.storefront_rounded,
      title: 'Online Store',
      text: 'Launch your store in minutes.',
    ),
    _Feature(
      icon: Icons.payments_rounded,
      title: 'Digital Payments',
      text: 'Accept UPI, cards and wallets.',
    ),
  ];

  final List<_CategoryOption> _categories = const [
    _CategoryOption('Kirana Store', 'kirana-store', Icons.local_grocery_store),
    _CategoryOption('Bakery', 'bakery', Icons.bakery_dining),
    _CategoryOption('Dairy Shop', 'dairy-farm', Icons.icecream),
    _CategoryOption('Clothing', 'clothing', Icons.checkroom),
    _CategoryOption('Cosmetics', 'cosmetics', Icons.brush),
    _CategoryOption('Electronics', 'electronics', Icons.devices_other),
    _CategoryOption('Fruits & Veggies', 'fruits', Icons.emoji_food_beverage),
    _CategoryOption('Electrical', 'electrical', Icons.electrical_services),
    _CategoryOption('Pharmacy', 'pharmacy', Icons.local_hospital),
    _CategoryOption('Stationery', 'stationery', Icons.edit_note),
    _CategoryOption('Hardware', 'hardware', Icons.handyman),
    _CategoryOption('Other', 'other', Icons.widgets),
  ];

  // Unique color per category for a vibrant grid
  final List<Color> _categoryColors = const [
    Color(0xFF16A34A),
    Color(0xFFF59E0B),
    Color(0xFF0EA5E9),
    Color(0xFFEC4899),
    Color(0xFFD946EF),
    Color(0xFF6366F1),
    Color(0xFF22C55E),
    Color(0xFFF97316),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFF64748B),
    Color(0xFF7C3AED),
  ];

  final List<String> _states = const [
    'Andhra Pradesh',
    'Assam',
    'Bihar',
    'Delhi',
    'Gujarat',
    'Karnataka',
    'Madhya Pradesh',
    'Maharashtra',
    'Rajasthan',
    'Tamil Nadu',
    'Telangana',
    'Uttar Pradesh',
    'West Bengal',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.86,
      initialPage: _features.length * 1000,
    );
    _carouselIndex = _pageController.initialPage % _features.length;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_pageController.hasClients) return;
      final next = _pageController.page!.round() + 1;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _storeCtrl.dispose();
    _ownerCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  // ─── Logic (unchanged) ────────────────────────────────────────────────────

  Future<void> _createStore() async {
    if (_submitting) return;
    final user = _client.auth.currentUser;
    if (user == null) {
      _showSnack('Please sign in to create a store.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final now = DateTime.now();
      final payload = {
        'user_id': user.id,
        'name': _storeCtrl.text.trim(),
        'category': _category,
        'business_mode': _businessMode,
        'state': _state,
        'city': _cityCtrl.text.trim(),
        'address': _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        'is_active': true,
        'subscription_status': 'trial',
        'trial_ends_at': now.add(const Duration(days: 14)).toIso8601String(),
      };
      final inserted = await _client
          .from('stores')
          .insert(payload)
          .select('id')
          .single();
      final storeId = inserted['id']?.toString();
      if (storeId != null) {
        await _client.auth.updateUser(
          UserAttributes(data: {'store_id': storeId}),
        );
      }
      if (!mounted) return;
      _showSnack('Store created successfully.');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to create store. ${e.toString()}');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  void _nextStep() {
    final ok = _validateStep();
    if (!ok) return;
    if (_step < 5) {
      setState(() => _step += 1);
    } else {
      _createStore();
    }
  }

  bool _validateStep() {
    switch (_step) {
      case 0:
        if (_storeCtrl.text.trim().isEmpty) {
          _showSnack('Enter store name.');
          return false;
        }
        if (_ownerCtrl.text.trim().isEmpty) {
          _showSnack('Enter your name.');
          return false;
        }
        final phone = _phoneCtrl.text.replaceAll(RegExp(r'\s+'), '');
        if (phone.isEmpty || phone.length < 10) {
          _showSnack('Enter valid 10 digit mobile number.');
          return false;
        }
        return true;
      case 1:
        if (_state == null || _state!.isEmpty) {
          _showSnack('Select state.');
          return false;
        }
        if (_cityCtrl.text.trim().isEmpty) {
          _showSnack('Enter city or town.');
          return false;
        }
        return true;
      case 2:
        if (_category == null) {
          _showSnack('Select a category.');
          return false;
        }
        return true;
      case 3:
        if (_businessMode == null) {
          _showSnack('Select delivery mode.');
          return false;
        }
        return true;
      case 4:
        if (_plan == null) {
          _showSnack('Select a plan.');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildStepper(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: _buildStepBody(),
              ),
            ),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  // ─── Top Bar ──────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: [
          // Back / close button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _C.divider),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                size: 18,
                color: _C.textPrimary,
              ),
            ),
          ),
          const Spacer(),
          // Brand logo + name
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_C.gradStart, _C.gradEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'BizGrow 360',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _C.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(width: 40), // balance
        ],
      ),
    );
  }

  // ─── Modern Stepper ───────────────────────────────────────────────────────

  Widget _buildStepper() {
    final stepLabels = [
      'Details',
      'Location',
      'Category',
      'Delivery',
      'Plan',
      'Account',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        children: [
          // Animated progress track
          Stack(
            children: [
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: _C.stepIdle,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                height: 5,
                width:
                    (MediaQuery.of(context).size.width - 40) *
                    ((_step + 1) / 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_C.gradStart, _C.gradEnd],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Step dots + labels
          Row(
            children: List.generate(6, (i) {
              final isDone = i < _step;
              final isActive = i == _step;
              return Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: isActive ? 32 : 26,
                      height: isActive ? 32 : 26,
                      decoration: BoxDecoration(
                        color: isDone
                            ? _C.success
                            : isActive
                            ? _C.accent
                            : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDone
                              ? _C.success
                              : isActive
                              ? _C.accent
                              : _C.stepIdle,
                          width: 2,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: _C.accent.withOpacity(0.32),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        isDone ? Icons.check_rounded : _stepIcons[i],
                        size: isActive ? 15 : 12,
                        color: isDone || isActive ? Colors.white : _C.textMuted,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      stepLabels[i],
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isActive
                            ? _C.accent
                            : isDone
                            ? _C.success
                            : _C.textMuted,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─── Step Router ──────────────────────────────────────────────────────────

  Widget _buildStepBody() {
    switch (_step) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      case 3:
        return _buildStep4();
      case 4:
        return _buildStep5();
      default:
        return _buildStep6();
    }
  }

  // ─── Step 1: Store Details ────────────────────────────────────────────────

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader('1 of 6', 'Store Details', 'Tell us about your store'),
        const SizedBox(height: 18),
        // Hero gradient card
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withOpacity(0.38),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Social proof pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '🚀  10,000+ Indian retailers trust us',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                  children: [
                    TextSpan(text: 'Transform your\n'),
                    TextSpan(
                      text: 'retail business ',
                      style: TextStyle(color: Color(0xFFFBBF24)),
                    ),
                    TextSpan(text: 'in minutes'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildCarousel(),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _buildCard(
          child: Column(
            children: [
              _buildField(
                label: 'Store Name',
                controller: _storeCtrl,
                hint: 'e.g. Shree Supermart',
                icon: Icons.store_rounded,
              ),
              const SizedBox(height: 14),
              _buildField(
                label: 'Owner Name',
                controller: _ownerCtrl,
                hint: 'e.g. Aarav Sharma',
                icon: Icons.person_rounded,
              ),
              const SizedBox(height: 14),
              _buildField(
                label: 'Mobile Number',
                controller: _phoneCtrl,
                hint: '9876543210',
                icon: Icons.phone_rounded,
                keyboard: TextInputType.phone,
                prefixText: '+91 ',
              ),
              const SizedBox(height: 10),
              // Custom WhatsApp checkbox
              GestureDetector(
                onTap: () => setState(() => _sameWhatsapp = !_sameWhatsapp),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _sameWhatsapp ? _C.accentSoft : _C.inputFill,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _sameWhatsapp ? _C.accentMid : _C.divider,
                    ),
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _sameWhatsapp ? _C.accent : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _sameWhatsapp ? _C.accent : _C.divider,
                            width: 1.5,
                          ),
                        ),
                        child: _sameWhatsapp
                            ? const Icon(
                                Icons.check_rounded,
                                size: 13,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.chat_rounded,
                        size: 16,
                        color: Color(0xFF25D366),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'WhatsApp same as mobile number',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: _C.textPrimary,
                          fontWeight: FontWeight.w600,
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
    );
  }

  // ─── Step 2: Location ─────────────────────────────────────────────────────

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader('2 of 6', 'Store Location', 'Help customers find you'),
        const SizedBox(height: 18),
        _buildCard(
          child: Column(
            children: [
              _buildDropdown(
                label: 'State',
                value: _state,
                items: _states,
                icon: Icons.location_on_rounded,
                onChanged: (v) => setState(() => _state = v),
              ),
              const SizedBox(height: 14),
              _buildField(
                label: 'City / Town',
                controller: _cityCtrl,
                hint: 'e.g. Mumbai, Delhi, Bengaluru',
                icon: Icons.location_city_rounded,
              ),
              const SizedBox(height: 14),
              _buildField(
                label: 'Address (optional)',
                controller: _addressCtrl,
                hint: 'Street, area, landmark…',
                icon: Icons.home_work_rounded,
              ),
              const SizedBox(height: 14),
              // Info banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _C.warn.withOpacity(0.1),
                      _C.warn.withOpacity(0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _C.warn.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _C.warn,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.place_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Your location helps customers find you easily in search results',
                        style: TextStyle(
                          fontSize: 12,
                          color: _C.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Step 3: Category ─────────────────────────────────────────────────────

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader('3 of 6', 'Store Category', 'What do you sell?'),
        const SizedBox(height: 18),
        _buildCard(
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.95,
            ),
            itemBuilder: (context, index) {
              final c = _categories[index];
              final active = _category == c.value;
              final color = _categoryColors[index % _categoryColors.length];
              return GestureDetector(
                onTap: () => setState(() => _category = c.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: active ? color.withOpacity(0.1) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: active ? color : _C.divider,
                      width: active ? 1.5 : 1,
                    ),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.18),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withOpacity(active ? 0.18 : 0.09),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(c.icon, color: color, size: 20),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        c.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: active ? color : _C.textPrimary,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Step 4: Delivery Mode ────────────────────────────────────────────────

  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader(
          '4 of 6',
          'Delivery Mode',
          'How do customers receive orders?',
        ),
        const SizedBox(height: 18),
        _buildCard(
          child: Column(
            children: [
              _buildChoiceTile(
                title: 'Shop Only',
                subtitle: 'Customers visit and pick up orders in person',
                value: 'shop-only',
                icon: Icons.storefront_rounded,
                iconColor: _C.accent,
              ),
              const SizedBox(height: 12),
              _buildChoiceTile(
                title: 'Shop + Delivery',
                subtitle: 'Offer in-store pickup and home delivery',
                value: 'shop-delivery',
                icon: Icons.local_shipping_rounded,
                iconColor: const Color(0xFF059669),
                badge: 'Best',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Step 5: Plan ─────────────────────────────────────────────────────────

  Widget _buildStep5() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader(
          '5 of 6',
          'Choose Your Plan',
          '14-day free trial on all paid plans',
        ),
        const SizedBox(height: 18),
        _buildPlanCard(
          title: 'Free',
          price: '0',
          note: '/forever',
          features: const ['Up to 10 products', 'Basic catalogue'],
          value: 'free',
          iconColor: _C.textSecondary,
        ),
        const SizedBox(height: 10),
        _buildPlanCard(
          title: 'Starter',
          price: '999',
          note: '/month',
          features: const ['Up to 100 products', 'Basic catalogue'],
          value: 'starter',
          iconColor: _C.accent,
        ),
        const SizedBox(height: 10),
        _buildPlanCard(
          title: 'Pro',
          price: '1,499',
          note: '/month',
          features: const ['Unlimited products', 'AI Photo Upload'],
          value: 'pro',
          badge: 'Popular',
          iconColor: Color(0xFFF59E0B),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _C.successSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.success.withOpacity(0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified_rounded, size: 18, color: _C.success),
              SizedBox(width: 10),
              Text(
                'No credit card required · Start free today',
                style: TextStyle(
                  fontSize: 12.5,
                  color: _C.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Step 6: Account / Summary ────────────────────────────────────────────

  Widget _buildStep6() {
    final email = _client.auth.currentUser?.email ?? 'Signed in user';
    final location = [
      _cityCtrl.text.trim(),
      _state ?? '',
    ].where((e) => e.isNotEmpty).join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader(
          '6 of 6',
          'Almost There!',
          'Review your store details and launch',
        ),
        const SizedBox(height: 18),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Store summary preview
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_C.accentSoft, _C.accentSoft.withOpacity(0.4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Store Summary',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _C.accent,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryRow(
                      Icons.store_rounded,
                      'Store',
                      _storeCtrl.text.trim().isEmpty
                          ? '—'
                          : _storeCtrl.text.trim(),
                    ),
                    _buildSummaryRow(
                      Icons.person_rounded,
                      'Owner',
                      _ownerCtrl.text.trim().isEmpty
                          ? '—'
                          : _ownerCtrl.text.trim(),
                    ),
                    _buildSummaryRow(
                      Icons.location_on_rounded,
                      'Location',
                      location.isEmpty ? '—' : location,
                    ),
                    _buildSummaryRow(
                      Icons.category_rounded,
                      'Category',
                      _category ?? '—',
                    ),
                    _buildSummaryRow(
                      Icons.local_shipping_rounded,
                      'Mode',
                      _businessMode ?? '—',
                    ),
                    _buildSummaryRow(
                      Icons.credit_card_rounded,
                      'Plan',
                      _plan ?? '—',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: _C.divider, height: 1),
              const SizedBox(height: 16),
              // Signed-in account row
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _C.inputFill,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _C.divider),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _C.accentSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.mail_rounded,
                        size: 18,
                        color: _C.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Signed in as',
                            style: TextStyle(
                              fontSize: 11,
                              color: _C.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: const TextStyle(
                              fontSize: 13,
                              color: _C.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _C.successSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 11,
                          color: _C.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Bottom Actions ───────────────────────────────────────────────────────

  Widget _buildBottomActions() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Row(
            children: [
              // Back button
              GestureDetector(
                onTap: _step == 0
                    ? () => Navigator.of(context).pop()
                    : () => setState(() => _step -= 1),
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: _C.accentSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _C.accentMid.withOpacity(0.5)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.arrow_back_rounded,
                        size: 17,
                        color: _C.accent,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Back',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _C.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Continue / Launch button
              Expanded(
                child: GestureDetector(
                  onTap: _submitting ? null : _nextStep,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: _submitting
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                      color: _submitting ? _C.stepIdle : null,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _submitting
                          ? null
                          : [
                              BoxShadow(
                                color: const Color(0xFF7C3AED).withOpacity(0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_submitting)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        else ...[
                          Text(
                            _step == 5 ? 'Launch Store 🚀' : 'Continue',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          if (_step < 5) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Shared Widgets ───────────────────────────────────────────────────────

  Widget _buildCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 126,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (i) =>
                setState(() => _carouselIndex = i % _features.length),
            itemBuilder: (context, index) {
              final item = _features[index % _features.length];
              return _FeatureCard(item: item);
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _features.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _carouselIndex == i ? 22 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _carouselIndex == i
                    ? _C.yellowAccent
                    : Colors.white.withOpacity(0.35),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepHeader(String step, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _C.accentSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'STEP $step',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: _C.accent,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: _C.textPrimary,
            letterSpacing: -0.5,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13.5,
            color: _C.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _C.divider),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(0.07),
            blurRadius: 22,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? prefixText,
    TextInputType? keyboard,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: _C.textPrimary,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          style: const TextStyle(
            fontSize: 14,
            color: _C.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: _C.textMuted,
              fontWeight: FontWeight.w400,
              fontSize: 13.5,
            ),
            prefixText: prefixText,
            prefixStyle: const TextStyle(
              fontSize: 14,
              color: _C.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _C.accentSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: _C.accent),
            ),
            filled: true,
            fillColor: _C.inputFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _C.inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _C.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _C.accent, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: _C.textPrimary,
          ),
        ),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(
          value: value,
          style: const TextStyle(
            fontSize: 14,
            color: _C.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            prefixIcon: Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _C.accentSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: _C.accent),
            ),
            filled: true,
            fillColor: _C.inputFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _C.inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _C.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _C.accent, width: 1.8),
            ),
          ),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildChoiceTile({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color iconColor,
    String? badge,
  }) {
    final active = _businessMode == value;
    return GestureDetector(
      onTap: () => setState(() => _businessMode = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: active ? iconColor.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? iconColor : _C.divider,
            width: active ? 1.5 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: iconColor.withOpacity(0.14),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _C.textPrimary,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _C.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: active ? iconColor : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: active ? iconColor : _C.divider,
                  width: 2,
                ),
              ),
              child: active
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required String note,
    required List<String> features,
    required String value,
    required Color iconColor,
    String? badge,
  }) {
    final active = _plan == value;
    return GestureDetector(
      onTap: () => setState(() => _plan = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: active ? iconColor.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? iconColor : _C.divider,
            width: active ? 1.5 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: iconColor.withOpacity(0.16),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(Icons.bolt_rounded, size: 22, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _C.textPrimary,
                        ),
                      ),
                      Text(
                        '₹$price',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: iconColor,
                        ),
                      ),
                      Text(
                        note,
                        style: const TextStyle(
                          fontSize: 11,
                          color: _C.textMuted,
                        ),
                      ),
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: features
                        .map(
                          (f) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: _C.success,
                                size: 13,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                f,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: _C.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: active ? iconColor : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: active ? iconColor : _C.divider,
                  width: 2,
                ),
              ),
              child: active
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(icon, size: 14, color: _C.accent),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: const TextStyle(
              fontSize: 12,
              color: _C.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: _C.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Supporting Widgets ───────────────────────────────────────────────────────

class _FeatureCard extends StatelessWidget {
  final _Feature item;
  const _FeatureCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        // Glassmorphism effect inside the gradient hero
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(item.icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.text,
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: Colors.white.withOpacity(0.75),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Data Models ──────────────────────────────────────────────────────────────

class _Feature {
  final IconData icon;
  final String title;
  final String text;
  const _Feature({required this.icon, required this.title, required this.text});
}

class _CategoryOption {
  final String label;
  final String value;
  final IconData icon;
  const _CategoryOption(this.label, this.value, this.icon);
}

// ─── Step Icons ───────────────────────────────────────────────────────────────

final List<IconData> _stepIcons = [
  Icons.storefront_rounded,
  Icons.location_on_rounded,
  Icons.category_rounded,
  Icons.local_shipping_rounded,
  Icons.credit_card_rounded,
  Icons.person_rounded,
];

// ─── Design Tokens ────────────────────────────────────────────────────────────

class _C {
  // Backgrounds
  static const bg = Color(0xFFF8F7FF);
  static const surface = Color(0xFFFFFFFF);

  // Accent — Rich Violet
  static const accent = Color(0xFF7C3AED);
  static const accentSoft = Color(0xFFEDE9FE);
  static const accentMid = Color(0xFFC4B5FD);

  // Text
  static const textPrimary = Color(0xFF1E1245);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);

  // Borders & Inputs
  static const divider = Color(0xFFEEEBFF);
  static const inputFill = Color(0xFFF9F8FF);
  static const inputBorder = Color(0xFFE4DEFF);

  // Gradient
  static const gradStart = Color(0xFF7C3AED);
  static const gradEnd = Color(0xFF4F46E5);

  // Step indicator
  static const stepIdle = Color(0xFFEAE7F8);

  // Status
  static const success = Color(0xFF10B981);
  static const successSoft = Color(0xFFECFDF5);
  static const warn = Color(0xFFF59E0B);

  // Misc
  static const yellowAccent = Color(0xFFFBBF24);
}
