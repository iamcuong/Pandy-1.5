import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'common.dart';

/// Điều khiển [StrokeWriter] từ bên ngoài — tương đương API hanzi-writer.
class StrokeWriterController {
  _StrokeWriterState? _s;

  bool get hasData => _s?._data != null;
  Future<void> animate() async => _s?._animateAll();
  void showCharacter() => _s?._showAll();
  void hideCharacter() => _s?._hideAll();

  void startQuiz({
    void Function(int totalMistakes)? onMistake,
    void Function(int totalMistakes)? onCorrectStroke,
    void Function(int totalMistakes)? onComplete,
  }) =>
      _s?._startQuiz(onMistake, onCorrectStroke, onComplete);

  void cancelQuiz() => _s?._cancelQuizAndShow();
}

/// Vẽ chữ Hán theo dữ liệu nét makemeahanzi, hoạt hoạ thứ tự nét và chấm điểm
/// khi người dùng tô từng nét.
///
/// Toạ độ gốc 1024×1024, trục Y lật: y_màn_hình = padding + (900 − y)·scale.
class StrokeWriter extends StatefulWidget {
  const StrokeWriter({
    super.key,
    required this.char,
    required this.controller,
    this.size = 240,
    this.padding = 20,
    this.showGrid = true,
    this.strokeColor = C.ink900,
    this.outlineColor = C.borderLight,
    this.highlightColor = C.amber,
    this.drawingColor = C.primary,
    this.quizStrokeColor = C.primary,
    this.drawingWidth = 5,
    this.delayBetweenStrokes = const Duration(milliseconds: 500),
    this.onLoaded,
  });

  final String char;
  final StrokeWriterController controller;
  final double size;
  final double padding;
  final bool showGrid;
  final Color strokeColor;
  final Color outlineColor;
  final Color highlightColor;
  final Color drawingColor;
  final Color quizStrokeColor;
  final double drawingWidth;
  final Duration delayBetweenStrokes;
  final ValueChanged<bool>? onLoaded;

  @override
  State<StrokeWriter> createState() => _StrokeWriterState();
}

class _StrokeWriterState extends State<StrokeWriter> with TickerProviderStateMixin {
  StrokeData? _data;
  bool _loading = true;
  int _loadGen = 0;

  List<Path> _paths = const [];
  List<Path> _medianPaths = const [];
  List<double> _prog = const [];
  List<Color> _colors = const [];

  late final AnimationController _strokeAnim;
  late final AnimationController _flash;
  int _animIndex = -1;
  int _animGen = 0;
  int _flashIndex = -1;

  bool _quiz = false;
  int _quizIndex = 0;
  int _mistakes = 0;
  List<Offset> _user = const [];
  void Function(int)? _onMistake;
  void Function(int)? _onCorrect;
  void Function(int)? _onComplete;

  double get _scale => (widget.size - 2 * widget.padding) / 1024;

  Offset _toScreen(Offset p) => Offset(widget.padding + p.dx * _scale, widget.padding + (900 - p.dy) * _scale);

  Offset _toChar(Offset s) => Offset((s.dx - widget.padding) / _scale, 900 - (s.dy - widget.padding) / _scale);

  @override
  void initState() {
    super.initState();
    widget.controller._s = this;
    _strokeAnim = AnimationController(vsync: this)
      ..addListener(() {
        if (_animIndex >= 0 && _animIndex < _prog.length) {
          setState(() => _prog[_animIndex] = _strokeAnim.value);
        }
      });
    _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..addListener(() => setState(() {}));
    _load();
  }

