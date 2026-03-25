  Widget _immunityTile(BuildContext context, ImmunityLines im, FamilyProvider provider, {required bool isActive}) {
    return GestureDetector(
      onTap: () => _showImmunityDetail(context, im, provider, isActive: isActive),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isActive
              ? const Color(0xFF00E676).withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.02),
          border: Border.all(
            color: isActive
                ? const Color(0xFF00E676).withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: isActive
                    ? const Color(0xFF00E676).withValues(alpha: 0.12)
                    : Colors.grey.withValues(alpha: 0.08),
              ),
              child: Center(
                child: Text('\u{1F6E1}', style: TextStyle(fontSize: 18, color: isActive ? null : Colors.grey)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    im.reason,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey[600],
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(im.statusLabel, style: TextStyle(color: isActive ? const Color(0xFF00E676) : Colors.grey[600], fontSize: 11)),
                      if (im.expiresAt != null) ...[
                        const SizedBox(width: 8),
                        Text(im.expiresLabel, style: TextStyle(color: im.isExpired ? Colors.orange : Colors.grey[600], fontSize: 10)),
                      ],
                    ],
                  ),
                  Text('Donne le ${im.createdAt.day}/${im.createdAt.month}/${im.createdAt.year}', style: TextStyle(color: Colors.grey[700], fontSize: 10)),
                ],
              ),
            ),
            if (isActive)
              Text('${im.availableLines}', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.w900, fontSize: 20))
            else
              Text('${im.usedLines}/${im.lines}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: isActive ? const Color(0xFF00E676).withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.3), size: 20),
          ],
        ),
      ),
    );
  }

  void _showImmunityDetail(BuildContext context, ImmunityLines im, FamilyProvider provider, {required bool isActive}) {
    final child = provider.getChild(im.childId);
    final dateStr = '${im.createdAt.day.toString().padLeft(2, '0')}/${im.createdAt.month.toString().padLeft(2, '0')}/${im.createdAt.year}';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            // Icone
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? const Color(0xFF00E676).withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
                border: Border.all(color: isActive ? const Color(0xFF00E676).withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.3), width: 2),
              ),
              child: const Center(child: Text('\u{1F6E1}', style: TextStyle(fontSize: 32))),
            ),
            const SizedBox(height: 12),
            Text(im.reason, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(child?.name ?? 'Inconnu', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
            const SizedBox(height: 16),
            // Stats
            Row(children: [
              Expanded(child: _immunityDetailChip('\u{1F6E1}', 'Total', '${im.lines} lignes', const Color(0xFF00E676))),
              const SizedBox(width: 10),
              Expanded(child: _immunityDetailChip('\u{2705}', 'Utilisees', '${im.usedLines}', Colors.amber)),
              const SizedBox(width: 10),
              Expanded(child: _immunityDetailChip('\u{2728}', 'Disponibles', '${im.availableLines}', isActive ? const Color(0xFF00E676) : Colors.grey)),
            ]),
            const SizedBox(height: 12),
            // Infos date + expiration
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Row(children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 8),
                  Text('Donne le $dateStr', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                ]),
                if (im.expiresAt != null) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.timer_rounded, size: 14, color: im.isExpired ? Colors.orange : Colors.grey[500]),
                    const SizedBox(width: 8),
                    Text(im.expiresLabel, style: TextStyle(color: im.isExpired ? Colors.orange : Colors.grey[400], fontSize: 13)),
                  ]),
                ],
                const SizedBox(height: 6),
                Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: isActive ? const Color(0xFF00E676) : im.isExpired ? Colors.orange : Colors.grey)),
                  const SizedBox(width: 8),
                  Text(im.statusLabel, style: TextStyle(color: isActive ? const Color(0xFF00E676) : Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            // Actions
            if (isActive) ...[
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _confirmDelete(context, im.id, provider);
                    },
                    icon: const Icon(Icons.delete_rounded, size: 18),
                    label: const Text('Supprimer'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF1744),
                      side: BorderSide(color: const Color(0xFFFF1744).withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      // Naviguer vers le TradeScreen pour vendre
                      Navigator.push(context, MaterialPageRoute(builder: (_) => TradeScreen(childId: im.childId)));
                    },
                    icon: const Icon(Icons.sell_rounded, size: 18),
                    label: const Text('Vendre'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ]),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _immunityDetailChip(String emoji, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
      ]),
    );
  }
