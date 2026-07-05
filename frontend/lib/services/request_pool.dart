class RequestPool {
  static Future<List<T>> run<T>(
    List<Future<T> Function()> tasks, {
    int concurrencyLimit = 5,
  }) async {
    if (tasks.isEmpty) {
      return <T>[];
    }

    final results = List<T?>.filled(tasks.length, null);
    var nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        final currentIndex = nextIndex;
        if (currentIndex >= tasks.length) {
          return;
        }

        nextIndex += 1;
        results[currentIndex] = await tasks[currentIndex]();
      }
    }

    final workerCount = tasks.length < concurrencyLimit
        ? tasks.length
        : concurrencyLimit;
    await Future.wait(List.generate(workerCount, (_) => worker()));

    return results.cast<T>();
  }
}
