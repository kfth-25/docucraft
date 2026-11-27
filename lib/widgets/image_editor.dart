// DocuCraft — Image Editor Widget
// Mirip Presenton's ImageEditor: Generate / Upload / Gallery / Previous

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../themes/app_theme.dart';
import '../services/ai_generation.dart';

class ImageEditor {
  static Future<ImageEditResult?> show(
    BuildContext context, {
    String? currentImageUrl,
    String? promptHint,
  }) {
    return showModalBottomSheet<ImageEditResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ImageEditorSheet(
        currentImageUrl: currentImageUrl,
        promptHint: promptHint,
      ),
    );
  }
}

class ImageEditResult {
  final String imageUrl;
  final String? prompt;
  const ImageEditResult({required this.imageUrl, this.prompt});
}

// ══ IMAGE EDITOR SHEET ══
class _ImageEditorSheet extends StatefulWidget {
  final String? currentImageUrl;
  final String? promptHint;
  const _ImageEditorSheet({this.currentImageUrl, this.promptHint});
  @override
  State<_ImageEditorSheet> createState() => _ImageEditorSheetState();
}

class _ImageEditorSheetState extends State<_ImageEditorSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _previewImage = '';
  String _prompt = '';
  bool _isGenerating = false;
  bool _isSearching = false;
  List<String> _stockResults = [];
  List<String> _previousImages = [];
  String? _selectedStockProvider = 'pexels';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _previewImage = widget.currentImageUrl ?? '';
    _prompt = widget.promptHint ?? '';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Padding(padding: const EdgeInsets.only(top: 8),
            child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 12),
          Row(children: [
            const Padding(padding: EdgeInsets.only(left: 16),
              child: Text('Edit Image', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white))),
            const Spacer(),
            // Preview thumbnail
            if (_previewImage.isNotEmpty)
              Container(
                width: 40, height: 40, margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: _previewImage.startsWith('http')
                      ? NetworkImage(_previewImage) as ImageProvider
                      : const NetworkImage('https://via.placeholder.com/40'),
                    fit: BoxFit.cover,
                  ),
                  border: Border.all(color: Colors.white.withAlpha(20)),
                ),
              ),
            GestureDetector(
              onTap: () => Navigator.pop(context, _previewImage.isNotEmpty ? ImageEditResult(imageUrl: _previewImage, prompt: _prompt) : null),
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(8)),
                child: const Text('Apply', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          // Tab Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: Colors.white.withAlpha(8), borderRadius: BorderRadius.circular(10)),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(color: AppTheme.primary.withAlpha(80), borderRadius: BorderRadius.circular(10)),
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(icon: Icon(Icons.auto_awesome, size: 16), text: 'Generate'),
                Tab(icon: Icon(Icons.upload, size: 16), text: 'Upload'),
                Tab(icon: Icon(Icons.search, size: 16), text: 'Gallery'),
                Tab(icon: Icon(Icons.history, size: 16), text: 'Previous'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: TabBarView(
            controller: _tabController,
            children: [
              _buildGenerateTab(),
              _buildUploadTab(),
              _buildGalleryTab(),
              _buildPreviousTab(),
            ],
          )),
        ],
      ),
    );
  }

  // ══ GENERATE TAB ══
  Widget _buildGenerateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('AI Image Generation (coming soon)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70)),
        const SizedBox(height: 12),
        TextField(
          controller: TextEditingController(text: _prompt),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Describe the image you want...',
            hintStyle: TextStyle(color: Colors.white.withAlpha(40)),
            filled: true, fillColor: Colors.white.withAlpha(5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withAlpha(15))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withAlpha(15))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary)),
          ),
          onChanged: (v) => _prompt = v,
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: _isGenerating ? null : _generateImage,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: _isGenerating ? null : const LinearGradient(colors: [AppTheme.primary, Color(0xFFA855F7)]),
                  color: _isGenerating ? Colors.white.withAlpha(10) : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (_isGenerating) ...[
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                    const SizedBox(width: 8),
                  ] else ...[
                    const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(_isGenerating ? 'Generating...' : 'Generate Image',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        ]),
        if (_previewImage.isNotEmpty) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(_previewImage, height: 200, width: double.infinity, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 200,
                decoration: BoxDecoration(color: Colors.white.withAlpha(5), borderRadius: BorderRadius.circular(12)),
                child: const Center(child: Icon(Icons.image, color: Colors.white24, size: 48)),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  // ══ UPLOAD TAB ══
  Widget _buildUploadTab() {
    return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: Colors.white.withAlpha(5), shape: BoxShape.circle, border: Border.all(color: Colors.white.withAlpha(20))),
          child: const Icon(Icons.cloud_upload_outlined, color: Colors.white54, size: 40),
        ),
        const SizedBox(height: 16),
        const Text('Upload Image', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('PNG, JPG, WebP up to 10MB', style: TextStyle(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _uploadImage,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(10)),
            child: const Text('Choose File', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    ));
  }

  // ══ GALLERY TAB (Stock Images) ══
  Widget _buildGalleryTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: _searchCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search stock images...',
            hintStyle: TextStyle(color: Colors.white.withAlpha(40)),
            prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
            filled: true, fillColor: Colors.white.withAlpha(5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withAlpha(15))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withAlpha(15))),
          ),
          onSubmitted: (v) => _searchStockImages(v),
        ),
        const SizedBox(height: 8),
        // Provider selector
        Row(children: [
          _providerChip('Pexels', 'pexels'),
          const SizedBox(width: 8),
          _providerChip('Pixabay', 'pixabay'),
        ]),
        const SizedBox(height: 12),
        Expanded(child: _isSearching
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _stockResults.isEmpty
            ? const Center(child: Text('Search for images', style: TextStyle(color: Colors.white38)))
            : GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
                itemCount: _stockResults.length,
                itemBuilder: (ctx, i) => GestureDetector(
                  onTap: () => setState(() {
                    _previewImage = _stockResults[i];
                    _previousImages.add(_stockResults[i]);
                  }),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(_stockResults[i], fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.white.withAlpha(5),
                        child: const Icon(Icons.broken_image, color: Colors.white24),
                      ),
                    ),
                  ),
                ),
              ),
        ),
      ]),
    );
  }

  // ══ PREVIOUS TAB ══
  Widget _buildPreviousTab() {
    if (_previousImages.isEmpty) {
      return const Center(child: Text('No previous images', style: TextStyle(color: Colors.white38)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemCount: _previousImages.length,
      itemBuilder: (ctx, i) => GestureDetector(
        onTap: () => setState(() => _previewImage = _previousImages[i]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(_previousImages[i], fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.white.withAlpha(5),
              child: const Icon(Icons.broken_image, color: Colors.white24),
            ),
          ),
        ),
      ),
    );
  }

  // ══ HELPERS ══
  Widget _providerChip(String label, String value) {
    final isActive = _selectedStockProvider == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedStockProvider = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary.withAlpha(80) : Colors.white.withAlpha(5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? AppTheme.primary : Colors.white.withAlpha(15)),
        ),
        child: Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Future<void> _generateImage() async {
    if (_prompt.trim().isEmpty) return;
    setState(() => _isGenerating = true);
    try {
      final result = await AiGenerationService.generateImage(prompt: _prompt);
      if (result != null && mounted) {
        setState(() {
          _previewImage = result;
          _previousImages.add(result);
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('AI Image Generation belum tersedia — upload gambar manual saja'),
            backgroundColor: AppTheme.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _uploadImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1920, maxHeight: 1080, imageQuality: 85);
      if (picked != null && mounted) {
        // For web, we'd use bytes; for now, show file path
        setState(() {
          _previewImage = picked.path; // Local path works for display
          _previousImages.add(picked.path);
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload error: $e')));
    }
  }

  Future<void> _searchStockImages(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isSearching = true);
    try {
      final results = await AiGenerationService.searchStockImages(query: query, provider: _selectedStockProvider ?? 'pexels');
      if (mounted) {
        setState(() => _stockResults = results);
        if (results.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Stock image belum tersedia — upload gambar manual saja'),
              backgroundColor: AppTheme.warning,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search error: $e')));
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }
}
