import 'package:flutter/material.dart';

import '../config/emerald_theme.dart';
import '../models/child_model.dart';
import '../utils/image_cache.dart';

/// Un appareil lié à un enfant ne présente que le profil qui lui correspond.
List<ChildModel> visibleFamilyChildren(
  List<ChildModel> children, {
  required String? memberRole,
  required String? memberChildId,
}) {
  final visible = memberRole == 'child'
      ? children.where((child) => child.id == memberChildId).toList()
      : List<ChildModel>.from(children);
  visible.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return visible;
}

class FamilyProfilesSection extends StatelessWidget {
  const FamilyProfilesSection(
      {super.key,
      required this.children,
      required this.onOpenChild,
      this.title = 'Profils enfants'});

  final List<ChildModel> children;
  final ValueChanged<ChildModel> onOpenChild;
  final String title;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EmeraldSectionTitle(title: title, icon: Icons.people_alt_rounded),
          if (children.isEmpty)
            const EmeraldCard(
                child: Text(
              'Aucun profil à afficher pour le moment. Les profils se gèrent dans les réglages de la famille.',
              style: TextStyle(color: EmeraldPalette.textSecondary),
            )),
          for (final child in children)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: EmeraldCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  leading: StableAvatar(
                      photoBase64: child.photoBase64,
                      emoji: child.avatar,
                      name: child.name,
                      radius: 24,
                      color: EmeraldPalette.surfaceHigh),
                  title: Text(child.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: EmeraldPalette.textPrimary,
                          fontWeight: FontWeight.w700)),
                  subtitle: Text('${child.points} points · Voir le profil',
                      style:
                          const TextStyle(color: EmeraldPalette.textSecondary)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: EmeraldPalette.gold),
                  onTap: () => onOpenChild(child),
                ),
              ),
            ),
        ],
      );
}
