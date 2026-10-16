"""Contrôle le bundle réel avant de le conserver comme artefact Actions."""
import argparse
import json
import re
import subprocess
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

ANDROID = "{http://schemas.android.com/apk/res/android}"


def validate_manifest(xml, version_name, version_code):
    root = ET.fromstring(xml)
    expected = {"package": "com.bubakr.sks_family",
                ANDROID + "versionName": version_name,
                ANDROID + "versionCode": str(version_code)}
    for key, value in expected.items():
        if root.get(key) != value:
            raise ValueError(f"Identité/version incorrecte : {key}")
    sdk = root.find("uses-sdk")
    if sdk is None or int(sdk.get(ANDROID + "targetSdkVersion", "0")) < 36:
        raise ValueError("Le bundle doit cibler API 36 au minimum")
    permissions = sorted({element.get(ANDROID + "name") for element in root
                          if element.tag.startswith("uses-permission")})
    if "android.permission.REQUEST_INSTALL_PACKAGES" in permissions:
        raise ValueError("Permission REQUEST_INSTALL_PACKAGES interdite")
    return {"package": root.get("package"), "versionName": version_name,
            "versionCode": int(version_code),
            "targetSdk": int(sdk.get(ANDROID + "targetSdkVersion")),
            "permissions": permissions}


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout


def certificate(path):
    output = run("keytool", "-J-Duser.language=en", "-printcert", "-jarfile", str(path))
    fingerprints = re.findall(r"SHA256:\s*([0-9A-Fa-f:]+)", output)
    if len(fingerprints) != 1:
        raise ValueError("Un seul certificat de signature est attendu")
    return fingerprints[0].replace(":", "").lower()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle", required=True)
    parser.add_argument("--bundletool", required=True)
    parser.add_argument("--version-name", required=True)
    parser.add_argument("--version-code", required=True)
    parser.add_argument("--expected-cert", required=True)
    parser.add_argument("--report", required=True)
    args = parser.parse_args()
    run("java", "-jar", args.bundletool, "validate", f"--bundle={args.bundle}")
    xml = run("java", "-jar", args.bundletool, "dump", "manifest",
              f"--bundle={args.bundle}", "--module=base")
    report = validate_manifest(xml, args.version_name, args.version_code)
    verification = run("jarsigner", "-J-Duser.language=en", "-verify", args.bundle)
    if "jar verified." not in verification:
        raise ValueError("Signature AAB absente ou invalide")
    actual_cert = certificate(args.bundle)
    if actual_cert != args.expected_cert.replace(":", "").lower():
        raise ValueError("Le certificat AAB diffère du certificat APK officiel")
    with zipfile.ZipFile(args.bundle) as archive:
        for name in archive.namelist():
            if re.search(r"(^|/)(service_account\.json|key\.properties|[^/]*\.(jks|keystore))$", name, re.I):
                raise ValueError("Fichier sensible présent dans le bundle")
    report["certificateSha256"] = actual_cert
    Path(args.report).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("Bundle vérifié : identité, version, API, permissions et signature.")


if __name__ == "__main__":
    main()
