import 'base_validator.dart';

class CompositeValidator<T> implements Validator<T> {
  final List<Validator<T>> validators;

  CompositeValidator(this.validators);

  @override
  String? validate(T value) {
    for (final validator in validators) {
      final error = validator.validate(value);
      if (error != null) return error;
    }
    return null;
  }
}
