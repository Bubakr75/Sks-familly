// Dans le Drawer, AJOUTER cette entrée après "Historique Complet" :

// ─── ADMINISTRATION PARENT ───
if (pinProvider.canPerformParentAction()) ...[
  const Divider(color: Colors.white12),
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Text('ADMINISTRATION',
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.redAccent.withOpacity(0.7),
            letterSpacing: 1.5)),
  ),
  TvFocusWrapper(
    onTap: () {
      Navigator.pop(context);
      Navigator.push(context,
          SlidePageRoute(page: const ParentAdminScreen()));
    },
    child: GlassCard(
      child: ListTile(
        leading: const Text('👑', style: TextStyle(fontSize: 24)),
        title: const Text('Panneau d\'administration'),
        subtitle: const Text('Gérer points, historique, données',
            style: TextStyle(fontSize: 11, color: Colors.white54)),
        trailing: const Icon(Icons.admin_panel_settings,
            color: Colors.redAccent),
      ),
    ),
  ),
],
