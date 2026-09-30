import 'dart:ui';

class TrackedObject {
  const TrackedObject({
    required this.id,
    required this.boundingBox,
    required this.label,
  });

  final int id;
  final Rect boundingBox;
  final String label;
}
