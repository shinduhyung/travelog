from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import configure_jev_key as setup


class KeySetupTests(unittest.TestCase):
    def test_migration_preserves_key_and_other_app_settings(self):
        folder=Path(__file__).parent/'out'
        folder.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=folder) as temporary:
            root=Path(temporary)
            self.assertTrue(root.resolve().is_relative_to(folder.resolve()))
            original='OTHER_SETTING=keep\r\nTYPESAFE_API_KEY=fixture-only\r\nJEV_API_KEY=old-fixture\r\n'
            (root/'.env').write_bytes(original.encode())
            with patch.object(setup,'ENV_PATH',root/'.env.jev'):
                self.assertEqual(setup.migrate_legacy_key(),2)
                self.assertEqual((root/'.env').read_bytes().decode(),'OTHER_SETTING=keep\r\n')
                self.assertIn('TYPESAFE_API_KEY=fixture-only',(root/'.env.jev').read_text())
                self.assertEqual(setup.migrate_legacy_key(),0)

    def test_update_keeps_other_keys_and_removes_duplicate_entries(self):
        text='OTHER=keep\nTYPESAFE_API_KEY=old\nTYPESAFE_API_KEY=older\n'
        result=setup.update_env(text,'fixture-new')
        self.assertEqual(result.count('TYPESAFE_API_KEY='),1)
        self.assertIn('OTHER=keep',result)


if __name__=='__main__':
    unittest.main()
