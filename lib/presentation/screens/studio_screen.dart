import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/nav/studio_browse.dart';
import '../../core/theme/drive_colors.dart';
import '../../core/theme/drive_theme.dart';
import '../../data/catalog/catalog.dart';
import '../../data/models/models.dart';
import '../../data/store/app_store.dart';
import '../shell/app_shell.dart';
import '../widgets/drive_ui.dart';
import '../widgets/preview_widget_canvas.dart';

/// Studio home matching video structure: Create + Manage Slots, Custom grid,
/// Latest Added, browsable Stock section.
class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key});

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen>
    with AutomaticKeepAliveClientMixin {
  String? _stockCategory;
  String _tier = 'all';
  bool _showLatestOnly = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    StudioBrowse.pendingCategory.addListener(_onBrowseRequest);
    _applyPendingBrowse();
  }

  @override
  void dispose() {
    StudioBrowse.pendingCategory.removeListener(_onBrowseRequest);
    super.dispose();
  }

  void _onBrowseRequest() => _applyPendingBrowse();

  void _applyPendingBrowse() {
    final pending = StudioBrowse.takePendingCategory();
    if (pending == null || !mounted) return;
    setState(() {
      _stockCategory = pending;
      _showLatestOnly = false;
    });
  }

  String _createBlank() {
    final store = context.read<AppStore>();
    final n = store.drafts.length + 1;
    return store.createDraft(
      'CustomWidget-$n',
      WidgetSpec(
        background: const WidgetBackground(
          type: BgType.gradient,
          from: '#101828',
          to: '#1E3A5F',
        ),
        layers: [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final store = context.watch<AppStore>();
    final drafts = [...store.drafts]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final latest = drafts.take(4).toList();
    final shownDrafts = _showLatestOnly ? latest : drafts;

    final templates = Catalog.templates.where((t) {
      final matchC = _stockCategory == null || t.category == _stockCategory;
      final matchTier = _tier == 'all' ||
          (_tier == 'free' && !t.premium) ||
          (_tier == 'premium' && t.premium);
      return matchC && matchTier;
    }).toList(growable: false);

    // True when the free-user upgrade affordance should appear above the
    // stock grid (any tier that surfaces premium templates).
    final showUpgradeCard =
        !store.isPremium && (_tier == 'all' || _tier == 'premium');

    // Own CustomScrollView so SliverGrid only mounts visible tiles.
    // Nested shrinkWrap GridViews previously built every stock canvas at once.
    return AppScreen(
      scroll: false,
      child: CustomScrollView(
        cacheExtent: 280,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Widget Studio',
                  style: GoogleFonts.manrope(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Blank canvas to compose layers — stock is optional',
                  style:
                      GoogleFonts.manrope(color: DriveColors.mutedForeground),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _HeroAction(
                        icon: CupertinoIcons.plus,
                        label: 'Create New',
                        onTap: () {
                          final id = _createBlank();
                          context.push('/studio/editor/$id');
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _HeroAction(
                        icon: CupertinoIcons.square_grid_2x2,
                        label: 'Manage Slots',
                        onTap: () => context.push('/studio/slots'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Text(
                      'Custom Widget',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    if (drafts.isNotEmpty)
                      TextButton(
                        onPressed: () => context.push('/studio/my-widgets'),
                        child: const Text('Manage'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          if (shownDrafts.isEmpty)
            const SliverToBoxAdapter(child: _EmptyCustomWidgets())
          else
            SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final d = shownDrafts[i];
                  return GestureDetector(
                    onTap: () => context.push('/studio/editor/${d.id}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: PreviewWidgetCanvas(
                            spec: d.spec,
                            scale: 0.55,
                            logicalSize: 180,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          d.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                        ),
                        Text(
                          formatWhen(d.updatedAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: driveMono(size: 11),
                        ),
                      ],
                    ),
                  );
                },
                childCount: shownDrafts.length,
                addAutomaticKeepAlives: false,
              ),
            ),
          if (drafts.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Center(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _showLatestOnly = !_showLatestOnly),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: DriveColors.carbon,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _showLatestOnly
                              ? DriveColors.primary
                              : DriveColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.sparkles,
                            size: 14,
                            color: _showLatestOnly
                                ? DriveColors.primary
                                : DriveColors.warning,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Latest Added',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: _showLatestOnly
                                  ? DriveColors.primary
                                  : DriveColors.foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                Text(
                  'Stock Widget',
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: DriveChip(
                          label: 'All',
                          selected: _stockCategory == null,
                          onTap: () => setState(() => _stockCategory = null),
                        ),
                      ),
                      for (final c in Catalog.categories)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Align(
                            alignment: Alignment.center,
                            child: DriveChip(
                              label: c,
                              selected: _stockCategory == c,
                              onTap: () =>
                                  setState(() => _stockCategory = c),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in ['all', 'free', 'premium'])
                      DriveChip(
                        label: t[0].toUpperCase() + t.substring(1),
                        selected: _tier == t,
                        onTap: () => setState(() => _tier = t),
                      ),
                  ],
                ),
                if (_stockCategory == 'Speedometer') ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: DriveColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: DriveColors.primary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      '${templates.length} speedometer layouts — thumbs show sample speed; live editor shows GPS km/h on iPhone (— / Unavailable when GPS is off).',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        height: 1.35,
                        color: DriveColors.foreground,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
          if (showUpgradeCard)
            SliverToBoxAdapter(
              child: _UpgradePremiumCard(
                premiumCount: templates.where((t) => t.premium).length,
                totalCount: templates.length,
              ),
            ),
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 0.68,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final t = templates[i];
                final locked = Catalog.isLocked(t, isPremium: store.isPremium);
                return GestureDetector(
                  onTap: () {
                    if (locked) {
                      context.push('/settings');
                      return;
                    }
                    context.push('/studio/templates/${t.id}');
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(
                          clipBehavior: Clip.none,
                          fit: StackFit.expand,
                          children: [
                            if (locked)
                              _LockedTemplateTile(
                                spec: t.spec,
                                scale: 0.55,
                                logicalSize: 180,
                              )
                            else
                              PreviewWidgetCanvas(
                                spec: t.spec,
                                scale: 0.55,
                                logicalSize: 180,
                              ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: TierBadge(premium: t.premium),
                            ),
                            if (locked)
                              const Positioned(
                                top: 8,
                                right: 8,
                                child: _LockedBadge(),
                              )
                            else if (templateHasLiveMotion(t.spec))
                              Positioned(
                                top: 8,
                                right: 8,
                                child: LiveBadge(
                                  maxWidth: 96,
                                  label: () {
                                    final style =
                                        templatePrimaryAnimLabel(t.spec);
                                    return style == null
                                        ? 'LIVE'
                                        : 'LIVE · $style';
                                  }(),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                      Text(
                        t.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: driveMonoLabel(size: 10),
                      ),
                    ],
                  ),
                );
              },
              childCount: templates.length,
              addAutomaticKeepAlives: false,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 104)),
        ],
      ),
    );
  }
}

class _EmptyCustomWidgets extends StatelessWidget {
  const _EmptyCustomWidgets();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: DriveColors.carbon,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DriveColors.border),
      ),
      child: Column(
        children: [
          Icon(
            CupertinoIcons.square_stack_3d_up,
            size: 36,
            color: DriveColors.mutedForeground.withValues(alpha: 0.8),
          ),
          const SizedBox(height: 12),
          Text(
            'No custom widgets yet',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap Create New to start a blank canvas.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: DriveColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroAction extends StatelessWidget {
  const _HeroAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DriveColors.carbon,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: DriveColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: DriveColors.foreground),
              const SizedBox(height: 10),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Upgrade to Premium" card shown above the stock grid when a free user
/// is browsing tiers that include premium templates.
class _UpgradePremiumCard extends StatelessWidget {
  const _UpgradePremiumCard({
    required this.premiumCount,
    required this.totalCount,
  });

  final int premiumCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: DriveColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => context.push('/settings'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: DriveColors.primary.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: DriveColors.primary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    CupertinoIcons.sparkles,
                    size: 22,
                    color: DriveColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upgrade to Premium',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$premiumCount of $totalCount stock layouts are'
                        ' premium — unlock to edit and assign.',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          height: 1.35,
                          color: DriveColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 16,
                  color: DriveColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Premium template tile shown to non-premium users. Renders the preview
/// dimmed beneath a lock + "Upgrade" CTA so the catalog stays browseable.
class _LockedTemplateTile extends StatelessWidget {
  const _LockedTemplateTile({
    required this.spec,
    required this.scale,
    required this.logicalSize,
  });

  final WidgetSpec spec;
  final double scale;
  final double logicalSize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: 0.35,
          child: PreviewWidgetCanvas(
            spec: spec,
            scale: scale,
            logicalSize: logicalSize,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: DriveColors.carbon.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: DriveColors.primary.withValues(alpha: 0.5),
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.lock_fill,
                  size: 22,
                  color: DriveColors.primary,
                ),
                const SizedBox(height: 6),
                Text(
                  'Upgrade',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: DriveColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact corner badge that overlays the locked template tile.
class _LockedBadge extends StatelessWidget {
  const _LockedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: DriveColors.graphite.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: DriveColors.primary.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.lock_fill,
            size: 9,
            color: DriveColors.primary,
          ),
          const SizedBox(width: 4),
          Text(
            'LOCKED',
            style: driveMonoLabel(
              size: 9,
              color: DriveColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
