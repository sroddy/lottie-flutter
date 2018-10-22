import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'package:lottie_flutter/src/painting.dart' show Mask;
import 'package:lottie_flutter/src/parsers/parsers.dart';
import 'package:lottie_flutter/src/utils.dart';
import 'package:lottie_flutter/src/values.dart';
import 'package:lottie_flutter/src/keyframes.dart';
import 'package:flutter/painting.dart' show Color, Offset, Path;
import 'package:meta/meta.dart';

abstract class BaseKeyframeAnimation<K, A> {
  final List<ValueChanged<double>> _listeners = <ValueChanged<double>>[];
  bool isDiscrete = false;

  final Scene<K> scene;
  double _progress = 0.0;

  Keyframe<K> cachedKeyframe;

  BaseKeyframeAnimation(this.scene);

  void addListener(ValueChanged<double> onValueChanged) =>
      _listeners.add(onValueChanged);

  double get startDelayProgress =>
      scene.isEmpty ? 0.0 : scene.firstKeyframe.startProgress;

  double get endProgress =>
      scene.isEmpty ? 1.0 : scene.lastKeyframe.endProgress;

  double get progress => _progress;

  set progress(double val) {
    if (val < startDelayProgress) {
      val = startDelayProgress;
    } else if (val > endProgress) {
      val = endProgress;
    }

    if (val == _progress) {
      return;
    }

    _progress = val;
    for (ValueChanged<double> listener in _listeners) {
      listener(progress);
    }
  }

  Keyframe<K> get currentKeyframe {
    if (scene.isEmpty) {
      throw new StateError('There are no keyframes');
    }

    if (cachedKeyframe?.containsProgress(_progress) == true) {
      return cachedKeyframe;
    }

    cachedKeyframe = scene.keyframes.lastWhere(
        (Keyframe<K> keyframe) => keyframe.containsProgress(_progress),
        orElse: () => scene.firstKeyframe);
    return cachedKeyframe;
  }

  double get currentKeyframeProgress {
    if (isDiscrete) {
      return 0.0;
    }

    final Keyframe<K> keyframe = currentKeyframe;
    if (keyframe.isStatic) {
      return 0.0;
    }

    final double progressIntoFrame = _progress - keyframe.startProgress;
    final double keyframeProgress =
        keyframe.endProgress - keyframe.startProgress;
    final double linearProgress =
        (progressIntoFrame / keyframeProgress).clamp(0.0, 1.0);
    return keyframe.curve.transform(linearProgress);
  }

  A get value {
    return getValue(currentKeyframe, currentKeyframeProgress);
  }

  // keyframeProgress will be [0, 1] unless the interpolator has overshoot in which case, this
  // should be able to handle values outside of that range.
  @protected
  A getValue(Keyframe<K> keyframe, double keyframeProgress);
}

abstract class KeyframeAnimation<T> extends BaseKeyframeAnimation<T, T> {
  KeyframeAnimation(Scene<T> scene) : super(scene);

  void checkKeyframe(Keyframe<T> keyframe) {
    if (keyframe?.startValue == null || keyframe?.endValue == null) {
      throw new StateError('Missing values for keyframe.');
    }
  }
}

class StaticKeyframeAnimation<T> extends KeyframeAnimation<T> {
  final T _initialValue;

  StaticKeyframeAnimation(this._initialValue) : super(new Scene<T>.empty());

  @override
  set progress(double progress) {
    // Do nothing
  }

  @override
  T get value {
    return _initialValue;
  }

  @override
  T getValue(Keyframe<T> keyframe, double keyframeProgress) {
    return _initialValue;
  }
}

class IntegerKeyframeAnimation extends KeyframeAnimation<int> {
  IntegerKeyframeAnimation(Scene<int> scene) : super(scene);

  @override
  int getValue(Keyframe<int> keyframe, double keyframeProgress) {
    checkKeyframe(keyframe);
    return ui
        .lerpDouble(keyframe.startValue, keyframe.endValue,
            keyframeProgress) // lerpInt(keyframe.startValue, keyframe.endValue, keyframeProgress)
        .toInt();
  }
}

class DoubleKeyframeAnimation extends KeyframeAnimation<double> {
  DoubleKeyframeAnimation(Scene<double> scene) : super(scene);

  @override
  double getValue(Keyframe<double> keyframe, double keyframeProgress) {
    checkKeyframe(keyframe);
    return ui.lerpDouble(
        keyframe.startValue, keyframe.endValue, keyframeProgress);
  }
}

class ColorKeyframeAnimation extends KeyframeAnimation<Color> {
  ColorKeyframeAnimation(Scene<Color> scene) : super(scene);

