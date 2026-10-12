import 'package:flutter/widgets.dart';

import 'theme.dart';

/// Where the privacy policy is published, for the two places that link it.
const privacyPolicy = 'https://zamansheikh.github.io/gyotaku-android/privacy/';

/// The app's mark, drawn from the same shapes as `assets/icon.svg`: a fish
/// in lines of text, with the line the search found in shu.
class Mark extends StatelessWidget {
  const Mark({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _MarkPainter(Palette.dark)),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.p);

  // The icon is the same in both themes, like the one on the home screen.
  final Palette p;

  static const _bars = [
    (7.0, 10.5, 8.0),
    (11.0, 17.0, 8.0),
    (26.0, 17.0, 18.0),
    (17.0, 23.5, 33.0),
    (15.0, 36.5, 34.0),
    (11.0, 43.0, 8.0),
    (26.0, 43.0, 18.0),
    (7.0, 49.5, 8.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 64);
    RRect pill(double x, double y, double w) => RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, 4),
      const Radius.circular(2),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 64, 64),
        const Radius.circular(14),
      ),
      Paint()..color = p.panel,
    );
    final ink = Paint()..color = p.text;
    for (final (x, y, w) in _bars) {
      canvas.drawRRect(pill(x, y, w), ink);
    }
    canvas.drawCircle(const Offset(44.6, 25.5), 1.1, Paint()..color = p.panel);
    canvas.drawRRect(pill(13, 30, 44), Paint()..color = p.shu);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.p != p;
}
