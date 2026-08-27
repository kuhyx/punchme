import 'package:crdt_sync/crdt_sync.dart';

/// An in-memory [LogPersistence], so a test never touches the filesystem.
///
/// Hand-written rather than generated: this repo uses no mocking package, and
/// the port is two methods.
class FakeLogPersistence implements LogPersistence {
  /// Creates a store that starts holding [text], or nothing.
  FakeLogPersistence([this.text]);

  /// The persisted payload, or null when nothing has been written.
  String? text;

  /// How many times [write] has been called, to pin that a write happened.
  int writes = 0;

  @override
  Future<String?> read() async => text;

  @override
  Future<void> write(String value) async {
    text = value;
    writes++;
  }
}

/// A [LogStore] over a fresh [FakeLogPersistence], hydrated and ready.
Future<LogStore> openFakeStore({
  String nodeId = 'test-device',
  String? initial,
}) async {
  final store = LogStore(
    persistence: FakeLogPersistence(initial),
    nodeId: nodeId,
  );
  await store.load();
  return store;
}
