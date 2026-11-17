import { describe, it, expect } from '@ohos/hypium';
import { ringHit, trendHit, trendY } from '../main/ets/domain/ChartGeometry';
export default function chartsTest() {
  describe('Charts', () => {
    it('ringMapsClockwiseFromTopRejectsHoleAndEmptyValues', 0, () => {
      expect(ringHit([1, 3], 180, 100, 200)).assertEqual(1);
      expect(ringHit([1, 3], 100, 20, 200)).assertEqual(0);
      expect(ringHit([1, 3], 100, 100, 200)).assertEqual(-1);
      expect(ringHit([0, 0], 180, 100, 200)).assertEqual(-1);
      expect(ringHit([0, 1], 180, 100, 200)).assertEqual(1);
      expect(ringHit([1], 201, 100, 200)).assertEqual(-1);
    });
    it('trendFindsNearestPointWithinRadiusIncludingZeroAndSingle', 0, () => {
      expect(trendHit([0, 100, 0], 100, 20, 200, 160)).assertEqual(1);
      expect(trendHit([0, 100, 0], 20, 140, 200, 160)).assertEqual(0);
      expect(trendHit([0, 100, 0], 100, 120, 200, 160)).assertEqual(-1);
      expect(trendHit([], 100, 20, 200, 160)).assertEqual(-1);
      expect(trendHit([0], 100, 140, 200, 160)).assertEqual(0);
      expect(trendY(0, 0, 160)).assertEqual(140);
    });
  });
}
