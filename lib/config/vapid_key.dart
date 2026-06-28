class VapidKeyConfig {
  // Cle VAPID generee dans Firebase Console (Cloud Messaging > Web Push certificates)
  static const String vapidKey = "BPlYsfIrUVb_LRNt8q1acG2bufeaL4SOvv1KM0Cdkpx16X3cpQm9-16o5Z_QY5lWAoWf_bh04LtrfCO5n4u8Tlo";

  // Retourne true si la cle VAPID a ete configuree (commence par "B" et n'est pas vide)
  static bool get isConfigured =>
      vapidKey.isNotEmpty &&
      vapidKey.startsWith("B") &&
      vapidKey.length > 80;
}
