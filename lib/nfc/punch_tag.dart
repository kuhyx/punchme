/// The payload punchme writes to, and reads from, a clock tag.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

/// The MIME type identifying a punchme clock tag.
///
/// Identity is the MIME record, never the tag UID: a custom type routes
/// straight to this app with no chooser, and needs no enrolment flow, so a
/// replacement tag works the moment it is written.
const String kPunchMime = 'application/vnd.kuhy.punchme';

/// The payload version this build writes.
const int kPunchTagVersion = 1;

/// The label used when a tag omits one.
const String kDefaultTagLabel = 'default';

/// A decoded clock tag.
///
/// Parsing is deliberately forgiving in one direction only: a record that is
/// *ours* but oddly shaped still yields a usable tag, because refusing to
/// clock someone in over a missing field would be worse than guessing. A
/// record that is not ours at all is rejected outright by the codec.
@immutable
class PunchTag {
  /// Creates a tag.
  const PunchTag({
    this.version = kPunchTagVersion,
    this.label = kDefaultTagLabel,
  });

  /// Rebuilds a tag from its decoded [json] map.
  ///
  /// Missing fields fall back to their defaults; unknown fields are ignored,
  /// so a tag written by a later version stays readable here.
  factory PunchTag.fromJson(Map<String, dynamic> json) {
    final version = json['v'];
    final label = json['tag'];
    return PunchTag(
      version: version is int ? version : kPunchTagVersion,
      label: label is String && label.isNotEmpty ? label : kDefaultTagLabel,
    );
  }

  /// Decodes a tag from a record's raw UTF-8 JSON [payload].
  ///
  /// Throws [FormatException] when the payload is not a JSON object. That is
  /// the one hard failure: it means the record claimed our MIME type and then
  /// carried something else, which is worth surfacing rather than guessing at.
  factory PunchTag.fromBytes(Uint8List payload) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(payload));
    } on FormatException {
      throw const FormatException('punchme tag payload is not valid JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('punchme tag payload is not a JSON object');
    }
    return PunchTag.fromJson(decoded);
  }

  /// The payload schema version found on the tag.
  final int version;

  /// The human label for this tag, e.g. `desk`. Shown in the result banner.
  final String label;

  /// Whether this build understands [version].
  ///
  /// A false here does not block the punch -- the coordinator commits anyway
  /// and warns once, since a tag from a newer build still means "clock me".
  bool get isKnownVersion => version == kPunchTagVersion;

  /// This tag as a JSON-encodable map.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'v': version,
    'tag': label,
  };

  /// This tag as the raw UTF-8 JSON bytes to write into a record.
  Uint8List toBytes() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  @override
  bool operator ==(Object other) =>
      other is PunchTag && other.version == version && other.label == label;

  @override
  int get hashCode => Object.hash(version, label);

  @override
  String toString() => 'PunchTag(v$version, $label)';
}
