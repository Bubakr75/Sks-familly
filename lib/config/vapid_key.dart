class VapidKeyConfig {
  static const String vapidKey = "BPlYsfIrUVb_LRNt8q1acG2bufeaL4SOvv1KM0Cdkpx16X3cpQm9-16o5Z_QY5lWAoWf_bh04LtrfCO5n4u8Tlo";

  static bool get isConfigured =>
      vapidKey.isNotEmpty &&
      vapidKey != "BPlYsfIrUVb_LRNt8q1acG2bufeaL4SOvv1KM0Cdkpx16X3cpQm9-16o5Z_QY5lWAoWf_bh04LtrfCO5n4u8Tlo" &&
      vapidKey.startsWith("B");
}