// Use this instead of [Color.lerp] because it interpolates through the gamma color
// space which looks better to us humans.
//
// Writted by Romain Guy and Francois Blavoet.
// https://androidstudygroup.slack.com/archives/animation/p1476461064000335

import 'dart:math';
import 'package:lottie_flutter/src/animations.dart';
import 'package:lottie_flutter/src/mathutils.dart';
import 'package:lottie_flutter/src/values.dart';
import 'package:flutter/painting.dart';
import 'package:vector_math/vector_math_64.dart';



/// Parse the color string and return the corresponding Color.
/// Supported formatS are:
/// #RRGGBB and #AARRGGBB
Color parseColor(String colorString) {
  if (colorString[0] == '#') {
    int color = int.parse(colorString.substring(0),
        radix: 16, onError: (source) => 0xff000000);
    if (colorString.length == 7) {
      return new Color(color |= 0x00000000ff000000);
    }

    if (colorString.length == 9) {
      return new Color(color);
    }
  }

  throw new ArgumentError.value(colorString, "colorString", "Unknown color");
}

class GammaEvaluator {
  GammaEvaluator._();

  static Color evaluate(double fraction, Color start, Color end) {
    double startA = start.alpha / 255.0;
    double startR = start.red / 255.0;
    double startG = start.green / 255.0;
    double startB = start.blue / 255.0;

    double endA = end.alpha / 255.0;
    double endR = end.red / 255.0;
    double endG = end.green / 255.0;
    double endB = end.blue / 255.0;

    // convert from sRGB to linear
    startR = _EOCF_sRGB(startR);
    startG = _EOCF_sRGB(startG);
    startB = _EOCF_sRGB(startB);

    endR = _EOCF_sRGB(endR);
    endG = _EOCF_sRGB(endG);
    endB = _EOCF_sRGB(endB);

    // compute the interpolated color in linear space
    double a = startA + fraction * (endA - startA);
    double r = startR + fraction * (endR - startR);
    double g = startG + fraction * (endG - startG);
    double b = startB + fraction * (endB - startB);

    // convert back to sRGB in the [0..255] range
    a = a * 255.0;
    r = _OECF_sRGB(r) * 255.0;
    g = _OECF_sRGB(g) * 255.0;
    b = _OECF_sRGB(b) * 255.0;

    return new Color(
        a.round() << 24 | r.round() << 16 | g.round() << 8 | b.round());
  }

  // Opto-electronic conversion function for the sRGB color space
  // Takes a gamma-encoded sRGB value and converts it to a linear sRGB value
  static double _OECF_sRGB(double linear) {
    // IEC 61966-2-1:1999
    return linear <= 0.0031308
        ? linear * 12.92
        : (pow(linear, 1.0 / 2.4) * 1.055) - 0.055;
  }

  // Electro-optical conversion function for the sRGB color space
  // Takes a linear sRGB value and converts it to a gamma-encoded sRGB value
  static double _EOCF_sRGB(double srgb) {
    // IEC 61966-2-1:1999
    return srgb <= 0.04045 ? srgb / 12.92 : pow((srgb + 0.055) / 1.055, 2.4);
  }
}

int calculateAlpha(int from, BaseKeyframeAnimation<dynamic, int> opacity) =>
    ((from / 255.0 * opacity.value / 100.0) * 255.0).toInt();


//TODO: Review this :?
// Android version: path.add(path, parentMatrix)
void addPathToPath(Path path, Path other, Matrix4 transform) =>
    path.addPath(other.transform(transform.storage), const Offset(0.0, 0.0));

Path applyScaleTrimIfNeeded(
    Path path, double start, double end, double offset) {
  return applyTrimPathIfNeeded(path, start / 100.0, end / 100.0, offset / 100.0);
}

Path applyTrimPathIfNeeded(Path path, double startValue, double endValue, double offsetValue) {
  final metrics = path.computeMetrics().first;

  final length = metrics.length;
  if (startValue == 1.0 && endValue == 0.0) {
    return path;
  }
  if (length < 1.0 || (endValue - startValue - 1).abs() < 0.01) {
  return path;
  }

  final start = length * startValue;
  final end = length * endValue;
  var newStart = min(start, end);
  var newEnd = max(start, end);

  final offset = offsetValue * length;
  newStart += offset;
  newEnd += offset;

  // If the trim path has rotated around the path, we need to shift it back.
  if (newStart >= length && newEnd >= length) {
    newStart = _floorMod(newStart, length).toDouble();
    newEnd = _floorMod(newEnd, length).toDouble();
  }

  if (newStart < 0) {
    newStart = _floorMod(newStart, length).toDouble();
  }
  if (newEnd < 0) {
    newEnd = _floorMod(newEnd, length).toDouble();
  }

  // If the start and end are equals, return an empty path.
  if (newStart == newEnd) {
    path.reset();
    return path;
  }

  if (newStart >= newEnd) {
    newStart -= length;
  }

  final tempPath = metrics.extractPath(newStart, newEnd);

  if (newEnd > length) {
    final tempPath2 = metrics.extractPath(0.0, newEnd % length);
    tempPath.addPath(tempPath2, const Offset(0.0, 0.0));
  } else if (newStart < 0) {
    final tempPath2 = metrics.extractPath(length + newStart, length);
    tempPath.addPath(tempPath2, const Offset(0.0, 0.0));
  }

  return tempPath;
}


Shader createGradientShader(GradientColor gradient, GradientType type,
    Offset startPoint, Offset endPoint, Rect bounds) {
  double x0 = bounds.left + bounds.width / 2 + startPoint.dx;
  double y0 = bounds.top + bounds.height / 2 + startPoint.dy;
  double x1 = bounds.left + bounds.width / 2 + endPoint.dx;
  double y1 = bounds.top + bounds.height / 2 + endPoint.dy;

  return type == GradientType.Linear
      ? _createLinearGradientShader(gradient, x0, y0, x1, y1, bounds)
      : _createRadialGradientShader(gradient, x0, y0, x1, y1, bounds);
}

Shader _createLinearGradientShader(GradientColor gradient, double x0,
    double y0, double x1, double y1, Rect bounds) =>
    new LinearGradient(
      begin: new FractionalOffset(x0, y0),
      end: new FractionalOffset(x1, y1),
      colors: gradient.colors,
      stops: gradient.positions,
    ).createShader(bounds);

Shader _createRadialGradientShader(GradientColor gradient, double x0,
    double y0, double x1, double y1, Rect bounds) =>
    new RadialGradient(
      center: new FractionalOffset(x0, y0),
      radius: sqrt(hypot(x1 - x0, y1 - y0)),
      colors: gradient.colors,
      stops: gradient.positions,
    ).createShader(bounds);

int _floorMod(num x, num y) {
  x = x.toInt();
  y = y.toInt();
  return x - y * _floorDiv(x, y);
}

int _floorDiv(int x, int y) {
  var r = (x ~/ y);
  final sameSign = (x ^ y) >= 0;
  final mod = x % y;
  if (!sameSign && mod != 0) {
    r--;
  }
  return r;
}
