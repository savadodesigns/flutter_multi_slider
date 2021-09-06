import 'package:flutter/material.dart';
import 'dart:math' as math;

typedef DivisionPainterCallback = bool Function(Division division);

class MultiSlider extends StatefulWidget {
  MultiSlider({
    required this.values,
    required this.onChanged,
    this.max = 1,
    this.min = 0,
    this.onChangeStart,
    this.onChangeEnd,
    this.color,
    this.horizontalPadding = 26.0,
    this.height = 45,
    this.divisions,
    this.divisionPainterCallback,
    Key? key,
  })  : assert(divisions == null || divisions > 0),
        assert(max - min >= 0),
        range = max - min,
        super(key: key) {
    final valuesCopy = [...values]..sort();

    for (int index = 0; index < valuesCopy.length; index++) {
      assert(
        valuesCopy[index] == values[index],
        'MultiSlider: values must be in ascending order!',
      );
    }
    assert(
      values.first >= min && values.last <= max,
      'MultiSlider: At least one value is outside of min/max boundaries!',
    );
  }

  /// [MultiSlider] maximum value.
  final double max;

  /// [MultiSlider] minimum value.
  final double min;

  /// Difference between [max] and [min]. Must be positive!
  final double range;

  /// [MultiSlider] vertical dimension. Used by [GestureDetector] and [CustomPainter].
  final double height;

  /// Empty space between the [MultiSlider] bar and the end of [GestureDetector] zone.
  final double horizontalPadding;

  /// Bar and indicators active color.
  final Color? color;

  /// List of ordered values which will be changed by user gestures with this widget.
  final List<double> values;

  /// Callback for every user slide gesture.
  final ValueChanged<List<double>>? onChanged;

  /// Callback for every time user click on this widget.
  final ValueChanged<List<double>>? onChangeStart;

  /// Callback for every time user stop click/slide on this widget.
  final ValueChanged<List<double>>? onChangeEnd;

  /// Number of divisions for discrete Slider.
  final int? divisions;

  final DivisionPainterCallback? divisionPainterCallback;

  @override
  _MultiSliderState createState() => _MultiSliderState();
}

class _MultiSliderState extends State<MultiSlider> {
  double? _maxWidth;
  int? _selectedInputIndex;
  late bool _isDiscrete;

  @override
  void initState() {
    super.initState();

    _isDiscrete = widget.divisions != null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sliderTheme = SliderTheme.of(context);

    final bool isDisabled = widget.onChanged == null || widget.range == 0;

    return LayoutBuilder(
      builder: (context, BoxConstraints constraints) {
        _maxWidth = constraints.maxWidth;
        return GestureDetector(
          child: Container(
            constraints: constraints,
            width: double.infinity,
            height: widget.height,
            child: CustomPaint(
              painter: _MultiSliderPainter(
                isActiveDivisionCallback: widget.divisionPainterCallback ??
                    _defaultDivisionPainterCallback,
                isDiscrete: _isDiscrete,
                isDisabled: isDisabled,
                activeTrackColor: widget.color ??
                    sliderTheme.activeTrackColor ??
                    theme.colorScheme.primary,
                inactiveTrackColor: widget.color?.withOpacity(0.24) ??
                    sliderTheme.inactiveTrackColor ??
                    theme.colorScheme.primary.withOpacity(0.24),
                disabledActiveTrackColor:
                    sliderTheme.disabledActiveTrackColor ??
                        theme.colorScheme.onSurface.withOpacity(0.40),
                disabledInactiveTrackColor:
                    sliderTheme.disabledInactiveTrackColor ??
                        theme.colorScheme.onSurface.withOpacity(0.12),
                selectedInputIndex: _selectedInputIndex,
                values:
                    widget.values.map(_convertValueToPixelPosition).toList(),
                horizontalPadding: widget.horizontalPadding,
              ),
            ),
          ),
          onPanStart: isDisabled ? null : _handleOnChangeStart,
          onPanUpdate: isDisabled ? null : _handleOnChanged,
          onPanEnd: isDisabled ? null : _handleOnChangeEnd,
        );
      },
    );
  }

  void _handleOnChangeStart(DragStartDetails details) {
    double valuePosition = _convertPixelPositionToValue(
      details.localPosition.dx,
    );

    int index = _findNearestValueIndex(valuePosition);

    setState(() => _selectedInputIndex = index);

    final updatedValues = updateInternalValues(details.localPosition.dx);
    widget.onChanged!(updatedValues);
    if (widget.onChangeStart != null) widget.onChangeStart!(updatedValues);
  }

  void _handleOnChanged(DragUpdateDetails details) {
    widget.onChanged!(updateInternalValues(details.localPosition.dx));
  }

  void _handleOnChangeEnd(DragEndDetails details) {
    setState(() => _selectedInputIndex = null);

    if (widget.onChangeEnd != null) widget.onChangeEnd!(widget.values);
  }

  double _convertValueToPixelPosition(double value) {
    return (value - widget.min) *
            (_maxWidth! - 2 * widget.horizontalPadding) /
            (widget.range) +
        widget.horizontalPadding;
  }

