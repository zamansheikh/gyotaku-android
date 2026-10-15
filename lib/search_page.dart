import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'activity.dart';
import 'ink.dart';
import 'notice_card.dart';
import 'reader.dart';
import 'settings_sheet.dart';
import 'shot_page.dart';
import 'src/rust/api/index.dart' as core;
import 'theme.dart';
import 'timeline.dart';
import 'welcome.dart';
import 'when.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.reader});

  final Reader reader;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with WidgetsBindingObserver {
  static const _step = 120;
  static const _columns = 3;

  final _query = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  List<core.Hit> _hits = const [];

  /// The dates the results are narrowed to: a quick chip, a month from the
  /// strip or days from the calendar. One at a time.
  DateSpan? _span;

  /// How many screenshots the search finds in all, not just the page shown.
  int? _total;

  /// When each match of the words typed was taken, whatever dates are
  /// chosen, for the month strip. And what it was worked out for.
  List<int>? _spread;
  String? _spreadFor;
  int _limit = _step;
  int _count = 0;
  int _asked = 0;
  int _seen = -1;
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.reader.addListener(_onReader);
    _scroll.addListener(_onScroll);
    _search();
    widget.reader.run();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.reader.removeListener(_onReader);
    _query.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // A screenshot taken while the app was in the background should be there
  // when it comes back, without anyone asking.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.reader.run(quiet: true);
  }

  void _onReader() {
    if (!mounted) return;
    if (widget.reader.generation != _seen) {
      _seen = widget.reader.generation;
      _search();
    }
    setState(() {});
  }

  void _onScroll() {
    // The index has no paging, so more is asked for by raising the limit.
    final p = _scroll.position;
    if (_hits.length >= _limit && p.pixels > p.maxScrollExtent - 800) {
      _limit += _step;
      _search();
    }
  }

  bool get _typed => _query.text.trim().isNotEmpty;
  bool get _narrowed => _typed || _span != null;

  void _changed() {
    _limit = _step;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _search();
    setState(() {});
  }

  Future<void> _search() async {
    // Answers can come back out of order while typing; only the latest counts.
    final asked = ++_asked;
    final words = _query.text.trim();
    final text = [_query.text, ?_span?.filter].join(' ');
    // The month strip is about the words alone, and only worked out again
    // when they change or the index does.
    final spreadFor = words.isEmpty
        ? null
        : '${widget.reader.generation}|$words';
    try {
      final hits = await core.search(query: text, limit: _limit);
      final count = await core.shotCount();
      final total = _narrowed
          ? (await core.matchTimes(query: text)).length
          : null;
      final spread = spreadFor == null
          ? null
          : spreadFor == _spreadFor
          ? _spread
          : [for (final t in await core.matchTimes(query: words)) t.toInt()];
      if (!mounted || asked != _asked) return;
      setState(() {
        _hits = hits;
        _count = count;
        _total = total;
        _spread = spread;
        _spreadFor = spreadFor;
        _answered = true;
      });
    } catch (e) {
      debugPrint('gyotaku: search failed: $e');
    }
  }

  void _setSpan(DateSpan? span) {
    HapticFeedback.selectionClick();
    _span = span;
    _changed();
  }

  Future<void> _pickDays() async {
    _focus.unfocus();
    final span = await pickDays(context, _span?.range == null ? null : _span);
    if (span != null && mounted) _setSpan(span);
  }

  /// Whether the matches are worth showing by month: enough of them to be
  /// hard to look through, over more than one month.
  bool get _strip {
    final spread = _spread;
    if (!_typed || spread == null || spread.length < 30) return false;
    return MonthStrip.monthsOf(spread).length > 1;
  }

  void _open(int index) {
    _focus.unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShotPage(hits: _hits, index: index),
      ),
    );
  }

  String _status() {
    if (_narrowed) {
      final n = _total ?? _hits.length;
      return n == 1 ? '1 match' : '${counted(n)} matches';
    }
    return _count == 1 ? '1 screenshot' : '$_count screenshots';
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final reader = widget.reader;
    // With nothing indexed there is nothing to filter or count, and the
    // page below has the one thing to say.
    final bare = _answered && _count == 0 && !_narrowed;

    // Nothing to search and no leave to look for anything: the whole page
    // is the app explaining itself, before it asks or after it was
    // refused. A search field over an empty index would only be in the way.
    if (bare &&
        (reader.state == ReaderState.unasked ||
            reader.state == ReaderState.refused)) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: Theme.of(context).appBarTheme.systemOverlayStyle!,
        child: Scaffold(
          body: SafeArea(
            child: reader.state == ReaderState.unasked
                ? Welcome(onAllow: () => reader.run(ask: true))
                : Refused(reader: reader),
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).appBarTheme.systemOverlayStyle!,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 6, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _SearchField(
                        controller: _query,
                        focus: _focus,
                        onChanged: _changed,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _focus.unfocus();
                        showSettings(context, widget.reader);
                      },
                      icon: const Icon(Icons.tune),
                      color: p.muted,
                      tooltip: 'Settings',
                    ),
                  ],
                ),
              ),
              if (!bare)
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    children: [
                      // First, so it is never scrolled out of sight: any
                      // dates at all, and what was picked once it is.
                      _span == null || DateSpan.quick.contains(_span)
                          ? _Chip(
                              icon: Icons.calendar_month_outlined,
                              label: null,
                              tooltip: 'Pick dates',
                              selected: false,
                              onTap: _pickDays,
                            )
                          : _Chip(
                              icon: Icons.calendar_month_outlined,
                              label: _span!.label,
                              selected: true,
                              onTap: _pickDays,
                              onClear: () => _setSpan(null),
                            ),
                      for (final w in DateSpan.quick) ...[
                        const SizedBox(width: 8),
                        _Chip(
                          label: w.label,
                          selected: _span == w,
                          onTap: () => _setSpan(_span == w ? null : w),
                        ),
                      ],
                    ],
                  ),
                ),
              if (!bare && _strip)
                MonthStrip(times: _spread!, chosen: _span, onChoose: _setSpan),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
                child: bare
                    ? const SizedBox(height: 8)
                    : Row(
                        children: [
                          Text(
                            _status(),
                            style: TextStyle(fontSize: 13, color: p.muted),
                          ),
                          const Spacer(),
                          if (reader.state == ReaderState.done &&
                              reader.trouble == null &&
                              reader.failed == 0 &&
                              !reader.paused)
                            Text(
                              reader.report ?? 'Up to date',
                              style: TextStyle(fontSize: 13, color: p.faint),
                            ),
                        ],
                      ),
              ),
              Activity(
                reader: reader,
                footer: NoticeAsk(reader: reader),
              ),
              Expanded(child: _body(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final reader = widget.reader;
    if (!_answered) return const SizedBox();

    if (_hits.isEmpty) {
      if (_narrowed) {
        return _Notice(
          icon: Icons.search_off,
          title: 'Nothing matches',
          body: !_typed
              ? _span!.nothing
              : _span != null && (_spread?.isNotEmpty ?? false)
              ? 'There are matches, but none from ${_span!.label}.'
              : 'Every word has to appear in the screenshot. Try fewer words, or a few letters of one.',
          action: _typed && _span != null && (_spread?.isNotEmpty ?? false)
              ? 'Show every date'
              : 'Clear search',
          onAction: () {
            if (!_typed || (_spread?.isEmpty ?? true)) _query.clear();
            _span = null;
            _changed();
          },
        );
      }
      return switch (reader.state) {
        // Shown as whole pages instead, in `build`.
        ReaderState.unasked || ReaderState.refused => const SizedBox(),
        ReaderState.noFolder => _Notice(
          icon: Icons.folder_off_outlined,
          title: 'No folder is turned on',
          body: 'gyotaku reads the folders you choose. This phone has no screenshots folder yet, or every folder is off.',
          action: 'Choose folders',
          onAction: () => showSettings(context, reader),
        ),
        ReaderState.checking ||
        ReaderState.preparing ||
        ReaderState.reading => const _Notice(
          icon: Icons.hourglass_empty,
          title: 'Reading your screenshots',
          body: 'The newest come first. You can search as soon as they appear.',
        ),
        _ => _Notice(
          icon: Icons.image_not_supported_outlined,
          title: 'No screenshots yet',
          body: 'Take a screenshot and it will appear here.',
          action: 'Look again',
          onAction: reader.run,
        ),
      };
    }

    final width = MediaQuery.sizeOf(context).width;
    final decode = (width / _columns * MediaQuery.devicePixelRatioOf(context))
        .round();
    final p = Palette.of(context);

    return RefreshIndicator(
      onRefresh: reader.run,
      color: p.text,
      backgroundColor: p.tile,
      elevation: 0,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          for (final s in _sections()) ...[
            if (s.title != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                  child: Text(
                    s.title!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: p.text,
                    ),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _columns,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  // The tallest a tile gets, see `tile_aspect`.
                  childAspectRatio: 0.5,
                ),
                itemCount: s.count,
                itemBuilder: (context, i) => _Tile(
                  hit: _hits[s.start + i],
                  decodeWidth: decode,
                  onTap: () => _open(s.start + i),
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
          ),
        ],
      ),
    );
  }

  /// Runs of hits under one heading. Browsing, that's the day or month they
  /// were taken. Searching, the order is by how well they match, so the only
  /// heading is the one that sets the near matches apart.
  List<_Section> _sections() {
    final out = <_Section>[];
    final now = DateTime.now();
    String? last;
    for (var i = 0; i < _hits.length; i++) {
      final h = _hits[i];
      final title = _typed
          ? (h.near ? 'Near matches' : null)
          : sectionOf(h.mtime, now);
      if (i == 0 || title != last) {
        out.add(_Section(title, i));
        last = title;
      }
      out.last.count++;
    }
    return out;
  }
}

