import 'models/error.dart';

class ValidationException implements Exception {
  ValidationException(this.message, String type) {
    this.type = type.toError();
  }

  late ErrorType type;
  String message;

  String toString() => message;
}

class FatalException implements Exception {
  FatalException(this.message);

  String message;

  String toString() => message;
}
