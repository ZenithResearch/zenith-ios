"""Release preflight regressions; synthetic metadata only, no signing identity needed."""
import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('package_ios_app', Path(__file__).with_name('package-ios-app.py'))
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)


class BaselineGuardTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.app = Path(self.directory.name) / 'new.app'
        self.baseline = Path(self.directory.name) / 'old.app'
        for app in [self.app, self.baseline]:
            app.mkdir()
            (app / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': 'test.wallet'}))
        self.old = {'application-identifier': 'TEST.test.wallet',
                    'com.apple.developer.team-identifier': 'TEST',
                    'keychain-access-groups': ['TEST.*']}
        self.new = dict(self.old)
        self.profile = {'Entitlements': {'keychain-access-groups': ['TEST.*']}}
        self.verifier = self.enterContext(patch.object(package, 'verify', return_value={}))
        self.enterContext(patch.object(package, 'entitlements', side_effect=lambda p: self.new if p == self.app else self.old))
        self.runner = self.enterContext(patch.object(package, 'run', side_effect=lambda *args: SimpleNamespace(stdout=plistlib.dumps(self.profile))))

    def test_unchanged_baseline_passes(self):
        self.assertTrue(package.verify_baseline(self.app, self.baseline)['baseline_entitlements_unchanged'])
        self.verifier.assert_called_once_with(self.baseline)

    def test_missing_keychain_group_rejects_before_output_or_signing(self):
        self.new.pop('keychain-access-groups')
        with self.assertRaisesRegex(RuntimeError, 'entitlements differ'):
            package.verify_baseline(self.app, self.baseline)
        self.runner.assert_not_called()

    def test_changed_application_identity_rejects(self):
        self.new['application-identifier'] = 'OTHER.test.wallet'
        with self.assertRaisesRegex(RuntimeError, 'entitlements differ'):
            package.verify_baseline(self.app, self.baseline)

    def test_added_capability_requires_separate_review(self):
        self.new['new.capability'] = True
        with self.assertRaisesRegex(RuntimeError, 'entitlements differ'):
            package.verify_baseline(self.app, self.baseline)

    def test_bundle_identifier_change_rejects(self):
        (self.app / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': 'other.wallet'}))
        with self.assertRaisesRegex(RuntimeError, 'bundle identifier differs'):
            package.verify_baseline(self.app, self.baseline)

    def test_profile_not_admitting_baseline_rejects(self):
        self.profile['Entitlements']['keychain-access-groups'] = ['OTHER.*']
        with self.assertRaisesRegex(RuntimeError, 'does not admit'):
            package.verify_baseline(self.app, self.baseline)

    def test_invalid_baseline_signature_stops_immediately(self):
        self.verifier.side_effect = RuntimeError('invalid baseline signature')
        with self.assertRaisesRegex(RuntimeError, 'invalid baseline signature'):
            package.verify_baseline(self.app, self.baseline)
        self.runner.assert_not_called()


if __name__ == '__main__':
    unittest.main()
