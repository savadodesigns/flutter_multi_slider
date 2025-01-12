import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Used in [ValueRangePainterCallback] as parameter.
/// Every range between the edges of [MultiSlider] generate an [ValueRange].
/// Do NOT be mistaken with discrete intervals made by [divisions]!
class ValueRange {
  const ValueRange(
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

  bool contains(double x) => x >= start && x <= end;
}

typedef ValueRangePainterCallback = bool Function(ValueRange valueRange);

class MultiSlider extends StatefulWidget {
  MultiSlider({
    required this.values,
    required this.onChanged,
    this.max = 1,
    this.min = 0,
    this.onChangeStart,
    this.onChangeEnd,
    this.color,
    this.rangeColors,
    this.thumbColor,
    this.thumbRadius = 10,
    this.horizontalPadding = 26.0,
    this.height = 45,
    this.activeTrackSize = 6,
    this.inactiveTrackSize = 4,
    this.indicator = false,
    this.divisions,
    this.valueRangePainterCallback,
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

  /// Bar range active colors.
  final List<Color>? rangeColors;

  /// Thumb radius.
  final double thumbRadius;

  /// Thumb color.
  final Color? thumbColor;

  /// Value indicator.
  final bool indicator;

  /// Active track size.
  final double activeTrackSize;

  /// Inactive track size.
  final double inactiveTrackSize;

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

  /// Used to decide how a line between values or the boundaries should be painted.
  /// Returns [bool] and pass an [ValueRange] object as parameter.
  final ValueRangePainterCallback? valueRangePainterCallback;

  @override
  _MultiSliderState createState() => _MultiSliderState();
}

class _MultiSliderState extends State<MultiSlider> {
  double? _maxWidth;
  int? _selectedInputIndex;

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
                valueRangePainterCallback: widget.valueRangePainterCallback ??
                    _defaultDivisionPainterCallback,
                divisions: widget.divisions,
                isDisabled: isDisabled,
                rangeColors: widget.rangeColors,
                thumbColor: widget.thumbColor ?? widget.color ??
                    sliderTheme.activeTrackColor ??
                    theme.colorScheme.primary,
                thumbRadius: widget.thumbRadius,
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
                values: widget.values,
                indicator: widget.indicator,
                positions: widget.values.map(_convertValueToPixelPosition).toList(),
                horizontalPadding: widget.horizontalPadding,
                activeTrackSize: widget.activeTrackSize,
                inactiveTrackSize: widget.inactiveTrackSize,
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

    if (widget.divisions != null) {
      return copiedValues
          .map<double>(
            (value) => _getDiscreteValue(
              value,
              widget.min,
              widget.max,
              widget.divisions!,
            ),
          )
          .toList();
    }
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

  bool _defaultDivisionPainterCallback(ValueRange division) =>
      !division.isFirst && !division.isLast;
}

class _MultiSliderPainter extends CustomPainter {
  final List<double> values;
  final List<double> positions;
  final int? selectedInputIndex;
  final double horizontalPadding;
  final Paint activeTrackColorPaint;
  final Paint thumbColorPaint;
  final Paint bigCircleColorPaint;
  final Paint inactiveTrackColorPaint;
  final int? divisions;
  final ValueRangePainterCallback valueRangePainterCallback;
  final List<Color>? rangeColors;
  final double thumbRadius;
  final bool indicator;
  final double activeTrackSize;
  final double inactiveTrackSize;

  _MultiSliderPainter({
    required bool isDisabled,
    required Color activeTrackColor,
    required Color inactiveTrackColor,
    required Color disabledActiveTrackColor,
    required Color disabledInactiveTrackColor,
    required Color thumbColor,
    required this.values,
    required this.positions,
    required this.selectedInputIndex,
    required this.horizontalPadding,
    required this.divisions,
    required this.valueRangePainterCallback,
    required this.rangeColors,
    required this.thumbRadius,
    required this.indicator,
    required this.activeTrackSize,
    required this.inactiveTrackSize,
  })  : activeTrackColorPaint = _paintFromColor(
          isDisabled ? disabledActiveTrackColor : activeTrackColor,
          activeTrackSize,
        ),
        inactiveTrackColorPaint = _paintFromColor(
          isDisabled ? disabledInactiveTrackColor : inactiveTrackColor,
          inactiveTrackSize,
        ),
        thumbColorPaint = _paintFromColor(
          thumbColor,
          inactiveTrackSize,
        ),
        bigCircleColorPaint = _paintFromColor(
          activeTrackColor.withOpacity(0.20),
          inactiveTrackSize,
        );

  @override
  void paint(Canvas canvas, Size size) {
    final double baseLine = indicator ? size.height - thumbRadius : size.height / 2;
    final canvasStart = horizontalPadding;
    final canvasEnd = size.width - horizontalPadding;

    List<ValueRange> _makeRanges(
      List<double> innerValues,
      double start,
      double end,
    ) {
      final values = <double>[
        start,
        ...innerValues
            .map<double>(divisions == null
                ? (v) => v
                : (v) => _getDiscreteValue(v, start, end, divisions!))
            .toList(),
        end
      ];
      return List<ValueRange>.generate(
        values.length - 1,
        (index) => ValueRange(
          values[index],
          values[index + 1],
          index,
          index == 0,
          index == values.length - 2,
        ),
      );
    }

    final valueRanges = _makeRanges(positions, canvasStart, canvasEnd);

    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(valueRanges.first.start, baseLine),
        radius: valueRangePainterCallback(valueRanges.first) ? 3 : 2,
      ),
      math.pi / 2,
      math.pi,
      true,
      valueRangePainterCallback(valueRanges.first)
          ? activeTrackColorPaint
          : inactiveTrackColorPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(valueRanges.last.end, baseLine),
        radius: valueRangePainterCallback(valueRanges.last) ? 3 : 2,
      ),
      -math.pi / 2,
      math.pi,
      true,
      valueRangePainterCallback(valueRanges.last)
          ? activeTrackColorPaint
          : inactiveTrackColorPaint,
    );

