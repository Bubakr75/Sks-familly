import 'package:family_score/utils/family_inbox_visibility.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Web affiche la cloche au parent réel même sans mode PIN local', () {
    expect(
      shouldShowFamilyInbox(
        isWeb: true,
        memberRole: 'parent',
        androidParentMode: false,
      ),
      isTrue,
    );
  });

  test('Web masque la cloche aux enfants', () {
    expect(
      shouldShowFamilyInbox(
        isWeb: true,
        memberRole: 'child',
        androidParentMode: true,
      ),
      isFalse,
    );
  });

  test('Android conserve exactement la condition du mode parent', () {
    expect(
      shouldShowFamilyInbox(
        isWeb: false,
        memberRole: 'child',
        androidParentMode: true,
      ),
      isTrue,
    );
    expect(
      shouldShowFamilyInbox(
        isWeb: false,
        memberRole: 'owner',
        androidParentMode: false,
      ),
      isFalse,
    );
  });
}
