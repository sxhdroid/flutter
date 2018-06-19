// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' hide TypeMatcher;

void verifyPaintPosition(GlobalKey key, Offset ideal) {
  final RenderObject target = key.currentContext.findRenderObject();
  expect(target.parent, const TypeMatcher<RenderViewport>());
  final SliverPhysicalParentData parentData = target.parentData;
  final Offset actual = parentData.paintOffset;
  expect(actual, ideal);
}

void main() {
  testWidgets('Sliver appbars - scrolling', (WidgetTester tester) async {
    GlobalKey key1, key2, key3, key4, key5;
    await tester.pumpWidget(
      new Directionality(
        textDirection: TextDirection.ltr,
        child: new CustomScrollView(
          slivers: <Widget>[
            new BigSliver(key: key1 = new GlobalKey()),
            new SliverPersistentHeader(key: key2 = new GlobalKey(), delegate: new TestDelegate()),
            new SliverPersistentHeader(key: key3 = new GlobalKey(), delegate: new TestDelegate()),
            new BigSliver(key: key4 = new GlobalKey()),
            new BigSliver(key: key5 = new GlobalKey()),
          ],
        ),
      ),
    );
    final ScrollPosition position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
    final double max = RenderBigSliver.height * 3.0 + new TestDelegate().maxExtent * 2.0 - 600.0; // 600 is the height of the test viewport
    assert(max < 10000.0);
    expect(max, 1450.0);
    expect(position.pixels, 0.0);
    expect(position.minScrollExtent, 0.0);
    expect(position.maxScrollExtent, max);
    position.animateTo(10000.0, curve: Curves.linear, duration: const Duration(minutes: 1));
    await tester.pumpAndSettle(const Duration(milliseconds: 10));
    expect(position.pixels, max);
    expect(position.minScrollExtent, 0.0);
    expect(position.maxScrollExtent, max);
    verifyPaintPosition(key1, const Offset(0.0, 0.0));
    verifyPaintPosition(key2, const Offset(0.0, 0.0));
    verifyPaintPosition(key3, const Offset(0.0, 0.0));
    verifyPaintPosition(key4, const Offset(0.0, 0.0));
    verifyPaintPosition(key5, const Offset(0.0, 50.0));
  });

  testWidgets('Sliver appbars - scrolling off screen', (WidgetTester tester) async {
    final GlobalKey key = new GlobalKey();
    final TestDelegate delegate = new TestDelegate();
    await tester.pumpWidget(
      new Directionality(
        textDirection: TextDirection.ltr,
        child: new CustomScrollView(
          slivers: <Widget>[
            const BigSliver(),
            new SliverPersistentHeader(key: key, delegate: delegate),
            const BigSliver(),
            const BigSliver(),
          ],
        ),
      ),
    );
    final ScrollPosition position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
    position.animateTo(RenderBigSliver.height + delegate.maxExtent - 5.0, curve: Curves.linear, duration: const Duration(minutes: 1));
    await tester.pumpAndSettle(const Duration(milliseconds: 1000));
    final RenderBox box = tester.renderObject<RenderBox>(find.byType(Container));
    final Rect rect = new Rect.fromPoints(box.localToGlobal(Offset.zero), box.localToGlobal(box.size.bottomRight(Offset.zero)));
    expect(rect, equals(new Rect.fromLTWH(0.0, -195.0, 800.0, 200.0)));
  });

  testWidgets('Sliver appbars - scrolling - overscroll gap is below header', (WidgetTester tester) async {
    await tester.pumpWidget(
      new Directionality(
        textDirection: TextDirection.ltr,
        child: new CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: <Widget>[
            new SliverPersistentHeader(delegate: new TestDelegate()),
            const SliverList(
              delegate: const SliverChildListDelegate(const <Widget>[
                const SizedBox(
                  height: 300.0,
                  child: const Text('X'),
                ),
              ]),
            ),
          ],
        ),
      ),
    );

    expect(tester.getTopLeft(find.byType(Container)), Offset.zero);
    expect(tester.getTopLeft(find.text('X')), const Offset(0.0, 200.0));

    final ScrollPosition position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
    position.jumpTo(-50.0);
    await tester.pump();

    expect(tester.getTopLeft(find.byType(Container)), Offset.zero);
    expect(tester.getTopLeft(find.text('X')), const Offset(0.0, 250.0));
  });
}

class TestDelegate extends SliverPersistentHeaderDelegate {
  @override
  double get maxExtent => 200.0;

  @override
  double get minExtent => 200.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return new Container(height: maxExtent);
  }

  @override
  bool shouldRebuild(TestDelegate oldDelegate) => false;
}


class RenderBigSliver extends RenderSliver {
  static const double height = 550.0;
  double get paintExtent => (height - constraints.scrollOffset).clamp(0.0, constraints.remainingPaintExtent);

  @override
  void performLayout() {
    geometry = new SliverGeometry(
      scrollExtent: height,
      paintExtent: paintExtent,
      maxPaintExtent: height,
    );
  }
}

class BigSliver extends LeafRenderObjectWidget {
  const BigSliver({ Key key }) : super(key: key);
  @override
  RenderBigSliver createRenderObject(BuildContext context) {
    return new RenderBigSliver();
  }
}