  @override
  void didUpdateWidget(StrokeWriter old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      if (old.controller._s == this) old.controller._s = null;
      widget.controller._s = this;
    }
    if (old.char != widget.char || old.size != widget.size) _load();
  }

  @override
  void dispose() {
    if (widget.controller._s == this) widget.controller._s = null;
    _strokeAnim.dispose();
    _flash.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final gen = ++_loadGen;
    _stopAnim();
    _clearQuiz();
    // Được gọi từ initState/didUpdateWidget — build chạy ngay sau đó, không cần setState.
    _loading = true;
    _data = null;
    final ref = context.read<AppState>().ref;
    StrokeData? d;
    try {
      d = await ref.strokes(widget.char);
    } catch (_) {
      d = null;
    }
    if (!mounted || gen != _loadGen) return;

    final s = _scale;
    final m = Float64List.fromList(
        [s, 0, 0, 0, 0, -s, 0, 0, 0, 0, 1, 0, widget.padding, widget.padding + 900 * s, 0, 1]);
    final paths = <Path>[];
    final medians = <Path>[];
    if (d != null) {
      for (final sp in d.strokes) {
        paths.add(parseSvgPathData(sp).transform(m));
      }
      for (final med in d.medians) {
        final pts = med.map(_toScreen).toList();
        final p = Path();
        if (pts.isNotEmpty) {
          p.moveTo(pts.first.dx, pts.first.dy);
          for (final q in pts.skip(1)) {
            p.lineTo(q.dx, q.dy);
          }
        }
        medians.add(p);
      }
    }
    setState(() {
      _data = d;
      _loading = false;
      _paths = paths;
      _medianPaths = medians;
      _prog = List<double>.filled(paths.length, 1.0);
      _colors = List<Color>.filled(paths.length, widget.strokeColor);
    });
    widget.onLoaded?.call(d != null);
  }

  // ------------------------------------------------------------ hoạt hoạ
  void _stopAnim() {
    _animGen++;
    if (_strokeAnim.isAnimating) _strokeAnim.stop();
    _animIndex = -1;
  }

  void _showAll() {
    _stopAnim();
    _clearQuiz();
    setState(() {
      for (var i = 0; i < _prog.length; i++) {
        _prog[i] = 1;
        _colors[i] = widget.strokeColor;
      }
    });
  }

  void _hideAll() {
    _stopAnim();
    setState(() {
      for (var i = 0; i < _prog.length; i++) {
        _prog[i] = 0;
      }
    });
  }

  Future<void> _animateAll() async {
    if (_data == null) return;
    _stopAnim();
    _clearQuiz();
    final gen = _animGen;
    setState(() {
      for (var i = 0; i < _prog.length; i++) {
        _prog[i] = 0;
        _colors[i] = widget.strokeColor;
      }
    });
    for (var i = 0; i < _prog.length; i++) {
      if (!mounted || gen != _animGen) return;
      final ok = await _animateStroke(i, gen);
      if (!ok || !mounted || gen != _animGen) return;
      if (i < _prog.length - 1) await Future<void>.delayed(widget.delayBetweenStrokes);
    }
  }

  Future<bool> _animateStroke(int i, int gen) async {
    final len = _medianPaths[i].computeMetrics().fold<double>(0, (a, m) => a + m.length);
    _strokeAnim.duration = Duration(milliseconds: (250 + len * 3).clamp(300, 900).round());
    _animIndex = i;
    try {
      await _strokeAnim.forward(from: 0).orCancel;
    } on TickerCanceled {
      return false;
    }
    if (!mounted || gen != _animGen) return false;
    setState(() {
      _prog[i] = 1;
      _animIndex = -1;
    });
    return true;
  }

  // ------------------------------------------------------------ luyện viết
  void _clearQuiz() {
    _quiz = false;
    _user = const [];
    _onMistake = _onCorrect = _onComplete = null;
  }

  void _cancelQuizAndShow() => _showAll();

  void _startQuiz(void Function(int)? onMistake, void Function(int)? onCorrect, void Function(int)? onComplete) {
    if (_data == null) return;
    _stopAnim();
    setState(() {
      _quiz = true;
      _quizIndex = 0;
      _mistakes = 0;
      _user = const [];
      _onMistake = onMistake;
      _onCorrect = onCorrect;
      _onComplete = onComplete;
      for (var i = 0; i < _prog.length; i++) {
        _prog[i] = 0;
        _colors[i] = widget.quizStrokeColor;
      }
    });
  }

  void _pointerDown(PointerDownEvent e) {
    if (!_quiz) return;
    setState(() => _user = [e.localPosition]);
  }

  void _pointerMove(PointerMoveEvent e) {
    if (!_quiz || _user.isEmpty) return;
    setState(() => _user = [..._user, e.localPosition]);
  }

  void _pointerUp(PointerEvent e) {
    if (!_quiz || _user.isEmpty) return;
    final pts = _user.map(_toChar).toList();
    setState(() => _user = const []);
    final data = _data;
    if (data == null || _quizIndex >= data.medians.length) return;
    if (_polyLen(pts) < 25) return; // chạm nhẹ — không tính

    if (_strokeMatches(pts, data.medians[_quizIndex])) {
      final i = _quizIndex;
      _quizIndex++;
      setState(() => _prog[i] = 1);
      _onCorrect?.call(_mistakes);
      if (_quizIndex >= data.medians.length) {
        final done = _onComplete;
        final total = _mistakes;
        _clearQuiz();
        done?.call(total);
      }
    } else {
      _mistakes++;
      _onMistake?.call(_mistakes);
      _flashIndex = _quizIndex;
      _flash.forward(from: 0);
    }
  }

  // ------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    Widget body;
    if (_loading) {
      body = const Center(
        child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: C.primary)),
      );
    } else if (_data == null) {
      body = Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _GridPainter(widget.showGrid))),
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Hz(widget.char, size: size * 0.42, color: C.border),
            const SizedBox(height: 6),
            Text('Chưa có dữ liệu nét viết cho chữ này', style: ts(11, c: C.ink500)),
          ]),
        ),
      ]);
    } else {
      body = Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _pointerDown,
        onPointerMove: _pointerMove,
        onPointerUp: _pointerUp,
        onPointerCancel: (_) => setState(() => _user = const []),
        child: CustomPaint(
          size: Size(size, size),
          painter: _WriterPainter(
            paths: _paths,
            medians: _medianPaths,
            prog: _prog,
            colors: _colors,
            outlineColor: widget.outlineColor,
            grid: widget.showGrid,
            flashIndex: _flash.isAnimating ? _flashIndex : -1,
            flashValue: _flash.value,
            highlightColor: widget.highlightColor,
            user: _user,
            drawingColor: widget.drawingColor,
            drawingWidth: widget.drawingWidth,
            brush: 200 * _scale,
          ),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: C.surface,
        border: Border.all(color: C.borderLight),
        borderRadius: BorderRadius.circular(4),
      ),
      child: body,
    );
  }
}

