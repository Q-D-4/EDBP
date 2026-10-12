#!/usr/bin/env python3
"""Pure-mock regression tests for Phase 2 first-boot Flatseal gate.

No chroot, systemd, network, or real Flatpak execution.
"""
import importlib.machinery
import importlib.util
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / 'config/includes.chroot_after_packages/usr/local/sbin/edbp-flatseal-admin'
INSTALLER = ROOT / 'config/includes.installer/edbp-late-command'
UNITROOT = ROOT / 'config/includes.chroot_after_packages/etc/systemd/system'


def load_helper():
    loader = importlib.machinery.SourceFileLoader('flatseal_firstboot_test', str(HELPER))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


class FirstBootTests(unittest.TestCase):
    def setUp(self):
        self.helper = load_helper()
        self.tmp = tempfile.TemporaryDirectory(prefix='edbp-regression-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.admin_home = self.root / 'edbpadmin'
        self.admin_home.mkdir(mode=0o700)
        self.account = SimpleNamespace(pw_uid=os.getuid(), pw_gid=os.getgid(),
                                       pw_dir=str(self.admin_home))
        self.pinned = {f'runtime/test/{i}': str(i) for i in range(11)}
        self.pinned[self.helper.REF] = 'pinned-commit'
        self.edbp = SimpleNamespace(safe_environment=lambda: {})
        overrides = {
            'MARKER': self.root / 'flatseal-admin-ready',
            'LOCK': self.root / 'provision.lock',
            'BUNDLE': self.root / 'flatseal.flatpak',
            'ADMIN_HOME': self.admin_home,
        }
        for key, value in overrides.items():
            patch = mock.patch.object(self.helper, key, value)
            patch.start()
            self.addCleanup(patch.stop)
        self.helper.BUNDLE.write_bytes(b'pinned-offline-flatseal-bundle')
        self.common = [
            mock.patch.object(self.helper, 'require_root'),
            mock.patch.object(self.helper, 'load_importer', return_value=self.edbp),
            mock.patch.object(self.helper, 'load_lock', return_value=({}, {}, {}, self.pinned)),
            mock.patch.object(self.helper, 'bundle_record', return_value=hashlib.sha256(b'pinned-offline-flatseal-bundle').hexdigest()),
            mock.patch.object(self.helper, 'admin_identity', return_value=self.account),
            mock.patch.object(self.helper, 'verify_installed'),
        ]
        for patch in self.common:
            patch.start()
            self.addCleanup(patch.stop)

    def test_staged_verification_avoids_flatpak(self):
        with mock.patch.object(self.helper, 'system_pins', side_effect=AssertionError('no Flatpak during installer')),              mock.patch.object(self.helper.os.path, 'isfile', return_value=True),              mock.patch.object(self.helper.os, 'access', return_value=True):
            self.helper.verify_staged()

    def test_user_subprocess_uses_ephemeral_session_bus_and_network_namespace(self):
        with mock.patch.object(self.helper, 'run', return_value='') as run:
            self.helper.user_flatpak(self.account, 'list', '--user', network_isolated=True)
            argv = run.call_args.args[0]
            self.assertEqual(argv[:3], ['unshare', '--net', '--'])
            self.assertIn('dbus-run-session', argv)
            self.assertEqual(argv[-3:], ['flatpak', 'list', '--user'])
            self.assertIn('HOME=' + str(self.admin_home), argv)

    def test_recovers_after_system_flatseal_was_removed(self):
        def pins(*args, **kw):
            if self.helper.REF in args[4]:
                raise ValueError('12-ref mismatch: interrupted uninstall')
        with mock.patch.object(self.helper, 'system_pins', side_effect=pins), \
             mock.patch.object(self.helper, 'user_pins') as user_pins, \
             mock.patch.object(self.helper, 'run') as system_run, \
             mock.patch.object(self.helper, 'user_flatpak') as installer:
            self.helper.provision_unlocked()
            self.assertEqual(self.helper.MARKER.read_text(), hashlib.sha256(b'pinned-offline-flatseal-bundle').hexdigest() + '\n')
            self.assertEqual(user_pins.call_count, 2)
            system_run.assert_not_called()
            installer.assert_not_called()

    def test_install_then_system_uninstall_then_marker(self):
        state = {'installed': False, 'uninstalled': False}
        def pins(*args, **kw):
            with_app = self.helper.REF in args[4]
            if with_app == state['uninstalled']:
                raise ValueError('unexpected system refs')
        def user_pins(*args):
            if not state['installed']:
                raise self.helper.FlatpakRefMissing('absent')
        def install_user(*args, **kw):
            self.assertTrue(kw['network_isolated'])
            self.assertTrue(self.helper.REF in self.pinned)
            state['installed'] = True
        def system_run(args, **kw):
            self.assertTrue(state['installed'], 'system ref removal before verified user installation')
            self.assertEqual(args[1:3], ['uninstall', '--system'])
            state['uninstalled'] = True
        with mock.patch.object(self.helper, 'system_pins', side_effect=pins), \
             mock.patch.object(self.helper, 'user_pins', side_effect=user_pins), \
             mock.patch.object(self.helper, 'user_flatpak', side_effect=install_user), \
             mock.patch.object(self.helper, 'run', side_effect=system_run):
            self.helper.provision_unlocked()
            self.assertTrue(state['installed'])
            self.assertTrue(state['uninstalled'])
            self.assertEqual(self.helper.MARKER.read_text(), hashlib.sha256(b'pinned-offline-flatseal-bundle').hexdigest() + '\n')

    def test_rejects_unexpected_user_ref_without_mutating(self):
        with mock.patch.object(self.helper, 'system_pins'), \
             mock.patch.object(self.helper, 'user_pins', side_effect=ValueError('unapproved user refs')), \
             mock.patch.object(self.helper, 'run') as system_run:
            with self.assertRaisesRegex(ValueError, 'unapproved user refs'):
                self.helper.provision_unlocked()
            self.assertFalse(self.helper.MARKER.exists())
            system_run.assert_not_called()

    def test_fails_if_marker_exists_but_verification_fails(self):
        self.helper.MARKER.write_text('stale-value')
        with mock.patch.object(self.helper, 'verify_installed', side_effect=ValueError('marker mismatch')):
            with self.assertRaisesRegex(ValueError, 'marker mismatch'):
                self.helper.provision_unlocked()

    def test_rejects_world_readable_provisioning_lock(self):
        # Security check is deliberately exercised without mocking ownership.
        self.helper.LOCK.write_bytes(b'')
        self.helper.LOCK.chmod(0o644)
        with mock.patch.object(self.helper, 'provision_unlocked') as unlocked:
            with self.assertRaisesRegex(ValueError, 'unsafe provisioning lock permissions'):
                self.helper.provision()
            unlocked.assert_not_called()

    def test_rejects_symlinked_provisioning_lock(self):
        destination = self.root / 'unrelated-file'
        destination.write_text('preserve this content')
        self.helper.LOCK.symlink_to(destination)
        with mock.patch.object(self.helper, 'provision_unlocked') as unlocked:
            with self.assertRaisesRegex(ValueError, 'unsafe provisioning lock symlink'):
                self.helper.provision()
            unlocked.assert_not_called()
        self.assertEqual(destination.read_text(), 'preserve this content')

    def test_lock_passes_mocked_root_owner_then_calls_provision(self):
        # Mock ONLY the root-owned-lock stat; never weaken production validation.
        # The lock remains an actual regular file locked by flock().
        self.helper.LOCK.touch(mode=0o600)
        self.helper.LOCK.chmod(0o600)
        real_fstat = os.fstat

        def root_owned_stat(fd):
            actual = real_fstat(fd)
            return SimpleNamespace(st_uid=0, st_mode=actual.st_mode)

        with mock.patch.object(self.helper.os, 'fstat', side_effect=root_owned_stat), \
             mock.patch.object(self.helper, 'provision_unlocked') as unlocked:
            self.helper.provision()
            unlocked.assert_called_once_with()

    def test_subprocess_failures_preserve_bounded_stderr(self):
        err = subprocess.CalledProcessError(1, ['flatpak'], stderr='Could not connect: No such file or directory')
        with mock.patch.object(self.helper.subprocess, 'run', side_effect=err):
            with self.assertRaisesRegex(ValueError, 'Could not connect'):
                self.helper.run(['flatpak', 'info'])

    def test_installer_and_login_gate_are_wired(self):
        late = INSTALLER.read_text()
        self.assertIn('edbp-flatseal-admin verify-staged', late)
        self.assertNotIn('edbp-flatseal-admin provision', late)
        self.assertIn('edbp-flatseal-provision.service', late)
        gate = (UNITROOT / 'edbp-flatseal-provision.service').read_text()
        self.assertIn('Requires=dbus.service', gate)
        self.assertIn('ExecStart=/usr/local/sbin/edbp-flatseal-admin provision', gate)
        self.assertNotIn('ConditionPathExists=!/var/lib/edbp/flatseal-admin-ready', gate)
        for path in [UNITROOT / 'edbp-oobe.service.d/20-flatseal-provision.conf',
                     UNITROOT / 'sddm.service.d/20-flatseal-provision.conf']:
            content = path.read_text()
            self.assertIn('Requires=edbp-flatseal-provision.service', content)
            self.assertIn('After=edbp-flatseal-provision.service', content)

if __name__ == '__main__':
    unittest.main()
