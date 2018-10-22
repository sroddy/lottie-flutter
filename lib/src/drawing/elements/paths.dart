import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:lottie_flutter/src/animations.dart';
import 'package:lottie_flutter/src/drawing/elements/groups.dart';
import 'package:lottie_flutter/src/drawing/drawing.dart';
import 'package:lottie_flutter/src/values.dart';

import 'package:lottie_flutter/src/drawing/drawing_layers.dart';

///
/// TrimPathDrawable
///
class TrimPathDrawable extends AnimationDrawable {
  final ShapeTrimPathType _type;
  final List<ValueChanged<double>> _listeners = <ValueChanged<double>>[];
  final BaseKeyframeAnimation<dynamic, double> _startAnimation;
  final BaseKeyframeAnimation<dynamic, double> _endAnimation;
  final BaseKeyframeAnimation<dynamic, double> _offsetAnimation;

  TrimPathDrawable(
      String name,
      Repaint repaint,
      this._type,
      this._startAnimation,
      this._endAnimation,
      this._offsetAnimation,
      BaseLayer layer)
      : super(name, repaint, layer) {
    addAnimation(_startAnimation);
    addAnimation(_endAnimation);
    addAnimation(_offsetAnimation);
  }

  ShapeTrimPathType get type => _type;

  double get start => _startAnimation.value;

  double get end => _endAnimation.value;

  double get offset => _offsetAnimation.value;

  @override
  void onValueChanged(double progress) {
    for (ValueChanged<double> listener in _listeners) {
      listener(offset);
    }
  }

  void addListener(ValueChanged<double> listener) {
    _listeners.add(listener);
  }
}

class MergePathsDrawable extends AnimationDrawable implements PathContent {
  final MergePathsMode _mode;
  final List<PathContent> _pathContents = <PathContent>[];

  MergePathsDrawable(String name, Repaint repaint, this._mode, BaseLayer layer)
      : super(name, repaint, layer);

  void addContentIfNeeded(Content content) {
    if (content is PathContent) {
      _pathContents.add(content);
    }
  }

  @override
  void setContents(List<Content> contentsBefore, List<Content> contentsAfter) {
    for (PathContent pathContent in _pathContents) {
      pathContent.setContents(contentsBefore, contentsAfter);
    }
  }

  @override
  Path get path {
    //final path = new Path();

    switch (_mode) {
      case MergePathsMode.Merge:
        return addPaths();
      case MergePathsMode.Add:
        return opFirstPathWithRest(PathOperation.union);
      case MergePathsMode.Subtract:
        return opFirstPathWithRest(PathOperation.reverseDifference);
      case MergePathsMode.Intersect:
        // TODO: figure out why this is broken.
        // return opFirstPathWithRest(PathOperation.intersect);
        return opFirstPathWithRest(PathOperation.union);
      case MergePathsMode.ExcludeIntersections:
        return opFirstPathWithRest(PathOperation.xor);
      default:
        return new Path();
    }

    //return path;
  }

  Path addPaths() {
    final Path path = new Path();
    for (PathContent pathContent in _pathContents) {
      path.addPath(pathContent.path, const Offset(0.0, 0.0));
    }
    return path;
  }

  Path opFirstPathWithRest(PathOperation op) {
    Path firstPath = new Path();
    final Path remainderPath = new Path();

    for (int i = _pathContents.length - 1; i >= 1; i--) {
      final PathContent content = _pathContents[i];

      if (content is DrawableGroup) {
        final List<PathContent> paths = content.paths;
        for (int j = paths.length - 1; j >= 0; j--) {
          final Path nextPath = paths[j].path;
          nextPath.transform(content.transformation.storage);
          remainderPath.addPath(nextPath, const Offset(0.0, 0.0));
        }
      } else {
        remainderPath.addPath(content.path, const Offset(0.0, 0.0));
      }
    }

    final PathContent lastContent = _pathContents[0];
    if (lastContent is DrawableGroup) {
      final List<PathContent> paths = lastContent.paths;
      for (int j = 0; j < paths.length; j++) {
        final Path nextPath = paths[j].path;
        firstPath.addPath(nextPath, Offset.zero,
            matrix4: lastContent.transformation.storage);
      }
    } else {
      firstPath = lastContent.path;
    }

    // TODO: figure out why this is broken.
    // this is broken in android as well - just doesn't show up because it's usually disabled.
    return Path.combine(op, firstPath, remainderPath);

    // firstPath.op(op, firstPath, remainderPath);
    // return firstPath;
  }
}
