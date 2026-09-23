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
