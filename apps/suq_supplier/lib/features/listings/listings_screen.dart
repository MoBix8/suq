import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import 'listing_dialog.dart';

class ListingsScreen extends ConsumerStatefulWidget {
  const ListingsScreen({super.key});

  @override
  ConsumerState<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends ConsumerState<ListingsScreen>
    with WidgetsBindingObserver {
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(listingsProvider);
  }

  Future<void> _openEditor({SupplierListing? listing}) async {
    final draft = await showDialog<ListingDraft>(
      context: context,
      builder: (_) => ListingDialog(listing: listing),
    );
    if (draft == null) return;

    try {
      final api = ref.read(apiProvider);
      final response = listing == null
          ? await api.post('/supplier/listings', body: draft.toJson())
          : await api.patch(
              '/supplier/listings/${listing.id}',
              body: draft.toJson(),
            );
      _rememberSavedListing(response);
      ref.invalidate(listingsProvider);
      if (mounted) {
        showAppSnack(
          context,
          listing == null
              ? 'Listing published. It is now under Listings; shops see it in Orders.'
              : 'Listing updated.',
        );
      }
    } on ApiException catch (error) {
      if (mounted) await _showSaveError(error, editing: listing != null);
    } catch (error) {
      if (mounted) await _showSaveError(error, editing: listing != null);
    }
  }

  Future<void> _setActive(SupplierListing listing, bool active) async {
    try {
      final response = await ref.read(apiProvider).patch(
        '/supplier/listings/${listing.id}',
        body: {'active': active},
      );
      _rememberSavedListing(response);
      ref.invalidate(listingsProvider);
      if (mounted) {
        showAppSnack(
          context,
          active ? 'Listing is visible to shops.' : 'Listing hidden.',
        );
      }
    } on ApiException catch (error) {
      if (mounted) await _showSaveError(error, editing: true);
    } catch (error) {
      if (mounted) await _showSaveError(error, editing: true);
    }
  }

  void _rememberSavedListing(Map<String, dynamic> response) {
    final saved = response['listing'];
    if (saved is! Map) return;
    final listing = SupplierListing.fromJson(asMap(saved));
    if (listing.id.isEmpty) return;
    ref.read(recentlyPublishedListingProvider.notifier).remember(listing);
  }

