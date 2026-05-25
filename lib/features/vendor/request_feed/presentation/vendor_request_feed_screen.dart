import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_state_widgets.dart';
import '../../../../shared/models/location_model.dart';
import '../../../requests/providers/request_provider.dart';
import '../providers/vendor_request_feed_provider.dart';
import '../widgets/vendor_feed_filter_bar.dart';
import '../widgets/vendor_request_card.dart';

/// Vendor marketplace feed: nearby active requests matching categories & radius.
class VendorRequestFeedScreen extends ConsumerStatefulWidget {
  const VendorRequestFeedScreen({super.key, required this.isDark});

  final bool isDark;

  @override
  ConsumerState<VendorRequestFeedScreen> createState() =>
      _VendorRequestFeedScreenState();
}

class _VendorRequestFeedScreenState
    extends ConsumerState<VendorRequestFeedScreen> {
  bool _initialLoadScheduled = false;
  bool _isDetectingLocation = false;

  void _safePopSheet(BuildContext sheetContext) {
    if (!sheetContext.mounted) return;
    final navigator = Navigator.of(sheetContext);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_initialLoadScheduled) return;
      _initialLoadScheduled = true;
      Future.microtask(() {
        ref.read(vendorRequestFeedProvider.notifier).loadFeed();
      });
    });
  }

  void _showShopLocationPicker(BuildContext context) {
    final isDark = widget.isDark;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final requestState = ref.read(requestProvider);
    final requestNotifier = ref.read(requestProvider.notifier);
    final feedNotifier = ref.read(vendorRequestFeedProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor:
          isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> detectVendorGPS() async {
              if (_isDetectingLocation) return;
              setSheetState(() => _isDetectingLocation = true);

              try {
                final status = await ph.Permission.location.request();
                if (!mounted) return;

                if (status.isGranted) {
                  final position = await Geolocator.getCurrentPosition(
                    desiredAccuracy: LocationAccuracy.high,
                    timeLimit: const Duration(seconds: 5),
                  );
                  if (!mounted) return;

                  final nearest = LocationModel.findNearest(
                    position.latitude,
                    position.longitude,
                  );
                  await requestNotifier.updateVendorLocation(
                    latitude: position.latitude,
                    longitude: position.longitude,
                    area: '${nearest.name} (GPS)',
                  );
                  if (!mounted) return;

                  await feedNotifier.loadFeed();
                  if (!mounted) return;

                  if (sheetContext.mounted) {
                    _safePopSheet(sheetContext);
                  }
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Shop GPS matched closest suburb: ${nearest.name}!',
                      ),
                      backgroundColor: AppColors.vendorColor,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Location permission denied. Please enable location settings.',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (_) {
                if (!mounted) return;

                final nearest = LocationModel.findNearest(6.9271, 79.8485);
                await requestNotifier.updateVendorLocation(
                  latitude: 6.9271,
                  longitude: 79.8485,
                  area: '${nearest.name} (GPS Simulated)',
                );
                if (!mounted) return;

                await feedNotifier.loadFeed();
                if (!mounted) return;

                if (sheetContext.mounted) {
                  _safePopSheet(sheetContext);
                }
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Shop GPS simulated: ${nearest.name}!'),
                    backgroundColor: AppColors.vendorColor,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } finally {
                if (mounted) {
                  setSheetState(() => _isDetectingLocation = false);
                }
              }
            }

            Future<void> selectSuburb(LocationModel loc) async {
              if (_isDetectingLocation) return;
              setSheetState(() => _isDetectingLocation = true);
              try {
                await requestNotifier.updateVendorLocation(
                  latitude: loc.latitude,
                  longitude: loc.longitude,
                  area: loc.name,
                );
                if (!mounted) return;

                await feedNotifier.loadFeed();
                if (!mounted) return;

                if (sheetContext.mounted) {
                  _safePopSheet(sheetContext);
                }
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Shop location updated to ${loc.name}'),
                    backgroundColor: AppColors.vendorColor,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } finally {
                if (mounted) {
                  setSheetState(() => _isDetectingLocation = false);
                }
              }
            }

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(sheetContext).size.height * 0.65,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select shop base suburb',
                        style: AppTextStyles.h3(primaryText),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Category-based radius filters requests from your shop location.',
                        style: AppTextStyles.caption(
                          isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      const Divider(height: 16),
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.vendorColor.withOpacity(0.12),
                          child: _isDetectingLocation
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.vendorColor,
                                  ),
                                )
                              : const Icon(
                                  Icons.my_location_rounded,
                                  color: AppColors.vendorColor,
                                  size: 20,
                                ),
                        ),
                        title: const Text(
                          'Detect current GPS location',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.vendorColor,
                          ),
                        ),
                        subtitle: const Text(
                          'Uses device sensors for coordinates',
                          style: TextStyle(fontSize: 11),
                        ),
                        enabled: !_isDetectingLocation,
                        onTap: _isDetectingLocation ? null : detectVendorGPS,
                      ),
                      const Divider(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: LocationModel.sriLankanLocations.length,
                          itemBuilder: (context, idx) {
                            final loc =
                                LocationModel.sriLankanLocations[idx];
                            final isSelected =
                                loc.name == requestState.vendorArea;
                            return ListTile(
                              title: Text(
                                loc.name,
                                style: AppTextStyles.bodyLarge(primaryText),
                              ),
                              trailing: isSelected
                                  ? const Icon(
                                      Icons.check_circle_rounded,
                                      color: AppColors.vendorColor,
                                    )
                                  : null,
                              enabled: !_isDetectingLocation,
                              onTap: _isDetectingLocation
                                  ? null
                                  : () => selectSuburb(loc),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      if (mounted) {
        setState(() => _isDetectingLocation = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final feedState = ref.watch(vendorRequestFeedProvider);
    final requestState = ref.watch(requestProvider);

    ref.listen(requestProvider, (prev, next) {
      if (prev?.vendorLatitude != next.vendorLatitude ||
          prev?.vendorLongitude != next.vendorLongitude ||
          prev?.vendorArea != next.vendorArea) {
        Future.microtask(() {
          if (!mounted) return;
          ref.read(vendorRequestFeedProvider.notifier).loadFeed();
        });
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: AppColors.vendorColor,
        onRefresh: () async {
          await ref.read(vendorRequestFeedProvider.notifier).refresh();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                'Marketplace requests',
                style: AppTextStyles.h2(primaryText),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Active requests in your categories · radius by item type',
                style: AppTextStyles.caption(secondaryText),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : AppColors.cardLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.storefront_rounded,
                      color: AppColors.vendorColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My shop base',
                            style: AppTextStyles.caption(secondaryText),
                          ),
                          Text(
                            requestState.vendorArea,
                            style: AppTextStyles.bodyMedium(primaryText)
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor:
                            AppColors.vendorColor.withOpacity(0.12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(
                        Icons.edit_location_alt_rounded,
                        color: AppColors.vendorColor,
                        size: 20,
                      ),
                      onPressed: () => _showShopLocationPicker(context),
                    ),
                  ],
                ),
              ),
            ),
            if (!feedState.vendorApproved &&
                feedState.pendingApprovalMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.hourglass_top_rounded,
                        color: AppColors.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          feedState.pendingApprovalMessage!,
                          style: AppTextStyles.bodySmall(AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (feedState.vendorApproved) ...[
              VendorFeedFilterBar(
                isDark: isDark,
                categoryChips: feedState.categoryChips,
                selectedCategory: feedState.categoryFilter,
                sortMode: feedState.sortMode,
                onCategorySelected: (cat) {
                  ref
                      .read(vendorRequestFeedProvider.notifier)
                      .setCategoryFilter(cat);
                },
                onSortChanged: (mode) {
                  ref.read(vendorRequestFeedProvider.notifier).setSortMode(mode);
                },
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: feedState.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.vendorColor,
                      ),
                    )
                  : !feedState.vendorApproved
                      ? const AppEmptyState(
                          icon: Icons.verified_user_outlined,
                          title: 'Approval required',
                          subtitle:
                              'Complete vendor verification to access the marketplace feed.',
                        )
                      : feedState.items.isEmpty
                          ? const AppEmptyState(
                              icon: Icons.location_searching_rounded,
                              title: 'No active requests nearby',
                              subtitle:
                                  'New customer requests in your radius and categories will appear here.',
                            )
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 100),
                              itemCount: feedState.items.length,
                              itemBuilder: (context, index) {
                                return VendorRequestCard(
                                  feedRequest: feedState.items[index],
                                  isDark: isDark,
                                  animationDelay:
                                      Duration(milliseconds: 40 * index),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
