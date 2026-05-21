import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../theme/theme.dart';
import '../widgets/add_task_sheet.dart';
import '../widgets/today_view.dart';
import '../widgets/tomorrow_view.dart';
import 'categories_screen.dart';
import 'goals_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

  static const _colors = [kTodayColor, kTomorrowColor];
  static const _labels = ['TODAY', 'TOMORROW'];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectPage(int page) {
    if (_currentPage == page) return;
    setState(() => _currentPage = page);
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Title + date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _labels[_currentPage],
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: _colors[_currentPage],
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(
                          height: 18,
                          child: _currentPage == 0
                              ? Text(
                                  DateFormat('EEEE, d MMMM')
                                      .format(DateTime.now()),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: kTextMuted,
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                  // Goals nav
                  IconButton(
                    icon: const Icon(Icons.flag_outlined, color: kGoalsColor),
                    tooltip: 'Goals',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const GoalsScreen(),
                      ),
                    ),
                  ),
                  // Categories nav
                  IconButton(
                    icon: const Icon(Icons.tune, color: kTextMuted),
                    tooltip: 'Categories',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CategoriesScreen(),
                      ),
                    ),
                  ),
                  // Segmented control
                  _SegmentedControl(
                    selected: _currentPage,
                    onSelect: _selectPage,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // ── Page content ───────────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: const [
                  TodayView(),
                  TomorrowView(),
                ],
              ),
            ),

            // ── Add bar ────────────────────────────────────────────────────
            _AddBar(
              label: _currentPage == 0 ? 'Add to Today' : 'Add to Tomorrow',
              onAdd: () => showAddTaskSheet(
                context,
                ref,
                initialBucket: _currentPage == 0 ? 'today' : 'tomorrow',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Segmented control ──────────────────────────────────────────────────────────

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8EE),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Segment(
              label: 'Today', index: 0, selected: selected, onSelect: onSelect),
          _Segment(
              label: 'Tmrw', index: 1, selected: selected, onSelect: onSelect),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.index,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final int index;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final isSelected = index == selected;
    return GestureDetector(
      onTap: () => onSelect(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? kTextDark : kTextMuted,
          ),
        ),
      ),
    );
  }
}

// ── Swipe-up add bar ───────────────────────────────────────────────────────────

class _AddBar extends StatefulWidget {
  const _AddBar({required this.label, required this.onAdd});

  final String label;
  final VoidCallback onAdd;

  @override
  State<_AddBar> createState() => _AddBarState();
}

class _AddBarState extends State<_AddBar> {
  double _offset = 0;

  @override
  Widget build(BuildContext context) {
    final active = _offset < -8;
    return GestureDetector(
      onTap: widget.onAdd,
      onVerticalDragUpdate: (d) {
        if (d.delta.dy < 0) {
          setState(() => _offset = (_offset + d.delta.dy).clamp(-24.0, 0.0));
        }
      },
      onVerticalDragEnd: (d) {
        final go = (d.primaryVelocity ?? 0) < -400 || _offset < -12;
        setState(() => _offset = 0);
        if (go) widget.onAdd();
      },
      onVerticalDragCancel: () => setState(() => _offset = 0),
      child: Transform.translate(
        offset: Offset(0, _offset),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          height: 52,
          decoration: BoxDecoration(
            color: active ? kPrimary.withValues(alpha: 0.04) : kSurface,
            border: Border(
              top: BorderSide(
                color: active
                    ? kPrimary.withValues(alpha: 0.25)
                    : kTextMuted.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSlide(
                offset: active ? const Offset(0, -0.15) : Offset.zero,
                duration: const Duration(milliseconds: 120),
                child: Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: 18,
                  color: active ? kPrimary : kTextMuted,
                ),
              ),
              const SizedBox(width: 6),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 120),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: active ? kPrimary : kTextMuted,
                  letterSpacing: 0.1,
                ),
                child: Text(widget.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
