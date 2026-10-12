import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:url_launcher/url_launcher.dart';

import 'mark.dart';
import 'reader.dart';
import 'theme.dart';

/// The first thing anyone sees, before the phone has been asked for
/// anything. Access to every photo is a lot to ask of someone who opened
/// the app a second ago, so this says what the app is for, what it does
/// with the images and what it never does, and what Android is about to
/// ask, in that order. The system's own prompt only comes after the button.
class Welcome extends StatelessWidget {
  const Welcome({super.key, required this.onAllow});

  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return _Page(
      action: 'Allow access to photos',
      onAction: onAllow,
      children: [
        Text(
          'Find any screenshot by the text inside it',
          style: TextStyle(
            fontSize: 25,
            height: 1.15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: p.text,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Type a few letters of anything you remember seeing: a '
          'name, an order number, a wifi password.',
          style: TextStyle(fontSize: 15.5, height: 1.45, color: p.muted),
        ),
        const SizedBox(height: 16),
        const _Demo(),
        const SizedBox(height: 22),
        const _Promises(),
        const SizedBox(height: 18),
        Text(
          'Android asks next, for your photos and then for '
          'notifications. Allow all photos, so new screenshots are '
          'found as you take them. The notification is only the '
          'reading progress.',
          style: TextStyle(fontSize: 13.5, height: 1.45, color: p.muted),
        ),
      ],
    );
  }
}

/// What is shown once access to photos has been refused. Someone who said
/// no was not convinced, so this does not scold or just point at the
/// settings: it says plainly why the one permission is needed, repeats
/// what the app does and never does with the photos, and makes saying yes
/// as short as Android lets it be.
class Refused extends StatelessWidget {
  const Refused({super.key, required this.reader});

  final Reader reader;

  // Android shows its prompt a second time and then never again. There is
  // no asking which of the two this is, but a refusal that comes back
  // faster than anyone could read a prompt means none was shown.
  static const _noPrompt = Duration(milliseconds: 700);

  Future<void> _allow() async {
    final clock = Stopwatch()..start();
    await reader.run(ask: true);
    if (reader.state == ReaderState.refused && clock.elapsed < _noPrompt) {
      await PhotoManager.openSetting();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return _Page(
      action: 'Allow access to photos',
      onAction: _allow,
      children: [
        Text(
          'gyotaku has nothing to search yet',
          style: TextStyle(
            fontSize: 25,
            height: 1.15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: p.text,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'It finds a screenshot by reading the text in it, and it can '
          'only read what the phone lets it see. Access to photos is the '
          'one thing it needs, and it was not allowed.',
          style: TextStyle(fontSize: 15.5, height: 1.45, color: p.muted),
        ),
        const SizedBox(height: 22),
        const _Promises(),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: p.tile,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'If Android does not ask again',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: p.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'The button below opens the settings for gyotaku instead. '
                'There:',
                style: TextStyle(fontSize: 13.5, height: 1.4, color: p.muted),
              ),
              const _Step(number: 1, text: 'Tap Permissions'),
              const _Step(number: 2, text: 'Tap Photos and videos'),
              const _Step(number: 3, text: 'Choose to allow all'),
              const _Step(number: 4, text: 'Come back to gyotaku'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'You can take it away again in the same place whenever you like.',
          style: TextStyle(fontSize: 13.5, height: 1.45, color: p.muted),
        ),
      ],
    );
  }
}

/// The frame the two pages share: the mark and name, what the page has to
/// say, and under it the one way forward and the privacy policy.
class _Page extends StatelessWidget {
  const _Page({
    required this.children,
    required this.action,
    required this.onAction,
  });

  final List<Widget> children;
  final String action;
  final VoidCallback onAction;

