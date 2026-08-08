import 'package:flutter/material.dart';

import '../../core/theme/drive_colors.dart';
import '../../core/theme/drive_theme.dart';
import '../../data/models/models.dart';
import '../../data/store/app_store.dart';
import 'widget_canvas.dart';

/// Thumbnail wrapper: chrome paints first frame; canvas mounts after layout.
///
/// Uses [previewMode] (frozen clocks / no AnimationControllers) and sample
/// telemetry fill so Studio stock tiles look complete without inventing live %.
class PreviewWidgetCanvas extends StatefulWidget {
  const PreviewWidgetCanvas({
    super.key,
    required this.spec,
    this.scale = 1.0,
    this.logicalSize = 360,
    this.samplePreview,
  });

  final WidgetSpec spec;
  final double scale;
  final bool? samplePreview;

  /// Logical canvas size before [FittedBox] shrinks into the tile.
  final double logicalSize;

  @override
  State<PreviewWidgetCanvas> createState() => _PreviewWidgetCanvasState();
}

class _PreviewWidgetCanvasState extends State<PreviewWidgetCanvas> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // Defer heavy paint until after the shell / headers are interactive.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final side = widget.logicalSize;
    return RepaintBoundary(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: side,
          height: side,
          child: _ready
              ? WidgetCanvas(
                  spec: widget.spec,
                  scale: widget.scale,
                  previewMode: true,
                  samplePreview: widget.samplePreview,
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(DriveRadii.xxxl),
                    border: Border.all(color: DriveColors.border),
                    gradient: LinearGradient(
                      begin: const Alignment(-0.6, -1),
                      end: const Alignment(0.8, 1),
                      colors: [
                        hexColor(widget.spec.background.from),
                        hexColor(
                          widget.spec.background.to ??
                              widget.spec.background.from,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
