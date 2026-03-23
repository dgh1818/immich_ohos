import 'dart:ui' as ui;

class ViewerHdr {
  const ViewerHdr._();

  static void enableEngine({required bool imageEnabled, required bool videoEnabled}) {
    ui.SetHdr.enableHdr(enable_hdr: imageEnabled || videoEnabled);
  }

  static int applyImageMode({required bool enabled, required int hdr}) {
    if (!enabled) {
      ui.SetHdr.setHdrMode(hdr: 0, is_image: true);
      return 0;
    }

    final nextMode = hdr > 0 ? 1 : 0;
    ui.SetHdr.setHdrMode(hdr: nextMode, is_image: true);
    return nextMode;
  }

  static int imageModeFromColorSpace(ui.ColorSpace colorSpace) {
    return colorSpace == ui.ColorSpace.extendedSRGB ? 1 : 0;
  }

  static void applyVideoMode({required bool enabled}) {
    if (enabled) {
      ui.SetHdr.setHdrMode(hdr: -1, is_image: false);
    } else {
      ui.SetHdr.enableHdr(enable_hdr: false);
      ui.SetHdr.setHdrMode(hdr: -1, is_image: false);
    }
  }

  static void resetModes() {
    ui.SetHdr.setHdrMode(hdr: 0, is_image: true);
    ui.SetHdr.setHdrMode(hdr: 0, is_image: false);
    ui.SetHdr.enableHdr(enable_hdr: false);
  }
}
