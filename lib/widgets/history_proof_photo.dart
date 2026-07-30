import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/history_entry.dart';
import '../services/storage_service.dart';

class HistoryProofPhoto extends StatefulWidget {
  final HistoryEntry entry;
  final double width;
  final double height;

  const HistoryProofPhoto({
    super.key,
    required this.entry,
    this.width = 44,
    this.height = 44,
  });

  @override
  State<HistoryProofPhoto> createState() => _HistoryProofPhotoState();
}

class _HistoryProofPhotoState extends State<HistoryProofPhoto> {
  Future<Uint8List?>? _download;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HistoryProofPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.proofPhotoPath != widget.entry.proofPhotoPath ||
        oldWidget.entry.proofPhotoBase64 != widget.entry.proofPhotoBase64) {
      _load();
    }
  }

  void _load() {
    final path = widget.entry.proofPhotoPath;
    _download = path == null ? null : StorageService().readActionPhoto(path);
  }

  Uint8List? _legacyBytes() {
    final value = widget.entry.proofPhotoBase64;
    if (value == null || value.isEmpty) return null;
    try {
      return base64Decode(value.contains(',') ? value.split(',').last : value);
    } catch (_) {
      return null;
    }
  }

  void _showFullScreen(Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5,
                child: Center(
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: IconButton.filled(
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _image(Uint8List bytes) {
    return Semantics(
      button: true,
      label: 'Ouvrir la preuve photo',
      child: GestureDetector(
        onTap: () => _showFullScreen(bytes),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            width: widget.width,
            height: widget.height,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.entry.hasProofPhoto) return const SizedBox.shrink();
    final legacy = _legacyBytes();
    if (legacy != null) return _image(legacy);

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: FutureBuilder<Uint8List?>(
        future: _download,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          final bytes = snapshot.data;
          if (snapshot.hasError || bytes == null) {
            return IconButton(
              tooltip: 'Réessayer le chargement',
              padding: EdgeInsets.zero,
              onPressed: () => setState(_load),
              icon: const Icon(Icons.refresh_rounded, color: Colors.orange),
            );
          }
          return _image(bytes);
        },
      ),
    );
  }
}
