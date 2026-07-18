import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class VendorShopfrontScreen extends StatefulWidget {
  const VendorShopfrontScreen({
    super.key,
    required this.vendorName,
    required this.vendorPhone,
  });

  final String vendorName;
  final String vendorPhone;

  @override
  State<VendorShopfrontScreen> createState() => _VendorShopfrontScreenState();
}

class _VendorShopfrontScreenState extends State<VendorShopfrontScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Mock catalog categories & items for Sri Lankan shops
  final Map<String, List<Map<String, String>>> _catalog = {
    'Groceries': [
      {'name': 'Araliya Samba Rice 5kg', 'price': 'Rs. 1,150', 'desc': 'Premium unpolished Keeri Samba.'},
      {'name': 'Anchor Milk Powder 400g', 'price': 'Rs. 780', 'desc': 'Full cream milk powder.'},
      {'name': 'Lipton Ceylonta Tea 200g', 'price': 'Rs. 420', 'desc': '100% Pure Ceylon black tea.'},
      {'name': 'Munchee Cream Crackers', 'price': 'Rs. 240', 'desc': 'Original super cream crackers.'},
      {'name': 'Wijaya Chili Powder 100g', 'price': 'Rs. 180', 'desc': 'Finely ground hot red chilies.'},
    ],
    'Dairies & Liquids': [
      {'name': 'Kotmale Fresh Milk 1L', 'price': 'Rs. 450', 'desc': 'Pasteurized rich cow milk.'},
      {'name': 'Astra Margarine 250g', 'price': 'Rs. 380', 'desc': 'Vitamin enriched spread.'},
      {'name': 'Pelwatte Salted Butter', 'price': 'Rs. 690', 'desc': 'Creamy local dairy butter.'},
    ],
    'Household': [
      {'name': 'Sunlight Soap 115g x 4', 'price': 'Rs. 320', 'desc': 'Multi-purpose washing soap.'},
      {'name': 'Vim Dishwash Liquid 500ml', 'price': 'Rs. 290', 'desc': 'Lemon fresh grease removal.'},
      {'name': 'Signal Toothpaste 120g', 'price': 'Rs. 195', 'desc': 'Double action decay protection.'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _catalog.keys.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : Colors.black;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 220,
              floating: false,
              pinned: true,
              backgroundColor: surfaceColor,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Banner background with gradient
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.customerColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    // Semi-transparent overlay
                    Container(color: Colors.black.withOpacity(0.3)),
                    // Header Details
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.verified_user_rounded, color: Colors.white, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Verified Partner Shop Owner',
                                    style: AppTextStyles.caption(Colors.white).copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.vendorName,
                              style: AppTextStyles.h1(Colors.white).copyWith(
                                shadows: [
                                  const Shadow(color: Colors.black45, blurRadius: 10, offset: Offset(2, 2)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  '4.8 ★ (140+ reviews)',
                                  style: AppTextStyles.bodyMedium(Colors.white70).copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 12),
                                const Icon(Icons.location_on, color: Colors.white70, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  'Colombo 03',
                                  style: AppTextStyles.bodyMedium(Colors.white70),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contact & Map Card
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Shop Owner Contact', style: AppTextStyles.subtitle(primaryText)),
                              const SizedBox(height: 4),
                              Text(widget.vendorPhone, style: AppTextStyles.bodyLarge(secondaryText)),
                            ],
                          ),
                          IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.customerColor.withOpacity(0.12),
                            ),
                            icon: const Icon(Icons.phone, color: AppColors.customerColor),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Calling ${widget.vendorName} at ${widget.vendorPhone}...')),
                              );
                            },
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 20, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Text('Open Daily: 8:00 AM - 9:00 PM', style: AppTextStyles.bodyMedium(primaryText)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Simulated Map Mocks
                      Text('Outlet Coordinates', style: AppTextStyles.caption(secondaryText)),
                      const SizedBox(height: 8),
                      Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[900] : Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Aesthetic roads background mock
                            Opacity(
                              opacity: 0.2,
                              child: GridView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6),
                                itemCount: 12,
                                itemBuilder: (context, index) => Container(
                                  decoration: BoxDecoration(border: Border.all(color: primaryText)),
                                ),
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.location_on_rounded, size: 36, color: AppColors.error),
                                const SizedBox(height: 4),
                                Text(
                                  'Galle Face View Outlet',
                                  style: AppTextStyles.bodySmall(primaryText).copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Lat: 6.9271° N, Lon: 79.8485° E',
                                  style: AppTextStyles.caption(secondaryText),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Policy bypass warnings
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.shield_outlined, color: AppColors.warning, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Speedmart Ceylon Bypass Protection',
                              style: AppTextStyles.bodyMedium(primaryText).copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'To safeguard your refunds and order dispute rights, always transact and pay within the Speedmart Lanka application.',
                              style: AppTextStyles.bodySmall(secondaryText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Catalog Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('Digital Product Catalogue', style: AppTextStyles.h2(primaryText)),
              ),
              const SizedBox(height: 12),

              // Category tabs
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.customerColor,
                labelColor: AppColors.customerColor,
                unselectedLabelColor: secondaryText,
                labelStyle: AppTextStyles.bodyMedium(primaryText).copyWith(fontWeight: FontWeight.bold),
                isScrollable: true,
                tabs: _catalog.keys.map((c) => Tab(text: c)).toList(),
              ),
              const SizedBox(height: 8),

              // Category Items Lists
              Container(
                height: 400,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TabBarView(
                  controller: _tabController,
                  children: _catalog.keys.map((category) {
                    final items = _catalog[category]!;
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['name']!, style: AppTextStyles.bodyLarge(primaryText).copyWith(fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Text(item['desc']!, style: AppTextStyles.caption(secondaryText)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(item['price']!, style: AppTextStyles.bodyLarge(AppColors.success).copyWith(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'In Stock',
                                      style: AppTextStyles.caption(AppColors.success).copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

