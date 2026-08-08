import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/drive_colors.dart';
import '../../core/theme/drive_theme.dart';
import '../../data/catalog/catalog.dart';
import '../../data/models/models.dart';
import '../../data/store/app_store.dart';
import '../shell/app_shell.dart';
import '../widgets/drive_ui.dart';
import '../widgets/surfaces.dart';
import '../widgets/vehicle_art.dart';
import '../widgets/widget_canvas.dart';

class MyWidgetsScreen extends StatelessWidget {
  const MyWidgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    return AppScreen(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(CupertinoIcons.back),
              ),
              Expanded(
                child: Text(
                  'My widgets',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (store.drafts.isEmpty)
            SurfaceCard(
              child: Column(
                children: [
                  const SizedBox(height: 140, child: OnboardArt(variant: 2)),
                  const SizedBox(height: 12),
                  Text(
                    'No saved widgets yet',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Browse templates to create your first draft.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      color: DriveColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/studio'),
                    child: const Text('Browse templates'),
                  ),
                ],
              ),
            )
          else
            for (final d in store.drafts) ...[
              SurfaceCard(
                child: Row(
                  children: [
                    SizedBox(
                      width: 72,
                      child: WidgetCanvas(
                        spec: d.spec,
                        scale: 0.6,
                        previewMode: true,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
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
                    ),
                    PopupMenuButton<String>(
                      color: DriveColors.carbon,
                      onSelected: (v) async {
                        switch (v) {
                          case 'edit':
                            context.push('/studio/editor/${d.id}');
                          case 'dup':
                            final id = store.duplicateDraft(d.id);
                            if (id != null) context.push('/studio/editor/$id');
                          case 'rename':
                            final name = await _promptName(context, d.name);
                            if (name != null && name.trim().isNotEmpty) {
                              store.saveDraft(d.id, name: name.trim());
                            }
                          case 'delete':
                            final ok = await _confirmDelete(context);
                            if (ok) store.deleteDraft(d.id);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'dup', child: Text('Duplicate')),
                        PopupMenuItem(value: 'rename', child: Text('Rename')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  Future<String?> _promptName(BuildContext context, String current) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename widget'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete draft?'),
        content: const Text('This removes the widget from slots that use it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: DriveColors.destructive,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class SlotsScreen extends StatelessWidget {
  const SlotsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(CupertinoIcons.back),
              ),
              Expanded(
                child: Text(
                  'Dashboard slots',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Assign drafts to four Home Screen widget slots. Live WidgetKit rendering requires the Mac Wave 2 build - this screen manages the shared slot contract (not a CarPlay dashboard).',
            style: GoogleFonts.manrope(
              color: DriveColors.mutedForeground,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < 4; i++) ...[
            _SlotCard(index: i),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final id = store.slots[index];
    final draft = id == null ? null : store.draftById(id);

    return SurfaceCard(
      glow: draft != null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoLabel('Slot ${index + 1}'),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 88,
                child: draft == null
                    ? AspectRatio(
                        aspectRatio: 1,
                        child: DashedBorderBox(
                          child: Center(
                            child: Text(
                              'Empty',
                              style: driveMonoLabel(size: 9),
                            ),
                          ),
                        ),
                      )
                    : WidgetCanvas(
                        spec: draft.spec,
                        scale: 0.6,
                        previewMode: true,
                        // Assigned slot = actual use: real telemetry only.
                        samplePreview: false,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft?.name ?? 'No widget assigned',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                    ),
                    if (draft != null)
                      Text(
                        formatWhen(draft.updatedAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: driveMono(size: 11),
                      ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => _pickDraft(context, index),
                          child: Text(draft == null ? 'Assign' : 'Replace'),
                        ),
                        if (draft != null)
                          TextButton(
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Remove from slot?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) store.assignSlot(index, null);
                            },
                            child: Text(
                              'Remove',
                              style: GoogleFonts.manrope(
                                color: DriveColors.destructive,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickDraft(BuildContext context, int index) async {
    final store = context.read<AppStore>();
    if (store.drafts.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Create a draft first')));
      return;
    }
    await DriveSheet.show<void>(
      context: context,
      builder: (ctx) {
        return DriveSheet(
          title: 'Assign draft',
          child: ListView(
            children: [
              for (final d in store.drafts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: DriveColors.graphite,
                    borderRadius: BorderRadius.circular(DriveRadii.lg),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(DriveRadii.lg),
                      onTap: () {
                        store.assignSlot(index, d.id);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Assigned to Slot ${index + 1}'),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 52,
                              child: WidgetCanvas(
                                spec: d.spec,
                                scale: 0.5,
                                previewMode: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d.name,
                                    style: GoogleFonts.manrope(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    formatWhen(d.updatedAt),
                                    style: driveMono(size: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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

class TemplateDetailScreen extends StatelessWidget {
  const TemplateDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final t = Catalog.templateById(id);
    if (t == null) {
      return AppScreen(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () => context.go('/studio'),
              icon: const Icon(CupertinoIcons.back, size: 16),
              label: const Text('Studio'),
            ),
            const SizedBox(height: 48),
            Center(
              child: Column(
                children: [
                  Icon(
                    CupertinoIcons.doc_text_search,
                    size: 40,
                    color: DriveColors.mutedForeground.withValues(alpha: 0.8),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Template not found',
                    style: GoogleFonts.manrope(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This template id is missing from the local catalog.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      color: DriveColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => context.go('/studio'),
                    child: const Text('Browse templates'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final store = context.watch<AppStore>();

    return AppScreen(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => context.go('/studio'),
            icon: const Icon(CupertinoIcons.back, size: 16),
            label: const Text('Studio'),
          ),
          const SizedBox(height: 8),
          WidgetCanvas(
            spec: t.spec,
            previewMode: true,
            // Template detail hero thumb - sample fill OK; Edit/Assign = live.
            samplePreview: true,
          ),
          const SizedBox(height: 20),
          Text(
            t.name,
            style: GoogleFonts.manrope(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaPill(t.category),
              const _MetaPill('systemSmall'),
              TierBadge(premium: t.premium),
              if (templateHasLiveMotion(t.spec))
                LiveBadge(
                  label: () {
                    final style = templatePrimaryAnimLabel(t.spec);
                    return style == null ? 'Animated' : 'LIVE · $style';
                  }(),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const MonoLabel('Included components'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final l in t.spec.layers)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: DriveColors.carbon,
                    borderRadius: BorderRadius.circular(DriveRadii.sm),
                    border: Border.all(color: DriveColors.border),
                  ),
                  child: Text(
                    l.label.isNotEmpty
                        ? l.label
                        : (l.format.isNotEmpty
                              ? '${l.kind.name} · ${l.format}'
                              : l.kind.name),
                    style: driveMono(
                      size: 11,
                      color: DriveColors.mutedForeground,
                    ),
                  ),
                ),
            ],
          ),
          if (t.premium && !store.isPremium) ...[
            const SizedBox(height: 12),
            SurfaceCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.lock_fill,
                    size: 16,
                    color: DriveColors.warning,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Premium template. Unlock in Settings to edit or assign.',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: DriveColors.mutedForeground,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () => context.push('/settings'),
                    child: const Text('Settings'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (t.premium && !store.isPremium) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Premium template - unlock in Settings',
                          ),
                        ),
                      );
                      return;
                    }
                    final draftId = store.createDraftFromTemplate(t);
                    if (draftId == null) return;
                    context.push('/studio/editor/$draftId');
                  },
                  child: Text(
                    t.premium && !store.isPremium
                        ? 'Unlock to edit'
                        : 'Edit copy',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _assignToSlot(context, store, t),
                  child: Text(
                    t.premium && !store.isPremium
                        ? 'Unlock to assign'
                        : 'Assign slot',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _assignToSlot(
    BuildContext context,
    AppStore store,
    TemplateItem template,
  ) async {
    if (template.premium && !store.isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Premium template - unlock in Settings')),
      );
      return;
    }
    final slot = await DriveSheet.show<int>(
      context: context,
      builder: (ctx) {
        return DriveSheet(
          title: 'Choose slot',
          child: ListView(
            children: [
              for (var i = 0; i < 4; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: DriveColors.graphite,
                    borderRadius: BorderRadius.circular(DriveRadii.md),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(DriveRadii.md),
                      onTap: () => Navigator.pop(ctx, i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Slot ${i + 1}',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Flexible(
                              child: Text(
                                store.slots[i] == null
                                    ? 'Empty'
                                    : (store.draftById(store.slots[i]!)?.name ??
                                          'Occupied'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: driveMono(
                                  size: 11,
                                  color: DriveColors.mutedForeground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
    if (slot == null || !context.mounted) return;
    final draftId = store.createDraftFromTemplate(template);
    if (draftId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Premium template - unlock in Settings')),
      );
      return;
    }
    store.assignSlot(slot, draftId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${template.name} assigned to Slot ${slot + 1}')),
    );
    context.push('/studio/slots');
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: DriveColors.graphite,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: driveMonoLabel(size: 10)),
    );
  }
}
