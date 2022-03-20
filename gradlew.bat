// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'box.dart';
import 'object.dart';
import 'table_border.dart';

/// Parent data used by [RenderTable] for its children.
class TableCellParentData extends BoxParentData {
  /// Where this cell should be placed vertically.
  ///
  /// When using [TableCellVerticalAlignment.baseline], the text baseline must be set as well.
  TableCellVerticalAlignment? verticalAlignment;

  /// The column that the child was in the last time it was laid out.
  int? x;

  /// The row that the child was in the last time it was laid out.
  int? y;

  @override
  String toString() => '${super.toString()}; ${verticalAlignment == null ? "default vertical alignment" : "$verticalAlignment"}';
}

/// Base class to describe how wide a column in a [RenderTable] should be.
///
/// To size a column to a specific number of pixels, use a [FixedColumnWidth].
/// This is the cheapest way to size a column.
///
/// Other algorithms that are relatively cheap include [FlexColumnWidth], which
/// distributes the space equally among the flexible columns,
/// [FractionColumnWidth], which sizes a column based on the size of the
/// table's container.
@immutable
abstract class TableColumnWidth {
  /// Abstract const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  const TableColumnWidth();

  /// The smallest width that the column can have.
  ///
  /// The `cells` argument is an iterable that provides all the cells
  /// in the table for this column. Walking the cells is by definition
  /// O(N), so algorithms that do that should be considered expensive.
  ///
  /// The `containerWidth` argument is the `maxWidth` of the incoming
  /// constraints for the table, and might be infinite.
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth);

  /// The ideal width that the column should have. This must be equal
  /// to or greater than the [minIntrinsicWidth]. The column might be
  /// bigger than this width, e.g. if the column is flexible or if the
  /// table's width ends up being forced to be bigger than the sum of
  /// all the maxIntrinsicWidth values.
  ///
  /// The `cells` argument is an iterable that provides all the cells
  /// in the table for this column. Walking the cells is by definition
  /// O(N), so algorithms that do that should be considered expensive.
  ///
  /// The `containerWidth` argument is the `maxWidth` 