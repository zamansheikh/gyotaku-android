import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'mark.dart';
import 'reader.dart';
import 'theme.dart';

/// Asks whether the reading progress may be shown in a notification, in
/// the app's own words, before Android asks in its.
///
/// It sits under the progress banner with a picture of the notification
/// itself, and it is not in the way: reading goes on whatever is answered.
/// The system's prompt only comes after "Show progress".
///
/// "Not now" means not now. The first time, the card is there as soon as
/// anything is read. After a no it comes back only while a long read is
/// under way, which is when the notification is worth having, and not
/// before a day has gone by; after a second no, a week. A third is taken
/// as the answer and the card is not shown again. The switch stays in
/// settings throughout.
class NoticeCard extends StatefulWidget {
  const NoticeCard({super.key, required this.reader});

  final Reader reader;

  @override
  State<NoticeCard> createState() => _NoticeCardState();
}

class _NoticeCardState extends State<NoticeCard> with WidgetsBindingObserver {
  // How long a no is left alone: after the first, and after the second.
  // After one more than there are waits, the card stops asking.
  static const _waits = [Duration(days: 1), Duration(days: 7)];

  // Nothing is shown until both are known, so the card never flashes up
  // on a phone that already allows notifications.
  bool? _allowed;
  _Asks? _asks;

  // Once up, the card stays until it is answered. A read that turns out
  // shorter than it looked must not take it away mid-sentence.
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _look();
    _Asks.load().then((asks) {
      if (mounted) setState(() => _asks = asks);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // The system's prompt, and its settings, both take the app off the
  // screen. Coming back is when the answer may have changed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _look();
  }

  Future<void> _look() async {
    final allowed = await widget.reader.noticeAllowed();
    if (mounted) setState(() => _allowed = allowed);
  }

  /// A read long enough that someone will put the app away before it is
  /// over: the slow second pass, the wait for its readers, or a first pass
  /// with more than a minute to go.
  static bool _long(Reader reader) => switch (reader.state) {
    ReaderState.preparing => true,
    ReaderState.reading =>
      reader.deep ||
          reader.next != null ||
          (reader.left ?? Duration.zero) > const Duration(minutes: 1),
    _ => false,
  };

  bool _due(Reader reader) {
    final asks = _asks;
    if (asks == null) return false;
    if (asks.refusals == 0) {
      return switch (reader.state) {
        ReaderState.checking ||
        ReaderState.preparing ||
        ReaderState.reading ||
        ReaderState.done => true,
        _ => false,
      };
    }
    if (asks.refusals > _waits.length) return false;
    final since = DateTime.now().difference(asks.at);
    return since >= _waits[asks.refusals - 1] && _long(reader);
  }

  /// Whether this is the last time the card will ask by itself.
  bool get _last => (_asks?.refusals ?? 0) >= _waits.length;

  Future<void> _answer({required bool ask}) async {
    final last = _last;
    if (ask) {
      await widget.reader.askForNotice();
      final allowed = await widget.reader.noticeAllowed();
      if (!mounted) return;
      setState(() => _allowed = allowed);
      if (allowed) return;
    }
    // A no here, or one given to Android's prompt, counts the same.
    final asks = _Asks((_asks?.refusals ?? 0) + 1, DateTime.now());
    setState(() {
      _asks = asks;
      _showing = false;
    });
    await asks.save();
    if (!ask && mounted) {
      say(
        context,
        last
            ? 'It can still be turned on in settings'
            : 'It can be turned on in settings whenever you like',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.reader,
      builder: (context, _) {
        if (_allowed != false) {
          _showing = false;
          return const SizedBox.shrink();
        }
        if (!_showing && _due(widget.reader)) _showing = true;
        if (!_showing) return const SizedBox.shrink();

        final p = Palette.of(context);
        final again = (_asks?.refusals ?? 0) > 0;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          decoration: BoxDecoration(
            color: p.tile,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Picture(),
              const SizedBox(height: 14),
              Text(
                'See the progress outside the app',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: p.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                again
                    ? 'This part takes a while, and it carries on when '
                          'gyotaku is put away. A notification can show '
                          'how far it has got, with a button to pause it.'
                    : 'Reading carries on when gyotaku is put away. A '
                          'notification can show how far it has got, with '
                          'a button to pause it. gyotaku sends no other '
                          'kind.',
                style: TextStyle(fontSize: 13.5, height: 1.4, color: p.muted),
              ),
              if (_last) ...[
                const SizedBox(height: 6),
                Text(
                  'This is the last time gyotaku asks. The switch stays in '
                  'settings.',
                  style: TextStyle(fontSize: 13, height: 1.4, color: p.faint),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  InkButton(
                    label: 'Show progress',
                    onPressed: () => _answer(ask: true),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () => _answer(ask: false),
                    style: TextButton.styleFrom(
                      foregroundColor: p.muted,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      textStyle: const TextStyle(
                        fontFamily: 'IBM Plex Sans',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: Text(_last ? 'No thanks' : 'Not now'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The notification as it will look, near enough: the mark, what is being
/// read, how far along, and Pause. A picture, so its text keeps its size.
class _Picture extends StatelessWidget {
  const _Picture();

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ExcludeSemantics(
      child: MediaQuery.withNoTextScaling(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
          decoration: BoxDecoration(
            color: p.panel,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Mark(size: 30),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'gyotaku',
                      style: TextStyle(fontSize: 11.5, color: p.muted),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Reading screenshots',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: p.text,
                      ),
                    ),
                    Text(
                      '128 of 163, about 12 s left',
                      style: TextStyle(fontSize: 12.5, color: p.muted),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: 128 / 163,
                        minHeight: 3,
                        backgroundColor: p.track,
                        valueColor: AlwaysStoppedAnimation(p.text),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      'Pause',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: p.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How many times the card has been told no, and when last. Kept in a
/// small file beside the app's other choices.
class _Asks {
  const _Asks(this.refusals, this.at);

  final int refusals;
  final DateTime at;

  // Where there is no telling, the card keeps quiet: better none than one
  // that comes back every time.
  static final _unknown = _Asks(1 << 20, DateTime.now());

  static Future<File?> _file() async {
    try {
      final dir = await getApplicationSupportDirectory();
      return File('${dir.path}/notice-asks.json');
    } catch (e) {
      return null;
    }
  }

  static Future<_Asks> load() async {
    try {
      final file = await _file();
      if (file == null) return _unknown;
      if (!await file.exists()) {
        return _Asks(0, DateTime.fromMillisecondsSinceEpoch(0));
      }
      final saved = jsonDecode(await file.readAsString()) as Map;
      return _Asks(
        saved['refusals'] as int,
        DateTime.fromMillisecondsSinceEpoch(saved['at'] as int),
      );
    } catch (e) {
      debugPrint('gyotaku: could not load the notification answers: $e');
      return _unknown;
    }
  }

  Future<void> save() async {
    try {
      await (await _file())?.writeAsString(
        jsonEncode({'refusals': refusals, 'at': at.millisecondsSinceEpoch}),
      );
    } catch (e) {
      debugPrint('gyotaku: could not remember the notification answer: $e');
    }
  }
}
