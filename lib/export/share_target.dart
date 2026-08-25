/// Handing an exported file to the Android share sheet.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Writes [contents] to a temporary [fileName] and offers it to the share
/// sheet.
///
/// The temp directory, not app-support: this file is a hand-off artefact, and
/// the OS is free to reclaim it once the share completes.
typedef ShareFile =
    Future<void> Function({
      required String fileName,
      required String contents,
      required String subject,
    });

/// Default [ShareFile] implementation, backed by share_plus.
Future<void> shareTextFile({
  required String fileName,
  required String contents,
  required String subject,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, fileName));
  await file.writeAsString(contents);
  await SharePlus.instance.share(
    ShareParams(files: <XFile>[XFile(file.path)], subject: subject),
  );
}
