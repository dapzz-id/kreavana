class ApiPool {
  static Future<List<T>> run<T>(
    Iterable<Future<T> Function()> jobs, {
    int concurrency = 5,
  }) async {
    final queue = jobs.toList();
    final results = List<T?>.filled(queue.length, null);
    var nextIndex = 0;

    Future<void> worker() async {
      while (nextIndex < queue.length) {
        final current = nextIndex++;
        results[current] = await queue[current]();
      }
    }

    final workerCount = concurrency.clamp(1, 5);
    await Future.wait(
      List.generate(
        queue.length < workerCount ? queue.length : workerCount,
        (_) => worker(),
      ),
    );

    return results.cast<T>();
  }
}
