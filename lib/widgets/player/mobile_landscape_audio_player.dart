import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

enum LandscapePlayerPanelTab { lyrics, queue }

class MobileLandscapeAudioPlayer extends StatelessWidget {
  const MobileLandscapeAudioPlayer({
    super.key,
    required this.title,
    required this.subtitle,
    required this.artwork,
    required this.progress,
    required this.elapsedLabel,
    required this.durationLabel,
    required this.controls,
    required this.actions,
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
  final Widget progress;
  final String elapsedLabel;
  final String durationLabel;
  final Widget controls;
  final Widget actions;
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
      body: SafeArea(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 40,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              tooltip: '收起',
                              onPressed: onCollapse,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: 40,
                                height: 40,
                              ),
                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Row(
                            children: [
                              SizedBox(
                                width: 150,
                                child: Center(child: artwork),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
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
                                    const SizedBox(height: 8),
                                    Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: Colors.white60),
                                    ),
                                    const SizedBox(height: 12),
                                    actions,
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        progress,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              elapsedLabel,
                              style: const TextStyle(color: Colors.white),
                            ),
                            Text(
                              durationLabel,
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: controls),
                            IconButton(
                              tooltip: sidePanelVisible ? '隐藏歌词和队列' : '显示歌词和队列',
                              onPressed: sidePanelVisible
                                  ? onHideSidePanel
                                  : onShowSidePanel,
                              icon: Icon(
                                sidePanelVisible
                                    ? Icons.keyboard_arrow_right
                                    : Icons.queue_music,
                                color: sidePanelVisible
                                    ? Colors.white70
                                    : AppTheme.mikuGreen,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (sidePanelVisible)
                  SizedBox(
                    key: const ValueKey('mobile-landscape-player-side-panel'),
                    width: sidePanelWidth,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 16, 20, 16),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  _PanelTabButton(
                                    semanticsKey: const ValueKey(
                                      'mobile-landscape-panel-tab-lyrics',
                                    ),
                                    label: '歌词',
                                    selected:
                                        selectedPanelTab ==
                                        LandscapePlayerPanelTab.lyrics,
                                    onPressed: () => onSelectPanelTab(
                                      LandscapePlayerPanelTab.lyrics,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _PanelTabButton(
                                    semanticsKey: const ValueKey(
                                      'mobile-landscape-panel-tab-queue',
                                    ),
                                    label: '队列',
                                    selected:
                                        selectedPanelTab ==
                                        LandscapePlayerPanelTab.queue,
                                    onPressed: () => onSelectPanelTab(
                                      LandscapePlayerPanelTab.queue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child:
                                  selectedPanelTab ==
                                      LandscapePlayerPanelTab.lyrics
                                  ? lyrics
                                  : queue,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
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
    required this.onPressed,
  });

  final Key semanticsKey;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: semanticsKey,
      selected: selected,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: selected ? AppTheme.mikuGreen : Colors.white70,
        ),
        child: Text(label),
      ),
    );
  }
}
