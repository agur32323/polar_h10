class Measurement {
  final int id;
  final int bpm;
  final String timestamp;

  Measurement({required this.id, required this.bpm, required this.timestamp});

  factory Measurement.fromMap(Map<String, dynamic> map) {
    return Measurement(
      id: map['id'],
      bpm: map['bpm'],
      timestamp: map['timestamp'],
    );
  }
}
