import 'package:flutter/material.dart';

class HowToPlayDialog extends StatelessWidget {
  const HowToPlayDialog({super.key, this.showStartButton = false});

  final bool showStartButton;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFFF6F1E7),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            return DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFF4D8),
                    Color(0xFFF2F7F1),
                    Color(0xFFD7E6F5),
                  ],
                ),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  compact ? 20 : 28,
                  20,
                  compact ? 20 : 28,
                  28,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton.filledTonal(
                            onPressed: () => Navigator.of(context).pop(false),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '遊び方',
                          style: TextStyle(
                            fontSize: compact ? 38 : 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.4,
                            color: const Color(0xFF172033),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '盤面を直接さわって、行や列を入れ替えながら 3 つ以上そろえて消していきます。まずは次の 3 点だけ覚えれば大丈夫です。',
                          style: TextStyle(
                            fontSize: 17,
                            height: 1.5,
                            color: Color(0xFF314155),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: const [
                            _HowToCard(
                              icon: Icons.touch_app_rounded,
                              title: '1. 触ったマスが起点',
                              body:
                                  '触れたマスを中心にガイドが光ります。どのマスを拾えたかを見てから、そのままドラッグしてください。',
                              accent: Color(0xFFF59E0B),
                            ),
                            _HowToCard(
                              icon: Icons.swap_horiz_rounded,
                              title: '2. 横で列・縦で行',
                              body:
                                  '横に動かすと列が、縦に動かすと行が動きます。消せない手はアニメーション後にもとへ戻ります。',
                              accent: Color(0xFF0F766E),
                            ),
                            _HowToCard(
                              icon: Icons.local_fire_department_rounded,
                              title: '3. フィーバー',
                              body:
                                  'FEVER は 500pt → 2500pt → 5000pt → 8000pt → 12000pt の順に解放されます。右下のボタンから発動すると、7.5 秒間はどこを動かしてもそろいます。',
                              accent: Color(0xFF2563EB),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFD7E1EC)),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '時間を伸ばすコツ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF172033),
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                '3つ消しで +1.05秒、4つ以上をまとめて消すと +2.1秒。連鎖ほどスコア倍率が大きく伸び、必要ポイントを満たして FEVER を押すと 7.5 秒間どこを動かしてもそろいます。',
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.5,
                                  color: Color(0xFF556273),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.center,
                          child: FilledButton.icon(
                            onPressed: () => Navigator.of(context).pop(true),
                            icon: Icon(
                              showStartButton
                                  ? Icons.play_arrow_rounded
                                  : Icons.check_rounded,
                            ),
                            label: Text(showStartButton ? '理解してスタート' : '閉じる'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HowToCard extends StatelessWidget {
  const _HowToCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent.withValues(alpha: 0.24)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.12),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(icon, color: accent),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xFF556273),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
