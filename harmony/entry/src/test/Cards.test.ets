import { describe, it, expect } from '@ohos/hypium';
import { cardLayers, nextCard, swipedCard, cardDimensions, cardDepth, turningCards, cardPose, cardToneColor,
  CardDimensions, cardRotation, cardFanScale } from '../main/ets/domain/CardLayout';
import { depositHeroHeight, DEPOSIT_NAV_CLEARANCE, DEPOSIT_RECENT_TOP } from '../main/ets/domain/DepositLayout';
export default function cardsTest() {
  describe('Cards', () => {
    it('fanShowsTwoRealNeighboursOnEachSideWithoutDuplicatingAccounts', 0, () => {
      expect(cardLayers(0, 0).length).assertEqual(0);
      const one = cardLayers(1, 8); expect(one.length).assertEqual(1); expect(one[0].index).assertEqual(0);
      const layers = cardLayers(5, 4);
      expect(layers.map((row) => row.index).join(',')).assertEqual('2,1,3,0,4');
      expect(layers.map((row) => row.depth).join(',')).assertEqual('4,3,2,1,0');
      expect(layers[0].shiftX).assertEqual(84); expect(layers[2].shiftX).assertEqual(42);
      expect(layers[0].angle).assertEqual(28); expect(layers[1].angle).assertEqual(-28);
      expect(layers[2].angle).assertEqual(14); expect(layers[3].angle).assertEqual(-14);
      expect(layers[4].angle).assertEqual(0);
      [1, 2, 3, 4, 5, 6, 9].forEach((count: number) => {
        const fan = cardLayers(count, count - 1);
        expect(fan.length).assertEqual(Math.min(5, count));
        fan.forEach((layer, position: number) => {
          expect(fan.findIndex((other) => other.index === layer.index)).assertEqual(position);
          expect(cardDepth(count, count - 1, layer.index)).assertEqual(layer.depth);
        });
      });
      const two = cardLayers(2, 0);
      expect(two.length).assertEqual(2);
      expect(two[0].index).assertEqual(1); expect(two[1].index).assertEqual(0);
      expect(cardLayers(3, 99)[2].index).assertEqual(2);
      expect(cardLayers(3, -5)[2].index).assertEqual(0);
    });
    it('swipesWrapWithoutInvalidIndexes', 0, () => {
      expect(nextCard(0, 0, 1)).assertEqual(0);
      expect(nextCard(3, 2, 1)).assertEqual(0);
      expect(nextCard(3, 0, -1)).assertEqual(2);
    });
    it('verticalSwipeUpAdvancesAndDownReturnsExactlyOneAccount', 0, () => {
      expect(swipedCard(3, 0, -30)).assertEqual(1);
      expect(swipedCard(3, 1, 30)).assertEqual(0);
      expect(swipedCard(3, 2, -180)).assertEqual(0);
      expect(swipedCard(3, 0, 180)).assertEqual(2);
      expect(swipedCard(3, 1, 29)).assertEqual(1);
      expect(swipedCard(3, 1, -29)).assertEqual(1);
      expect(swipedCard(0, 0, -60)).assertEqual(0);
      expect(swipedCard(1, 0, 60)).assertEqual(0);
    });
    it('swipeSelectsTheVisibleNeighbourNotTheFarthestRearAccount', 0, () => {
      // Regression: 招商银行 6450 must advance to the lower 200 card, not 500.
      const balances = [200, 500, 6450];
      const layers = cardLayers(3, 2);
      const below = layers.find((row) => row.depth === 1)!;
      const above = layers.find((row) => row.depth === 2)!;
      expect(balances[below.index]).assertEqual(200);
      expect(balances[above.index]).assertEqual(500);
      expect(balances[swipedCard(3, 2, -100)]).assertEqual(200);
      expect(balances[swipedCard(3, 2, 100)]).assertEqual(500);
      [2, 3, 4, 5].forEach((count: number) => {
        for (let active = 0; active < count; active++) {
          const neighbours = cardLayers(count, active);
          const next = neighbours.find((row) => row.depth === 1)!;
          expect(swipedCard(count, active, -100)).assertEqual(next.index);
          expect(cardDepth(count, active, next.index)).assertEqual(1);
          if (count > 2) {
            const previous = neighbours.find((row) => row.depth === 2)!;
            expect(swipedCard(count, active, 100)).assertEqual(previous.index);
            expect(cardDepth(count, active, previous.index)).assertEqual(2);
          }
        }
      });
      let selected = 2;
      [200, 500, 6450].forEach((balance: number) => {
        selected = swipedCard(3, selected, -100);
        expect(balances[selected]).assertEqual(balance);
      });
    });
    it('referenceFanOpensUpperAndLowerWingsAroundTheHorizontalFace', 0, () => {
      [false, true].forEach((dark: boolean) => {
        const face = cardDimensions(360, 0, dark);
        const lower = cardDimensions(360, 1, dark);
        const upper = cardDimensions(360, 2, dark);
        const outerLower = cardDimensions(360, 3, dark);
        const outerUpper = cardDimensions(360, 4, dark);
        expect(face.width + face.x > 360).assertTrue(); expect(face.angle).assertEqual(0);
        expect(lower.angle < 0 && upper.angle > 0).assertTrue();
        expect(outerLower.angle).assertEqual(lower.angle * 2);
        expect(outerUpper.angle).assertEqual(upper.angle * 2);
        expect(lower.x).assertEqual(upper.x); expect(lower.x > face.x).assertTrue();
        expect(outerLower.x).assertEqual(outerUpper.x); expect(outerLower.x > lower.x).assertTrue();
        [lower, upper, outerLower, outerUpper].forEach((rear: CardDimensions) => {
          expect(rear.width).assertEqual(face.width); expect(rear.height).assertEqual(face.height);
          if (dark) { expect(Math.abs(rear.y - face.y) > 0).assertTrue(); }
          else { expect(rear.y).assertEqual(face.y); }
        });
        // At the visible left edge, the upper wing exposes its amount while
        // the lower wing exposes its name; they cannot both occupy the top.
        const radians = upper.angle * Math.PI / 180;
        const pivotRatio = Number.parseFloat(cardRotation(upper.angle).centerX) / 100;
        const upperTop = upper.y - upper.width * pivotRatio * Math.sin(radians) - upper.height / 2 * Math.cos(radians);
        const lowerBottom = lower.y + lower.width * pivotRatio * Math.sin(radians) + lower.height / 2 * Math.cos(radians);
        expect(upperTop < face.y - face.height / 2).assertTrue();
        expect(lowerBottom > face.y + face.height / 2).assertTrue();
      });
      expect(cardDimensions(360, 0, true).height).assertEqual(270);
      expect(cardDimensions(280, 0, true).stackHeight < cardDimensions(360, 0, true).stackHeight).assertTrue();
      expect(cardDimensions(800, 0, true).stackHeight > cardDimensions(360, 0, true).stackHeight).assertTrue();
    });
    it('cardSurfaceRotatesOnlyInTheScreenPlaneWithNoPerspectiveOrSkew', 0, () => {
      [-28, -14, 0, 14, 28].forEach((angle: number) => {
        const rotation = cardRotation(angle);
        expect(rotation.x).assertEqual(0); expect(rotation.y).assertEqual(0);
        expect(rotation.z).assertEqual(1); expect(rotation.angle).assertEqual(angle);
        expect(rotation.centerX).assertEqual('60%'); expect(rotation.centerY).assertEqual('50%');
      });
    });
    it('completeDetailRearRectanglesFitVerticallyInsteadOfBeingCutIntoStrips', 0, () => {
      [240, 280, 360, 430, 800].forEach((width: number) => {
        [0, 1, 2, 3, 4].forEach((depth: number) => {
          const card = cardDimensions(width, depth, true);
          const rotation = cardRotation(card.angle);
          const pivotX = Number.parseFloat(rotation.centerX) / 100 * card.width;
          const pivotY = card.height / 2;
          const radians = card.angle * Math.PI / 180;
          [0, card.width].forEach((x: number) => {
            [0, card.height].forEach((y: number) => {
              const transformedY = card.stackHeight / 2 + card.y +
                (x - pivotX) * Math.sin(radians) + (y - pivotY) * Math.cos(radians);
              expect(transformedY >= 8).assertTrue();
              expect(transformedY <= card.stackHeight - 8).assertTrue();
            });
          });
        });
      });
    });
    it('lowerCardsExposeBodiesAcrossTheScreenInsteadOfTaperingToZeroAtTheRightEdge', 0, () => {
      [240, 280, 360, 400, 430].forEach((width: number) => {
        const face = cardDimensions(width, 0, true);
        let previousBottom = face.height / 2;
        [1, 3].forEach((depth: number) => {
          const card = cardDimensions(width, depth, true);
          const radians = Math.abs(card.angle) * Math.PI / 180;
          const pivotX = Number.parseFloat(cardRotation(card.angle).centerX) / 100 * card.width;
          const bottomAtRight = card.y + card.height / (2 * Math.cos(radians)) -
            Math.tan(radians) * (width - card.x - pivotX);
          expect(bottomAtRight - previousBottom > face.height * 0.05).assertTrue();
          previousBottom = bottomAtRight;
        });
      });
    });
    it('rotatedCornersKeepRightAnglesParallelEdgesAndTheSameSideLengthsDuringEveryTurn', 0, () => {
      [false, true].forEach((dark: boolean) => {
        [-1, 0, 1, 2, 3, 4].forEach((from: number) => {
          [-1, 0, 1, 2, 3, 4].forEach((to: number) => {
            [1, -1].forEach((direction: number) => {
              [0, 0.25, 0.5, 0.75, 1].forEach((t: number) => {
                const pose = cardPose(360, dark, 320, from, to, t, direction);
                const rotation = cardRotation(pose.angle);
                const radians = rotation.angle * Math.PI / 180;
                // Screen-plane rotation of the two edges that meet at a corner.
                const ax = pose.width * Math.cos(radians), ay = pose.width * Math.sin(radians);
                const bx = -pose.height * Math.sin(radians), by = pose.height * Math.cos(radians);
                expect(Math.abs(ax * bx + ay * by) < 0.000001).assertTrue();
                expect(Math.abs(Math.hypot(ax, ay) - 360) < 0.000001).assertTrue();
                expect(Math.abs(Math.hypot(bx, by) - cardDimensions(360, 0, dark, 320).height) < 0.000001).assertTrue();
                expect(rotation.x).assertEqual(0); expect(rotation.y).assertEqual(0); expect(rotation.z).assertEqual(1);
              });
            });
          });
        });
      });
    });
    it('restingDetailCardsAreOpaqueSoRearTextCannotBleedThroughTheNextCard', 0, () => {
      [0, 1, 2, 3, 4].forEach((depth: number) => {
        expect(cardPose(360, true, 300, depth, depth, 0, 1).opacity).assertEqual(1);
      });
      expect(cardPose(360, false, 300, 1, 1, 0, 1).opacity).assertEqual(0.22);
    });
    it('homeFaceRetainsItsCompactProportionsAndLoweredPosition', 0, () => {
      const face = cardDimensions(290, 0, false, 400);
      expect(Math.abs(face.height / face.width - 0.76) < 0.01).assertTrue();
      expect(face.height <= 224).assertTrue();
      const top = (face.stackHeight - face.height) / 2 + face.y;
      expect(top > 80).assertTrue();
      expect(face.stackHeight - top - face.height >= 10).assertTrue();
      expect(face.y).assertEqual(34); expect(face.x).assertEqual(40);
      expect(cardDimensions(420, 0, false, 500).height).assertEqual(224);
      expect(cardDimensions(290, 0, false, 240).height).assertEqual(158.4);
    });
    it('turnKeepsUniqueAccountsIncludingIncomingAndOutgoingNeighbours', 0, () => {
      expect(turningCards(0, 0, -1).length).assertEqual(0);
      expect(turningCards(1, 0, -1).join(',')).assertEqual('0');
      expect(turningCards(2, 0, 1).length).assertEqual(2);
      const forward = turningCards(7, 6, 0);
      expect(forward.length).assertEqual(6);
      expect(forward.indexOf(4) >= 0).assertTrue(); expect(forward.indexOf(2) >= 0).assertTrue();
      expect(cardDepth(7, 6, 0)).assertEqual(1);
      expect(cardDepth(7, 6, 5)).assertEqual(2);
      expect(cardDepth(7, 6, 1)).assertEqual(3);
      expect(cardDepth(7, 6, 4)).assertEqual(4);
      expect(cardDepth(7, 6, 2)).assertEqual(-1);
      expect(cardDepth(0, 0, 0)).assertEqual(-1);
      expect(turningCards(7, 0, 6).length).assertEqual(6);
      expect(turningCards(5, 0, 4).length).assertEqual(5);
    });
    it('adjacentCardMovesIntoFaceContinuouslyWithoutWrappingOrChangingShape', 0, () => {
      [false, true].forEach((dark: boolean) => {
        [1, -1].forEach((direction: number) => {
          const incoming = direction === 1 ? 1 : 2;
          const outgoing = direction === 1 ? 2 : 1;
          const start = cardDimensions(360, incoming, dark);
          const face = cardDimensions(360, 0, dark);
          [0, 0.1, 0.25, 0.5, 0.75, 1].forEach((t: number) => {
            const arriving = cardPose(360, dark, 300, incoming, 0, t, direction);
            const departing = cardPose(360, dark, 300, 0, outgoing, t, direction);
            // Only the outermost card wraps. The two adjacent cards stay visible.
            expect(arriving.opacity > 0).assertTrue(); expect(departing.opacity > 0).assertTrue();
            expect(arriving.x <= start.x && arriving.x >= face.x).assertTrue();
            expect(Math.abs(arriving.angle) <= Math.abs(start.angle)).assertTrue();
            expect(arriving.angle * start.angle >= 0).assertTrue();
          });
          expect(cardPose(360, dark, 300, incoming, 0, 0, direction).y).assertEqual(start.y);
          const end = cardPose(360, dark, 300, incoming, 0, 1, direction);
          expect(end.y).assertEqual(face.y); expect(end.x).assertEqual(face.x);
          expect(end.angle).assertEqual(0); expect(end.opacity).assertEqual(1);
          const departing = cardPose(360, dark, 300, 0, outgoing, 0.5, direction);
          const rear = cardDimensions(360, outgoing, dark);
          expect(departing.y >= Math.min(face.y, rear.y) && departing.y <= Math.max(face.y, rear.y)).assertTrue();
          expect(departing.tone > 0).assertTrue();
        });
      });
      expect(cardToneColor(0, false)).assertEqual('rgb(51, 51, 51)');
      expect(cardToneColor(2, true)).assertEqual('rgb(150, 150, 150)');
    });
    it('carouselNeverResizesAnyCardIncludingTheDetailRearLayers', 0, () => {
      [false, true].forEach((dark: boolean) => {
        const face = cardDimensions(360, 0, dark, 320);
        [-1, 0, 1, 2, 3, 4].forEach((from: number) => {
          [-1, 0, 1, 2, 3, 4].forEach((to: number) => {
            [1, -1].forEach((direction: number) => {
              [0, 0.18, 0.25, 0.42, 0.5, 0.62, 0.75, 1].forEach((t: number) => {
                const pose = cardPose(360, dark, 320, from, to, t, direction);
                expect(pose.width).assertEqual(face.width);
                expect(pose.height).assertEqual(face.height);
                expect(pose.opacity >= 0 && pose.opacity <= 1).assertTrue();
              });
            });
          });
        });
      });
    });
    it('everyCompletedPoseMatchesTheNextStaticFanWithoutAnEndpointJump', 0, () => {
      [false, true].forEach((dark: boolean) => {
        [-1, 0, 1, 2, 3, 4].forEach((from: number) => {
          [-1, 0, 1, 2, 3, 4].forEach((to: number) => {
            [1, -1].forEach((direction: number) => {
              const end = cardPose(360, dark, 320, from, to, 1, direction);
              const staticPose = cardPose(360, dark, 320, to, to, 0, direction);
              expect(end.x).assertEqual(staticPose.x); expect(end.y).assertEqual(staticPose.y);
              expect(end.angle).assertEqual(staticPose.angle); expect(end.opacity).assertEqual(staticPose.opacity);
            });
          });
        });
      });
    });
    it('twoAccountFanNeverFadesTheOnlyNeighbourOutOfItsSwitch', 0, () => {
      [1, -1].forEach((direction: number) => {
        [0.1, 0.5, 0.9].forEach((t: number) => {
          expect(cardPose(360, true, 300, 1, 0, t, direction).opacity > 0).assertTrue();
          expect(cardPose(360, true, 300, 0, 1, t, direction).opacity > 0).assertTrue();
        });
      });
    });
    it('rearCardsMovingAlongTheSameWingStayVisible', 0, () => {
      [1, -1].forEach((direction: number) => {
        [0.1, 0.5, 0.9].forEach((t: number) => {
          expect(cardPose(360, true, 300, 1, 3, t, direction).opacity > 0).assertTrue();
          expect(cardPose(360, true, 300, 4, 2, t, direction).opacity > 0).assertTrue();
        });
      });
    });
    it('singlePageDetailFitsTheWholeFanUsingOneUniformScale', 0, () => {
      [280, 360, 430, 800].forEach((width: number) => {
        [120, 260, 440, 560, 900].forEach((height: number) => {
          const natural = cardDimensions(width, 0, true);
          const scale = cardFanScale(width, height);
          expect(scale > 0 && scale <= 1).assertTrue();
          expect(natural.stackHeight * scale <= height + 0.000001).assertTrue();
          [0, 1, 2, 3, 4].forEach((depth: number) => {
            const card = cardDimensions(width, depth, true);
            expect(Math.abs((card.width * scale) / (card.height * scale) - natural.width / natural.height) < 0.000001).assertTrue();
          });
        });
      });
    });
    it('sideRevealNeverDropsCardsFromAboveOrBelowTheirRestingSlots', 0, () => {
      [false, true].forEach((dark: boolean) => {
        [-1, 0, 1, 2, 3, 4].forEach((from: number) => {
          [-1, 0, 1, 2, 3, 4].forEach((to: number) => {
            const start = cardDimensions(360, from, dark, 320);
            const end = cardDimensions(360, to, dark, 320);
            [1, -1].forEach((direction: number) => {
              [0, 0.1, 0.25, 0.4999, 0.5, 0.5001, 0.75, 0.9, 1].forEach((t: number) => {
                const pose = cardPose(360, dark, 320, from, to, t, direction);
                expect(pose.y >= Math.min(start.y, end.y) && pose.y <= Math.max(start.y, end.y)).assertTrue();
                expect(pose.x >= Math.min(start.x, end.x)).assertTrue();
                expect(pose.x <= Math.max(start.x, end.x) + 40).assertTrue();
              });
            });
          });
        });
      });
    });
    it('largerAccountStageLeavesRecentsAttachedToTheNavigation', 0, () => {
      expect(DEPOSIT_RECENT_TOP).assertEqual(24);
      expect(DEPOSIT_NAV_CLEARANCE).assertEqual(88 + 16);
      [600, 744, 900].forEach((viewport: number) => {
        const pageHeight = viewport - DEPOSIT_NAV_CLEARANCE;
        const hero = depositHeroHeight(pageHeight);
        expect(hero > pageHeight / 2).assertTrue();
        expect(hero).assertEqual(pageHeight * 0.58);
        const panelTop = hero + DEPOSIT_RECENT_TOP;
        expect(panelTop > (viewport - 132) / 2 + 28).assertTrue();
        const panelHeight = pageHeight - panelTop;
        expect(panelHeight > 0).assertTrue();
        expect(panelTop + panelHeight).assertEqual(viewport - 16 - 88);
      });
    });
    it('onlyTheOuterRearCardWrapsWhileTransparent', 0, () => {
      [1, -1].forEach((direction: number) => {
        const from = direction === 1 ? 4 : 3;
        const to = direction === 1 ? 3 : 4;
        const before = cardPose(300, false, 320, from, to, 0.4999, direction);
        const during = cardPose(300, false, 320, from, to, 0.5, direction);
        const after = cardPose(300, false, 320, from, to, 0.5001, direction);
        expect(before.opacity < 0.001).assertTrue(); expect(during.opacity).assertEqual(0);
        expect(after.opacity < 0.001).assertTrue();
        expect(before.zIndex).assertEqual(10 - from); expect(after.zIndex).assertEqual(10 - to);
      });
    });
  });
}
