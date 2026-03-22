class UseCaseResult<T> {
  const UseCaseResult.success(this.value)
      : error = null,
        isSuccess = true;

  const UseCaseResult.failure(this.error)
      : value = null,
        isSuccess = false;

  final T? value;
  final String? error;
  final bool isSuccess;
}

class UseCaseException implements Exception {
  UseCaseException(this.message);

  final String message;

  @override
  String toString() => 'UseCaseException: $message';
}