    for (ValueRange valueRange in valueRanges) {
      Color rangeColor = valueRangePainterCallback(valueRange)
          ? activeTrackColorPaint.color
          : inactiveTrackColorPaint.color;

      if (rangeColors != null && valueRange.index < rangeColors!.length) {
        rangeColor = rangeColors![valueRange.index];
      }

      final Paint rangePaint = _paintFromColor(rangeColor, valueRangePainterCallback(valueRange) ? activeTrackSize : inactiveTrackSize);

      canvas.drawLine(
        Offset(valueRange.start, baseLine),
        Offset(valueRange.end, baseLine),
        rangePaint,
      );
    }

    if (divisions != null) {
      final divisionsList = List<double>.generate(
          divisions! + 1,
          (index) =>
              canvasStart + index * (canvasEnd - canvasStart) / divisions!);

      for (double x in divisionsList) {
        final valueRange = valueRanges.firstWhere(
          (valueRange) => valueRange.contains(x),
        );

        canvas.drawCircle(
          Offset(x, baseLine),
          1,
          _paintFromColor(valueRangePainterCallback(valueRange)
              ? Colors.white.withOpacity(0.5)
              : activeTrackColorPaint.color.withOpacity(0.5)),
        );
      }
    }

    final textStyle = TextStyle(fontSize: 14);
    final textPainter = TextPainter(textAlign: TextAlign.center, textDirection: TextDirection.ltr);

    for (int i = 0; i < positions.length; i++) {
      double x = divisions == null
          ? positions[i]
          : _getDiscreteValue(positions[i], canvasStart, canvasEnd, divisions!);

      if (selectedInputIndex == i)
        canvas.drawCircle(
          Offset(x, baseLine),
          thumbRadius + 10,
          bigCircleColorPaint,
        );

      if (indicator) {
        // Draw value indicator
        textPainter.text = TextSpan(text: values[i].toString(), style: textStyle);
        textPainter.layout();
        textPainter.paint(canvas, Offset(x - textPainter.width / 2, baseLine - thumbRadius - 30));
      }

      // Draw thumb
      Path path = Path();
      path.addOval(Rect.fromCircle(center: Offset(x, baseLine), radius: thumbRadius));
      canvas.drawShadow(path, Colors.black, 3, true);
      canvas.drawPath(path, thumbColorPaint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;

  static Paint _paintFromColor(Color color, [double strokeWidth = 6]) {
    return Paint()
      ..style = PaintingStyle.fill
      ..color = color
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;
  }
}

double _getDiscreteValue(
  double value,
  double start,
  double end,
  int divisions,
) {
  final k = (end - start) / divisions;
  return start + ((value - start) / k).roundToDouble() * k;
}
