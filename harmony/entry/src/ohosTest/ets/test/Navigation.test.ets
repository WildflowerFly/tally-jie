import { abilityDelegatorRegistry } from '@kit.TestKit';
import { describe, it, expect } from '@ohos/hypium';
import { Driver, ON, MatchPattern } from '@ohos.UiTest';

// Run after launching EntryAbility. No writes, no private ledger fixtures.
export default function navigationTest() {
  describe('FinanceNavigation', () => {
    it('defaultsToRecordAndHasFiveOrderedDestinations', 0, async () => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      await delegator.startAbility({ bundleName: 'com.tallyjie.harmony', abilityName: 'EntryAbility' });
      const driver = Driver.create();
      await driver.delayMs(2000);
      expect((await driver.findComponent(ON.id('finance-page-record'))) !== null).assertTrue();
      const ids: string[] = ['statistics', 'details', 'record', 'deposits', 'profile'];
      let previous = -1;
      for (const id of ids) {
        const item = await driver.findComponent(ON.id(`finance-nav-${id}`));
        const bounds = await item.getBounds();
        expect(bounds.left > previous).assertTrue(); previous = bounds.left;
      }
      await (await driver.findComponent(ON.id('finance-nav-profile'))).click();
      await driver.delayMs(500);
      expect((await driver.findComponent(ON.id('finance-page-profile'))) !== null).assertTrue();
      await (await driver.findComponent(ON.id('finance-nav-record'))).click();
    });
    it('redesignedPagesKeepChartsFiltersAndManagementReachable', 0, async () => {
      const driver = Driver.create();
      await (await driver.findComponent(ON.id('finance-nav-statistics'))).click();
      await driver.delayMs(500);
      expect((await driver.findComponent(ON.id('finance-page-statistics'))) !== null).assertTrue();
      await (await driver.findComponent(ON.id('finance-nav-details'))).click();
      await driver.delayMs(500);
      expect((await driver.findComponent(ON.id('details-month-overview'))) !== null).assertTrue();
      await (await driver.findComponent(ON.id('details-search-toggle'))).click();
      await driver.delayMs(300);
      expect((await driver.findComponent(ON.id('details-search-input'))) !== null).assertTrue();
      expect((await driver.findComponent(ON.id('details-search-panel'))) === null).assertTrue();
      await (await driver.findComponent(ON.id('details-search-close'))).click();
      await driver.delayMs(300);
      await (await driver.findComponent(ON.id('finance-nav-profile'))).click();
      await driver.delayMs(500);
      expect((await driver.findComponent(ON.id('profile-overview'))) !== null).assertTrue();
      await (await driver.findComponent(ON.id('profile-manage-accounts'))).click();
      await driver.delayMs(500);
      expect((await driver.findComponent(ON.id('deposit-account-detail'))) !== null).assertTrue();
      expect((await driver.findComponent(ON.id('finance-nav-surface'))) === null).assertTrue();
      await (await driver.findComponent(ON.id('deposit-detail-back'))).click();
      await (await driver.findComponent(ON.id('finance-nav-record'))).click();
      await driver.delayMs(500);
      expect((await driver.findComponent(ON.id('record-amount'))) !== null).assertTrue();
    });
    it('detailsUsesReferenceCardsAndFunctionalFilterShortcuts', 0, async () => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      await delegator.startAbility({ bundleName: 'com.tallyjie.harmony', abilityName: 'EntryAbility' });
      const driver = Driver.create();
      await driver.delayMs(1200);
      await (await driver.findComponent(ON.id('finance-nav-details'))).click();
      await driver.delayMs(500);
      const overview = await (await driver.findComponent(ON.id('details-month-overview'))).getBounds();
      const budget = await (await driver.findComponent(ON.id('details-budget-card'))).getBounds();
      const bar = await (await driver.findComponent(ON.id('details-filter-bar'))).getBounds();
      expect(overview.bottom < budget.top).assertTrue();
      expect(budget.bottom < bar.top).assertTrue();
      expect((await driver.findComponent(ON.text('本月结余'))) !== null).assertTrue();
      expect((await driver.findComponent(ON.text('本月'))) !== null).assertTrue();
      const ids: string[] = ['details-type-filter', 'details-period-filter', 'details-search-toggle'];
      let previous = -1;
      let firstWidth = 0;
      for (const id of ids) {
        const bounds = await (await driver.findComponent(ON.id(id))).getBounds();
        expect(bounds.left > previous).assertTrue(); previous = bounds.left;
        if (firstWidth === 0) { firstWidth = bounds.right - bounds.left; }
        expect(Math.abs(bounds.right - bounds.left - firstWidth) <= 2).assertTrue();
      }
      expect((await driver.findComponent(ON.id('details-open-statistics'))) === null).assertTrue();
      await (await driver.findComponent(ON.id('details-period-filter'))).click();
      await driver.delayMs(300);
      await (await driver.findComponent(ON.text('全部时间'))).click();
      await driver.delayMs(400);
      expect((await driver.findComponent(ON.text('全部时间'))) !== null).assertTrue();
      await (await driver.findComponent(ON.id('details-type-filter'))).click();
      await driver.delayMs(300);
      await (await driver.findComponent(ON.text('收入账单'))).click();
      await driver.delayMs(400);
      expect((await driver.findComponent(ON.text('收入账单'))) !== null).assertTrue();
      const navBefore = await (await driver.findComponent(ON.id('finance-nav-surface'))).getBounds();
      await (await driver.findComponent(ON.id('details-edit-budget'))).click();
      await driver.delayMs(650);
      expect((await driver.findComponent(ON.id('details-budget-sheet'))) !== null).assertTrue();
      const navExpanded = await (await driver.findComponent(ON.id('finance-nav-surface'))).getBounds();
      expect(navExpanded.top < navBefore.top).assertTrue();
      expect(Math.abs(navExpanded.bottom - navBefore.bottom) <= 2).assertTrue();
      expect((await driver.findComponent(ON.text('保存后立即更新剩余预算，不影响账单和账户余额。'))) === null).assertTrue();
      expect((await driver.findComponent(ON.text('仅统计本月支出。', MatchPattern.CONTAINS))) === null).assertTrue();
      expect((await driver.findComponent(ON.id('details-budget-message'))) === null).assertTrue();
      const amountBounds = await (await driver.findComponent(ON.id('details-budget-amount'))).getBounds();
      const keypadBounds = await (await driver.findComponent(ON.id('details-budget-keypad'))).getBounds();
      const saveBounds = await (await driver.findComponent(ON.id('details-budget-save'))).getBounds();
      expect(amountBounds.bottom < keypadBounds.top).assertTrue();
      expect(keypadBounds.bottom < saveBounds.top).assertTrue();
      expect(saveBounds.bottom <= navExpanded.bottom).assertTrue();
      // Invalid empty save exercises validation only; this test never commits a budget.
      const clearAmount = await driver.findComponent(ON.id('details-budget-clear'));
      if (await clearAmount.isEnabled()) { await clearAmount.click(); }
      await (await driver.findComponent(ON.id('details-budget-save'))).click();
      await driver.delayMs(250);
      expect((await driver.findComponent(ON.id('details-budget-message'))) !== null).assertTrue();
      for (const key of ['1', '2', 'decimal', '3', '4', '5', 'decimal']) {
        await (await driver.findComponent(ON.id(`details-budget-key-${key}`))).click();
      }
      expect(await (await driver.findComponent(ON.id('details-budget-amount'))).getText()).assertEqual('12.34');
      expect((await driver.findComponent(ON.id('details-budget-message'))) === null).assertTrue();
      await (await driver.findComponent(ON.id('details-budget-key-back'))).click();
      expect(await (await driver.findComponent(ON.id('details-budget-amount'))).getText()).assertEqual('12.3');
      await (await driver.findComponent(ON.id('details-budget-clear'))).click();
      await (await driver.findComponent(ON.id('details-budget-key-decimal'))).click();
      await (await driver.findComponent(ON.id('details-budget-key-0'))).click();
      await (await driver.findComponent(ON.id('details-budget-key-5'))).click();
      expect(await (await driver.findComponent(ON.id('details-budget-amount'))).getText()).assertEqual('0.05');
      await (await driver.findComponent(ON.id('details-budget-cancel'))).click();
      await driver.delayMs(650);
      expect((await driver.findComponent(ON.id('details-budget-sheet'))) === null).assertTrue();
      expect((await driver.findComponent(ON.text('全部时间'))) !== null).assertTrue();
      expect((await driver.findComponent(ON.text('收入账单'))) !== null).assertTrue();
      const navAfter = await (await driver.findComponent(ON.id('finance-nav-surface'))).getBounds();
      expect(Math.abs(navAfter.top - navBefore.top) <= 2).assertTrue();
      // Opening and dismissing the form never writes or leaves the details page.
      await (await driver.findComponent(ON.id('details-edit-budget'))).click();
      await driver.delayMs(650);
      await driver.pressBack();
      await driver.delayMs(650);
      expect((await driver.findComponent(ON.id('details-budget-sheet'))) === null).assertTrue();
      expect((await driver.findComponent(ON.id('details-budget-card'))) !== null).assertTrue();
      await (await driver.findComponent(ON.id('finance-nav-record'))).click();
    });
    it('detailsExpandsSearchInlineAndKeepsIconFiltersFunctional', 0, async () => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      await delegator.startAbility({ bundleName: 'com.tallyjie.harmony', abilityName: 'EntryAbility' });
      const driver = Driver.create();
      await driver.delayMs(1200);
      await (await driver.findComponent(ON.id('finance-nav-details'))).click();
      await driver.delayMs(500);
      const before = await (await driver.findComponent(ON.id('details-filter-bar'))).getBounds();
      const collapsed = await (await driver.findComponent(ON.id('details-search-toggle'))).getBounds();
      await (await driver.findComponent(ON.id('details-search-toggle'))).click();
      await driver.delayMs(650);
      const bar = await (await driver.findComponent(ON.id('details-filter-bar'))).getBounds();
      const type = await (await driver.findComponent(ON.id('details-type-filter'))).getBounds();
      const period = await (await driver.findComponent(ON.id('details-period-filter'))).getBounds();
      const search = await (await driver.findComponent(ON.id('details-search-capsule'))).getBounds();
      expect(Math.abs(bar.bottom - bar.top - (before.bottom - before.top)) <= 2).assertTrue();
      expect(Math.abs(type.right - type.left - (type.bottom - type.top)) <= 2).assertTrue();
      expect(Math.abs(period.right - period.left - (type.right - type.left)) <= 2).assertTrue();
      expect(type.right < period.left && period.right < search.left).assertTrue();
      expect(Math.abs(type.top - search.top) <= 2 && Math.abs(period.top - search.top) <= 2).assertTrue();
      expect(search.right - search.left > collapsed.right - collapsed.left).assertTrue();
      expect((await driver.findComponent(ON.id('details-type-icon'))) !== null).assertTrue();
      expect((await driver.findComponent(ON.id('details-period-icon'))) !== null).assertTrue();
      expect((await driver.findComponent(ON.text('全部账单'))) === null).assertTrue();
      expect((await driver.findComponent(ON.text('查找交易'))) === null).assertTrue();
      expect((await driver.findComponent(ON.id('details-search-panel'))) === null).assertTrue();
      expect((await driver.findComponent(ON.id('details-advanced-toggle'))) === null).assertTrue();
      expect((await driver.findComponent(ON.text('应用筛选'))) === null).assertTrue();
      expect((await driver.findComponent(ON.text('重置筛选'))) === null).assertTrue();
      await (await driver.findComponent(ON.id('details-search-input'))).inputText('__details_inline_no_match_719035__');
      await driver.delayMs(800);
      // Dismiss the IME before inspecting results below the input, not the search itself.
      await driver.pressBack();
      await driver.delayMs(400);
      expect(await (await driver.findComponent(ON.id('details-entry-count'))).getText()).assertEqual('0 条');
      expect((await driver.findComponent(ON.id('details-filter-summary'))) !== null).assertTrue();
      await (await driver.findComponent(ON.id('details-search-close'))).click();
      await driver.delayMs(500);
      expect((await driver.findComponent(ON.id('details-search-input'))) === null).assertTrue();
      expect((await driver.findComponent(ON.id('details-filter-summary'))) === null).assertTrue();
      expect((await driver.findComponent(ON.text('全部账单'))) !== null).assertTrue();
      expect((await driver.findComponent(ON.text('本月'))) !== null).assertTrue();
      // Compact icons remain menus; a nonempty query survives keyboard dismissal.
      await (await driver.findComponent(ON.id('details-search-toggle'))).click();
      await driver.delayMs(500);
      expect(await (await driver.findComponent(ON.id('details-search-input'))).getText()).assertEqual('');
      await (await driver.findComponent(ON.id('details-search-input'))).inputText('__details_inline_filter_719035__');
      await driver.delayMs(400);
      await (await driver.findComponent(ON.id('details-type-filter'))).click();
      await driver.delayMs(700);
      await (await driver.findComponent(ON.text('收入账单'))).click();
      await driver.delayMs(700);
      await (await driver.findComponent(ON.id('details-period-filter'))).click();
      await driver.delayMs(700);
      await (await driver.findComponent(ON.text('全部时间'))).click();
      await driver.delayMs(500);
      expect((await driver.findComponent(ON.id('details-search-input'))) !== null).assertTrue();
      await (await driver.findComponent(ON.id('details-search-close'))).click();
      await driver.delayMs(400);
      expect((await driver.findComponent(ON.text('收入账单'))) !== null).assertTrue();
      expect((await driver.findComponent(ON.text('全部时间'))) !== null).assertTrue();
      const restored = await (await driver.findComponent(ON.id('details-search-toggle'))).getBounds();
      expect(Math.abs(restored.right - restored.left - (collapsed.right - collapsed.left)) <= 2).assertTrue();
      await (await driver.findComponent(ON.id('details-clear-filters'))).click();
      await (await driver.findComponent(ON.id('finance-nav-record'))).click();
    });
    it('detailsRestoresEmptySearchAfterKeyboardDismissal', 0, async () => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      await delegator.startAbility({ bundleName: 'com.tallyjie.harmony', abilityName: 'EntryAbility' });
      const driver = Driver.create();
      await driver.delayMs(1200);
      await (await driver.findComponent(ON.id('finance-nav-details'))).click();
      await driver.delayMs(500);
      const normal = await (await driver.findComponent(ON.id('details-filter-bar'))).getBounds();
      await (await driver.findComponent(ON.id('details-search-toggle'))).click();
      await driver.delayMs(650);
      expect((await driver.findComponent(ON.id('details-search-input'))) !== null).assertTrue();
      // Prefer the actual IME hide control on this emulator; other IMEs may expose none.
      const hideKeyboard = await driver.findComponent(ON.id('KeyHideKbd'));
      if (hideKeyboard !== null) { await hideKeyboard.click(); } else { await driver.pressBack(); }
      await driver.delayMs(650);
      expect((await driver.findComponent(ON.id('details-search-input'))) === null).assertTrue();
      expect((await driver.findComponent(ON.text('全部账单'))) !== null).assertTrue();
      expect((await driver.findComponent(ON.text('本月'))) !== null).assertTrue();
      let width = 0;
      for (const id of ['details-type-filter', 'details-period-filter', 'details-search-toggle']) {
        const bounds = await (await driver.findComponent(ON.id(id))).getBounds();
        if (width === 0) { width = bounds.right - bounds.left; }
        expect(Math.abs(bounds.right - bounds.left - width) <= 2).assertTrue();
      }
      const restored = await (await driver.findComponent(ON.id('details-filter-bar'))).getBounds();
      expect(Math.abs(restored.bottom - restored.top - (normal.bottom - normal.top)) <= 2).assertTrue();
      // Whitespace is also empty for search; a real keyword stays visible with its results.
      await (await driver.findComponent(ON.id('details-search-toggle'))).click();
      await driver.delayMs(650);
      await (await driver.findComponent(ON.id('details-search-input'))).inputText('   ');
      await driver.pressBack();
      await driver.delayMs(650);
      expect((await driver.findComponent(ON.id('details-search-input'))) === null).assertTrue();
      expect((await driver.findComponent(ON.id('details-filter-summary'))) === null).assertTrue();
      await (await driver.findComponent(ON.id('details-search-toggle'))).click();
      await driver.delayMs(650);
      await (await driver.findComponent(ON.id('details-search-input'))).inputText('__details_dismiss_keep_719035__');
      await driver.delayMs(400);
      await driver.pressBack();
      await driver.delayMs(650);
      expect(await (await driver.findComponent(ON.id('details-search-input'))).getText()).assertEqual('__details_dismiss_keep_719035__');
      expect((await driver.findComponent(ON.id('details-type-icon'))) !== null).assertTrue();
      expect((await driver.findComponent(ON.id('details-period-icon'))) !== null).assertTrue();
      expect(await (await driver.findComponent(ON.id('details-entry-count'))).getText()).assertEqual('0 条');
      // Removing that keyword then dismissing should restore the normal controls again.
      await (await driver.findComponent(ON.id('details-search-input'))).inputText('');
      await driver.delayMs(400);
      await driver.pressBack();
      await driver.delayMs(650);
      expect((await driver.findComponent(ON.id('details-search-input'))) === null).assertTrue();
      expect((await driver.findComponent(ON.id('details-search-toggle'))) !== null).assertTrue();
      expect((await driver.findComponent(ON.id('details-filter-summary'))) === null).assertTrue();
      // Empty search also collapses when opening a filter menu, without losing that action.
      await (await driver.findComponent(ON.id('details-search-toggle'))).click();
      await driver.delayMs(650);
      await (await driver.findComponent(ON.id('details-type-filter'))).click();
      await driver.delayMs(700);
      await (await driver.findComponent(ON.text('收入账单'))).click();
      await driver.delayMs(500);
      expect((await driver.findComponent(ON.id('details-search-input'))) === null).assertTrue();
      expect((await driver.findComponent(ON.text('收入账单'))) !== null).assertTrue();
      await (await driver.findComponent(ON.id('details-period-filter'))).click();
      await driver.delayMs(500);
      await (await driver.findComponent(ON.text('全部时间'))).click();
      await driver.delayMs(500);
      await (await driver.findComponent(ON.id('details-search-toggle'))).click();
      await driver.delayMs(650);
      await driver.pressBack();
      await driver.delayMs(650);
      expect((await driver.findComponent(ON.text('收入账单'))) !== null).assertTrue();
      expect((await driver.findComponent(ON.text('全部时间'))) !== null).assertTrue();
      await (await driver.findComponent(ON.id('details-clear-filters'))).click();
      await (await driver.findComponent(ON.id('finance-nav-record'))).click();
    });
    it('entryEditorUsesCompactLabeledFieldsAndPreservesCancelledEdits', 0, async () => {
      // Requires a real ledger row. Changes below remain drafts; only invalid saves are attempted.
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      await delegator.startAbility({ bundleName: 'com.tallyjie.harmony', abilityName: 'EntryAbility' });
      const driver = Driver.create();
      await driver.delayMs(1200);
      await (await driver.findComponent(ON.id('finance-nav-details'))).click();
      await driver.delayMs(500);
      const nav = await (await driver.findComponent(ON.id('finance-nav-surface'))).getBounds();
      await driver.swipe(nav.right - 100, nav.top - 100, nav.right - 100, nav.top - 1100, 600);
      await driver.delayMs(400);
      const entries = await driver.findComponents(ON.id('details-entry-', MatchPattern.STARTS_WITH));
      let entryId = '';
      for (const entry of entries) {
        const id = await entry.getId();
        if (id !== 'details-entry-count') { entryId = id; break; }
      }
      if (!entryId) {
        console.info('Entry editor UI check skipped: the current ledger has no visible row.');
        return;
      }
      await (await driver.findComponent(ON.id(entryId))).click();
      await driver.delayMs(400);
      expect((await driver.findComponent(ON.text('TRANSACTIONS · 每一笔都有记录'))) === null).assertTrue();
      expect((await driver.findComponent(ON.text('交易详情'))) === null).assertTrue();
      expect((await driver.findComponent(ON.text('勾选为收入，未勾选为支出'))) === null).assertTrue();
      expect((await driver.findComponent(ON.text('编辑账单'))) !== null).assertTrue();
      const account = await (await driver.findComponent(ON.id('details-edit-account'))).getBounds();
      const category = await (await driver.findComponent(ON.id('details-edit-category'))).getBounds();
      const date = await (await driver.findComponent(ON.id('details-edit-date'))).getBounds();
      const time = await (await driver.findComponent(ON.id('details-edit-time'))).getBounds();
      const save = await (await driver.findComponent(ON.id('details-edit-save'))).getBounds();
      const remove = await (await driver.findComponent(ON.id('details-edit-delete'))).getBounds();
      expect(account.right < category.left && Math.abs(account.top - category.top) <= 2).assertTrue();
      expect(date.right < time.left && Math.abs(date.top - time.top) <= 2).assertTrue();
      expect(save.right < remove.left && Math.abs(save.top - remove.top) <= 2).assertTrue();
      expect(save.bottom < nav.top && remove.bottom < nav.top).assertTrue();
      const originalAmount = await (await driver.findComponent(ON.id('details-edit-amount'))).getText();
      const originalNote = await (await driver.findComponent(ON.id('details-edit-note'))).getText();
      const originalCategory = await (await driver.findComponent(ON.id('details-edit-category'))).getText();
      await (await driver.findComponent(ON.id('details-edit-delete'))).click();
      await driver.delayMs(250);
      expect((await driver.findComponent(ON.text('删除这笔账单？'))) !== null).assertTrue();
      await (await driver.findComponent(ON.text('取消'))).click();
      await driver.delayMs(350);
      await (await driver.findComponent(ON.id('details-edit-income'))).click();
      await driver.delayMs(250);
      await (await driver.findComponent(ON.id('details-edit-expense'))).click();
      await driver.delayMs(250);
      expect(await (await driver.findComponent(ON.id('details-edit-category'))).getText()).assertEqual('选择分类');
      await (await driver.findComponent(ON.id('details-edit-save'))).click();
      await driver.delayMs(300);
      expect((await driver.findComponent(ON.id('details-edit-error'))) !== null).assertTrue();
      expect((await driver.findComponent(ON.id('details-entry-editor'))) !== null).assertTrue();
      await (await driver.findComponent(ON.id('details-edit-back'))).click();
      await driver.delayMs(500);
      expect((await driver.findComponent(ON.text('放弃未保存的修改？'))) !== null).assertTrue();
      await (await driver.findComponent(ON.text('继续编辑'))).click();
      await driver.delayMs(500);
      expect((await driver.findComponent(ON.id('details-entry-editor'))) !== null).assertTrue();
      await (await driver.findComponent(ON.id('details-edit-back'))).click();
      await driver.delayMs(500);
      await (await driver.findComponent(ON.text('放弃修改'))).click();
      await driver.delayMs(500);
      await driver.swipe(nav.right - 100, nav.top - 100, nav.right - 100, nav.top - 1100, 600);
      await driver.delayMs(400);
      await (await driver.findComponent(ON.id(entryId))).click();
      await driver.delayMs(300);
      expect(await (await driver.findComponent(ON.id('details-edit-amount'))).getText()).assertEqual(originalAmount);
      expect(await (await driver.findComponent(ON.id('details-edit-note'))).getText()).assertEqual(originalNote);
      expect(await (await driver.findComponent(ON.id('details-edit-category'))).getText()).assertEqual(originalCategory);
      await (await driver.findComponent(ON.id('details-edit-back'))).click();
      await driver.delayMs(300);
      expect((await driver.findComponent(ON.id('details-entry-editor'))) === null).assertTrue();
      expect((await driver.findComponent(ON.text('放弃未保存的修改？'))) === null).assertTrue();
    });
    it('profileUsesTwoColumnCardsAndKeepsAllManagementDestinations', 0, async () => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      await delegator.startAbility({ bundleName: 'com.tallyjie.harmony', abilityName: 'EntryAbility' });
      const driver = Driver.create();
      await driver.delayMs(1000);
      await (await driver.findComponent(ON.id('finance-nav-profile'))).click();
      await driver.delayMs(500);
      // Other navigation tests can leave the profile section on a management subpage.
      const back = await driver.findComponent(ON.text('‹'));
      if (back !== null) { await back.click(); await driver.delayMs(400); }
      expect((await driver.findComponent(ON.id('profile-account-count'))) !== null).assertTrue();
      expect((await driver.findComponent(ON.id('profile-category-count'))) !== null).assertTrue();
      expect((await driver.findComponent(ON.id('profile-budget-count'))) !== null).assertTrue();
      const removedTexts: string[] = ['我的', '管理账本，也照顾好每一笔记录',
        '无需登录 · 数据仅存本机', '记得定期备份，让记录更安心'];
      for (const text of removedTexts) {
        expect((await driver.findComponent(ON.text(text))) === null).assertTrue();
      }
      expect((await driver.findComponent(ON.text('CNY'))) !== null).assertTrue();
      const accounts = await (await driver.findComponent(ON.id('profile-manage-accounts'))).getBounds();
      const categories = await (await driver.findComponent(ON.id('profile-manage-categories'))).getBounds();
      const budgets = await (await driver.findComponent(ON.id('profile-manage-budgets'))).getBounds();
      const exchange = await (await driver.findComponent(ON.id('profile-manage-exchange'))).getBounds();
      expect(accounts.right < categories.left).assertTrue();
      expect(accounts.top === categories.top).assertTrue();
      expect(budgets.right < exchange.left).assertTrue();
      expect(budgets.top === exchange.top).assertTrue();
      expect(accounts.bottom < budgets.top).assertTrue();
      await (await driver.findComponent(ON.id('profile-manage-accounts'))).click();
      await driver.delayMs(600);
      expect((await driver.findComponent(ON.id('deposit-account-detail'))) !== null).assertTrue();
      expect((await driver.findComponent(ON.text('ACCOUNTS · 资产的起点'))) === null).assertTrue();
      expect((await driver.findComponent(ON.id('finance-nav-surface'))) === null).assertTrue();
      expect((await driver.findComponent(ON.id('deposit-detail-add'))) !== null).assertTrue();
      await (await driver.findComponent(ON.id('deposit-detail-back'))).click();
      await driver.delayMs(600);
      expect((await driver.findComponent(ON.id('profile-overview'))) !== null).assertTrue();
      // Hardware back must also return to the originating profile, not the deposit home.
      await (await driver.findComponent(ON.id('profile-manage-accounts'))).click();
      await driver.delayMs(500);
      await driver.pressBack();
      await driver.delayMs(600);
      expect((await driver.findComponent(ON.id('profile-overview'))) !== null).assertTrue();
      const sections: string[] = ['categories', 'budgets', 'exchange'];
      const titles: string[] = ['分类管理', '预算计划', '数据与备份'];
      for (let index = 0; index < sections.length; index++) {
        await (await driver.findComponent(ON.id(`profile-manage-${sections[index]}`))).click();
        await driver.delayMs(400);
        expect((await driver.findComponent(ON.text(titles[index]))) !== null).assertTrue();
        await (await driver.findComponent(ON.text('‹'))).click();
        await driver.delayMs(400);
        expect((await driver.findComponent(ON.id('profile-overview'))) !== null).assertTrue();
      }
      await (await driver.findComponent(ON.id('finance-nav-record'))).click();
    });
    it('categoriesEditInSheetAndBackupKeepsFourFormatsWithoutLongCopy', 0, async () => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      await delegator.startAbility({ bundleName: 'com.tallyjie.harmony', abilityName: 'EntryAbility' });
      const driver = Driver.create();
      await driver.delayMs(1200);
      await (await driver.findComponent(ON.id('finance-nav-profile'))).click();
      await driver.delayMs(400);
      const back = await driver.findComponent(ON.text('‹'));
      if (back !== null) { await back.click(); await driver.delayMs(400); }
      const countBefore = await (await driver.findComponent(ON.id('profile-category-count'))).getText();
      await (await driver.findComponent(ON.id('profile-manage-categories'))).click();
      await driver.delayMs(500);
      expect((await driver.findComponent(ON.id('category-editor-name'))) === null).assertTrue();
      expect((await driver.findComponent(ON.text('CATEGORIES · 整理收支习惯'))) === null).assertTrue();
      const rows = await driver.findComponents(ON.id('category-row-', MatchPattern.CONTAINS));
      if (rows.length > 0) {
        await rows[0].click();
        await driver.delayMs(600);
        const original = await (await driver.findComponent(ON.id('category-editor-name'))).getText();
        expect(original.length > 0).assertTrue();
        expect((await driver.findComponent(ON.id('category-editor-delete'))) !== null).assertTrue();
        await (await driver.findComponent(ON.id('category-editor-cancel'))).click();
        await driver.delayMs(600);
      }
      await (await driver.findComponent(ON.id('category-tab-income'))).click();
      await (await driver.findComponent(ON.id('category-add'))).click();
      await driver.delayMs(600);
      expect(await (await driver.findComponent(ON.id('category-editor-name'))).getText()).assertEqual('');
      expect((await driver.findComponent(ON.id('category-editor-delete'))) === null).assertTrue();
      await (await driver.findComponent(ON.id('category-editor-save'))).click();
      await driver.delayMs(500);
      expect((await driver.findComponent(ON.text('名称不能为空或与同类型分类重名。'))) !== null).assertTrue();
      await (await driver.findComponent(ON.id('category-editor-cancel'))).click();
      await driver.delayMs(600);
      await (await driver.findComponent(ON.text('‹'))).click();
      await driver.delayMs(400);
      expect(await (await driver.findComponent(ON.id('profile-category-count'))).getText()).assertEqual(countBefore);
      await (await driver.findComponent(ON.id('profile-manage-exchange'))).click();
      await driver.delayMs(500);
      expect((await driver.findComponent(ON.text('属于你的数据，由你掌握'))) === null).assertTrue();
      expect((await driver.findComponent(ON.text('DATA VAULT · 财务记录妥善保存'))) === null).assertTrue();
      expect((await driver.findComponent(ON.id('exchange-export'))) !== null).assertTrue();
      expect((await driver.findComponent(ON.id('exchange-import'))) !== null).assertTrue();
      expect((await driver.findComponent(ON.text('完整备份 · JSON'))) !== null).assertTrue();
      const formats: string[] = ['收支明细 · CSV', '关联数据 · CSV', '账本数据 · JSON', '完整备份 · JSON'];
      const hints: string[] = ['收支明细，支持自定义列', '全量关联表，不含附件文件',
        '仅账本，不含附件文件', '含账本、附件与归档'];
      for (let index = 0; index < formats.length; index++) {
        await (await driver.findComponent(ON.id('exchange-format'))).click();
        await driver.delayMs(400);
        await (await driver.findComponent(ON.text(formats[index]))).click();
        await driver.delayMs(400);
        expect((await driver.findComponent(ON.id('exchange-start'))) !== null).assertEqual(index === 0);
        expect(await (await driver.findComponent(ON.id('exchange-format-hint'))).getText()).assertEqual(hints[index]);
      }
      expect((await driver.findComponent(ON.id('exchange-confirm-import'))) === null).assertTrue();
      await (await driver.findComponent(ON.text('‹'))).click();
      await (await driver.findComponent(ON.id('finance-nav-record'))).click();
    });
  });
}
