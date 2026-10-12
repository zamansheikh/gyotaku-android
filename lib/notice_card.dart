import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'activity.dart';
import 'reader.dart';
import 'theme.dart';

/// Offers the progress notification, in the app's own words, before
/// Android asks in its. One line at the foot of the progress notice, and
/// only while a long read is under way: that is when someone will put the
/// app away before it is over, and the only time the notification is worth
/// having. A read of a few seconds is never interrupted with it, and once
/// the reading is done the line is gone with the notice.
///
/// The system's prompt only comes after "Turn on". Closing the line means
/// not now: it is left alone for a day, then a week, and a third no is
/// taken as the answer. The switch stays in settings throughout.
class NoticeAsk extends StatefulWidget {
  const NoticeAsk({super.key, required this.reader});

  final Reader reader;

  @override
  State<NoticeAsk> createState() => _NoticeAskState();
}

class _NoticeAskState extends State<NoticeAsk> with WidgetsBindingObserver {
  // How long a no is left alone: after the first, and after the second.
  // After one more than there are waits, the line stops asking.
  static const _waits = [Duration(days: 1), Duration(days: 7)];

  // Nothing is shown until both are known, so the line never flashes up
  // on a phone that already allows notifications.
  bool? _allowed;
  _Asks? _asks;

  // Once up, the line stays for the rest of the read. One that turns out
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

  static bool _reading(Reader reader) =>
      reader.state == ReaderState.reading ||
      reader.state == ReaderState.preparing;

  /// A read long enough that someone will put the app away before it is
  /// over: the slow second pass, the wait for its readers, or a first pass
  /// with more than half a minute to go.
  static bool _long(Reader reader) => switch (reader.state) {
    ReaderState.preparing => true,
    ReaderState.reading =>
      reader.deep ||
          reader.next != null ||
          (reader.left ?? Duration.zero) > const Duration(seconds: 30),
    _ => false,
  };

  bool _due(Reader reader) {
    final asks = _asks;
    if (asks == null || asks.refusals > _waits.length) return false;
    if (!_long(reader)) return false;
    if (asks.refusals == 0) return true;
    final since = DateTime.now().difference(asks.at);
    return since >= _waits[asks.refusals - 1];
  }

  /// Whether this is the last time the line will ask by itself.
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

  // Listens for itself: whoever holds this may not build it again each
  // time the reader moves on.
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.reader,
    builder: (context, _) => _line(context),
  );

  Widget _line(BuildContext context) {
    final reader = widget.reader;
    if (_allowed != false || !_reading(reader)) {
      _showing = false;
      return const SizedBox.shrink();
    }
    if (!_showing && _due(reader)) _showing = true;
    if (!_showing) return const SizedBox.shrink();

    final p = Palette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Container(height: 1, color: p.track),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.notifications_none, size: 19, color: p.muted),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Progress notification',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: p.text,
                    ),
                  ),
                  Text(
                    _last
                        ? 'Last time of asking. It stays in settings'
                        : 'See this with the app put away',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.3,
                      color: p.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            PillButton(label: 'Turn on', onTap: () => _answer(ask: true)),
            IconButton(
              onPressed: () => _answer(ask: false),
              icon: const Icon(Icons.close, size: 18),
              color: p.muted,
              tooltip: 'Not now',
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      ],
    );
  }
}

/// How many times the offer has been told no, and when last. Kept in a
/// small file beside the app's other choices.
class _Asks {
  const _Asks(this.refusals, this.at);

  final int refusals;
  final DateTime at;

  // Where there is no telling, the line keeps quiet: better none than one
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
