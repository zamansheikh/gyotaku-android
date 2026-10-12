import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'mark.dart';
import 'reader.dart';
import 'theme.dart';

/// Asks whether the reading progress may be shown in a notification, in
/// the app's own words, before Android asks in its.
///
/// It sits under the progress banner once there is something being read,
/// with a picture of the notification itself, and it is not in the way:
/// reading goes on whatever is answered. The system's prompt only comes
/// after "Show progress". "Not now" is remembered and the card is not
/// shown again.
class NoticeCard extends StatefulWidget {
  const NoticeCard({super.key, required this.reader});

  final Reader reader;

  @override
  State<NoticeCard> createState() => _NoticeCardState();
}

class _NoticeCardState extends State<NoticeCard> with WidgetsBindingObserver {
  // Nothing is shown until both are known, so the card never flashes up
  // on a phone that already allows notifications.
  bool? _allowed;
  bool? _answered;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _look();
    _Answered.get().then((answered) {
      if (mounted) setState(() => _answered = answered);
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

  Future<void> _answer({required bool ask}) async {
    setState(() => _answered = true);
    await _Answered.set();
    if (ask) await widget.reader.askForNotice();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.reader,
      builder: (context, _) {
        final reading = switch (widget.reader.state) {
          ReaderState.checking ||
          ReaderState.preparing ||
          ReaderState.reading ||
          ReaderState.done => true,
          _ => false,
        };
        if (!reading || _allowed != false || _answered != false) {
          return const SizedBox.shrink();
        }
        final p = Palette.of(context);
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
                'Reading carries on when gyotaku is put away. A '
                'notification can show how far it has got, with a button '
                'to pause it. gyotaku sends no other kind.',
                style: TextStyle(fontSize: 13.5, height: 1.4, color: p.muted),
              ),
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
                    child: const Text('Not now'),
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

/// Whether the card has been answered, kept as a file that is there or
/// isn't, like the pause.
class _Answered {
  static Future<File?> _file() async {
    try {
      final dir = await getApplicationSupportDirectory();
      return File('${dir.path}/notice-answered');
    } catch (e) {
      return null;
    }
  }

  // Not knowing counts as answered: better no card than one that comes
  // back every time.
  static Future<bool> get() async {
    try {
      return await (await _file())?.exists() ?? true;
    } catch (e) {
      return true;
    }
  }

  static Future<void> set() async {
    try {
      await (await _file())?.create(recursive: true);
    } catch (e) {
      debugPrint('gyotaku: could not remember the notification answer: $e');
    }
  }
}
