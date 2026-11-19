import { describe, it, expect } from '@ohos/hypium';
import { navGeometry, makeNavOutline, makeNavCapsule, navContentInset, navTabCenter } from '../main/ets/domain/NavGeometry';

export default function navGeometryTest() {
  describe('NavGeometry', () => {
    it('usesTheIdenticalNotchAtEveryTabAndDuringTravel', 0, () => {
      [240, 288, 328, 400, 600, 800].forEach((width: number) => {
        [0, 0.25, 0.5, 0.75, 0.999, 1].forEach((progress: number) => {
          const middle = navGeometry(width / 2, width, progress);
          for (let step = 0; step <= 80; step++) {
            const center = navTabCenter(width, step / 20, 5);
            const g = navGeometry(center, width, progress);
            expect(Math.abs(g.center - center) < 0.000001).assertTrue();
            expect(g.left.reach).assertEqual(middle.left.reach);
            expect(g.right.reach).assertEqual(middle.right.reach);
            expect(g.bowlHalf).assertEqual(middle.bowlHalf);
            expect(g.bowlHeight).assertEqual(middle.bowlHeight);
            expect(g.bottomHandle).assertEqual(middle.bottomHandle);
            expect(g.left.cornerRadius).assertEqual(middle.cornerRadius);
            expect(g.right.cornerRadius).assertEqual(middle.cornerRadius);
            expect(g.depth).assertEqual(42 * (1 - progress));
            expect(g.center - g.left.reach >= -0.000001).assertTrue();
            expect(width - g.center - g.right.reach >= -0.000001).assertTrue();
          }
        });
      });
    });
    it('alignsTheHitTargetsCircleAndNotchUsingOneInset', 0, () => {
      [200, 240, 288, 328, 400, 600, 800].forEach((width: number) => {
        const inset = navContentInset(width, 5);
        const cell = (width - 2 * inset) / 5;
        for (let index = 0; index < 5; index++) {
          const center = navTabCenter(width, index, 5);
          expect(Math.abs(center - inset - cell * (index + 0.5)) < 0.000001).assertTrue();
          expect(Math.abs(navGeometry(center, width, 0).center - center) < 0.000001).assertTrue();
        }
        expect(navTabCenter(width, 2, 5)).assertEqual(width / 2);
        expect(Math.abs(navTabCenter(width, 0, 5) + navTabCenter(width, 4, 5) - width) < 0.000001).assertTrue();
      });
      expect(navTabCenter(328, 0, 5)).assertEqual(60);
      expect(navTabCenter(328, 4, 5)).assertEqual(268);
      expect(navContentInset(800, 5)).assertEqual(0);
      expect(navTabCenter(328, 0, 1)).assertEqual(164);
      expect(navContentInset(0, 5)).assertEqual(0);
    });
    it('retainsTheMiddleBowlAndRoundedOuterCaps', 0, () => {
      const edge = navGeometry(navTabCenter(328, 4, 5), 328, 0);
      expect(edge.left.reach).assertEqual(44);
      expect(edge.right.reach).assertEqual(44);
      expect(edge.bowlHalf).assertEqual(27);
      expect(edge.bowlHeight).assertEqual(20);
      expect(edge.left.cornerRadius).assertEqual(32);
      expect(edge.right.cornerRadius).assertEqual(32);
      expect(edge.cornerRadius).assertEqual(32);
      expect(edge.top + edge.depth).assertEqual(66);
      expect(makeNavOutline(edge.center, 328, 1, 0).split('C ').length).assertEqual(5);
    });
    it('increasesSpacingWithoutNarrowingTheNotch', 0, () => {
      [288, 328, 400].forEach((width: number) => {
        const oldStep = (width - 152) / 4;
        const step = navTabCenter(width, 1, 5) - navTabCenter(width, 0, 5);
        expect(Math.abs(step - oldStep - 8) < 0.000001).assertTrue();
        expect(step >= 42).assertTrue();
        for (let index = 1; index < 5; index++) {
          expect(Math.abs(navTabCenter(width, index, 5) - navTabCenter(width, index - 1, 5) - step) < 0.000001).assertTrue();
        }
      });
    });
    it('keepsTheOriginalCapsuleAsTheFixedClipBoundary', 0, () => {
      const capsule = makeNavCapsule(328, 1, 0);
      expect(capsule).assertEqual('M 32 24 L 296 24 A 32 32 0 0 1 328 56 ' +
        'L 328 56 A 32 32 0 0 1 296 88 L 32 88 A 32 32 0 0 1 0 56 ' +
        'L 0 56 A 32 32 0 0 1 32 24 Z');
      expect(makeNavCapsule(328, 2, 0).startsWith('M 64 48 L 592 48')).assertTrue();
      expect(makeNavCapsule(328, 1, 1).startsWith('M 24 0 L 304 0')).assertTrue();
      expect(makeNavCapsule(0, 1, 0)).assertEqual('');
    });
    it('expandsForBudgetKeypadWithoutStretchingTheCapsuleCorners', 0, () => {
      [240, 328, 400, 600].forEach((width: number) => {
        [0, 0.25, 0.5, 0.75, 1].forEach((progress: number) => {
          const original = navGeometry(width / 2, width, progress);
          const budget = navGeometry(width / 2, width, progress, 480);
          expect(budget.bottom).assertEqual(88 + 392 * progress);
          expect(budget.top).assertEqual(original.top);
          expect(budget.cornerRadius).assertEqual(original.cornerRadius);
          expect(budget.depth).assertEqual(original.depth);
          expect(budget.bowlHeight).assertEqual(original.bowlHeight);
          expect(makeNavOutline(width / 2, width, 3.2, progress, 480).includes('NaN')).assertFalse();
        });
      });
      expect(makeNavOutline(164, 328, 1, 1, 480).endsWith('L 328 0 L 328 480 L 0 480 Z')).assertTrue();
      expect(makeNavCapsule(328, 1, 1, 480).includes('L 328 456 A 24 24 0 0 1 304 480')).assertTrue();
      expect(makeNavOutline(164, 328, 1, 0, 480)).assertEqual(makeNavOutline(164, 328, 1, 0));
      expect(makeNavCapsule(328, 1, 0, 480)).assertEqual(makeNavCapsule(328, 1, 0));
    });
    it('preservesTheKeypadMorphAndPhysicalPixelScaling', 0, () => {
      [0, 0.25, 0.5, 0.75, 0.999, 1].forEach((progress: number) => {
        const path = makeNavOutline(200, 400, 3.2, progress);
        expect(path.includes('NaN') || path.includes('Infinity')).assertFalse();
      });
      const keypad = navGeometry(200, 400, 1);
      expect(keypad.depth).assertEqual(0);
      expect(keypad.bottom).assertEqual(360);
      expect(keypad.left.cornerRadius).assertEqual(24);
      expect(keypad.right.cornerRadius).assertEqual(24);
      expect(makeNavOutline(0, 0, 3.2, 0)).assertEqual('');
    });
  });
}