class _Section {
  _Section(this.title, this.start);
  final String? title;
  final int start;
  int count = 0;
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focus,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: p.tile,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(Icons.search, size: 22, color: p.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              onChanged: (_) => onChanged(),
              onSubmitted: (_) => focus.unfocus(),
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.search,
              style: TextStyle(fontSize: 17, color: p.text),
              decoration: InputDecoration(
                hintText: 'Search your screenshots',
                hintStyle: TextStyle(color: p.muted),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              onPressed: () {
                controller.clear();
                onChanged();
              },
              icon: const Icon(Icons.close, size: 20),
              color: p.muted,
              tooltip: 'Clear',
            )
          else
            const SizedBox(width: 14),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.tooltip,
    this.onClear,
  });

  /// Null for a chip that is only its icon.
  final String? label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  /// What the chip is called where it has no words of its own.
  final String? tooltip;

  /// With one, a cross on the chip takes the choice away.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final ink = selected ? p.panel : p.text;
    final chip = Container(
      alignment: Alignment.center,
      padding: EdgeInsets.only(
        left: label == null ? 10 : 14,
        right: onClear != null ? 4 : (label == null ? 10 : 14),
      ),
      decoration: BoxDecoration(
        // Selection is ink.
        color: selected ? p.text : Colors.transparent,
        border: Border.all(color: selected ? p.text : p.track),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, size: 17, color: ink),
          if (icon != null && label != null) const SizedBox(width: 6),
          if (label != null)
            Text(
              label!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: ink,
              ),
            ),
          if (onClear != null)
            Semantics(
              button: true,
              label: 'Show every date',
              child: GestureDetector(
                onTap: onClear,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                  child: Icon(Icons.close, size: 15, color: ink),
                ),
              ),
            ),
        ],
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: label == null ? tooltip : null,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: tooltip == null ? chip : Tooltip(message: tooltip!, child: chip),
      ),
    );
  }
}

/// What the page says when there is no grid to show.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(36, 0, 36, 96),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: p.tile,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 28, color: p.muted),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: p.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, height: 1.45, color: p.muted),
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              InkButton(label: action!, onPressed: onAction!),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatefulWidget {
  const _Tile({
    required this.hit,
    required this.decodeWidth,
    required this.onTap,
  });

  final core.Hit hit;
  final int decodeWidth;
  final VoidCallback onTap;

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final hit = widget.hit;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      child: Align(
        alignment: Alignment.topCenter,
        child: AspectRatio(
          aspectRatio: core.tileAspect(width: hit.width, height: hit.height),
          child: Opacity(
            opacity: _down ? 0.7 : 1,
            child: Container(
              foregroundDecoration: BoxDecoration(
                border: Border.all(color: p.track.withValues(alpha: 0.6)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: p.tile),
                    InkedShot(
                      path: hit.path,
                      crop: core.tileCrop(width: hit.width, height: hit.height),
                      lit: hit.lines,
                      decodeWidth: widget.decodeWidth,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
