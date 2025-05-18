// Only compile this file for web
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Registers a Google Maps iframe on web
Widget createGoogleMapIframe(double latitude, double longitude, String mapId) {
  // Register a view only once
  // ignore: undefined_prefixed_name
  ui.platformViewRegistry.registerViewFactory(
    mapId,
    (int viewId) =>
        html.IFrameElement()
          ..width = '100%'
          ..height = '400'
          ..src =
              'https://maps.google.com/maps?q=$latitude,$longitude&z=15&output=embed'
          ..style.border = '0',
  );

  return HtmlElementView(viewType: mapId);
}
