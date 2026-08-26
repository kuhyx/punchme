/// The one file that talks to the NFC plugin.
library;

import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import 'package:punchme/nfc/ndef_codec.dart';
import 'package:punchme/nfc/punch_tag.dart';

/// Checks whether the device can use NFC at all.
typedef NfcAvailabilityProbe = Future<NfcAvailability> Function();

/// Starts a reader session, calling back for each tag discovered.
typedef NfcSessionStart =
    Future<void> Function({
      required Set<NfcPollingOption> pollingOptions,
      required void Function(NfcTag) onDiscovered,
    });

/// Ends the reader session.
typedef NfcSessionStop = Future<void> Function();

/// Resolves the NDEF view of a discovered tag, or null when it has none.
typedef NdefResolver = Ndef? Function(NfcTag);

/// Why writing a tag failed.
enum NfcWriteFailure {
  /// The tag has no NDEF support, or was locked read-only.
  notWritable,

  /// The payload does not fit in the tag's capacity.
  tooLarge,

  /// The tag left the field, or the write threw for another reason.
  interrupted,

  /// The write reported success but reading it back disagreed.
  verifyMismatch,
}

/// Raised when [NfcService.writeTag] cannot complete.
class NfcWriteException implements Exception {
  /// Creates an exception for [failure].
  const NfcWriteException(this.failure);

  /// What went wrong.
  final NfcWriteFailure failure;

  @override
  String toString() => 'NfcWriteException($failure)';
}

/// Reads and writes punchme clock tags.
///
/// Every plugin entry point arrives as an injected function, following the
/// same shape `checkout_alarm.dart` uses for the SET_ALARM intent: the real
/// implementations are thin enough to exercise over a mocked channel, and the
/// branching that actually needs testing lives here rather than in a stub.
class NfcService {
  /// Creates a service, defaulting to the real plugin.
  NfcService({
    NfcAvailabilityProbe? availability,
    NfcSessionStart? startSession,
    NfcSessionStop? stopSession,
    NdefResolver? ndefFrom,
  }) : _availability = availability ?? _defaultAvailability,
       _startSession = startSession ?? _defaultStartSession,
       _stopSession = stopSession ?? _defaultStopSession,
       _ndefFrom = ndefFrom ?? Ndef.from;

  final NfcAvailabilityProbe _availability;
  final NfcSessionStart _startSession;
  final NfcSessionStop _stopSession;
  final NdefResolver _ndefFrom;

  /// Whether NFC is present and switched on.
  Future<NfcAvailability> checkAvailability() => _availability();

  /// Starts listening for tags, reporting each punchme tag to [onPunch].
  ///
  /// [onOther] fires for a tag that is readable but not ours -- a blank tag
  /// the user meant to write, say. A tag carrying no NDEF at all is reported
  /// as a blank one, since that is what an unwritten tag looks like.
  Future<void> startReading({
    required void Function(PunchTag) onPunch,
    void Function()? onOther,
  }) => _startSession(
    pollingOptions: const <NfcPollingOption>{NfcPollingOption.iso14443},
    onDiscovered: (tag) => _dispatch(tag, onPunch, onOther),
  );

  void _dispatch(
    NfcTag tag,
    void Function(PunchTag) onPunch,
    void Function()? onOther,
  ) {
    final message = _ndefFrom(tag)?.cachedMessage;
    if (message == null) {
      onOther?.call();
      return;
    }
    final PunchTag? punch;
    try {
      punch = readPunchTag(message);
    } on FormatException {
      // Ours, but unreadable. Treated as "not a clock tag" rather than
      // surfaced: a corrupt payload is not something the user can act on
      // mid-tap, and the write screen can rewrite it.
      onOther?.call();
      return;
    }
    if (punch == null) {
      onOther?.call();
      return;
    }
    onPunch(punch);
  }

  /// Stops listening.
  Future<void> stopReading() => _stopSession();

  /// Waits for a tag, writes [tag] onto it, then reports the outcome.
  ///
  /// [onDone] receives null on success, or the reason it failed. The session
  /// is closed either way, so the caller never has to unwind it.
  Future<void> startWriting({
    required PunchTag tag,
    required void Function(NfcWriteFailure?) onDone,
  }) => _startSession(
    pollingOptions: const <NfcPollingOption>{NfcPollingOption.iso14443},
    onDiscovered: (discovered) async {
      NfcWriteFailure? failure;
      try {
        await writeTag(discovered: discovered, tag: tag);
      } on NfcWriteException catch (e) {
        failure = e.failure;
      }
      await _stopSession();
      onDone(failure);
    },
  );

  /// Writes [tag] onto the NDEF tag [discovered], then reads it back.
  ///
  /// Throws [NfcWriteException] rather than letting a plugin error escape, so
  /// the write screen has one thing to catch and a reason to show.
  Future<void> writeTag({
    required NfcTag discovered,
    required PunchTag tag,
  }) async {
    final ndef = _ndefFrom(discovered);
    if (ndef == null || !ndef.isWritable) {
      throw const NfcWriteException(NfcWriteFailure.notWritable);
    }
    final message = buildPunchMessage(tag);
    if (message.byteLength > ndef.maxSize) {
      throw const NfcWriteException(NfcWriteFailure.tooLarge);
    }
    try {
      await ndef.write(message: message);
      // Read back rather than trusting the write: a tag pulled out of the
      // field mid-write can report success with only part of the payload on it.
      final written = await ndef.read();
      if (written == null || readPunchTag(written) != tag) {
        throw const NfcWriteException(NfcWriteFailure.verifyMismatch);
      }
    } on NfcWriteException {
      rethrow;
    } on Exception {
      throw const NfcWriteException(NfcWriteFailure.interrupted);
    }
  }
}

Future<NfcAvailability> _defaultAvailability() =>
    NfcManager.instance.checkAvailability();

Future<void> _defaultStartSession({
  required Set<NfcPollingOption> pollingOptions,
  required void Function(NfcTag) onDiscovered,
}) => NfcManager.instance.startSession(
  pollingOptions: pollingOptions,
  onDiscovered: onDiscovered,
);

Future<void> _defaultStopSession() => NfcManager.instance.stopSession();
