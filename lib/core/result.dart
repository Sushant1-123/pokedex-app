/// A sealed Result type so every layer can pattern-match on outcomes instead
/// of throwing/catching everywhere or juggling nullable + isLoading + error
/// fields separately. This is the "Dart 3 leverage" the brief asks for.
sealed class Result<T> {
  const Result();
}

class Loading<T> extends Result<T> {
  const Loading();
}

class Success<T> extends Result<T> {
  final T data;
  final bool fromCache;
  const Success(this.data, {this.fromCache = false});
}

class Failure<T> extends Result<T> {
  final String message;
  const Failure(this.message);
}

extension ResultMatch<T> on Result<T> {
  R when<R>({
    required R Function() loading,
    required R Function(T data, bool fromCache) success,
    required R Function(String message) failure,
  }) {
    return switch (this) {
      Loading<T>() => loading(),
      Success<T>(data: final d, fromCache: final c) => success(d, c),
      Failure<T>(message: final m) => failure(m),
    };
  }
}
