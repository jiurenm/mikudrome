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
                        Expanded(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 560),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 150,
                                    child: Center(child: artwork),
                                  ),
                                  const SizedBox(width: 22),
                                  Flexible(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
                            SizedBox(
                              height: 36,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  4,
                                  10,
                                  0,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
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
                                    const Spacer(),
                                    IconButton(
                                      tooltip: '隐藏歌词和队列',
                                      onPressed: onHideSidePanel,
                                      constraints:
                                          const BoxConstraints.tightFor(
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
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(label),
      ),
    );
  }
}
