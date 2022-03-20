// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui show Color;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart';

import 'layer.dart';
import 'object.dart';
import 'proxy_box.dart';
import 'sliver.dart';

/// A base class for sliver render objects that resemble their children.
///
/// A proxy sliver has a single child and simply mimics all the properties of
/// that child by calling through to the child for each function in the render
/// sliver protocol. For example, a proxy sliver determines its geometry by
/// asking its sliver child to layout with the same constraints and then
/// matching the geometry.
///
/// A proxy sliver isn't useful on its own because you might as well just
/// replace the proxy sliver with its child. However, RenderProxySliver is a
/// useful base class for render objects that wish to mimic most, but not all,
/// of the properties of their sliver child.
///
/// See also:
///
///  * [RenderProxyBox], a base class for render boxes that resemble their
///    children.
abstract class RenderProxySliver extends RenderSliver with RenderObjectWithChildMixin<RenderSliver> {
  /// Creates a proxy render sliver.
  ///
  /// Proxy render slivers aren't created directly because they simply proxy
  /// the render sliver protocol to their sliver [child]. Instead, use one of
  /// the subclasses.
  RenderProxySliver([RenderSliver? child]) {
    this.child = child;
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! SliverPhysicalParentData)
      child.parentData = SliverPhysicalParentData();
  }

  @override
  void performLayout() {
    assert(child != null);
    child!.layout(constraints, parentUsesSize: true);
    geometry = child!.geometry;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null)
      context.paintChild(child!, offset);
  }

  @override
  bool hitTestChildren(SliverHitTestResult result, {required double mainAxisPosition, required double crossAxisPosition}) {
    return child != null
      && child!.geometry!.hitTestExtent > 0
      && child!.hitTest(
        result,
        mainAxisPosition: mainAxisPosition,
        crossAxisPosition: crossAxisPosition,
      );
  }

  @override
  double childMainAxisPosition(RenderSliver child) {
    assert(child != null);
    assert(child == this.child);
    return 0.0;
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    assert(child != null);
    final SliverPhysicalParentData childParentData = child.parentData! as SliverPhysicalParentData;
    childParentData.applyPaintTransform(transform);
  }
}

/// Makes its sliver child partially transparent.
///
/// This class paints its sliver child into an intermediate buffer and then
/// blends the sliver child back into the scene, partially transparent.
///
/// For values of opacity other than 0.0 and 1.0, this class is relatively
/// expensive, because it requires painting the sliver child into an intermediate
/// buffer. For the value 0.0, the sliver child is simply not painted at all.
/// For the value 1.0, the sliver child is painted immediately without an
/// intermediate buffer.
class RenderSliverOpacity extends RenderProxySliver {
  /// Creates a partially transparent render object.
  ///
  /// The [opacity] argument must be between 0.0 and 1.0, inclusive.
  RenderSliverOpacity({
    double opacity = 1.0,
    bool alwaysIncludeSemantics = false,
    RenderSliver? sliver,
  }) : assert(opacity != null && opacity >= 0.0 && opacity <= 1.0),
       assert(alwaysIncludeSemantics != null),
       _opacity = opacity,
       _alwaysIncludeSemantics = alwaysIncludeSemantics,
       _alpha = ui.Color.getAlphaFromOpacity(opacity) {
    child = sliver;
  }

  @override
  bool get alwaysNeedsCompositing => child != null && (_alpha > 0);

  int _alpha;

  /// The fraction to scale the child's alpha value.
  ///
  /// An opacity of 1.0 is fully opaque. An opacity of 0.0 is fully transparent
  /// (i.e. invisible).
  ///
  /// The opacity must not be null.
  ///
  /// Values 1.0 and 0.0 are painted with a fast path. Other values
  /// require painting the child into an intermediate buffer, which is
  /// expensive.
  double get opacity => _opacity;
  double _opacity;
  set opacity(double value) {
    assert(value != null);
    assert(value >= 0.0 && value <= 1.0);
    if (_opacity == value)
      return;
    final bool didNeedCompositing = alwaysNeedsCompositing;
    final bool wasVisible = _alpha != 0;
    _opacity = value;
    _alpha = ui.Color.getAlphaFromOpacity(_opacity);
    if (didNeedCompositing != alwaysNeedsCompositing)
      markNeedsCompositingBitsUpdate();
    markNeedsPaint();
    if (wasVisible != (_alpha != 0) && !alwaysIncludeSemantics)
      markNeedsSemanticsUpdate();
  }

  /// Whether child semantics are included regardless of the opacity.
  ///
  /// If false, semantics are excluded when [opacity] is 0.0.
  ///
  /// Defaults to false.
  bool get alwaysIncludeSemantics => _alwaysIncludeSemantics;
  bool _alwaysIncludeSemantics;
  set alwaysIncludeSemantics(bool value) {
    if (value == _alwaysIncludeSemantics)
      return;
    _alwaysIncludeSemantics = value;
    markNeedsSemanticsUpdate();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null && child!.geometry!.visible) {
      if (_alpha == 0) {
  