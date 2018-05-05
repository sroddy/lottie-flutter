import 'dart:ui';
import 'package:lottie_flutter/src/animations.dart';
import 'package:lottie_flutter/src/drawing/elements/groups.dart';
import 'package:lottie_flutter/src/drawing/drawing.dart';
import 'package:lottie_flutter/src/values.dart';

///
/// TrimPathDrawable
///
class TrimPathDrawable extends AnimationDrawable {
  final ShapeTrimPathType _type;
  final List<OnValueChanged> _listeners = [];
  final BaseKeyframeAnimation<dynamic, double> _startAnimation;
  final BaseKeyframeAnimation<dynamic, double> _endAnimation;
  final BaseKeyframeAnimation<dynamic, double> _offsetAnimation;

  ShapeTrimPathType get type => _type;

  double get start => _startAnimation.value;

  double get end => _endAnimation.value;

  double get offset => _offsetAnimation.value;

  TrimPathDrawable(String name, Repaint repaint, this._type,
      this._startAnimation, this._endAnimation, this._offsetAnimation)
      : super(name, repaint) {
    addAnimation(_startAnimation);
    addAnimation(_endAnimation);
    addAnimation(_offsetAnimation);
  }

  @override
  void onValueChanged() {
    _listeners.forEach((listener) => listener());
  }

  void addListener(OnValueChanged listener) {
    _listeners.add(listener);
  }
}

class MergePathsDrawable extends AnimationDrawable implements PathContent {
  final MergePathsMode _mode;
  final List<PathContent> _pathContents = [];

  MergePathsDrawable(String name, Repaint repaint, this._mode)
      : super(name, repaint);

  void addContentIfNeeded(Content content) {
    if (content is PathContent) {
      _pathContents.add(content);
    }
  }

  @override
  void setContents(List<Content> contentsBefore, List<Content> contentsAfter) {
    for (var pathContent in _pathContents) {
      pathContent.setContents(contentsBefore, contentsAfter);
    }
  }

  @override
  Path get path {
    var path = new Path();

    switch (_mode) {
      case MergePathsMode.Merge:
        addPaths(path);
        break;
      case MergePathsMode.Add:
        path = _opFirstPathWithRest(PathOperation.union);
        break;
      case MergePathsMode.Subtract:
        path = _opFirstPathWithRest(PathOperation.reverseDifference);
        break;
      case MergePathsMode.Intersect:
        path = _opFirstPathWithRest(PathOperation.intersect);
        break;
      case MergePathsMode.ExcludeIntersections:
        path = _opFirstPathWithRest(PathOperation.xor);
        break;
    }

    return path;
  }

  void addPaths(Path path) {
    for (var pathContent in _pathContents) {
      path.addPath(pathContent.path, const Offset(0.0, 0.0));
    }
  }

  Path _opFirstPathWithRest(PathOperation op) {
    var firstPath = new Path();
    final remainderPath = new Path();

    for (int i = _pathContents.length - 1; i >= 1; i--) {
      final content = _pathContents[i];

      if(content is DrawableGroup) {
        List<PathContent> paths = content.paths;
        for (int j = paths.length - 1; j >= 0; j--) {
          Path nextPath = paths[j].path;
          nextPath.transform(content.transformation.storage);
          remainderPath.addPath(nextPath, const Offset(0.0, 0.0));
        }
      } else {
        remainderPath.addPath(content.path, const Offset(0.0, 0.0));
      }
    }


    final lastContent = _pathContents[0];
    if(lastContent is DrawableGroup) {
      List<PathContent> paths = lastContent.paths;
      for (int j = paths.length - 1; j >= 0; j--) {
        Path nextPath = paths[j].path;
        nextPath.transform(lastContent.transformation.storage);
        firstPath.addPath(nextPath, const Offset(0.0, 0.0));
      }
    } else {
      firstPath = lastContent.path;
    }

    return Path.combine(op, firstPath, remainderPath);
  }
}
