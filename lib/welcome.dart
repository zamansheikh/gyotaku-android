import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'mark.dart';
import 'theme.dart';

/// The first thing anyone sees, before the phone has been asked for
/// anything. Access to every photo is a lot to ask of someone who opened
/// the app a second ago, so this says what the app is for, what it does
/// with the images and what it never does, and what Android is about to
/// ask, in that order. The system's own prompt only comes after the button.
class Welcome extends StatelessWidget {
  const Welcome({super.key, required this.onAllow});

  final VoidCallback onAllow;

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
                  style: TextStyle(
                    fontSize: 15.5,
                    height: 1.45,
                    color: p.muted,
                  ),
                ),
                const SizedBox(height: 16),
                const _Found(),
                const SizedBox(height: 22),
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
                      'Nothing is uploaded. There is no account, no ads '
                      'and no analytics.',
                ),
                const _Promise(
                  icon: Icons.folder_outlined,
                  title: 'Only the folders you choose',
                  detail:
                      'Screenshot folders to begin with. The rest stay '
                      'unread unless you turn them on in settings.',
                ),
                const _Promise(
                  icon: Icons.visibility_outlined,
                  title: 'It only reads',
                  detail: 'gyotaku never changes, moves or deletes an image.',
                ),
                const SizedBox(height: 18),
                Text(
                  'Android asks next, for your photos and then for '
                  'notifications. Allow all photos, so new screenshots are '
                  'found as you take them. The notification is only the '
                  'reading progress.',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: p.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Kept out of the scrolling part, so the way forward is on screen
        // however small the phone or large the text.
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
          child: InkButton(label: 'Allow access to photos', onPressed: onAllow),
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

/// A search and what it finds, drawn as the app shows one: the lines that
/// match stay lit and carry the mark, the rest are dimmed. Still, like
/// everything else here.
class _Found extends StatelessWidget {
  const _Found();

  static const _lines = [
    ('Order 48213', 0),
    ('Out for delivery today', 5),
    ('2 items, paid by card', 0),
    ('Delivery address: 14 Lake Road', 5),
  ];

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
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
                  Text('deliv', style: TextStyle(fontSize: 15, color: p.text)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            for (final (text, hit) in _lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    // The same mark as beside a matching line of an open
                    // screenshot: shu where the search found something.
                    Container(
                      width: 3,
                      height: 24,
                      decoration: BoxDecoration(
                        color: hit > 0 ? p.shu : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            _matched(text, hit, p),
                            TextSpan(text: text.substring(_at(text) + hit)),
                          ],
                        ),
                        style: TextStyle(
                          fontSize: 14.5,
                          color: hit > 0 ? p.text : p.faint,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static int _at(String text) {
    final at = text.toLowerCase().indexOf('deliv');
    return at < 0 ? 0 : at;
  }

  // What comes before the match, then the match itself in shu.
  static TextSpan _matched(String text, int hit, Palette p) {
    final at = _at(text);
    return TextSpan(
      children: [
        TextSpan(text: text.substring(0, at)),
        if (hit > 0)
          TextSpan(
            text: text.substring(at, at + hit),
            style: TextStyle(color: p.shu, fontWeight: FontWeight.w600),
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