  Future<void> _policy(BuildContext context) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(privacyPolicy),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('gyotaku: could not open the privacy policy: $e');
    }
    // No browser, or none willing: the address is still worth having.
    if (!opened && context.mounted) {
      await Clipboard.setData(const ClipboardData(text: privacyPolicy));
      if (context.mounted) say(context, 'Copied the link instead');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Mark(size: 40),
                    const SizedBox(width: 12),
                    Text(
                      'gyotaku',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: p.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ...children,
              ],
            ),
          ),
        ),
        // Kept out of the scrolling part, so the way forward is on screen
        // however small the phone or large the text.
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
          child: InkButton(label: action, onPressed: onAction),
        ),
        Center(
          child: TextButton(
            onPressed: () => _policy(context),
            style: TextButton.styleFrom(
              foregroundColor: p.muted,
              textStyle: const TextStyle(
                fontFamily: 'IBM Plex Sans',
                fontSize: 13.5,
                decoration: TextDecoration.underline,
              ),
            ),
            child: const Text('Read the privacy policy'),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

/// A search being made, the way the app answers one: a few letters are
/// typed, the lines that hold them stay lit and carry the mark, and the
/// rest are dimmed. Then another, so it is plain that any part of the text
/// will do.
///
/// The one thing in the app that moves by itself. It is here to show
/// someone who has not used the app yet what it does, which a still
/// picture did not get across. Where the phone is set to reduce motion it
/// stays still, on the first search already made.
class _Demo extends StatefulWidget {
  const _Demo();

  @override
  State<_Demo> createState() => _DemoState();
}

class _DemoState extends State<_Demo> with SingleTickerProviderStateMixin {
  static const _lines = [
    'Order 48213',
    'Out for delivery today',
    '2 items, paid by card',
    'Delivery address: 14 Lake Road',
  ];
  static const _searches = ['deliv', 'lake', '482'];

  // One search, in milliseconds: a pause on the empty field, each letter,
  // a hold on what was found, then the field cleared before the next.
  static const _rest = 900;
  static const _letter = 230;
  static const _hold = 2400;
  static const _clear = 500;

  late final AnimationController _clock = AnimationController(vsync: this)
    ..addListener(_tick)
    ..addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      _search = (_search + 1) % _searches.length;
      _begin();
    });

  int _search = 0;
  int _typed = 0;

  String get _word => _searches[_search];

  int get _length => _rest + _word.length * _letter + _hold + _clear;

  void _begin() {
    _clock
      ..duration = Duration(milliseconds: _length)
      ..forward(from: 0);
  }

  void _tick() {
    final at = _clock.value * _length;
    final int typed;
    if (at >= _length - _clear) {
      typed = 0;
    } else {
      typed = ((at - _rest) / _letter).ceil().clamp(0, _word.length);
    }
    // Only when a letter comes or goes: the rest is eased by the widgets.
    if (typed != _typed) setState(() => _typed = typed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _clock.stop();
      _search = 0;
      _typed = _word.length;
    } else if (!_clock.isAnimating) {
      _typed = 0;
      _begin();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final typed = _word.substring(0, _typed);
    return Semantics(
      label:
          'An example. Searching for deliv finds the lines Out for '
          'delivery today and Delivery address.',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.tile,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: p.panel,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 19, color: p.muted),
                  const SizedBox(width: 8),
                  Text(
                    typed.isEmpty ? 'Search your screenshots' : typed,
                    style: TextStyle(
                      fontSize: 15,
                      color: typed.isEmpty ? p.faint : p.text,
                    ),
                  ),
                  // Where the next letter goes.
                  if (typed.isNotEmpty)
                    Container(
                      width: 1.5,
                      height: 18,
                      margin: const EdgeInsets.only(left: 1),
                      color: p.muted,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            for (final line in _lines) _line(line, typed, p),
          ],
        ),
      ),
    );
  }

  Widget _line(String line, String typed, Palette p) {
    // One letter is in nearly every line. The picture starts to mean
    // something at two.
    final searching = typed.length >= 2;
    final at = searching ? line.toLowerCase().indexOf(typed) : -1;
    final hit = at >= 0;
    const ease = Duration(milliseconds: 220);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // The same mark as beside a matching line of an open screenshot:
          // shu where the search found something.
          AnimatedContainer(
            duration: ease,
            width: 3,
            height: 24,
            decoration: BoxDecoration(
              color: hit ? p.shu : p.shu.withValues(alpha: 0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: ease,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans',
                fontSize: 14.5,
                color: searching && !hit ? p.faint : p.text,
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: hit ? line.substring(0, at) : line),
                    if (hit) ...[
                      TextSpan(
                        text: line.substring(at, at + typed.length),
                        style: TextStyle(
                          color: p.shu,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(text: line.substring(at + typed.length)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the app does with the photos and what it never does. Said before
/// asking, and again to anyone who refused.
class _Promises extends StatelessWidget {
  const _Promises();

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What it does with your photos',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: p.text,
          ),
        ),
        const SizedBox(height: 6),
        const _Promise(
          icon: Icons.phone_android,
          title: 'Read on this phone',
          detail:
              'Nothing is uploaded. There is no account, no ads and no '
              'analytics.',
        ),
        const _Promise(
          icon: Icons.folder_outlined,
          title: 'Only the folders you choose',
          detail:
              'Screenshot folders to begin with. The rest stay unread '
              'unless you turn them on in settings.',
        ),
        const _Promise(
          icon: Icons.visibility_outlined,
          title: 'It only reads',
          detail: 'gyotaku never changes, moves or deletes an image.',
        ),
      ],
    );
  }
}

class _Promise extends StatelessWidget {
  const _Promise({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: p.tile,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: p.muted),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                    color: p.text,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  detail,
                  style: TextStyle(fontSize: 13.5, height: 1.4, color: p.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.panel, shape: BoxShape.circle),
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: p.text,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 14.5, color: p.text)),
          ),
        ],
      ),
    );
  }
}
