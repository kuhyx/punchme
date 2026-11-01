/// Handing an exported file to the user's device storage.
library;

import 'package:data_transfer_flutter/data_transfer_flutter.dart';

/// Delivers [contents] to the user as a file named [fileName].
///
/// A seam so the UI tests need no platform plumbing.
typedef ShareFile =
    Future<void> Function({
      required String fileName,
      required String contents,
      required String subject,
    });

/// MIME type for [fileName], from its extension.
String mimeTypeFor(String fileName) {
  if (fileName.endsWith('.csv')) return 'text/csv';
  if (fileName.endsWith('.ics')) return 'text/calendar';
  return 'application/json';
}

/// Default [ShareFile]: the system Save-as picker via `data_transfer_flutter`.
///
/// Not the share sheet: on a stock phone it offers only cloud and chat
/// targets, which would turn an export into an upload. [subject] is unused
/// for the same reason; a saved file has no subject line.
Future<void> saveTextFile({
  required String fileName,
  required String contents,
  required String subject,
}) async {
  await exportTextFile(
    fileName: fileName,
    text: contents,
    mimeType: mimeTypeFor(fileName),
  );
}
