import { describe, it, expect } from '@ohos/hypium';
import { Driver, ON } from '@ohos.UiTest';

// Run after launching EntryAbility. No writes, no private ledger fixtures.
export default function navigationTest() {
  describe('FinanceNavigation', () => {
    it('defaultsToRecordAndHasFiveOrderedDestinations', 0, async () => {
      const driver = Driver.create();
      expect((await driver.findComponent(ON.id('finance-page-record'))) !== undefined).assertTrue();
      const ids: string[] = ['statistics', 'details', 'record', 'deposits', 'profile'];
      let previous = -1;
      for (const id of ids) {
        const item = await driver.findComponent(ON.id(`finance-nav-${id}`));
        const bounds = await item.getBounds();
        expect(bounds.left > previous).assertTrue(); previous = bounds.left;
      }
      await (await driver.findComponent(ON.id('finance-nav-profile'))).click();
      expect((await driver.findComponent(ON.id('finance-page-profile'))) !== undefined).assertTrue();
      await (await driver.findComponent(ON.id('finance-nav-record'))).click();
    });
  });
}