  @override
  Color getValue(Keyframe<Color> keyframe, double keyframeProgress) {
    checkKeyframe(keyframe);
    return GammaEvaluator.evaluate(
        keyframeProgress, keyframe.startValue, keyframe.endValue);
  }
}

class GradientColorKeyframeAnimation extends KeyframeAnimation<GradientColor> {
  GradientColor _gradientColor;

  GradientColorKeyframeAnimation(Scene<GradientColor> scene) : super(scene) {
    final GradientColor startValue = scene.firstKeyframe.startValue;
    final int length = startValue == null ? 0 : startValue.length;
    _gradientColor =
        new GradientColor(new List<double>(length), new List<Color>(length));
  }

  @override
  GradientColor getValue(
      Keyframe<GradientColor> keyframe, double keyframeProgress) {
    return _gradientColor
      ..lerpGradients(keyframe.startValue, keyframe.endValue, keyframeProgress);
  }
}

class PointKeyframeAnimation extends KeyframeAnimation<Offset> {
  PointKeyframeAnimation(Scene<Offset> scene) : super(scene);

  @override
  Offset getValue(Keyframe<Offset> keyframe, double keyframeProgress) {
    checkKeyframe(keyframe);

    final Offset startPoint = keyframe.startValue;
    final Offset endPoint = keyframe.endValue;

    return new Offset(
        startPoint.dx + keyframeProgress * (endPoint.dx - startPoint.dx),
        startPoint.dy + keyframeProgress * (endPoint.dy - startPoint.dy));
  }
}

class ScaleKeyframeAnimation extends KeyframeAnimation<Offset> {
  ScaleKeyframeAnimation(Scene<Offset> scene) : super(scene);

  @override
  Offset getValue(Keyframe<Offset> keyframe, double keyframeProgress) {
    checkKeyframe(keyframe);

    final Offset startTransform = keyframe.startValue;
    final Offset endTransform = keyframe.endValue;

    return new Offset(
        ui.lerpDouble(startTransform.dx, endTransform.dx, keyframeProgress),
        ui.lerpDouble(startTransform.dy, endTransform.dy, keyframeProgress));
  }
}

class ShapeKeyframeAnimation extends BaseKeyframeAnimation<ShapeData, Path> {
  ShapeKeyframeAnimation(Scene<ShapeData> scene) : super(scene);

  @override
  Path getValue(Keyframe<ShapeData> keyframe, double keyframeProgress) {
    final ShapeData shape = new ShapeData.fromInterpolateBetween(
        keyframe.startValue, keyframe.endValue, keyframeProgress);
    return Parsers.pathParser.parseFromShape(shape);
  }
}

class PathKeyframeAnimation extends KeyframeAnimation<Offset> {
  PathKeyframe _pathMeasureKeyframe;
  ui.PathMetric _pathMeasure;

  PathKeyframeAnimation(Scene<Offset> scene) : super(scene);

  @override
  Offset getValue(Keyframe<Offset> keyframe, double keyframeProgress) {
    final PathKeyframe pathKeyframe = keyframe;

    if (pathKeyframe.path == null) {
      return keyframe.startValue;
    }

    if (_pathMeasureKeyframe != pathKeyframe) {
      _pathMeasure = pathKeyframe.path.computeMetrics().first;
      _pathMeasureKeyframe = keyframe;
    }

    final ui.Tangent posTan = _pathMeasure
        .getTangentForOffset(keyframeProgress * _pathMeasure.length);
    return posTan.position;
  }
}

class SplitDimensionPathKeyframeAnimation extends KeyframeAnimation<Offset> {
  final BaseKeyframeAnimation<double, double> xAnimation;
  final BaseKeyframeAnimation<double, double> yAnimation;

  SplitDimensionPathKeyframeAnimation(this.xAnimation, this.yAnimation)
      : super(new Scene<Offset>.empty());

  @override
  set progress(double progress) {
    xAnimation.progress = progress;
    yAnimation.progress = progress;
    for (ValueChanged<double> listener in _listeners) {
      listener(progress);
    }
  }

  @override
  Offset get value {
    return new Offset(xAnimation.value, yAnimation.value);
  }

  @override
  Offset getValue(Keyframe<Offset> keyframe, double keyframeProgress) {
    return new Offset(xAnimation.value, yAnimation.value);
  }
}

class MaskKeyframeAnimation {
  final List<BaseKeyframeAnimation<dynamic, Path>> _animations;
  final List<Mask> _masks;

  MaskKeyframeAnimation(this._masks)
      : _animations =
            new List<BaseKeyframeAnimation<dynamic, Path>>(_masks.length) {
    for (int i = 0; i < _masks.length; i++) {
      _animations[i] = _masks[i].path.createAnimation();
    }
  }
  List<BaseKeyframeAnimation<dynamic, Path>> get animations => _animations;

  List<Mask> get masks => _masks;
}
