import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/legal/legal_copy.dart';
import '../../core/theme/drive_colors.dart';
import '../shell/app_shell.dart';
import '../widgets/surfaces.dart';

enum LegalDocument { privacy, terms }

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final isPrivacy = document == LegalDocument.privacy;
    final title = isPrivacy ? LegalCopy.privacyTitle : LegalCopy.termsTitle;
    final sections = isPrivacy
        ? LegalCopy.privacySections
        : LegalCopy.termsSections;

    return AppScreen(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(CupertinoIcons.back, size: 16),
            label: const Text('Back'),
          ),
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          if (isPrivacy) ...[
            const SizedBox(height: 4),
            Text(
              LegalCopy.privacyEffective,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: DriveColors.mutedForeground,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SurfaceCard(
            child: Text(
              LegalCopy.ugcPrivacyNote,
              style: GoogleFonts.manrope(
                fontSize: 13,
                height: 1.4,
                color: DriveColors.mutedForeground,
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final section in sections) ...[
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.$1,
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    section.$2,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      height: 1.45,
                      color: DriveColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (isPrivacy)
            TextButton(
              onPressed: () => context.push('/terms'),
              child: const Text('View Terms of Use'),
            )
          else
            TextButton(
              onPressed: () => context.push('/privacy'),
              child: const Text('View Privacy Policy'),
            ),
        ],
      ),
    );
  }
}
