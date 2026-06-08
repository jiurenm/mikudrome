import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../api/config.dart';
import '../../theme/app_theme.dart';

enum LandscapePlayerPanelTab { lyrics, queue }

class MobileLandscapeAudioPlayer extends StatelessWidget {
  const MobileLandscapeAudioPlayer({
    super.key,
    required this.title,
    required this.subtitle,
    required this.artwork,
    required this.coverUrl,
    required this.progress,
    required this.controls,
    required this.actions,
    required this.accentColor,
    required this.sidePanelVisible,
    required this.selectedPanelTab,
    required this.onShowSidePanel,
    required this.onHideSidePanel,
    required this.onSelectPanelTab,
    required this.onCollapse,
    required this.lyrics,
    required this.queue,
  });

  final String title;
  final String subtitle;
  final Widget artwork;
  final String coverUrl;
  final Widget progress;
  final Widget controls;
  final Widget actions;
  final Color accentColor;
  final bool sidePanelVisible;
  final LandscapePlayerPanelTab selectedPanelTab;
  final VoidCallback onShowSidePanel;
  final VoidCallback onHideSidePanel;
  final ValueChanged<LandscapePlayerPanelTab> onSelectPanelTab;
  final VoidCallback onCollapse;
  final Widget lyrics;
  final Widget queue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('mobile-landscape-player'),
      backgroundColor: const Color(0xFF061116),
      body: Stack(
        children: [
          Positioned.fill(
            child: _LandscapeCoverBackdrop(
              coverUrl: coverUrl,
              accentColor: accentColor,
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final sidePanelWidth = (constraints.maxWidth * 0.42)
                    .clamp(240.0, 320.0)
                    .toDouble();

                return Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 20, 16),
                        child: LayoutBuilder(
                          builder: (context, leftConstraints) {
                            final compact = leftConstraints.maxHeight < 420;
                            return Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 540,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Center(child: artwork),
                                    SizedBox(height: compact ? 12 : 18),
                                    Text(
                                      title,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    SizedBox(height: compact ? 4 : 8),
                                    Text(
                                      subtitle,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: Colors.white60),
                                    ),
                                    SizedBox(height: compact ? 14 : 22),
                                    progress,
                                    SizedBox(height: compact ? 2 : 8),
                                    SizedBox(
                                      height: 64,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Center(child: controls),
                                          if (!sidePanelVisible)
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  actions,
                                                  IconButton(
                                                    tooltip: '显示歌词和队列',
                                                    onPressed: onShowSidePanel,
                                                    icon: const Icon(
                                                      Icons.queue_music,
                                                      color: AppTheme.mikuGreen,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    if (sidePanelVisible)
                      SizedBox(
                        key: const ValueKey(
                          'mobile-landscape-player-side-panel',
                        ),
                        width: sidePanelWidth,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 18, 20, 18),
                          child: _ImmersiveSidePanel(
                            accentColor: accentColor,
                            selectedPanelTab: selectedPanelTab,
                            onHideSidePanel: onHideSidePanel,
                            onSelectPanelTab: onSelectPanelTab,
                            lyrics: lyrics,
                            queue: queue,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LandscapeCoverBackdrop extends StatelessWidget {
  const _LandscapeCoverBackdrop({
    required this.coverUrl,
    required this.accentColor,
  });

  final String coverUrl;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF061116),
      child: Stack(
        children: [
          if (coverUrl.isNotEmpty)
            Positioned.fill(
              child: Opacity(
                key: const ValueKey('mobile-landscape-cover-atmosphere'),
                opacity: 0.20,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Transform.scale(
                    scale: 1.12,
                    child: Image.network(
                      coverUrl,
                      headers: ApiConfig.defaultHeaders,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.35, -0.25),
                  radius: 0.9,
                  colors: [
                    accentColor.withValues(alpha: 0.045),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xF3061116),
                    Color(0xDE061116),
                    Color(0xEA061116),
                  ],
                  stops: [0.0, 0.46, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImmersiveSidePanel extends StatefulWidget {
  const _ImmersiveSidePanel({
    required this.accentColor,
    required this.selectedPanelTab,
    required this.onHideSidePanel,
    required this.onSelectPanelTab,
    required this.lyrics,
    required this.queue,
  });

  final Color accentColor;
  final LandscapePlayerPanelTab selectedPanelTab;
  final VoidCallback onHideSidePanel;
  final ValueChanged<LandscapePlayerPanelTab> onSelectPanelTab;
  final Widget lyrics;
  final Widget queue;

  @override
  State<_ImmersiveSidePanel> createState() => _ImmersiveSidePanelState();
}

class _ImmersiveSidePanelState extends State<_ImmersiveSidePanel> {
  static const _chromeAutoHideDelay = Duration(seconds: 3);

  bool _chromeVisible = false;
  Timer? _hideChromeTimer;

  @override
  void dispose() {
    _hideChromeTimer?.cancel();
    super.dispose();
  }

  void _revealChrome() {
    _hideChromeTimer?.cancel();
    if (!_chromeVisible) {
      setState(() {
        _chromeVisible = true;
      });
    }
    _hideChromeTimer = Timer(_chromeAutoHideDelay, () {
      if (!mounted) return;
      setState(() {
        _chromeVisible = false;
      });
    });
  }

  void _selectPanelTab(LandscapePlayerPanelTab tab) {
    widget.onSelectPanelTab(tab);
    _revealChrome();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _revealChrome,
      child: SizedBox.expand(
        key: const ValueKey('mobile-landscape-side-panel-content'),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF061116).withValues(alpha: 0.18),
                      const Color(0xFF061116).withValues(alpha: 0.32),
                    ],
                    stops: const [0.0, 0.52, 1.0],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: widget.selectedPanelTab == LandscapePlayerPanelTab.lyrics
                  ? widget.lyrics
                  : widget.queue,
            ),
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: _chromeVisible
                    ? _PanelChrome(
                        key: const ValueKey('mobile-landscape-panel-chrome'),
                        accentColor: widget.accentColor,
                        selectedPanelTab: widget.selectedPanelTab,
                        onHideSidePanel: widget.onHideSidePanel,
                        onSelectPanelTab: _selectPanelTab,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelChrome extends StatelessWidget {
  const _PanelChrome({
    super.key,
    required this.accentColor,
    required this.selectedPanelTab,
    required this.onHideSidePanel,
    required this.onSelectPanelTab,
  });

  final Color accentColor;
  final LandscapePlayerPanelTab selectedPanelTab;
  final VoidCallback onHideSidePanel;
  final ValueChanged<LandscapePlayerPanelTab> onSelectPanelTab;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accentColor.withValues(alpha: 0.18),
            const Color(0xFF061116).withValues(alpha: 0.82),
            const Color(0xFF061116).withValues(alpha: 0.46),
            Colors.transparent,
          ],
          stops: const [0.0, 0.28, 0.68, 1.0],
        ),
      ),
      child: SizedBox(
        height: 42,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 5, 10, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _PanelTabButton(
                semanticsKey: const ValueKey(
                  'mobile-landscape-panel-tab-lyrics',
                ),
                label: '歌词',
                selected: selectedPanelTab == LandscapePlayerPanelTab.lyrics,
                selectedColor: accentColor,
                onPressed: () =>
                    onSelectPanelTab(LandscapePlayerPanelTab.lyrics),
              ),
              const SizedBox(width: 8),
              _PanelTabButton(
                semanticsKey: const ValueKey(
                  'mobile-landscape-panel-tab-queue',
                ),
                label: '队列',
                selected: selectedPanelTab == LandscapePlayerPanelTab.queue,
                selectedColor: accentColor,
                onPressed: () =>
                    onSelectPanelTab(LandscapePlayerPanelTab.queue),
              ),
              const Spacer(),
              IconButton(
                tooltip: '隐藏歌词和队列',
                onPressed: onHideSidePanel,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.keyboard_arrow_right,
                  size: 24,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelTabButton extends StatelessWidget {
  const _PanelTabButton({
    required this.semanticsKey,
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onPressed,
  });

  final Key semanticsKey;
  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: semanticsKey,
      selected: selected,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: selected ? selectedColor : Colors.white70,
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(label),
      ),
    );
  }
}
