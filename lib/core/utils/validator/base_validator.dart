abstract class Validator<T> {
  /// Returns an error message when [value] is invalid, otherwise `null`.
  String? validate(T value);
}
