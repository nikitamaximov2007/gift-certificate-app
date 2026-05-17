import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// ---------------------------------------------------------------------------
// Image loader helper
// ---------------------------------------------------------------------------
Future<ui.Image> loadUiImage(String assetPath) async {
  final data = await rootBundle.load(assetPath);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  return frame.image;
}

// ---------------------------------------------------------------------------
// The core painter — used both in the live preview CustomPaint widget
// and by the export path via PictureRecorder.
// Coordinate system: proportional to canvas W and H (top-based Y).
// ---------------------------------------------------------------------------
class CertificatePainter extends CustomPainter {
  final String clientName;
  final String amountText;
  final ui.Image? backgroundImage;
  final ui.Image? qrImage;

  const CertificatePainter({
    required this.clientName,
    required this.amountText,
    this.backgroundImage,
    this.qrImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width;
    final H = size.height;

    _drawBackground(canvas, W, H);
    _drawTitle(canvas, W, H);
    _drawCentralBlock(canvas, W, H);
    _drawAmountBlock(canvas, W, H);
    _drawFooter(canvas, W, H);
    _drawContactBlock(canvas, W, H);
    _drawValidityNote(canvas, W, H);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static Paint _linePaint(Color color, double width) =>
      Paint()..color = color..strokeWidth = width..style = PaintingStyle.stroke;

  static Paint _fillPaint(Color color) =>
      Paint()..color = color..style = PaintingStyle.fill;

  // Draw horizontally-centered text at top-Y [y].
  // Returns the painter so callers can query .height.
  TextPainter _centered(
    Canvas canvas,
    String text,
    double y,
    TextStyle style,
    double maxWidth,
  ) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    // minWidth == maxWidth forces the painter box to fill the full canvas
    // width so textAlign:center actually centres each line correctly.
    )..layout(minWidth: maxWidth, maxWidth: maxWidth);
    tp.paint(canvas, Offset(0, y));
    return tp;
  }