  Future<void> _showSaveError(Object error, {required bool editing}) async {
    final message = error is ApiException ? error.message : error.toString();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(editing ? 'Listing not saved' : 'Listing not published'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listingsAsync = ref.watch(listingsProvider);
    final recent = ref.watch(recentlyPublishedListingProvider);

    return AsyncValueView<List<SupplierListing>>(
      value: listingsAsync,
      onRetry: () => ref.invalidate(listingsProvider),
      loadingMessage: 'Loading listings…',
      builder: (listings) {
        final recentListing = recent;
        final allListings = recentListing == null
            ? listings
            : <SupplierListing>[
                recentListing,
                ...listings.where(
                  (listing) => listing.id != recentListing.id,
                ),
              ];
        final filtered = switch (_filter) {
          'active' => allListings.where((listing) => listing.active).toList(),
          'hidden' =>
            allListings.where((listing) => !listing.active).toList(),
          _ => allListings,
        };

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(listingsProvider);
            await ref.read(listingsProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PageHeader(
                        title: 'Bulk listings',
                        subtitle:
                            '${allListings.where((l) => l.active).length} visible · ${allListings.length} total',
                        action: FilledButton.icon(
                          onPressed: () => _openEditor(),
                          icon: const Icon(Icons.add_rounded, size: 19),
                          label: const Text('Publish listing'),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const InfoBanner(
                        icon: Icons.storefront_outlined,
                        message:
                            'Listings are independent wholesale offers. The catalog tab is the same retail product library shops browse in the client app; it is not linked to listings.',
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 38,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final option in const [
                              ('all', 'All listings'),
                              ('active', 'Visible'),
                              ('hidden', 'Hidden'),
                            ])
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(option.$2),
                                  selected: _filter == option.$1,
                                  onSelected: (_) =>
                                      setState(() => _filter = option.$1),
                                ),
                              ),
                            SizedBox(
                              width: 34,
                              height: 34,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Refresh listings',
                                onPressed: () =>
                                    ref.invalidate(listingsProvider),
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 19,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (filtered.isEmpty)
                        EmptyState(
                          icon: Icons.sell_outlined,
                          title: allListings.isEmpty
                              ? 'No listings yet'
                              : 'Nothing in this filter',
                          message: allListings.isEmpty
                              ? 'Publish your first wholesale listing so shops can order from you.'
                              : 'Try a different filter.',
                          action: allListings.isEmpty
                              ? FilledButton.icon(
                                  onPressed: () => _openEditor(),
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text('Publish a listing'),
                                )
                              : null,
                        )
                      else
                        for (final listing in filtered) ...[
                          _ListingCard(
                            listing: listing,
                            onEdit: () => _openEditor(listing: listing),
                            onActiveChanged: (value) =>
                                _setActive(listing, value),
                          ),
                          const SizedBox(height: 10),
                        ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({
    required this.listing,
    required this.onEdit,
    required this.onActiveChanged,
  });

  final SupplierListing listing;
  final VoidCallback onEdit;
  final ValueChanged<bool> onActiveChanged;

  @override
  Widget build(BuildContext context) {
    final unit = saleUnitLabel(listing.saleUnit);
    final category = (listing.category ?? '').trim();
    final description = (listing.description ?? '').trim();

    return SectionCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (listing.active
                          ? SupplierColors.seed
                          : SupplierColors.muted)
                      .withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.sell_outlined,
                  color: listing.active
                      ? SupplierColors.seed
                      : SupplierColors.muted,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          listing.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: SupplierColors.ink,
                          ),
                        ),
                        StatusChip(
                          label: listing.active ? 'Visible' : 'Hidden',
                          color: listing.active
                              ? SupplierColors.success
                              : SupplierColors.muted,
                          icon: listing.active
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                      ],
                    ),
                    if (category.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        category,
                        style: const TextStyle(
                          color: SupplierColors.muted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: SupplierColors.muted,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if ((listing.publishedByName ?? '').isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Published by ${listing.publishedByName}',
                        style: const TextStyle(
                          color: SupplierColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money(listing.pricePerUnit),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: SupplierColors.ink,
                    ),
                  ),
                  Text(
                    'per $unit',
                    style: const TextStyle(
                      color: SupplierColors.muted,
                      fontSize: 10.5,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit listing',
                    visualDensity: VisualDensity.compact,
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 19),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DimensionChip(
                icon: Icons.shopping_basket_outlined,
                label: 'Min ${listing.minOrderQty} $unit',
              ),
              if (listing.piecesPerUnit > 1)
                _DimensionChip(
                  icon: Icons.widgets_outlined,
                  label: '${listing.piecesPerUnit} pieces / $unit',
                ),
              _DimensionChip(
                icon: Icons.scale_outlined,
                label: '${weightLabel(listing.weightPerUnitKg)} / $unit',
              ),
              _DimensionChip(
                icon: Icons.view_in_ar_outlined,
                label: volumeLabel(listing.volumePerUnitM3),
              ),
              _DimensionChip(
                icon: Icons.straighten_outlined,
                label:
                    '${qty(listing.lengthCm)}×${qty(listing.widthCm)}×${qty(listing.heightCm)} cm',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Visible to shops',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: SupplierColors.ink,
                  ),
                ),
              ),
              Switch(
                value: listing.active,
                onChanged: onActiveChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DimensionChip extends StatelessWidget {
  const _DimensionChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: SupplierColors.background,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: SupplierColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: SupplierColors.muted),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: SupplierColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
