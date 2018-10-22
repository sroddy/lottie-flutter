import 'package:lottie_flutter/src/animatables.dart';

enum MaskMode { Add, Subtract, Intersect, Unknown }

class Mask {
  final MaskMode mode;
  final AnimatableShapeValue path;

  Mask.fromMap(dynamic map, double scale, double durationFrames)
      : mode = calculateMode(map['mode']),
        path = new AnimatableShapeValue.fromMap(map['pt'], scale, durationFrames);

  static MaskMode calculateMode(String rawMode) {
    switch (rawMode) {
      case 'a':
        return MaskMode.Add;
      case 's':
        return MaskMode.Subtract;
      case 'i':
        return MaskMode.Intersect;
      default:
        return MaskMode.Unknown;
    }
  }
}
