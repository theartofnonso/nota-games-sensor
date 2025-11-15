import 'package:collection/collection.dart';
import 'package:flutter/material.dart';


import '../colors.dart';
import '../utils/general_utils.dart';
import 'buttons/opacity_button_widget.dart';
import 'buttons/opacity_circle_button_widget.dart';
import 'dividers/label_divider.dart';

class WeightPlateCalculator extends StatefulWidget {
  final double target;

  const WeightPlateCalculator({super.key, required this.target});

  @override
  State<WeightPlateCalculator> createState() => _WeightCalculatorState();
}

class _WeightCalculatorState extends State<WeightPlateCalculator> {
  final List<_PlatesEnum> _selectedPlates = [];
  _BarsEnum _selectedBar = _BarsEnum.twenty;

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    final plates = _PlatesEnum.values
        .map((plate) => Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: OpacityCircleButtonWidget(
                  padding: EdgeInsets.all(16),
                  onPressed: () => _onSelectPlate(newPlate: plate),
                  buttonColor: _getPlate(plate: plate) != null ? vibrantGreen : null,
                  label: "${weightWithConversion(value: plate.weight)}"),
            ))
        .toList();

    final bars = _BarsEnum.values
        .map((bar) => Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: OpacityButtonWidget(
                  onPressed: () => _onSelectBar(newBar: bar),
                  padding: EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  buttonColor: _selectedBar == bar ? vibrantGreen : null,
                  label: "${weightWithConversion(value: bar.weight)}"),
            ))
        .toList();

    final weightSuggestions = _findClosestWeightCombination(targetWeight: widget.target);

    final plateSuggestions = weightSuggestions.map((weight) => _PlatesEnum.fromDouble(weight));

    final weightEstimate = (weightSuggestions.sum * 2) + _selectedBar.weight;

    final isExact = weightEstimate == widget.target;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text("${weightWithConversion(value: widget.target)}${weightUnit()}".toUpperCase(),
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(
            height: 2,
          ),
          Text("Target Weight".toUpperCase(),
              textAlign: TextAlign.start, style: Theme.of(context).textTheme.bodyMedium),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: _Bar(
              bar: _selectedBar,
              plates: plateSuggestions.sorted((a, b) => b.weight.compareTo(a.weight)),
            ),
          ),
          if (_selectedPlates.isNotEmpty && !isExact)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                  "Closest estimate is ${weightWithConversion(value: weightEstimate)}${weightUnit()}".toUpperCase(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LabelDivider(
                label: "Available Weights (${weightUnit()})".toUpperCase(),
                labelColor: isDarkMode ? Colors.white70 : Colors.black,
                dividerColor: sapphireLighter),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: plates,
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LabelDivider(
              label: "Available Bar (${weightUnit()})".toUpperCase(),
              labelColor: isDarkMode ? Colors.white70 : Colors.black,
              dividerColor: sapphireLighter,
              leftToRight: true,
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: bars)),
        ],
      ),
    );
  }

  void _onSelectPlate({required _PlatesEnum newPlate}) {
    final oldPlate = _selectedPlates.firstWhereOrNull((previousPlate) => previousPlate.weight == newPlate.weight);
    setState(() {
      if (oldPlate != null) {
        _selectedPlates.remove(oldPlate);
      } else {
        _selectedPlates.add(newPlate);
      }
    });
  }

  void _onSelectBar({required _BarsEnum newBar}) {
    setState(() {
      _selectedBar = newBar;
    });
  }

  _PlatesEnum? _getPlate({required _PlatesEnum plate}) =>
      _selectedPlates.firstWhereOrNull((previousPlate) => previousPlate.weight == plate.weight);

  List<double> _findClosestWeightCombination({required double targetWeight}) {
    // Calculate the weight needed for one side
    double halfTargetWeight = (targetWeight - _selectedBar.weight) / 2;

    // Sort weights in descending order for better efficiency
    _selectedPlates.sort((a, b) => b.weight.compareTo(a.weight));

    List<double> bestCombination = [];
    double bestSum = 0;

    // Recursive function to find the best combination
    void findCombination(List<double> currentCombination, double currentSum, int index) {
      if (currentSum > halfTargetWeight) return;

      if (currentSum > bestSum) {
        bestSum = currentSum;
        bestCombination = List.from(currentCombination);
      }

      for (int i = index; i < _selectedPlates.length; i++) {
        currentCombination.add(_selectedPlates[i].weight);
        findCombination(currentCombination, currentSum + _selectedPlates[i].weight, i);
        currentCombination.removeLast();
      }
    }

    findCombination([], 0, 0);

    return bestCombination;
  }
}

class _Bar extends StatelessWidget {
  final _BarsEnum bar;
  final List<_PlatesEnum> plates;

  const _Bar({required this.bar, required this.plates});

  @override
  Widget build(BuildContext context) {

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        SizedBox(width: 16),
        Container(
            width: 100,
            height: 20,
            color: Colors.grey.shade400,
            child: Center(
              child: Text("${weightWithConversion(value: bar.weight)}",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold)),
            )),
        Container(width: 15, height: 40, color: sapphireDark),
        ...plates.map((plate) => _Plate(plate: plate)),
        Container(
            width: 10,
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(5),
                bottomRight: Radius.circular(5),
              ),
              color: Colors.grey.shade400,
            )),
        SizedBox(width: 16)
      ]),
    );
  }
}

class _Plate extends StatelessWidget {
  final _PlatesEnum plate;

  const _Plate({
    required this.plate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: plate.width,
      height: plate.height,
      margin: EdgeInsets.only(right: 3),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: sapphireDark),
      child: Center(
        child: Text("${weightWithConversion(value: plate.weight)}",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

enum _PlatesEnum {
  twentyFive(weight: 25, height: 100, width: 38),
  twenty(weight: 20, height: 90, width: 36),
  fifteen(weight: 15, height: 80, width: 38),
  ten(weight: 10, height: 70, width: 38),
  five(weight: 5, height: 60, width: 38),
  twoFive(weight: 2.5, height: 50, width: 38),
  oneTwoFive(weight: 1.25, height: 40, width: 38),
  zeroFive(weight: 0.5, height: 30, width: 38);

  final double weight;
  final double height;
  final double width;

  const _PlatesEnum({required this.weight, required this.height, required this.width});

  static _PlatesEnum fromDouble(double weight) {
    return _PlatesEnum.values.firstWhere((value) => value.weight == weight);
  }
}

enum _BarsEnum {
  twenty(weight: 20),
  fifteen(weight: 15),
  ten(weight: 10),
  five(weight: 5),
  sevenFive(weight: 7.5);

  final double weight;

  const _BarsEnum({required this.weight});
}
