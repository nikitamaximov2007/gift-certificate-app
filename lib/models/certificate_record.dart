class CertificateRecord {
  final int? id;
  final String fullName;
  final double amount;
  final String season;
  final String createdAt;
  final String filePath;

  const CertificateRecord({
    this.id,
    required this.fullName,
    required this.amount,
    required this.season,
    required this.createdAt,
    required this.filePath,
  });

  factory CertificateRecord.fromMap(Map<String, dynamic> map) {
    return CertificateRecord(
      id: map['id'] as int?,
      fullName: map['full_name'] as String,
      amount: (map['amount'] as num).toDouble(),
      season: map['season'] as String,
      createdAt: map['created_at'] as String,
      filePath: map['file_path'] as String,
    );
  }

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'full_name': fullName,
    'amount': amount,
    'season': season,
    'created_at': createdAt,
    'file_path': filePath,
  };

  String get seasonLabel {
    switch (season) {
      case 'summer': return 'Лето';
      case 'autumn': return 'Осень';
      case 'winter': return 'Зима';
      case 'spring': return 'Весна';
      default: return season;
    }
  }

  String get amountFormatted {
    final n = amount.truncate();
    return '${n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} ₽';
  }
}
