import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_background_remover/image_background_remover.dart';
import 'package:provider/provider.dart';

import '../../data/store/app_store.dart';
import '../../presentation/screens/studio_creation_sheets.dart';

class VehicleUploader {
  static Future<void> uploadAndProcessVehicle(BuildContext context) async {
    final choice = await showImageSelectionSheet(context);
    if (choice == null) return;

    if (!context.mounted) return;

    final picker = ImagePicker();
    XFile? file;
    if (choice == ImageSelectionChoice.camera) {
      file = await picker.pickImage(source: ImageSource.camera);
    } else {
      file = await picker.pickImage(source: ImageSource.gallery);
    }

    if (file == null) return;
    final bytes = await file.readAsBytes();

    if (!context.mounted) return;

    final removeBgPrompt = choice == ImageSelectionChoice.removeBg
        ? RemoveBgPromptChoice.removeBg
        : await showRemoveBackgroundPrompt(context);

    if (removeBgPrompt == null) return;

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoActivityIndicator(radius: 20),
            SizedBox(height: 16),
            Text('Processing image...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    try {
      Uint8List finalBytes = bytes;

      if (removeBgPrompt == RemoveBgPromptChoice.removeBg) {
        await BackgroundRemover.instance.initializeOrt();
        final ui.Image resultImage = await BackgroundRemover.instance.removeBg(
          bytes,
        );

        // Convert ui.Image back to PNG bytes
        final byteData = await resultImage.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (byteData != null) {
          finalBytes = byteData.buffer.asUint8List();
        }
      }

      final base64Image = 'data:image/png;base64,${base64Encode(finalBytes)}';

      if (context.mounted) {
        final store = context.read<AppStore>();
        store.updateVehicle((v) => v..customImage = base64Image);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error processing image: $e')));
      }
    } finally {
      if (context.mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop(); // Dismiss loading dialog
      }
      try {
        BackgroundRemover.instance.dispose();
      } catch (_) {}
    }
  }
}
