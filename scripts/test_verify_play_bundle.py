import unittest
from verify_play_bundle import validate_manifest


class ManifestTests(unittest.TestCase):
    def xml(self, package="com.bubakr.sks_family", sdk="36", name="4.8.12", code="525", permission="android.permission.CAMERA"):
        return f'''<manifest xmlns:android="http://schemas.android.com/apk/res/android"
          package="{package}" android:versionName="{name}" android:versionCode="{code}">
          <uses-sdk android:targetSdkVersion="{sdk}"/>
          <uses-permission android:name="{permission}"/></manifest>'''

    def test_valid(self):
        report = validate_manifest(self.xml(), "4.8.12", "525")
        self.assertEqual(report["targetSdk"], 36)
        self.assertEqual(report["permissions"], ["android.permission.CAMERA"])

    def test_reject_invalid_identity_version_sdk_permission(self):
        for change in ({"package": "other.app"}, {"sdk": "35"},
                       {"name": "4.8.11"}, {"code": "524"},
                       {"permission": "android.permission.REQUEST_INSTALL_PACKAGES"}):
            with self.subTest(change=change), self.assertRaises(ValueError):
                validate_manifest(self.xml(**change), "4.8.12", "525")

    def test_missing_sdk(self):
        with self.assertRaises(ValueError):
            validate_manifest(self.xml().replace('<uses-sdk android:targetSdkVersion="36"/>', ''), "4.8.12", "525")


if __name__ == "__main__":
    unittest.main()
