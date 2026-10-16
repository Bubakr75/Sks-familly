"""Garde les points d'entrée Android des alarmes disponibles et non exportés."""
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ANDROID = "{http://schemas.android.com/apk/res/android}"
PREFIX = "com.dexterous.flutterlocalnotifications."


class NotificationManifestTests(unittest.TestCase):
    def setUp(self):
        path = Path(__file__).resolve().parents[1] / "android/app/src/main/AndroidManifest.xml"
        self.root = ET.parse(path).getroot()
        self.receivers = {node.get(ANDROID + "name"): node
                          for node in self.root.findall("application/receiver")}

    def test_scheduled_alarm_has_private_receiver(self):
        receiver = self.receivers.get(PREFIX + "ScheduledNotificationReceiver")
        self.assertIsNotNone(receiver, "Récepteur requis pour les alarmes programmées")
        self.assertEqual(receiver.get(ANDROID + "exported"), "false")

    def test_reboot_and_update_restore_alarms_without_exported_receiver(self):
        permissions = {node.get(ANDROID + "name") for node in self.root.findall("uses-permission")}
        self.assertIn("android.permission.RECEIVE_BOOT_COMPLETED", permissions)
        receiver = self.receivers.get(PREFIX + "ScheduledNotificationBootReceiver")
        self.assertIsNotNone(receiver)
        self.assertEqual(receiver.get(ANDROID + "exported"), "false")
        actions = {node.get(ANDROID + "name") for node in receiver.findall("intent-filter/action")}
        self.assertTrue({"android.intent.action.BOOT_COMPLETED",
                         "android.intent.action.MY_PACKAGE_REPLACED"}.issubset(actions))


if __name__ == "__main__":
    unittest.main()