  // Draw text centered around cx (not left-aligned).
  TextPainter _atX(
    Canvas canvas,
    String text,
    double cx,
    double y,
    TextStyle style,
  ) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, y));
    return tp;
  }

  void _decorRule(Canvas canvas, double cx, double y, double halfLen, Color color, double strokeW) {
    const double gap = 0.012; // fraction of halfLen used as gap ratio — kept proportional
    final gapPx = halfLen * 0.04 + strokeW * 6;
    final paint = _linePaint(color, strokeW);
    canvas.drawLine(Offset(cx - halfLen, y), Offset(cx - gapPx, y), paint);
    canvas.drawLine(Offset(cx + gapPx, y), Offset(cx + halfLen, y), paint);
    canvas.drawCircle(Offset(cx, y), strokeW * 3.5, _fillPaint(color));
  }

  // ── Background ────────────────────────────────────────────────────────────

  void _drawBackground(Canvas canvas, double W, double H) {
    if (backgroundImage != null) {
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(0, 0, W, H),
        image: backgroundImage!,
        fit: BoxFit.fill,
      );
    } else {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, W, H),
        _fillPaint(const Color(0xFFF3EEE5)),
      );
    }
  }

  // ── Title ─────────────────────────────────────────────────────────────────
  // "ПОДАРОЧНЫЙ" (small Playfair) then "СЕРТИФИКАТ" (large Playfair)

  void _drawTitle(Canvas canvas, double W, double H) {
    const darkText = Color(0xFF2F2118);

    final smallStyle = TextStyle(
      fontFamily: 'PlayfairDisplay',
      fontSize: H * 0.048,
      color: darkText,
      letterSpacing: H * 0.048 * 0.08,
      height: 1.0,
    );
    final bigStyle = TextStyle(
      fontFamily: 'PlayfairDisplay',
      fontSize: H * 0.094,
      color: darkText,
      letterSpacing: H * 0.094 * 0.03,
      height: 1.0,
    );

    final tp1 = _centered(canvas, 'ПОДАРОЧНЫЙ', H * 0.108, smallStyle, W);
    _centered(canvas, 'СЕРТИФИКАТ', H * 0.108 + tp1.height + H * 0.018, bigStyle, W);
  }

  // ── Central block ─────────────────────────────────────────────────────────
  // Decor rule → subtitle → client name → underline

  void _drawCentralBlock(Canvas canvas, double W, double H) {
    const darkText = Color(0xFF2F2118);
    const nameColor = Color(0xFF231915);
    const accent = Color(0xFFB58B4A);
    const lineColor = Color(0xFFBFA374);

    final subtitleStyle = TextStyle(
      fontFamily: 'Montserrat',
      fontSize: H * 0.027,
      color: darkText,
      letterSpacing: H * 0.027 * 0.12,
      fontWeight: FontWeight.w500,
      height: 1.0,
    );
    final scriptStyle = TextStyle(
      fontFamily: 'GreatVibes',
      fontSize: H * 0.072,
      color: nameColor,
      height: 1.0,
    );

    final double ruleY = H * 0.336;
    _decorRule(canvas, W / 2, ruleY, W * 0.21, accent, H * 0.002);

    final double subtitleY = H * 0.388;
    final tpSub = _centered(canvas, 'НАСТОЯЩИЙ СЕРТИФИКАТ ВЫДАН', subtitleY, subtitleStyle, W);

    final double nameY = subtitleY + tpSub.height + H * 0.038;
    final tpName = _centered(canvas, clientName.isEmpty ? 'Имя клиента' : clientName, nameY, scriptStyle, W);

    final double underlineY = nameY + tpName.height + H * 0.018;
    canvas.drawLine(
      Offset(W / 2 - W * 0.19, underlineY),
      Offset(W / 2 + W * 0.19, underlineY),
      _linePaint(lineColor, H * 0.0009),
    );
  }

  // ── Amount block ──────────────────────────────────────────────────────────

  void _drawAmountBlock(Canvas canvas, double W, double H) {
    const darkText = Color(0xFF2F2118);
    const amountColor = Color(0xFF1F1510);
    const lineColor = Color(0xFFBFA374);

    final labelStyle = TextStyle(
      fontFamily: 'Montserrat',
      fontSize: H * 0.030,
      color: darkText,
      letterSpacing: H * 0.030 * 0.18,
      fontWeight: FontWeight.w500,
      height: 1.0,
    );
    final amountStyle = TextStyle(
      fontFamily: 'PlayfairDisplay',
      fontSize: H * 0.078,
      color: amountColor,
      letterSpacing: H * 0.078 * 0.03,
      height: 1.0,
    );
    final currencyStyle = TextStyle(
      fontFamily: 'PlayfairDisplay',
      // Fallback chain so ₽ (U+20BD) is resolved by a system font when
      // PlayfairDisplay does not contain the glyph.
      fontFamilyFallback: const ['Roboto', 'NotoSans', 'sans-serif'],
      fontSize: H * 0.072,
      color: const Color(0xFF2B1F17),
      height: 1.0,
    );

    final double labelY = H * 0.612;
    final tpLabel = _centered(canvas, 'НА СУММУ', labelY, labelStyle, W);

    final double valueY = labelY + tpLabel.height + H * 0.036;

    final display = amountText.isEmpty ? '0' : amountText;
    final tpAmount = TextPainter(
      text: TextSpan(text: display, style: amountStyle),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final tpCurrency = TextPainter(
      text: TextSpan(text: ' ₽', style: currencyStyle),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final totalW = tpAmount.width + tpCurrency.width;
    final startX = (W - totalW) / 2;
    tpAmount.paint(canvas, Offset(startX, valueY));
    tpCurrency.paint(canvas, Offset(startX + tpAmount.width, valueY + H * 0.006));

    canvas.drawLine(
      Offset(W / 2 - W * 0.11, valueY + H * 0.094),
      Offset(W / 2 + W * 0.11, valueY + H * 0.094),
      _linePaint(lineColor, H * 0.0009),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────
  // Signature (left), date (right), validity note

  void _drawFooter(Canvas canvas, double W, double H) {
    const darkText = Color(0xFF4A3A2B);
    const lineColor = Color(0xFFB9A07A);

    final signStyle = TextStyle(
      fontFamily: 'GreatVibes',
      fontSize: H * 0.037,
      color: const Color(0xFF3A2B20),
      height: 1.0,
    );
    final roleStyle = TextStyle(
      fontFamily: 'Montserrat',
      fontSize: H * 0.022,
      color: darkText,
      letterSpacing: H * 0.022 * 0.16,
      fontWeight: FontWeight.w500,
      height: 1.0,
    );
    final dateStyle = TextStyle(
      fontFamily: 'Montserrat',
      fontSize: H * 0.024,
      color: const Color(0xFF2F241C),
      height: 1.0,
    );

    final double fTop = H * 0.842;
    final double lx = W * 0.33;
    final double rx = W * 0.67;

    // Left: signature
    _atX(canvas, 'Екатерина Максимова', lx, fTop, signStyle);
    canvas.drawLine(
      Offset(W * 0.24, fTop + H * 0.042),
      Offset(W * 0.42, fTop + H * 0.042),
      _linePaint(lineColor, H * 0.0009),
    );
    _atX(canvas, 'МАСТЕР', lx, fTop + H * 0.052, roleStyle);

    // Right: date
    _atX(canvas, 'ДАТА ВЫДАЧИ', rx, fTop, roleStyle);
    canvas.drawLine(
      Offset(W * 0.58, fTop + H * 0.042),
      Offset(W * 0.76, fTop + H * 0.042),
      _linePaint(lineColor, H * 0.0009),
    );
    _atX(canvas, DateFormat('dd.MM.yyyy').format(DateTime.now()), rx, fTop + H * 0.052, dateStyle);
  }

  // ── Contact / QR block ────────────────────────────────────────────────────

  void _drawContactBlock(Canvas canvas, double W, double H) {
    const darkText = Color(0xFF2F241C);

    final titleStyle = TextStyle(
      fontFamily: 'Montserrat',
      fontSize: H * 0.016,
      color: darkText,
      fontWeight: FontWeight.w600,
      height: 1.0,
    );
    final bodyStyle = TextStyle(
      fontFamily: 'Montserrat',
      fontSize: H * 0.015,
      color: darkText,
      height: 1.0,
    );
    final vkStyle = TextStyle(
      fontFamily: 'Montserrat',
      fontSize: H * 0.014,
      color: darkText,
      fontWeight: FontWeight.w500,
      height: 1.0,
    );

    final double qrSize = H * 0.145;
    final double qrX = W * 0.88;
    final double qrY = H * 0.790;
    final Rect qrRect = Rect.fromLTWH(qrX, qrY, qrSize, qrSize);

    // QR background
    canvas.drawRRect(
      RRect.fromRectAndRadius(qrRect.inflate(H * 0.004), const Radius.circular(10)),
      _fillPaint(const Color(0xDDFFFFFF)),
    );

    if (qrImage != null) {
      paintImage(canvas: canvas, rect: qrRect, image: qrImage!, fit: BoxFit.fill);
    } else {
      final tp = TextPainter(
        text: TextSpan(text: 'VK\nQR', style: titleStyle.copyWith(fontSize: H * 0.016)),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: qrSize);
      tp.paint(canvas, Offset(qrX + (qrSize - tp.width) / 2, qrY + (qrSize - tp.height) / 2));
    }

    _atX(canvas, 'vk.com/permtatuazh', qrX + qrSize / 2, qrY + qrSize + H * 0.018, vkStyle);

    // Contact lines
    final double cx = qrX + qrSize / 2;
    final double startY = qrY - H * 0.160;
    double cy = startY;

    final lines = <MapEntry<String?, String>>[
      MapEntry('Адрес:', 'Докучаева 50Б, офис 210'),
      MapEntry('Мастер:', 'Екатерина Максимова'),
      MapEntry('Телефон:', '89091011771'),
    ];

    for (final entry in lines) {
      if (entry.key != null) {
        final tp = TextPainter(
          text: TextSpan(text: entry.key, style: titleStyle),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(cx - W * 0.10, cy));
        cy += tp.height + H * 0.003;
      }
      final tp = TextPainter(
        text: TextSpan(text: entry.value, style: bodyStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - W * 0.10, cy));
      cy += tp.height + H * 0.009;
    }
  }

  // ── Validity note ─────────────────────────────────────────────────────────

  void _drawValidityNote(Canvas canvas, double W, double H) {
    final style = TextStyle(
      fontFamily: 'Montserrat',
      fontSize: H * 0.018,
      color: const Color(0xFF3B2F25),
      height: 1.0,
    );
    _centered(canvas, 'Сертификат действителен в течение 6 месяцев', H * 0.956, style, W);
  }

  @override
  bool shouldRepaint(CertificatePainter old) =>
      old.clientName != clientName ||
      old.amountText != amountText ||
      old.backgroundImage != backgroundImage ||
      old.qrImage != qrImage;
}

// ---------------------------------------------------------------------------
// Export service — renders at full 4096×2304 and returns PNG bytes.
// ---------------------------------------------------------------------------
class CertificateGenerator {
  CertificateGenerator._();

  static const double _outW = 4096;
  static const double _outH = 2304;

  static Future<Uint8List> generate({
    required String clientName,
    required String amount,
    required String season,
  }) async {
    final bg = await loadUiImage('assets/certificate_template_$season.png');
    ui.Image? qr;
    try {
      qr = await loadUiImage('assets/vk_qr.png');
    } catch (_) {}

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      const Rect.fromLTWH(0, 0, _outW, _outH),
    );

    CertificatePainter(
      clientName: clientName,
      amountText: amount,
      backgroundImage: bg,
      qrImage: qr,
    ).paint(canvas, const Size(_outW, _outH));

    final picture = recorder.endRecording();
    final image = await picture.toImage(_outW.toInt(), _outH.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static Future<String> saveToAppDir({
    required Uint8List bytes,
    required String clientName,
    required String season,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final certDir = Directory('${dir.path}/certificates');
    await certDir.create(recursive: true);

    final safeName = clientName
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final path = '${certDir.path}/${season}_${safeName}_$ts.png';
    await File(path).writeAsBytes(bytes);
    return path;
  }
}
