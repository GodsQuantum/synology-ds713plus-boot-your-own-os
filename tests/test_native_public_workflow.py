import hashlib
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]

class NativePublicWorkflow(unittest.TestCase):
    def text(self, rel):
        return (ROOT / rel).read_text()

    def test_validated_n3_payload_is_shipped_and_exact(self):
        p = ROOT / 'native' / 'validated' / 'DS713NativeBoot-N3.efi'
        self.assertTrue(p.is_file())
        self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),
                         '63037d646791ddfc133840ecd5b4c80151213c61e8ce34862b7483799734d6a3')

    def test_validated_efi_payloads_are_tracked_by_git(self):
        tracked = set(subprocess.check_output(['git', 'ls-files'], cwd=ROOT, text=True).splitlines())
        required = {
            'native/validated/DS713NativeBoot-N3.efi',
            'native/validated/drivers/XhciDxe.efi',
            'native/validated/drivers/UsbBusDxe.efi',
            'native/validated/drivers/UsbMassStorageDxe.efi',
            'native/validated/drivers/DiskIoDxe.efi',
            'native/validated/drivers/PartitionDxe.efi',
            'native/validated/drivers/EnglishDxe.efi',
            'native/validated/drivers/Fat.efi',
        }
        self.assertTrue(required <= tracked, sorted(required - tracked))

    def test_native_public_scripts_have_no_developer_absolute_paths(self):
        for p in (ROOT / 'scripts' / 'native').glob('*'):
            if p.is_file():
                self.assertNotIn('/home/arezki', p.read_text(errors='ignore'), p)

    def test_builder_combines_f400_candidate_with_n3_from_stock_carrier(self):
        s = self.text('scripts/native/build_firmware.py')
        for token in ('bios-read1.bin', 'used-regions-read1.bin', 'candidate-bios.bin',
                      'DS713NativeBoot-N3.efi', 'FINAL_F400_UNLOCK=PASS',
                      'FINAL_N3_LOADER=PASS'):
            self.assertIn(token, s)

    def test_preflight_is_retail_safe_not_n2_dependent(self):
        s = self.text('scripts/native/02-preflight.sh')
        self.assertNotIn('N2_STATUS', s)
        self.assertNotIn('N3_BASELINE_STATUS', s)
        self.assertIn('READY_TO_FLASH=YES', s)

    def test_flash_requires_explicit_arm_and_has_rollback_and_double_verify(self):
        s = self.text('scripts/native/03-flash.sh')
        self.assertIn('DS713_NATIVE_N3_FLASH_ARM_V1', s)
        self.assertIn('ROLLBACK', s)
        self.assertGreaterEqual(s.count('CANDIDATE_VERIFY'), 2)
        self.assertGreaterEqual(s.count('ROLLBACK_VERIFY'), 2)

    def test_quickstart_makes_native_firmware_primary_and_bridge_optional(self):
        s = self.text('docs/QUICKSTART.fr.md')
        self.assertIn('./scripts/open-ds713plus.sh build', s)
        self.assertIn('native/validated/', s)
        self.assertIn('N3', s)
        self.assertIn("n'est plus nécessaire", s.lower())
        self.assertTrue((ROOT / 'bridge' / 'README.fr.md').is_file())

    def test_loader_format_check_is_mandatory(self):
        s = self.text('scripts/native/00-prepare-loader.sh')
        self.assertIn("grep -q 'pei-x86-64'", s)
        self.assertNotIn("grep -q 'pei-x86-64' || true", s)

    def test_make_lint_covers_native_workflow(self):
        s = self.text('Makefile')
        self.assertIn('scripts/native/*.sh', s)
        self.assertIn('scripts/native/build_firmware.py', s)
        self.assertIn('tests.test_native_public_workflow', s)

    def test_uefi_tool_builder_does_not_depend_on_eol_debian11(self):
        s = self.text('scripts/04-build-uefi-tools.sh')
        self.assertNotIn('debian:11', s)
        self.assertIn('debian:12', s)

    def test_f400_verifier_matches_real_ds713_instruction_context(self):
        anchor = '33F6448ACA'
        self.assertIn(anchor, self.text('scripts/05-patch-bios.sh').upper())
        self.assertIn(anchor, self.text('scripts/native/build_firmware.py').upper())

    def test_one_entrypoint_exposes_safe_retail_stages(self):
        p = ROOT / 'scripts' / 'open-ds713plus.sh'
        self.assertTrue(p.is_file())
        s = p.read_text()
        for stage in ('audit', 'build', 'prepare', 'arm', 'status', 'verify'):
            self.assertIn(stage, s)
        self.assertNotIn('/home/arezki', s)

if __name__ == '__main__':
    unittest.main()
