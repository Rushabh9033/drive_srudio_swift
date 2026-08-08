/// In-app legal copy - keep aligned with `docs/legal/*.html`.
class LegalCopy {
  LegalCopy._();

  static const privacyTitle = 'Privacy Policy';
  static const termsTitle = 'Terms of Use';
  static const supportTitle = 'Support';

  /// Public HTTPS targets after you host `docs/legal/` (see STORE_LISTING.md).
  static const hostedPrivacyUrl = 'https://drivestudio.app/privacy';
  static const hostedSupportUrl = 'https://drivestudio.app/support';
  static const hostedTermsUrl = 'https://drivestudio.app/terms';

  static const privacyEffective = 'Effective August 3, 2026 · Version 1.0';

  static const privacySections = <(String, String)>[
    (
      'Summary',
      'Drive Studio helps you design Home Screen drive widgets, assign four slots, '
          'and prepare short connection sound cues for Shortcuts. No account. No social feed.\n\n'
          '• Drafts, preferences, and photos you add stay on your device.\n'
          '• Optional Photo Library and Camera for your own artwork.\n'
          '• Optional Location (While In Use) for live GPS speed on speedometer widgets while the app is open.\n'
          '• StoreKit handles optional Premium purchase and restore.\n'
          '• No ads, no third-party trackers, no selling of personal data in V1.\n'
          '• Background removal runs on-device. We do not upload your photos to our servers for cutout.',
    ),
    (
      'On-device data',
      'Widget drafts, slot assignments, vehicle selections, sound cue choices, and settings '
          '(including the manual Car connected toggle) are stored locally.\n\n'
          'If you grant Photo Library or Camera permission, images you choose may be used as '
          'garage art or widget layers and remain on-device unless you export or share them yourself.\n\n'
          'If you grant Location When In Use, the app may read speed derived from GPS while Drive Studio '
          'is in the foreground for speedometer widgets. We do not build a location history server-side. '
          'Deny permission and speedometers show Unavailable - we never invent a speed.\n\n'
          'Battery level/charging and network online/offline may be read to mirror live glance data.',
    ),
    (
      'Purchases',
      'Optional Premium is a one-time non-consumable In-App Purchase (drive_studio_premium). '
          'Apple processes payment via StoreKit. We store only a local entitlement flag. '
          'We do not receive your full payment card details.',
    ),
    (
      'What we do not do (V1)',
      'No advertising SDKs or ATT prompts. No analytics/crash SDKs that phone home. '
          'No account system or cloud sync of drafts. No sale of personal information. '
          'No custom CarPlay UI shell - Home Screen widgets + Shortcuts only.',
    ),
    (
      'Your images',
      'Photos are private and on-device for your own widgets. You must have the rights to every '
          'image you upload or photograph. There is no public gallery in V1.',
    ),
    (
      'Your choices',
      'Revoke Photo, Camera, or Location in iOS Settings. Clear drafts and custom vehicle images '
          'from in-app Settings. Uninstall to remove on-device app data. Manage Premium via your Apple ID.',
    ),
    (
      'Contact',
      'Hosted policy: $hostedPrivacyUrl\n'
          'Support: $hostedSupportUrl\n'
          'Source pages ship in-repo under docs/legal/ - publish on HTTPS before App Store Connect.',
    ),
  ];

  static const termsSections = <(String, String)>[
    (
      'What the app is',
      'Drive Studio is a personal design tool for Home Screen widgets and Shortcuts sound cues. '
          'It does not provide a custom CarPlay OS UI.',
    ),
    (
      'Your images',
      'Photos and artwork you add are private and stay on your device. '
          'You must have the rights (and any needed permission) to use every image you upload or photograph. '
          'Do not upload unlawful, infringing, or harmful content. '
          'There is no public gallery or sharing feed in V1.',
    ),
    (
      'Purchases',
      'Optional Premium is sold through Apple In-App Purchase. Apple’s terms apply to billing and restore.',
    ),
    (
      'Disclaimer',
      'Live GPS speed and battery readings depend on device sensors and permissions. '
          'Drive Studio is not a certified automotive instrument and must not be relied on as a '
          'primary speedometer while driving.',
    ),
  ];

  static const ugcPrivacyNote =
      'Your photos stay private on this device for your own widgets. '
      'Only add images you have the rights to use. See Privacy Policy and Terms for details.';
}
