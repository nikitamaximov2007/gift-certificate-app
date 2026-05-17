import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/certificate_record.dart';
import '../services/database_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with AutomaticKeepAliveClientMixin {
  List<CertificateRecord> _records = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await DatabaseService.instance.fetchAll();
    if (mounted) setState(() { _records = rows; _loading = false; });
  }

  Future<void> _confirmDelete(CertificateRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Удалить запись?',
          style: TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 18),
        ),
        content: Text(
          '${record.fullName} — ${record.amountFormatted}',
          style: const TextStyle(fontFamily: 'Montserrat', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена',
                style: TextStyle(
                    fontFamily: 'Montserrat', color: Color(0xFF7A6152))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить',
                style: TextStyle(
                    fontFamily: 'Montserrat', color: Color(0xFFB00020))),
          ),
        ],
      ),
    );
    if (confirmed == true && record.id != null) {
      await DatabaseService.instance.deleteRecord(record.id!);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('История'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _load,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFC8A97E)))
          : _records.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  color: const Color(0xFFC8A97E),
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 32),
                    itemCount: _records.length,
                    itemBuilder: (_, i) => _buildCard(_records[i]),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_outlined,
              size: 72, color: Colors.black.withOpacity(0.12)),
          const SizedBox(height: 16),
          Text(
            'Сертификаты ещё не созданы',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 15,
              color: Colors.black.withOpacity(0.35),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Перейдите на вкладку «Создать»',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 13,
              color: Colors.black.withOpacity(0.25),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(CertificateRecord record) {
    final file = File(record.filePath);
    return Dismissible(
      key: ValueKey(record.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Color(0xFFB00020)),
      ),
      confirmDismiss: (_) async {
        await _confirmDelete(record);
        return false;
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openPreview(record),
          onLongPress: () => _confirmDelete(record),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 90,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFFEDE7DD),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: file.existsSync()
                        ? Image.file(file, fit: BoxFit.cover)
                        : _thumbnailFallback(record.season),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.fullName,
                        style: const TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 15,
                          color: Color(0xFF2C1A0E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        record.amountFormatted,
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFC8A97E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _tag(record.seasonLabel),
                          const SizedBox(width: 6),
                          Text(
                            record.createdAt,
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 11,
                              color: Color(0xFFAA9080),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: Color(0xFFCCBBAA), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumbnailFallback(String season) {
    const icons = {
      'summer': '☀',
      'autumn': '🍂',
      'winter': '❄',
      'spring': '🌸',
    };
    return Center(
      child: Text(icons[season] ?? '✦', style: const TextStyle(fontSize: 22)),
    );
  }

  Widget _tag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EFE7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFD4C5B0)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 10,
          color: Color(0xFF7A6152),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _openPreview(CertificateRecord record) {
    final file = File(record.filePath);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Файл не найден',
            style: TextStyle(fontFamily: 'Montserrat')),
        backgroundColor: Color(0xFF2C1A0E),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PreviewPage(record: record, file: file),
      ),
    );
  }
}

// ── Full-screen preview ───────────────────────────────────────────────────────

class _PreviewPage extends StatelessWidget {
  final CertificateRecord record;
  final File file;

  const _PreviewPage({required this.record, required this.file});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: const Color(0xFFC8A97E),
        title: Text(
          record.fullName,
          style: const TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () => Share.shareXFiles(
              [XFile(file.path)],
              text: 'Подарочный сертификат',
            ),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(file),
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.black,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _info('Сумма', record.amountFormatted),
            _info('Сезон', record.seasonLabel),
            _info('Дата', record.createdAt),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 10,
                color: Color(0xFF8C7560))),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 13,
                color: Color(0xFFC8A97E),
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}
