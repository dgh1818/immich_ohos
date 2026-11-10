import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/utils/viewer_hdr.dart';

void main() {
  test('uses explicit HDR metadata rather than extended sRGB', () {
    expect(ViewerHdr.imageModeFromHdrColorSpace(ui.ImageHdrColorSpace.unknown), 0);
    for (final colorSpace in ui.ImageHdrColorSpace.values) {
      if (colorSpace != ui.ImageHdrColorSpace.unknown) {
        expect(ViewerHdr.imageModeFromHdrColorSpace(colorSpace), 1, reason: '$colorSpace');
      }
    }
  });
}