// ---------------------------------------------------------------- chấm điểm nét
double _polyLen(List<Offset> pts) {
  var l = 0.0;
  for (var i = 1; i < pts.length; i++) {
    l += (pts[i] - pts[i - 1]).distance;
  }
  return l;
}

List<Offset> _resample(List<Offset> pts, int n) {
  if (pts.length < 2) return List.filled(n, pts.isEmpty ? Offset.zero : pts.first);
  final cum = <double>[0];
  for (var i = 1; i < pts.length; i++) {
    cum.add(cum.last + (pts[i] - pts[i - 1]).distance);
  }
  final total = cum.last;
  if (total == 0) return List.filled(n, pts.first);
  final out = <Offset>[];
  var seg = 0;
  for (var k = 0; k < n; k++) {
    final d = total * k / (n - 1);
    while (seg < pts.length - 2 && cum[seg + 1] < d) {
      seg++;
    }
    final segLen = cum[seg + 1] - cum[seg];
    final double t = segLen == 0 ? 0.0 : ((d - cum[seg]) / segLen).clamp(0.0, 1.0).toDouble();
    out.add(Offset.lerp(pts[seg], pts[seg + 1], t)!);
  }
  return out;
}

double _distToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (len2 == 0) return (p - a).distance;
  final double t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2).clamp(0.0, 1.0).toDouble();
  return (p - (a + ab * t)).distance;
}

double _distToPolyline(Offset p, List<Offset> line) {
  if (line.length == 1) return (p - line.first).distance;
  var best = double.infinity;
  for (var i = 1; i < line.length; i++) {
    best = math.min(best, _distToSegment(p, line[i - 1], line[i]));
  }
  return best;
}

