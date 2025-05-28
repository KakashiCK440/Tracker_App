class Detection {
  final int id;
  final String label;
  final double confidence;
  final double x1; // normalized [0,1]
  final double y1; // normalized [0,1]
  final double x2; // normalized [0,1]
  final double y2; // normalized [0,1]

  Detection({
    required this.id,
    required this.label,
    required this.confidence,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  factory Detection.fromJson(Map<String, dynamic> json) {
    return Detection(
      id: json['id'] as int,
      label: json['label'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      x1: (json['x1'] as num).toDouble(),
      y1: (json['y1'] as num).toDouble(),
      x2: (json['x2'] as num).toDouble(),
      y2: (json['y2'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'confidence': confidence,
      'x1': x1,
      'y1': y1,
      'x2': x2,
      'y2': y2,
    };
  }

  @override
  String toString() {
    return 'Detection{id: $id, label: $label, confidence: $confidence, x1: $x1, y1: $y1, x2: $x2, y2: $y2}';
  }
}
