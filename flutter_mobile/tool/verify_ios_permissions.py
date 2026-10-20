"""Check iOS permission declarations in source or the signed TestFlight IPA."""

import argparse
import plistlib
import shutil
import subprocess
import tempfile
from pathlib import Path
from zipfile import ZipFile


PROJECT = Path(__file__).resolve().parents[1]
USAGE_KEYS = {
    "NSCameraUsageDescription",
    "NSPhotoLibraryUsageDescription",
    "NSHealthShareUsageDescription",
    # Kept for the pinned HealthKit authorization API; no write types are asked.
    "NSHealthUpdateUsageDescription",
}


def verify(info, entitlements, version=None, build=None):
    actual = {key for key in info if key.startswith("NS") and key.endswith("UsageDescription")}
    if actual != USAGE_KEYS:
        raise ValueError(f"Unexpected usage descriptions: {sorted(actual ^ USAGE_KEYS)}")
    for key in USAGE_KEYS:
        if not isinstance(info[key], str) or not info[key].strip():
            raise ValueError(f"Missing explanation for {key}")
    if entitlements.get("com.apple.developer.healthkit") is not True:
        raise ValueError("Missing signed HealthKit entitlement")
    if entitlements.get("com.apple.developer.applesignin") != ["Default"]:
        raise ValueError("Missing signed Sign in with Apple entitlement")
    if info.get("UIBackgroundModes"):
        raise ValueError("Unexpected persistent background modes")
    if version and info.get("CFBundleShortVersionString") != version:
        raise ValueError("IPA marketing version does not match the release")
    if build and str(info.get("CFBundleVersion")) != build:
        raise ValueError("IPA build number does not match the release")
    print("iOS permission declarations verified: camera, photos, read-only HealthKit setup; Sign in with Apple.")
    print("No microphone, location, motion, tracking or persistent background-mode declaration.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--source", action="store_true")
    mode.add_argument("--ipa", type=Path)
    parser.add_argument("--version")
    parser.add_argument("--build")
    args = parser.parse_args()
    if args.source:
        with (PROJECT / "ios/Runner/Info.plist").open("rb") as stream:
            info = plistlib.load(stream)
        with (PROJECT / "ios/Runner/Runner.entitlements").open("rb") as stream:
            entitlements = plistlib.load(stream)
        verify(info, entitlements)
        return

    with ZipFile(args.ipa) as archive, tempfile.TemporaryDirectory() as directory:
        candidates = [name for name in archive.namelist()
                      if name.startswith("Payload/") and name.count("/") == 2
                      and name.endswith(".app/Info.plist")]
        if len(candidates) != 1:
            raise ValueError("Expected exactly one main app in the IPA")
        info_path = candidates[0]
        info = plistlib.loads(archive.read(info_path))
        executable_name = info["CFBundleExecutable"]
        if Path(executable_name).name != executable_name:
            raise ValueError("Unexpected executable name")
        executable = Path(directory) / executable_name
        with archive.open(info_path.rsplit("/", 1)[0] + "/" + executable_name) as source:
            with executable.open("wb") as destination:
                shutil.copyfileobj(source, destination)
        signed = subprocess.run(
            ["/usr/bin/codesign", "-d", "--entitlements", ":-", str(executable)],
            check=True, capture_output=True,
        )
        entitlements = plistlib.loads(signed.stdout)
        verify(info, entitlements, args.version, args.build)


if __name__ == "__main__":
    main()
