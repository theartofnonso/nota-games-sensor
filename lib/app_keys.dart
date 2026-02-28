import 'package:flutter/material.dart';

/// Global navigator key for root-level operations (e.g. dismissing overlays
/// when the calling widget's context may be unmounted).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
