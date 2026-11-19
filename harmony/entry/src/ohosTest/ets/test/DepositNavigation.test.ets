import { abilityDelegatorRegistry } from '@kit.TestKit';
import { describe, it, expect } from '@ohos/hypium';
import { Driver, ON } from '@ohos.UiTest';

// Read-only smoke test: uses existing accounts, never creates or deletes ledger data.
async function swipeStack(driver: Driver, id: string, up: boolean): Promise<void> {
  const bounds = await (await driver.findComponent(ON.id(id))).getBounds();
  const x = Math.round((bounds.left + bounds.right) / 2);
  const upper = Math.round(bounds.top + (bounds.bottom - bounds.top) * 0.3);
  const lower = Math.round(bounds.top + (bounds.bottom - bounds.top) * 0.7);
  await driver.swipe(x, up ? lower : upper, x, up ? upper : lower, 600);
  await driver.delayMs(650);
}
export default function depositNavigationTest() {
  describe('DepositNavigation', () => {
    it('fanOnlyDetailOpensEditorDirectlyWithoutWriting', 0, async () => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      await delegator.startAbility({ bundleName: 'com.tallyjie.harmony', abilityName: 'EntryAbility' });
      const driver = Driver.create();
      await driver.delayMs(1500);
      await (await driver.findComponent(ON.id('finance-nav-deposits'))).click();
      await driver.delayMs(500);
      expect((await driver.findComponent(ON.text('转账'))) === null).assertTrue();
      const stack = await driver.findComponent(ON.id('deposit-home-stack'));
      if (stack === null) {
        expect((await driver.findComponent(ON.text('创建账户'))) !== null).assertTrue();
        await (await driver.findComponent(ON.id('finance-nav-record'))).click();
        return;
      }
      const upper = await (await driver.findComponent(ON.id('deposit-card-half'))).getBounds();
      const lower = await (await driver.findComponent(ON.id('deposit-recent-half'))).getBounds();
      expect(upper.bottom - upper.top > lower.bottom - lower.top).assertTrue();
      const panel = await (await driver.findComponent(ON.id('deposit-recent-panel'))).getBounds();
      const nav = await (await driver.findComponent(ON.id('finance-nav-surface'))).getBounds();
      expect(panel.top > lower.top).assertTrue();
      expect(Math.abs(panel.bottom - nav.top) <= 2).assertTrue();
      const face = await (await driver.findComponent(ON.id('deposit-active-card'))).getBounds();
      // The compact face sits slightly below center, with clear space above it.
      const halfHeight = upper.bottom - upper.top;
      expect(face.top - upper.top > halfHeight * 0.22).assertTrue();
      expect(face.bottom < upper.bottom).assertTrue();
      expect(face.bottom - face.top < halfHeight * 0.7).assertTrue();
      expect((face.top + face.bottom) / 2 > (upper.top + upper.bottom) / 2).assertTrue();
      const homeName = await (await driver.findComponent(ON.id('deposit-active-name'))).getText();
      const nextHome = await driver.findComponent(ON.id('deposit-next-name'));
      const hasNextHome = (await driver.findComponent(ON.id('deposit-next-card'))) !== null;
      const nextHomeName = nextHome === null ? '' : await nextHome.getText();
      await swipeStack(driver, 'deposit-home-stack', true);
      const switchedHome = await (await driver.findComponent(ON.id('deposit-active-name'))).getText();
      if (nextHomeName.length > 0) { expect(switchedHome).assertEqual(nextHomeName); }
      else { expect(switchedHome !== homeName).assertEqual(hasNextHome); }
      const nextFace = await (await driver.findComponent(ON.id('deposit-active-card'))).getBounds();
      expect(nextFace.bottom - nextFace.top).assertEqual(face.bottom - face.top);
      await swipeStack(driver, 'deposit-home-stack', false);
      expect(await (await driver.findComponent(ON.id('deposit-active-name'))).getText()).assertEqual(homeName);
      await (await driver.findComponent(ON.id('deposit-active-name'))).click();
      await driver.delayMs(500);
      expect((await driver.findComponent(ON.id('deposit-detail-stack'))) !== null).assertTrue();
      expect((await driver.findComponent(ON.id('deposit-vertical-deck'))) === null).assertTrue();
      expect((await driver.findComponent(ON.id('deposit-deck-toggle'))) === null).assertTrue();
      expect((await driver.findComponent(ON.id('deposit-account-add'))) === null).assertTrue();
      expect((await driver.findComponent(ON.id('finance-nav-deposits'))) === null).assertTrue();
      expect((await driver.findComponent(ON.id('deposit-account-position'))) === null).assertTrue();
      expect((await driver.findComponent(ON.text('⌃'))) === null).assertTrue();
      expect((await driver.findComponent(ON.text('⌄'))) === null).assertTrue();
      expect((await driver.findComponent(ON.id('deposit-detail-scroll'))) === null).assertTrue();
      const page = await (await driver.findComponent(ON.id('finance-page-deposits'))).getBounds();
      const info = await (await driver.findComponent(ON.id('deposit-detail-info'))).getBounds();
      expect(info.top > page.top && info.bottom <= page.bottom).assertTrue();
      expect((await driver.findComponent(ON.id('deposit-account-delete'))) === null).assertTrue();
      const accountNameBounds = await (await driver.findComponent(ON.id('deposit-account-name-display'))).getBounds();
      const holderBounds = await (await driver.findComponent(ON.id('deposit-account-holder-display'))).getBounds();
      expect(holderBounds.top > accountNameBounds.bottom && holderBounds.left === accountNameBounds.left).assertTrue();
      const localName = await (await driver.findComponent(ON.id('deposit-account-name-display'))).getText();
      await swipeStack(driver, 'deposit-detail-stack', true);
      expect(await (await driver.findComponent(ON.id('deposit-active-name'))).getText()).assertEqual(switchedHome);
      await swipeStack(driver, 'deposit-detail-stack', false);
      expect(await (await driver.findComponent(ON.id('deposit-active-name'))).getText()).assertEqual(homeName);
      // Tapping the current fan card edits it directly; there is no expanded deck.
      await (await driver.findComponent(ON.id('deposit-active-name'))).click();
      await driver.delayMs(400);
      expect((await driver.findComponent(ON.id('deposit-vertical-deck'))) === null).assertTrue();
      expect(await (await driver.findComponent(ON.id('deposit-account-name'))).getText()).assertEqual(localName);
      expect((await driver.findComponent(ON.id('deposit-account-english-name'))) !== null).assertTrue();
      expect((await driver.findComponent(ON.text('账户类型'))) !== null).assertTrue();
      expect((await driver.findComponent(ON.text('卡面图标'))) === null).assertTrue();
      expect((await driver.findComponent(ON.text('这是记账起点的余额，不是当前余额；修改后会重新计算账户余额。'))) === null).assertTrue();
      expect((await driver.findComponent(ON.text('仅信用账户允许负余额。'))) === null).assertTrue();
      expect((await driver.findComponent(ON.id('deposit-account-holder'))) !== null).assertTrue();
      const removedKeys: string[] = ['cash', 'wallet', 'applepay', 'paypal', 'bank', 'card'];
      for (let index = 0; index < removedKeys.length; index++) {
        expect((await driver.findComponent(ON.id(`deposit-icon-${removedKeys[index]}`))) === null).assertTrue();
      }
      const iconKeys: string[] = ['wechat', 'alipay', 'unionpay', 'quickpass',
        'icbc', 'abc', 'boc', 'ccb', 'bocom', 'psbc', 'cmb', 'citic', 'pab'];
      for (let index = 0; index < iconKeys.length; index++) {
        expect((await driver.findComponent(ON.id(`deposit-icon-${iconKeys[index]}`))) !== null).assertTrue();
      }
      const fields = await (await driver.findComponent(ON.id('deposit-editor-scroll'))).getBounds();
      const save = await (await driver.findComponent(ON.id('deposit-account-save'))).getBounds();
      expect(save.top >= fields.bottom && save.bottom <= page.bottom).assertTrue();
      // Changing a provider and cancelling must not write to the real ledger.
      await (await driver.findComponent(ON.id('deposit-icon-icbc'))).click();
      expect(await (await driver.findComponent(ON.id('deposit-account-english-name'))).getText()).assertEqual('ICBC');
      await (await driver.findComponent(ON.id('deposit-icon-cmb'))).click();
      expect(await (await driver.findComponent(ON.id('deposit-account-english-name'))).getText())
        .assertEqual('China Merchants Bank');
      await (await driver.findComponent(ON.text('取消'))).click();
      await driver.delayMs(400);
      expect((await driver.findComponent(ON.id('deposit-detail-stack'))) !== null).assertTrue();
      expect((await driver.findComponent(ON.id('deposit-vertical-deck'))) === null).assertTrue();
      expect((await driver.findComponent(ON.id('deposit-account-name'))) === null).assertTrue();
      expect(await (await driver.findComponent(ON.id('deposit-active-name'))).getText()).assertEqual(homeName);
      await (await driver.findComponent(ON.id('deposit-detail-back'))).click();
      await driver.delayMs(400);
      expect((await driver.findComponent(ON.id('finance-nav-deposits'))) !== null).assertTrue();
      expect(await (await driver.findComponent(ON.id('deposit-active-name'))).getText()).assertEqual(homeName);
      // Every visit retains the fan and the selected account.
      await (await driver.findComponent(ON.id('deposit-active-name'))).click();
      await driver.delayMs(500);
      expect((await driver.findComponent(ON.id('deposit-detail-stack'))) !== null).assertTrue();
      expect((await driver.findComponent(ON.id('deposit-vertical-deck'))) === null).assertTrue();
      expect((await driver.findComponent(ON.id('deposit-deck-toggle'))) === null).assertTrue();
      expect((await driver.findComponent(ON.id('deposit-account-add'))) === null).assertTrue();
      expect(await (await driver.findComponent(ON.id('deposit-active-name'))).getText()).assertEqual(homeName);
      await (await driver.findComponent(ON.id('deposit-detail-back'))).click();
      await driver.delayMs(400);
      await (await driver.findComponent(ON.id('finance-nav-record'))).click();
    });
  });
}
