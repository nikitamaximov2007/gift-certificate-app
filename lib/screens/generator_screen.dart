import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import '../models/certificate_record.dart';
import '../services/certificate_generator.dart';
import '../services/database_service.dart';
import '../widgets/season_chip.dart';
import 'package:intl/intl.dart';

class GeneratorScreen extends StatefulWidget {
  const GeneratorScreen({super.key});

  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _season = 'summer';
  ui.Image? _bgImage;
  ui.Image? _qrImage;
  bool _imagesLoading = false;

  bool _isGenerating = false;
  Uint8List? _outputBytes;
  String? _outputPath;
  String? _statusMessage;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _loadImages('summer');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadImages(String season) async {
    setState(() {
      _imagesLoading = true;
      _bgImage = null;
    });
    try {
      final bg = await loadUiImage('assets/certificate_template_$season.png');
      ui.Image? qr;
      if (_qrImage == null) {
        try { qr = await loadUiImage('assets/vk_qr.png'); } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _bgImage = bg;
          if (qr != null) _qrImage = qr;
          _imagesLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _imagesLoading = false);
    }
  }

  Future<void> _onSeasonChanged(String season) async {
    if (season == _season) return;
    setState(() => _season = season);
    await _loadImages(season);
  }

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameCtrl.text.trim();
    final amount = _amountCtrl.text.trim();

    setState(() {
      _isGenerating = true;
      _statusMessage = null;
      _isError = false;
      _outputBytes = null;
    });

    try {
      final bytes = await CertificateGenerator.generate(
        clientName: name,
        amount: amount,
        season: _season,
      );

      final path = await CertificateGenerator.saveToAppDir(
        bytes: bytes,
        clientName: name,
        season: _season,
      );

      final record = CertificateRecord(
        fullName: name,
        amount: double.tryParse(amount) ?? 0,
        season: _season,
        createdAt: DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now()),
        filePath: path,
      );
      await DatabaseService.instance.addRecord(record);

      if (mounted) {
        setState(() {
          _outputBytes = bytes;
          _outputPath = path;
          _statusMessage = 'Сертификат создан';
          _isError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Ошибка: $e';
          _isError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _saveToGallery() async {
    if (_outputBytes == null) return;
    try {
      await Gal.putImageBytes(_outputBytes!);
      if (mounted) _showSnack('Сохранено в галерею');
    } catch (e) {
      if (mounted) _showSnack('Ошибка сохранения: $e', isError: true);
    }
  }

  Future<void> _share() async {
    if (_outputPath == null) return;
    try {
      await Share.shareXFiles(
        [XFile(_outputPath!)],
        text: 'Подарочный сертификат',
      );
    } catch (e) {
      if (mounted) _showSnack('Ошибка: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Montserrat')),
      backgroundColor: isError ? const Color(0xFFB00020) : const Color(0xFF2C1A0E),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сертификат'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 32),
          children: [
            _buildFormCard(),
            const SizedBox(height: 4),
            _buildPreviewSection(),
            if (_statusMessage != null) ...[
              const SizedBox(height: 8),
              _buildStatusBanner(),
            ],
            if (_outputBytes != null) ...[
              const SizedBox(height: 4),
              _buildActionButtons(),
            ],
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildGenerateButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Имя клиента'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Полное имя клиента',
                prefixIcon: Icon(Icons.person_outline, color: Color(0xFFC8A97E)),
              ),
              style: const TextStyle(fontFamily: 'Montserrat', fontSize: 15),
              onChanged: (_) => setState(() {}),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите имя клиента' : null,
            ),
            const SizedBox(height: 20),
            _label('Сумма сертификата'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              decoration: const InputDecoration(
                hintText: '0',
                prefixIcon: Icon(Icons.payments_outlined, color: Color(0xFFC8A97E)),
                suffixText: '₽',
                suffixStyle: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 18,
                  color: Color(0xFFC8A97E),
                ),
              ),
              style: const TextStyle(fontFamily: 'Montserrat', fontSize: 15),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Введите сумму';
                if (double.tryParse(v.trim()) == null) return 'Введите число';
                return null;
              },
            ),
            const SizedBox(height: 20),
            _label('Сезон оформления'),
            const SizedBox(height: 10),
            SeasonSelector(
              selected: _season,
              onChanged: _onSeasonChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            'Предпросмотр',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 4096 / 2304,
                child: _imagesLoading
                    ? _previewPlaceholder(loading: true)
                    : CustomPaint(
                        painter: CertificatePainter(
                          clientName: _nameCtrl.text.trim().isEmpty
                              ? 'Имя клиента'
                              : _nameCtrl.text.trim(),
                          amountText: _amountCtrl.text.trim().isEmpty
                              ? '0'
                              : _amountCtrl.text.trim(),
                          backgroundImage: _bgImage,
                          qrImage: _qrImage,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewPlaceholder({bool loading = false}) {
    return Container(
      color: const Color(0xFFEDE7DD),
      child: Center(
        child: loading
            ? const CircularProgressIndicator(color: Color(0xFFC8A97E))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_outlined,
                      size: 36, color: Colors.black.withOpacity(0.2)),
                  const SizedBox(height: 6),
                  Text(
                    'Выберите сезон',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      color: Colors.black.withOpacity(0.3),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _isError
              ? const Color(0xFFF9E8E8)
              : const Color(0xFFE8F2E8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _isError ? const Color(0xFFE57373) : const Color(0xFF81C784),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _isError ? Icons.error_outline : Icons.check_circle_outline,
              color: _isError ? const Color(0xFFB00020) : const Color(0xFF388E3C),
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _statusMessage!,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                  color: _isError ? const Color(0xFFB00020) : const Color(0xFF2E7D32),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _outlinedBtn(
              icon: Icons.download_outlined,
              label: 'Галерея',
              onPressed: _saveToGallery,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _outlinedBtn(
              icon: Icons.share_outlined,
              label: 'Поделиться',
              onPressed: _share,
            ),
          ),
        ],
      ),
    );
  }

  Widget _outlinedBtn({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF2C1A0E),
        side: const BorderSide(color: Color(0xFFC8A97E)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        minimumSize: const Size(0, 48),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return ElevatedButton(
      onPressed: _isGenerating ? null : _generate,
      child: _isGenerating
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFFC8A97E),
              ),
            )
          : const Text('СОЗДАТЬ СЕРТИФИКАТ'),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF7A6152),
        letterSpacing: 0.8,
      ),
    );
  }
}
