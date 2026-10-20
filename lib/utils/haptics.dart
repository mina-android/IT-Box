import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

enum HapticStrength { selection, light, medium, heavy }

class AppHaptics {
  static void tap(BuildContext context,
      [HapticStrength strength = HapticStrength.light]) {
    switch (strength) {
      case HapticStrength.selection:
        HapticFeedback.selectionClick();
        break;
      case HapticStrength.light:
        HapticFeedback.lightImpact();
        break;
      case HapticStrength.medium:
        HapticFeedback.mediumImpact();
        break;
      case HapticStrength.heavy:
        HapticFeedback.heavyImpact();
        break;
    }
  }
}