  double _convertPixelPositionToValue(double pixelPosition) {
    final value = (pixelPosition - widget.horizontalPadding) *
            (widget.range) /
            (_maxWidth! - 2 * widget.horizontalPadding) +
        widget.min;

    return value;
  }

  List<double> updateInternalValues(double xPosition) {
    if (_selectedInputIndex == null) return widget.values;

    List<double> copiedValues = [...widget.values];

    double convertedPosition = _convertPixelPositionToValue(xPosition);

    copiedValues[_selectedInputIndex!] = convertedPosition.clamp(
      _calculateInnerBound(),
      _calculateOuterBound(),
    );

    return copiedValues;
  }

  double _calculateInnerBound() {
    return _selectedInputIndex == 0
        ? widget.min
        : widget.values[_selectedInputIndex! - 1];
  }

  double _calculateOuterBound() {
    return _selectedInputIndex == widget.values.length - 1
        ? widget.max
        : widget.values[_selectedInputIndex! + 1];
  }

  int _findNearestValueIndex(double convertedPosition) {
    if (widget.values.length == 1) return 0;

    List<double> differences = widget.values
        .map<double>((double value) => (value - convertedPosition).abs())
        .toList();
    double minDifference = differences.reduce(
      (previousValue, value) => value < previousValue ? value : previousValue,
    );

    int minDifferenceFirstIndex = differences.indexOf(minDifference);
    int minDifferenceLastIndex = differences.lastIndexOf(minDifference);

    bool hasCollision = minDifferenceLastIndex != minDifferenceFirstIndex;

    if (hasCollision &&
        (convertedPosition > widget.values[minDifferenceFirstIndex])) {
      return minDifferenceLastIndex;
    }
    return minDifferenceFirstIndex;
  }

  bool _defaultDivisionPainterCallback(Division division) =>
      !division.isFirst && !division.isLast;
}

class Division {
  const Division(
    this.start,
    this.end,
    this.index,
    this.isFirst,
    this.isLast,
  );

  final double start;
  final double end;
  final int index;
  final bool isFirst;
  final bool isLast;
}

class _MultiSliderPainter extends CustomPainter {
  final List<double> values;
  final int? selectedInputIndex;
  final double horizontalPadding;
  final Paint activeTrackColorPaint;
  final Paint bigCircleColorPaint;
  final Paint inactiveTrackColorPaint;
  final bool isDiscrete;
  final DivisionPainterCallback isActiveDivisionCallback;

  _MultiSliderPainter({
    required bool isDisabled,
    required Color activeTrackColor,
    required Color inactiveTrackColor,
    required Color disabledActiveTrackColor,
    required Color disabledInactiveTrackColor,
    required this.values,
    required this.selectedInputIndex,
    required this.horizontalPadding,
    required this.isDiscrete,
    required this.isActiveDivisionCallback,
  })  : activeTrackColorPaint = _paintFromColor(
          isDisabled ? disabledActiveTrackColor : activeTrackColor,
          true,
        ),
        inactiveTrackColorPaint = _paintFromColor(
          isDisabled ? disabledInactiveTrackColor : inactiveTrackColor,
        ),
        bigCircleColorPaint = _paintFromColor(
          activeTrackColor.withOpacity(0.20),
        );

  List<Division> _makeDivisions(
    List<double> innerValues,
    double start,
    double end,
  ) {
    final values = [start, ...innerValues, end];
    return List<Division>.generate(
      values.length - 1,
      (index) => Division(
        values[index],
        values[index + 1],
        index,
        index == 0,
        index == values.length - 2,
      ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double halfHeight = size.height / 2;

    final divisions = _makeDivisions(
      values,
      horizontalPadding,
      size.width - horizontalPadding,
    );

    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(divisions.first.start, halfHeight),
        radius: isActiveDivisionCallback(divisions.first) ? 3 : 2,
      ),
      math.pi / 2,
      math.pi,
      true,
      isActiveDivisionCallback(divisions.first)
          ? activeTrackColorPaint
          : inactiveTrackColorPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(divisions.last.end, halfHeight),
        radius: isActiveDivisionCallback(divisions.last) ? 3 : 2,
      ),
      -math.pi / 2,
      math.pi,
      true,
      isActiveDivisionCallback(divisions.last)
          ? activeTrackColorPaint
          : inactiveTrackColorPaint,
    );

    for (Division division in divisions) {
      canvas.drawLine(
        Offset(division.start, halfHeight),
        Offset(division.end, halfHeight),
        isActiveDivisionCallback(division)
            ? activeTrackColorPaint
            : inactiveTrackColorPaint,
      );
    }

    for (int i = 0; i < values.length; i++) {
      canvas.drawCircle(
        Offset(values[i], halfHeight),
        10,
        _paintFromColor(Colors.white),
      );

      canvas.drawCircle(
        Offset(values[i], halfHeight),
        10,
        activeTrackColorPaint,
      );

      if (selectedInputIndex != null)
        canvas.drawCircle(
          Offset(values[selectedInputIndex!], halfHeight),
          22.5,
          bigCircleColorPaint,
        );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;

  static Paint _paintFromColor(Color color, [bool active = false]) {
    return Paint()
      ..style = PaintingStyle.fill
      ..color = color
      ..strokeWidth = active ? 6 : 4
      ..isAntiAlias = true;
  }
}