import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/screens/trip_dna_screen.dart';

void main() {
  testWidgets('Answers remain 1–7 while the visible bar runs 0–6', (tester) async {
    int? answer;
    Future<void> show(int? selected) => tester.pumpWidget(MaterialApp(home: Scaffold(
      body: CustomSliderWidget(selectedValue: selected, onChanged: (value) => answer = value))));
    await show(1);
    var slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 0);
    expect(slider.min, 0);
    expect(slider.max, 6);
    expect(slider.divisions, 6);
    final theme = tester.widget<SliderTheme>(find.byType(SliderTheme));
    expect(theme.data.activeTrackColor, theme.data.inactiveTrackColor);
    await show(7);
    slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 6);
    slider.onChanged!(0);
    expect(answer, 1);
    slider.onChanged!(6);
    expect(answer, 7);
    await show(null);
    await tester.tap(find.text('1'));
    expect(answer, 1);
    expect(tester.takeException(), isNull);
  });
}
