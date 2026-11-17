import { describe, it, expect } from '@ohos/hypium';
import { cardLayers, nextCard } from '../main/ets/domain/CardLayout';
export default function cardsTest() {
  describe('Cards', () => {
    it('fanHasUniqueAccountsBackToFrontAndNormalizesDeletedSelection', 0, () => {
      expect(cardLayers(0, 0).length).assertEqual(0);
      const one = cardLayers(1, 8); expect(one.length).assertEqual(1); expect(one[0].index).assertEqual(0);
      const layers = cardLayers(5, 4);
      expect(layers.map((row) => row.index).join(',')).assertEqual('1,0,4');
      expect(layers[2].depth).assertEqual(0); expect(layers[2].angle).assertEqual(0);
      expect(layers[0].angle < layers[1].angle).assertTrue();
      expect(cardLayers(2, 0).length).assertEqual(2);
    });
    it('swipesWrapWithoutInvalidIndexes', 0, () => {
      expect(nextCard(0, 0, 1)).assertEqual(0);
      expect(nextCard(3, 2, 1)).assertEqual(0);
      expect(nextCard(3, 0, -1)).assertEqual(2);
    });
  });
}
