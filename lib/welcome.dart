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
          'Android asks next. Allow all photos, so new screenshots are '
          'found as you take them.',
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
/// typed, the screenshots that hold them stay lit with the line that
/// matched marked, and the rest go dark. Then another, so it is plain that
/// any part of the text will do.
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

/// One made up screenshot, small: whose it is and a few lines of text.
class _Shot {
  const _Shot(this.title, this.accent, this.lines, {required this.dark});

  final String title;
  final Color accent;
  final List<String> lines;
  final bool dark;
}

class _DemoState extends State<_Demo> with SingleTickerProviderStateMixin {
  // Lines short enough to be read at this size. Everything in them is
  // invented.
  static const _shots = [
    _Shot('Nadia', Color(0xff3b6cf6), [
      'At the new flat?',
      'Just got in',
      'wifi: maple-4821',
      'Thanks!',
    ], dark: true),
    _Shot('Fern & Co', Color(0xff1f8a5b), [
      'Planter  \$28.00',
      'Cutting  \$14.50',
      'Delivery  \$5.70',
      'Total  \$48.20',
    ], dark: false),
    _Shot('Parcel', Color(0xffd98a00), [
      'RX 4471 9920',
      'Out for delivery',
      'Arrives Thursday',
      'Courier: Swift',
    ], dark: true),
  ];
  static const _searches = ['wifi', 'deliv', '48.2'];

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

  static bool _holds(String line, String typed) =>
      line.toLowerCase().contains(typed);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final typed = _word.substring(0, _typed);
    // One letter is in nearly every line. The picture starts to mean
    // something at two.
    final searching = typed.length >= 2;
    final found = [
      for (final s in _shots)
        if (s.lines.any((l) => _holds(l, typed))) s,
    ].length;
    return Semantics(
      label:
          'An example. Three screenshots: a chat, a receipt and a parcel. '
          'Searching for wifi leaves the chat lit, where a line gives the '
          'wifi password, and darkens the other two.',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
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
            const SizedBox(height: 12),
            // Pictures of screenshots, so their text keeps its size.
            MediaQuery.withNoTextScaling(
              child: Row(
                children: [
                  for (final (i, shot) in _shots.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: _shot(shot, typed, searching, p)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              !searching
                  ? '${_shots.length} screenshots'
                  : found == 1
                  ? '1 match'
                  : '$found matches',
              style: TextStyle(fontSize: 12.5, color: p.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shot(_Shot shot, String typed, bool searching, Palette p) {
    const ease = Duration(milliseconds: 240);
    final fg = shot.dark ? const Color(0xffecebe7) : const Color(0xff18181a);
    final found = searching && shot.lines.any((l) => _holds(l, typed));
    return AnimatedOpacity(
      duration: ease,
      // A screenshot the search did not find goes dark, as under the ink.
      opacity: searching && !found ? 0.22 : 1,
      child: Container(
        height: 122,
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
        decoration: BoxDecoration(
          color: shot.dark ? const Color(0xff101114) : const Color(0xfff7f6f2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '9:41',
                  style: TextStyle(
                    fontSize: 5.5,
                    color: fg.withValues(alpha: 0.6),
                  ),
                ),
                Container(
                  width: 9,
                  height: 4,
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: shot.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  shot.title,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final line in shot.lines)
              _line(line, typed, found, fg, p, ease),
          ],
        ),
      ),
    );
  }

  Widget _line(
    String line,
    String typed,
    bool found,
    Color fg,
    Palette p,
    Duration ease,
  ) {
    final at = found ? line.toLowerCase().indexOf(typed) : -1;
    final hit = at >= 0;
    return AnimatedOpacity(
      duration: ease,
      // In a screenshot that matched, only the line that did stays lit.
      opacity: found && !hit ? 0.28 : 1,
      child: AnimatedContainer(
        duration: ease,
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.fromLTRB(4, 3, 3, 3),
        decoration: BoxDecoration(
          color: fg.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(4),
          // Shu round the line the search found, as on an open screenshot.
          border: Border.all(
            color: hit ? p.shu : p.shu.withValues(alpha: 0),
            width: 1.2,
          ),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
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
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans',
                fontSize: 7.5,
                height: 1.2,
                color: fg,
              ),
            ),
          ),
        ),
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