/// So khớp nét người dùng với đường trung tuyến (đơn vị toạ độ 1024).
/// Ngưỡng ~1/4 ô viết cho điểm đầu/cuối; kiểm tra thêm khoảng cách trung bình,
/// hướng đầu→cuối và tỉ lệ độ dài.
bool _strokeMatches(List<Offset> user, List<Offset> median) {
  if (median.isEmpty) return false;
  final u = _resample(user, 20);
  final m = _resample(median, 20);

  if ((u.first - m.first).distance > 256 || (u.last - m.last).distance > 256) return false;

  final avgUserToMedian = u.fold<double>(0, (a, p) => a + _distToPolyline(p, median)) / u.length;
  if (avgUserToMedian > 180) return false;
  final avgMedianToUser = m.fold<double>(0, (a, p) => a + _distToPolyline(p, user)) / m.length;
  if (avgMedianToUser > 200) return false;

  final du = u.last - u.first;
  final dm = m.last - m.first;
  if (du.distance > 30 && dm.distance > 30) {
    final cos = (du.dx * dm.dx + du.dy * dm.dy) / (du.distance * dm.distance);
    if (cos < 0.2) return false;
  }

  final lu = _polyLen(user);
  final lm = _polyLen(median);
  if (lm > 60 && (lu < lm * 0.35 || lu > lm * 2.5)) return false;
  return true;
}

// ---------------------------------------------------------------- painter
void _paintGrid(Canvas canvas, Size size) {
  final paint = Paint()
    ..color = C.borderLight
    ..strokeWidth = 1;
  void dashed(Offset a, Offset b) {
    final total = (b - a).distance;
    final dir = (b - a) / total;
    var d = 0.0;
    while (d < total) {
      final e = math.min(d + 4, total);
      canvas.drawLine(a + dir * d, a + dir * e, paint);
      d += 8;
    }
  }

  final w = size.width, h = size.height;
  dashed(Offset(w / 2, 0), Offset(w / 2, h));
  dashed(Offset(0, h / 2), Offset(w, h / 2));
  dashed(Offset.zero, Offset(w, h));
  dashed(Offset(w, 0), Offset(0, h));
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.grid);
  final bool grid;

  @override
  void paint(Canvas canvas, Size size) {
    if (grid) _paintGrid(canvas, size);
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.grid != grid;
}

class _WriterPainter extends CustomPainter {
  _WriterPainter({
    required this.paths,
    required this.medians,
    required this.prog,
    required this.colors,
    required this.outlineColor,
    required this.grid,
    required this.flashIndex,
    required this.flashValue,
    required this.highlightColor,
    required this.user,
    required this.drawingColor,
    required this.drawingWidth,
    required this.brush,
  });

  final List<Path> paths;
  final List<Path> medians;
  final List<double> prog;
  final List<Color> colors;
  final Color outlineColor;
  final bool grid;
  final int flashIndex;
  final double flashValue;
  final Color highlightColor;
  final List<Offset> user;
  final Color drawingColor;
  final double drawingWidth;
  final double brush;

  @override
  void paint(Canvas canvas, Size size) {
    if (grid) _paintGrid(canvas, size);

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    fill.color = outlineColor;
    for (final p in paths) {
      canvas.drawPath(p, fill);
    }

    for (var i = 0; i < paths.length; i++) {
      final t = prog[i];
      if (t <= 0) continue;
      if (t >= 1) {
        fill.color = colors[i];
        canvas.drawPath(paths[i], fill);
        continue;
      }
      // Nét đang vẽ dở: tô theo đường trung tuyến, cắt trong viền nét.
      final pen = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = brush
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = colors[i];
      canvas.save();
      canvas.clipPath(paths[i]);
      for (final metric in medians[i].computeMetrics()) {
        canvas.drawPath(metric.extractPath(0, metric.length * t), pen);
      }
      canvas.restore();
    }

    if (flashIndex >= 0 && flashIndex < paths.length) {
      final double a = math.sin(math.pi * flashValue).clamp(0.0, 1.0).toDouble();
      fill.color = highlightColor.withValues(alpha: a);
      canvas.drawPath(paths[flashIndex], fill);
    }

    if (user.length > 1) {
      final pen = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = drawingWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = drawingColor;
      final path = Path()..moveTo(user.first.dx, user.first.dy);
      for (final p in user.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, pen);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
