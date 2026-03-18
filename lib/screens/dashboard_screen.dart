  void _quickAddPoints(BuildContext context, child, FamilyProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF141833) : null,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            NeonText(text: 'Points pour ${child.name}', fontSize: 18, color: Colors.white, glowIntensity: 0.2),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10, runSpacing: 10, alignment: WrapAlignment.center,
              children: [
                _pointChip('+1', const Color(0xFF00E676), isDark, () { provider.addPoints(child.id, 1, 'Bonus +1', 'Bonus'); Navigator.pop(ctx); setState(() => _showConfetti = true); }),
                _pointChip('+2', const Color(0xFF00E676), isDark, () { provider.addPoints(child.id, 2, 'Bon comportement', 'Bonus'); Navigator.pop(ctx); setState(() => _showConfetti = true); }),
                _pointChip('+5', const Color(0xFF00E676), isDark, () { provider.addPoints(child.id, 5, 'Tres bien !', 'Bonus'); Navigator.pop(ctx); setState(() => _showConfetti = true); }),
                _pointChip('+10', const Color(0xFF00E676), isDark, () { provider.addPoints(child.id, 10, 'Excellent !', 'Bonus'); Navigator.pop(ctx); setState(() => _showConfetti = true); }),
                _pointChip('-1', const Color(0xFFFF1744), isDark, () { provider.addPoints(child.id, -1, 'Penalite -1', 'Penalite', isBonus: false); Navigator.pop(ctx); }),
                _pointChip('-2', const Color(0xFFFF1744), isDark, () { provider.addPoints(child.id, -2, 'Mauvais comportement', 'Penalite', isBonus: false); Navigator.pop(ctx); }),
                _pointChip('-5', const Color(0xFFFF1744), isDark, () { provider.addPoints(child.id, -5, 'Sanction', 'Penalite', isBonus: false); Navigator.pop(ctx); }),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
