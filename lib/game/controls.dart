import 'dart:math';
import 'dart:ui';

/// Yüzen sanal çubuk: parmağın değdiği yerde açılır, parmak tabandan uzaklaşırsa taban peşinden gelir
class Stick {
  static const radius = 58.0;

  int? pointer;
  Offset center = Offset.zero;
  Offset finger = Offset.zero;

  bool get active => pointer != null;

  /// Tabana göre yön ve şiddet; uzunluk 0..1
  Offset get vector {
    final d = finger - center;
    final l = d.distance;
    if (l <= radius) return d / radius;
    return d / l;
  }

  void press(int id, Offset at, Size area) {
    pointer = id;
    center = Offset(
      at.dx.clamp(radius * 0.7, area.width - radius * 0.7),
      at.dy.clamp(radius * 0.7, area.height - radius * 0.7),
    );
    finger = at;
  }

  void drag(Offset at) {
    finger = at;
    final d = finger - center;
    if (d.distance > radius) center = finger - d / d.distance * radius;
  }

  void release() => pointer = null;
}

/// Hareket çubuğunda ölü bölge ve ince ayar için hafif eğri
Offset shapeMove(Offset v) {
  const dead = 0.12;
  final l = v.distance;
  if (l <= dead) return Offset.zero;
  final m = pow((l - dead) / (1 - dead), 1.2).toDouble();
  return v / l * m;
}
