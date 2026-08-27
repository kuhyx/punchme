import 'package:crdt_sync/crdt_sync.dart';

/// An in-memory [RemoteStore], so a test never reaches the network.
///
/// Hand-written rather than generated: this repo uses no mocking package.
/// Files are held in a flat map keyed by full path, which is enough for
/// `syncLog`'s directory listing and read/write calls.
class FakeRemoteStore implements RemoteStore {
  /// Creates a store holding [files], keyed by full path.
  FakeRemoteStore([Map<String, String>? files])
    : files = <String, String>{...?files};

  /// Everything currently stored, by path.
  final Map<String, String> files;

  /// Paths passed to [putFileText], in call order.
  final List<String> writes = <String>[];

  /// Whether [canAccessRemote] should report the remote as reachable.
  bool reachable = true;

  @override
  Future<List<String>> listDirectory(String path) async {
    final prefix = '$path/';
    final names = <String>{};
    for (final key in files.keys) {
      if (!key.startsWith(prefix)) {
        continue;
      }
      names.add(key.substring(prefix.length).split('/').first);
    }
    return names.toList()..sort();
  }

  @override
  Future<String?> getFileText(String path) async => files[path];

  @override
  Future<void> putFileText(
    String path,
    String text, {
    required String message,
  }) async {
    files[path] = text;
    writes.add(path);
  }

  @override
  Future<void> deleteFile(String path, {String message = ''}) async {
    files.remove(path);
  }

  @override
  Future<bool> canAccessRemote() async => reachable;

  /// Whether [close] has been called, so a leak is visible to a test.
  bool closed = false;

  @override
  void close() => closed = true;
}
