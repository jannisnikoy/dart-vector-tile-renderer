import 'dart:collection';

import 'expression.dart';

extension ExpressionList on List<Expression> {
  List<String> joinProperties() {
    final accumulator = HashSet<String>();
    for (final expression in this) {
      accumulator.addAll(expression.properties());
    }
    return accumulator.toList();
  }
}
