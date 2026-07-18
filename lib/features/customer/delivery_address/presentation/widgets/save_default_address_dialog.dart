import 'package:flutter/material.dart';

/// Asks whether to persist an edited address as the customer default.
enum SaveDefaultAddressChoice { saveAsDefault, useForRequestOnly, cancelled }

class SaveDefaultAddressDialog {
  SaveDefaultAddressDialog._();

  static Future<SaveDefaultAddressChoice> show(BuildContext context) async {
    final result = await showDialog<SaveDefaultAddressChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save delivery address?'),
        content: const Text(
          'Save this as your default delivery address?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, SaveDefaultAddressChoice.cancelled),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, SaveDefaultAddressChoice.useForRequestOnly),
            child: const Text('Use only for this request'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, SaveDefaultAddressChoice.saveAsDefault),
            child: const Text('Save as default'),
          ),
        ],
      ),
    );
    return result ?? SaveDefaultAddressChoice.cancelled;
  }
}
