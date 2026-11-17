import { describe, it, expect } from '@ohos/hypium';
import { emptyLedger } from '../main/ets/model/LedgerModels';
import { encodePortable, previewPortable } from '../main/ets/service/PortableBackup';
export default function portableBackupTest() {
  describe('PortableBackup', () => {
    it('carriesAttachmentsAndLegacyArchiveWithoutActivatingDiary', 0, () => {
      const data = emptyLedger(); data.attachments.push({ id: 'x', relativePath: 'images/img_test.jpg' });
      const text = encodePortable(data, [{ path: 'images/img_test.jpg', base64: 'YWJj' }, { path: 'legacy/tallyjie.json', base64: 'e30=' }]);
      const result = previewPortable(emptyLedger(), text);
      expect(result.files.length).assertEqual(2); expect(result.preview.data.attachments[0].id).assertEqual('x');
      expect(previewPortable(result.preview.data, text).preview.added).assertEqual(0);
      let failed = false; try { encodePortable(data, []); } catch (_) { failed = true; } expect(failed).assertTrue();
    });
    it('rejectsTraversalDuplicatePathsAndMalformedBase64', 0, () => {
      for (const path of ['../secret', '/absolute', 'images/../x', 'images/a.exe']) {
        let failed = false; try { encodePortable(emptyLedger(), [{ path: path, base64: 'YWJj' }]); } catch (_) { failed = true; }
        expect(failed).assertTrue();
      }
      let failed = false;
      try { encodePortable(emptyLedger(), [{ path: 'legacy/tallyjie.json', base64: '???' }]); } catch (_) { failed = true; }
      expect(failed).assertTrue();
      failed = false;
      try { encodePortable(emptyLedger(), [{ path: 'legacy/tallyjie.json', base64: 'e30=' }, { path: 'legacy/tallyjie.json', base64: 'e30=' }]); } catch (_) { failed = true; }
      expect(failed).assertTrue();
    });
  });
}
