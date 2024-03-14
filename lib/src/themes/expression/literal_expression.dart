import 'expression.dart';

class LiteralExpression extends Expression {
  final dynamic _literal;

  LiteralExpression(this._literal) : super('literal($_literal)', const []);

  @override
  evaluate(EvaluationContext context) => _literal;

  @override
  bool get isConstant => true;
}
