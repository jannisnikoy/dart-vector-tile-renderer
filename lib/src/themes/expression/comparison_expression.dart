import 'expression.dart';

class ComparisonExpression extends Expression {
  final Expression _first;
  final Expression _second;
  final bool Function(num, num) _comparison;

  ComparisonExpression(
      this._comparison, String comparisonKey, this._first, this._second)
      : super(
            '(${_first.cacheKey} $comparisonKey ${_second.cacheKey})',
            <String>{..._first.properties(), ..._second.properties()}
                .toList(growable: false));

  @override
  evaluate(EvaluationContext context) {
    final first = _first.evaluate(context);
    final second = _second.evaluate(context);
    if (first is num && second is num) {
      return _comparison(first, second);
    }
    return false;
  }

  @override
  bool get isConstant => _first.isConstant && _second.isConstant;
}

class MatchExpression extends Expression {
  final Expression _input;
  final List<List<Expression>> _values;
  final List<Expression> _outputs;

  MatchExpression(this._input, this._values, this._outputs)
      : super(
            'match(${_input.cacheKey},${_values.map((e) => "[${e.map((i) => i.cacheKey).join(',')}]").join(',')},${_outputs.map((e) => e.cacheKey).join(',')})',
            _createProperties(_input, _values, _outputs));

  @override
  evaluate(EvaluationContext context) {
    final input = _input.evaluate(context);
    if (input != null) {
      for (int index = 0;
          index < _values.length && index < _outputs.length;
          ++index) {
        if (_values[index].any((e) => e.evaluate(context) == input)) {
          return _outputs[index].evaluate(context);
        }
      }
    }
    if (_outputs.length > _values.length) {
      return _outputs.last.evaluate(context);
    }
  }

  @override
  bool get isConstant => false;
}

@override
List<String> _createProperties(Expression input,
    final List<List<Expression>> values, final List<Expression> outputs) {
  final accumulator = <String>{...input.properties()};
  for (final value in values) {
    for (final delegate in value) {
      accumulator.addAll(delegate.properties());
    }
  }
  for (final output in outputs) {
    accumulator.addAll(output.properties());
  }
  return accumulator.toList(growable: false);
}
