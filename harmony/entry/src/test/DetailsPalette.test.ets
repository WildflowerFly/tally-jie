import { describe, it, expect } from '@ohos/hypium';
import { DetailsPalette } from '../main/ets/theme/DetailsPalette';

export default function detailsPaletteTest() {
  describe('DetailsPalette', () => {
    it('budgetAndDetailsNeutralColorsHaveNoGreenCast', 0, () => {
      const neutrals: string[] = [
        DetailsPalette.income, DetailsPalette.incomeOnDark, DetailsPalette.availableBudget,
        DetailsPalette.background, DetailsPalette.surfaceMuted, DetailsPalette.text,
        DetailsPalette.secondary, DetailsPalette.muted, DetailsPalette.faint,
        DetailsPalette.strongBackground, DetailsPalette.ringTrack, DetailsPalette.handle
      ];
      neutrals.forEach((color: string) => {
        expect(/^#[0-9A-F]{6}$/.test(color)).assertTrue();
        expect(color.slice(1, 3)).assertEqual(color.slice(3, 5));
        expect(color.slice(3, 5)).assertEqual(color.slice(5, 7));
      });
      expect(DetailsPalette.availableBudget).assertEqual('#707070');
      expect(DetailsPalette.surfaceMuted).assertEqual('#F3F3F3');
      expect(DetailsPalette.strongBackground).assertEqual('#373737');
    });
    it('keepsPreviouslySpecifiedExpenseAccentSeparateFromBudgetGray', 0, () => {
      expect(DetailsPalette.expense).assertEqual('#EC5F36');
      expect(DetailsPalette.expense === DetailsPalette.availableBudget).assertFalse();
      expect(DetailsPalette.overBudgetBackground).assertEqual('#FFF4E8');
    });
  });
}
