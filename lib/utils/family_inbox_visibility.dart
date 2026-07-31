/// La PWA utilise le rôle Firestore réel car le mode parent par PIN est local.
///
/// Android conserve volontairement son comportement historique fondé sur le
/// mode parent local.
bool shouldShowFamilyInbox({
  required bool isWeb,
  required String? memberRole,
  required bool androidParentMode,
}) {
  if (!isWeb) return androidParentMode;
  return memberRole == 'owner' || memberRole == 'parent';
}
