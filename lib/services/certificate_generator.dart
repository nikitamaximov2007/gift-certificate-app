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
// CertificatePainter
//
// COORDINATE SYSTEM: all Y values are BASELINES, matching the Qt/C++ desktop
// renderer (QPainter::drawText with a QPoint draws at the alphabetic baseline).
//
// Font sizes are expressed as fractions of the canvas height H, identical to
// the desktop's  fh(x) = int(H * x).
//
// All numeric constants were ported directly from CertificateGenerator.cpp.
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

  // ── Low-level paint utilities ──────────────────────────────────────────────

  static Paint _stroke(Color c, double w) =>
      Paint()..color = c..strokeWidth = w..style = PaintingStyle.stroke;

  static Paint _fill(Color c) =>
      Paint()..color = c..style = PaintingStyle.fill;

  /// Lay out [text] and return (painter, alphabeticBaseline).
  /// The baseline is the distance from the top-left of the painter box to
  /// the alphabetic baseline, matching QFontMetrics::ascent().
  (TextPainter, double) _layout(String text, TextStyle style,
      {double? minW, double? maxW}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      textAlign: minW != null ? TextAlign.center : TextAlign.left,
    )..layout(
        minWidth: minW ?? 0,
        maxWidth: maxW ?? double.infinity,
      );
    final asc = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic) ??
        (style.fontSize ?? 16) * 0.8;
    return (tp, asc);
  }

  /// Draw [text] horizontally centred on the canvas, BASELINE at [baselineY].
  /// Mirrors Qt: drawCenteredText(painter, text, font, cx, baselineY, color)
  /// Returns the TextPainter for metric queries (height, width).
  TextPainter _centered(
      Canvas canvas, String text, double baselineY, TextStyle style, double W) {
    final (tp, asc) = _layout(text, style, minW: W, maxW: W);
    tp.paint(canvas, Offset(0, baselineY - asc));
    return tp;
  }

  /// Draw [text] centred around [cx], BASELINE at [baselineY].
  /// Mirrors Qt: drawCenteredText(painter, text, font, cx, baselineY, color)
  TextPainter _centeredAtX(Canvas canvas, String text, double cx,
      double baselineY, TextStyle style) {
    final (tp, asc) = _layout(text, style);
    tp.paint(canvas, Offset(cx - tp.width / 2, baselineY - asc));
    return tp;
  }

  /// Draw [text] left-aligned at [x], BASELINE at [baselineY].
  /// Mirrors Qt: painter.drawText(x, cy, text)
  TextPainter _leftAt(Canvas canvas, String text, double x, double baselineY,
      TextStyle style) {
    final (tp, asc) = _layout(text, style);
    tp.paint(canvas, Offset(x, baselineY - asc));
    return tp;
  }

  /// Decorative horizontal rule with centre dot — matches drawDecorRule().
  void _decorRule(Canvas canvas, double cx, double y, double halfLen,
      Color color, double strokeW) {
    final gap = halfLen * 0.04 + strokeW * 6;
    final p = _stroke(color, strokeW);
    canvas.drawLine(Offset(cx - halfLen, y), Offset(cx - gap, y), p);
    canvas.drawLine(Offset(cx + gap, y), Offset(cx + halfLen, y), p);
    canvas.drawCircle(Offset(cx, y), strokeW * 3.5, _fill(color));
  }

  // ── Background ─────────────────────────────────────────────────────────────

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
          Rect.fromLTWH(0, 0, W, H), _fill(const Color(0xFFF3EEE5)));
    }
  }

  // ── Title ──────────────────────────────────────────────────────────────────
  //
  // Qt source:
  //   int y = fh(0.150);
  //   drawCenteredText(..., "ПОДАРОЧНЫЙ", titleSmall, cx, y, ...);
  //   y += QFontMetrics(titleSmall).height() + fh(0.020);
  //   drawCenteredText(..., "СЕРТИФИКАТ", titleBig,   cx, y, ...);

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

    final double y1 = H * 0.150; // baseline of "ПОДАРОЧНЫЙ"
    final tp1 = _centered(canvas, 'ПОДАРОЧНЫЙ', y1, smallStyle, W);
    // Qt: y += QFM.height() + fh(0.020).
    // On Windows QFM.height() includes leading and is ~15-20% larger than
    // fontSize, so the effective advance is H*0.048*1.18 + H*0.020 ≈ H*0.077.
    // We replicate that with tp1.height + H*0.058 to produce the same visual gap.
    final double y2 = y1 + tp1.height + H * 0.058;
    _centered(canvas, 'СЕРТИФИКАТ', y2, bigStyle, W);
  }

  // ── Central block ──────────────────────────────────────────────────────────
  //
  // Qt source:
  //   centerZoneTop = fh(0.360); centralLift = fh(0.010);
  //   dividerYBase  = centerZoneTop - fh(0.012)  → fh(0.348)
  //   dividerY      = dividerYBase  - centralLift → fh(0.338)
  //   subtitleYBase = dividerYBase  + fh(0.052)  → fh(0.400)
  //   subtitleY     = subtitleYBase - centralLift → fh(0.390)  [baseline]
  //   nameY         = subtitleYBase + QFM(subtitle).height() + fh(0.040)
  //                 = fh(0.400) + fh(0.027) + fh(0.040)      [baseline]
  //   nameLineY     = nameY + scriptFm.descent() + fh(0.028) - centralLift

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

    _decorRule(canvas, W / 2, H * 0.338, W * 0.21, accent, H * 0.002);

    // subtitle baseline = fh(0.390)
    final tpSub =
        _centered(canvas, 'НАСТОЯЩИЙ СЕРТИФИКАТ ВЫДАН', H * 0.390, subtitleStyle, W);

    // name baseline = fh(0.400) + subtitle.height + fh(0.040)
    final double nameBaseline = H * 0.400 + tpSub.height + H * 0.040;
    final tpName = _centered(
      canvas,
      clientName.isEmpty ? 'Имя клиента' : clientName,
      nameBaseline,
      scriptStyle,
      W,
    );

    // underline: nameBaseline + descent + fh(0.028) - centralLift(0.010)
    final (_, nameAsc) = _layout(
      clientName.isEmpty ? 'Имя клиента' : clientName,
      scriptStyle,
    );
    final nameDesc = tpName.height - nameAsc;
    final double lineY = nameBaseline + nameDesc + H * 0.028 - H * 0.010;
    canvas.drawLine(
      Offset(W / 2 - W * 0.19, lineY),
      Offset(W / 2 + W * 0.19, lineY),
      _stroke(lineColor, H * 0.0009),
    );
  }

  // ── Amount block ───────────────────────────────────────────────────────────
  //
  // Qt source:
  //   yAmountLabel = fh(0.615)                               [baseline]
  //   yAmountValue = yAmountLabel + QFM(label).height() + fh(0.038)  [baseline]
  //   amountGap    = fw(0.010)
  //   line at yAmountValue + fh(0.048)

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

    // ₽ (U+20BD) is absent from PlayfairDisplay-Regular.
    // fontFamilyFallback is unreliable for TextPainter on Android canvas —
    // the engine may not trigger glyph substitution at all, producing □.
    // Safest fix: omit fontFamily entirely so the platform picks its default
    // (Roboto on Android, SF Pro on iOS) — both contain ₽ natively.
    final currencyStyle = TextStyle(
      fontSize: H * 0.072,
      color: const Color(0xFF2B1F17),
      height: 1.0,
    );

    final double labelBaseline = H * 0.615;
    final tpLabel = _centered(canvas, 'НА СУММУ', labelBaseline, labelStyle, W);

    final double amtBaseline = labelBaseline + tpLabel.height + H * 0.038;

    final display = amountText.isEmpty ? '0' : amountText;

    // Measure number and ruble symbol to compute the combined centred position.
    final (tpNum, numAsc) = _layout(display, amountStyle);
    final (tpRub, rubAsc) = _layout('₽', currencyStyle);

    // amountGap = fw(0.010) — extra kerning gap between number and symbol
    final double gap = W * 0.010;
    final double totalW = tpNum.width + gap + tpRub.width;
    final double startX = (W - totalW) / 2;

    tpNum.paint(canvas, Offset(startX, amtBaseline - numAsc));
    tpRub.paint(canvas, Offset(startX + tpNum.width + gap, amtBaseline - rubAsc));

    // decorative line fh(0.048) below the amount baseline
    canvas.drawLine(
      Offset(W / 2 - W * 0.11, amtBaseline + H * 0.048),
      Offset(W / 2 + W * 0.11, amtBaseline + H * 0.048),
      _stroke(lineColor, H * 0.0009),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────
  //
  // Qt source:
  //   footerTop = fh(0.845)                       [baseline for signature]
  //   line at footerTop + fh(0.015)
  //   role/date baselines at footerTop + fh(0.052)

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

    final double ft = H * 0.845; // footerTop baseline
    final double lx = W * 0.33;
    final double rx = W * 0.67;

    // Left column: signature → rule → role label
    _centeredAtX(canvas, 'Екатерина Максимова', lx, ft, signStyle);
    canvas.drawLine(
      Offset(W * 0.24, ft + H * 0.015),
      Offset(W * 0.42, ft + H * 0.015),
      _stroke(lineColor, H * 0.0009),
    );
    _centeredAtX(canvas, 'МАСТЕР', lx, ft + H * 0.052, roleStyle);

    // Right column: date label → rule → date value
    _centeredAtX(canvas, 'ДАТА ВЫДАЧИ', rx, ft, roleStyle);
    canvas.drawLine(
      Offset(W * 0.58, ft + H * 0.015),
      Offset(W * 0.76, ft + H * 0.015),
      _stroke(lineColor, H * 0.0009),
    );
    _centeredAtX(canvas, DateFormat('dd.MM.yyyy').format(DateTime.now()), rx,
        ft + H * 0.052, dateStyle);
  }

  // ── Contact / QR block ─────────────────────────────────────────────────────
  //
  // Qt source:
  //   qrRect  = QRect(fw(0.88), fh(0.79), qrSize, qrSize)
  //   contactX = qrRect.center().x() - fw(0.10)   [left edge of text block]
  //   cy       = qrRect.y() - fh(0.160)            [first line baseline]
  //   advance  = QFM.height() + gap (title: +fh(0.003), body: +fh(0.006))
  //   VK link  = qrRect.bottom() + fh(0.040)       [baseline]

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
      _fill(const Color(0xDDFFFFFF)),
    );

    if (qrImage != null) {
      paintImage(canvas: canvas, rect: qrRect, image: qrImage!, fit: BoxFit.fill);
    } else {
      final (tp, _) = _layout('VK\nQR', titleStyle.copyWith(fontSize: H * 0.016),
          maxW: qrSize);
      tp.paint(canvas,
          Offset(qrX + (qrSize - tp.width) / 2, qrY + (qrSize - tp.height) / 2));
    }

    // VK link — baseline at qrRect.bottom() + fh(0.040)
    _centeredAtX(
        canvas, 'vk.com/permtatuazh', qrRect.center.dx, qrRect.bottom + H * 0.040, vkStyle);

    // Contact lines — contactX = qrRect.center.x - fw(0.10)
    final double contactX = qrRect.center.dx - W * 0.10;
    double cy = qrY - H * 0.160; // first baseline

    const entries = [
      ('Адрес:', 'Докучаева 50Б, офис 210'),
      ('Мастер:', 'Екатерина Максимова'),
      ('Телефон:', '89091011771'),
    ];

    for (final (label, value) in entries) {
      _leftAt(canvas, label, contactX, cy, titleStyle);
      cy += titleStyle.fontSize! + H * 0.003; // QFM.height() ≈ fontSize (height:1.0)
      _leftAt(canvas, value, contactX, cy, bodyStyle);
      cy += bodyStyle.fontSize! + H * 0.006;
    }
  }

  // ── Validity note ──────────────────────────────────────────────────────────
  //
  // Qt: bottomRuleY = fh(0.935); text baseline = fh(0.935) + fh(0.034)

  void _drawValidityNote(Canvas canvas, double W, double H) {
    final style = TextStyle(
      fontFamily: 'Montserrat',
      fontSize: H * 0.018,
      color: const Color(0xFF3B2F25),
      height: 1.0,
    );
    _centered(canvas, 'Сертификат действителен в течение 6 месяцев',
        H * 0.935 + H * 0.034, style, W);
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
