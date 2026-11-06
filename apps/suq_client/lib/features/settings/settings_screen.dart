import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../activation/activation_screen.dart';
import '../products/library_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _syncing = false;
  bool _checking = false;

  Future<void> _syncNow() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final count = await ref.read(syncRepositoryProvider).flush();
      ref.invalidate(pendingSyncProvider);
      ref.invalidate(lastSyncedProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(productsProvider);
      ref.invalidate(customersProvider);
      ref.invalidate(reportProvider);
      if (!mounted) return;
      showAppSnack(
        context,
        count == 0
            ? 'Everything is up to date.'
            : 'Synced $count change${count == 1 ? '' : 's'}.',
      );
    } catch (error) {
      if (mounted) showAppSnack(context, 'Sync failed: $error', error: true);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _checkSubscription() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      await ref.read(entitlementProvider.notifier).refresh();
      final state = ref.read(entitlementProvider).asData?.value;
      if (!mounted) return;
      final active = state?.active == true;
      showAppSnack(
        context,
        active
            ? 'Subscription is active. ${state!.daysLeft} day${state.daysLeft == 1 ? '' : 's'} left.'
            : (state?.message ?? 'Subscription could not be verified.'),
        error: !active,
      );
    } catch (error) {
      if (mounted) {
        showAppSnack(context, 'Could not check: $error', error: true);
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _openPlans() async {
    final entitlement = ref.read(entitlementProvider).asData?.value;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActivationScreen(state: entitlement),
      ),
    );
    if (!mounted) return;
    await ref.read(entitlementProvider.notifier).refresh();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'Your shop data stays on this device and will sync again when you log back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.loss),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final navigator = Navigator.of(context);
    try {
      await ref.read(sessionProvider.notifier).logout();
    } catch (error) {
      if (mounted) {
        showAppSnack(
          context,
          'Could not release this device. Connect to the internet and try again. $error',
          error: true,
        );
      }
      return;
    }
    navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final entitlement = ref.watch(entitlementProvider).asData?.value;
    final pending = ref.watch(pendingSyncProvider).asData?.value ?? 0;
    final lastSynced = ref.watch(lastSyncedProvider).asData?.value;

    final active = entitlement?.active == true;
    final city = [session.shop?.city, session.shop?.subcity]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .join(', ');

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const AppLogo(size: 46),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session.shop?.name ?? 'Your shop',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  Text(
                                    session.user?.name ?? '',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            StatusChip(
                              label: session.user?.role ?? 'OWNER',
                              color: AppColors.seed,
                              icon: Icons.storefront_rounded,
                            ),
                          ],
                        ),
                        const Divider(height: 26),
                        KeyValueRow(
                          label: 'Phone',
                          value: session.user?.phone ?? '—',
                        ),
                        KeyValueRow(
                          label: 'Location',
                          value: city.isEmpty ? '—' : city,
                        ),
                        KeyValueRow(
                          label: 'Shop ID',
                          value: session.shop?.id ?? '—',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.seed.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.workspace_premium_rounded,
                                color: AppColors.seed,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'SUQ subscription',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    active
                                        ? (entitlement?.packageName ?? 'Active plan')
                                        : 'Not active',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            StatusChip(
                              label: active
                                  ? '${entitlement?.daysLeft ?? 0}d left'
                                  : 'Locked',
                              color: active ? AppColors.profit : AppColors.loss,
                              icon: active
                                  ? Icons.verified_rounded
                                  : Icons.lock_outline_rounded,
                            ),
                          ],
                        ),
                        const Divider(height: 26),
                        KeyValueRow(
                          label: 'Ends on',
                          value: entitlement?.endsAt == null
                              ? '—'
                              : formatDate(entitlement!.endsAt!),
                        ),
                        KeyValueRow(
                          label: 'Offline check valid until',
                          value: entitlement?.leaseUntil == null
                              ? '—'
                              : formatDate(entitlement!.leaseUntil!),
                        ),
                        KeyValueRow(
                          label: 'Offline days left',
                          value: '${entitlement?.offlineDaysLeft ?? 0}',
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: _checking ? null : _checkSubscription,
                              icon: _checking
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.refresh_rounded, size: 19),
                              label: Text(
                                _checking ? 'Checking…' : 'Check now',
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _openPlans,
                              icon: const Icon(Icons.add_card_rounded, size: 19),
                              label: Text(active ? 'Extend plan' : 'Choose a plan'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Subscription dates are controlled by the SUQ server. '
                          'The app also verifies a signed offline lease, so changing the device date does not extend access.',
                          style: TextStyle(
                            fontSize: 10.5,
                            height: 1.4,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E5EAA).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.sync_rounded,
                                color: Color(0xFF2E5EAA),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Offline sync',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    pending == 0
                                        ? 'No changes waiting to sync'
                                        : '$pending change${pending == 1 ? '' : 's'} waiting to sync',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (pending > 0)
                              StatusChip(
                                label: '$pending',
                                color: AppColors.warning,
                                icon: Icons.cloud_upload_outlined,
                              ),
                          ],
                        ),
                        const Divider(height: 26),
                        KeyValueRow(
                          label: 'Last synced',
                          value: lastSynced == null
                              ? 'Never'
                              : formatDateTime(lastSynced),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _syncing ? null : _syncNow,
                          icon: _syncing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.sync_rounded, size: 19),
                          label: Text(_syncing ? 'Syncing…' : 'Sync now'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.storefront_outlined,
                            color: AppColors.seed,
                          ),
                          title: const Text(
                            'SUQ product library',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'Download more products or adjust your prices',
                            style: TextStyle(fontSize: 11.5),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.muted,
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LibraryScreen(),
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.muted,
                          ),
                          title: const Text(
                            'About SUQ',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Version ${AppConfig.version} • Offline-first shop manager',
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: _logout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.loss,
                      side: const BorderSide(color: AppColors.loss),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 19),
                    label: const Text('Log out'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your sales and customers are stored on this device and sync to the SUQ server when you are online.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 10.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
