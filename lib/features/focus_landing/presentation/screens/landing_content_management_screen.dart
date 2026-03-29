import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/services/media_picker_service.dart';
import '../../../../core/services/ux_telemetry_service.dart';
import '../../../../core/utils/english_content_normalizer.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/widgets/optimized_image.dart';
import '../../data/models/focus_landing_content.dart';
import '../../data/repositories/focus_landing_repository.dart';

class LandingContentManagementScreen extends StatefulWidget {
  final User currentUser;
  final AppLanguage currentLanguage;

  const LandingContentManagementScreen({
    super.key,
    required this.currentUser,
    required this.currentLanguage,
  });

  @override
  State<LandingContentManagementScreen> createState() =>
      _LandingContentManagementScreenState();
}

class _LandingContentManagementScreenState
    extends State<LandingContentManagementScreen> {
  final FocusLandingRepository _repo = FocusLandingRepository();
  final MediaPickerService _mediaPicker = MediaPickerService();
  final UxTelemetryService _telemetry = UxTelemetryService.instance;

  final TextEditingController _introTitleEnController = TextEditingController();
  final TextEditingController _introTitleTeController = TextEditingController();
  final TextEditingController _introTitleHiController = TextEditingController();
  final TextEditingController _introBodyEnController = TextEditingController();
  final TextEditingController _introBodyTeController = TextEditingController();
  final TextEditingController _introBodyHiController = TextEditingController();
  final TextEditingController _secondaryTitleEnController =
      TextEditingController();
  final TextEditingController _secondaryTitleTeController =
      TextEditingController();
  final TextEditingController _secondaryTitleHiController =
      TextEditingController();
  final TextEditingController _secondaryBodyEnController =
      TextEditingController();
  final TextEditingController _secondaryBodyTeController =
      TextEditingController();
  final TextEditingController _secondaryBodyHiController =
      TextEditingController();
  final TextEditingController _tertiaryTitleEnController =
      TextEditingController();
  final TextEditingController _tertiaryTitleTeController =
      TextEditingController();
  final TextEditingController _tertiaryTitleHiController =
      TextEditingController();
  final TextEditingController _tertiaryBodyEnController =
      TextEditingController();
  final TextEditingController _tertiaryBodyTeController =
      TextEditingController();
  final TextEditingController _tertiaryBodyHiController =
      TextEditingController();

  String _heroImageUrl = '';
  String _secondaryImageUrl = '';
  String _tertiaryImageUrl = '';
  bool _showHeroImage = true;
  bool _showSecondarySection = true;
  bool _showTertiarySection = false;
  bool _autoShowForPublicUsers = true;
  int _autoShowDurationSeconds = 4;
  int _autoShowFrequencyPerDay = 1;
  int _autoShowStartHour24 = 8;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingHero = false;
  bool _isUploadingSecondary = false;
  bool _isUploadingTertiary = false;
  bool _previewMode = false;
  int _previewImageVersion = DateTime.now().millisecondsSinceEpoch;
  late AppLanguage _previewLanguage;
  List<FocusLandingBlock> _blocks = [];

  @override
  void initState() {
    super.initState();
    _previewLanguage = widget.currentLanguage;
    _loadContent();
  }

  @override
  void dispose() {
    _introTitleEnController.dispose();
    _introTitleTeController.dispose();
    _introTitleHiController.dispose();
    _introBodyEnController.dispose();
    _introBodyTeController.dispose();
    _introBodyHiController.dispose();
    _secondaryTitleEnController.dispose();
    _secondaryTitleTeController.dispose();
    _secondaryTitleHiController.dispose();
    _secondaryBodyEnController.dispose();
    _secondaryBodyTeController.dispose();
    _secondaryBodyHiController.dispose();
    _tertiaryTitleEnController.dispose();
    _tertiaryTitleTeController.dispose();
    _tertiaryTitleHiController.dispose();
    _tertiaryBodyEnController.dispose();
    _tertiaryBodyTeController.dispose();
    _tertiaryBodyHiController.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final content = await _repo.getContent(forceRefresh: true);
    if (!mounted) return;

    _introTitleEnController.text = content.introTitleEn;
    _introTitleTeController.text = content.introTitleTe;
    _introTitleHiController.text = content.introTitleHi;
    _introBodyEnController.text = content.introBodyEn;
    _introBodyTeController.text = content.introBodyTe;
    _introBodyHiController.text = content.introBodyHi;
    _secondaryTitleEnController.text = content.secondaryTitleEn;
    _secondaryTitleTeController.text = content.secondaryTitleTe;
    _secondaryTitleHiController.text = content.secondaryTitleHi;
    _secondaryBodyEnController.text = content.secondaryBodyEn;
    _secondaryBodyTeController.text = content.secondaryBodyTe;
    _secondaryBodyHiController.text = content.secondaryBodyHi;
    _tertiaryTitleEnController.text = content.tertiaryTitleEn;
    _tertiaryTitleTeController.text = content.tertiaryTitleTe;
    _tertiaryTitleHiController.text = content.tertiaryTitleHi;
    _tertiaryBodyEnController.text = content.tertiaryBodyEn;
    _tertiaryBodyTeController.text = content.tertiaryBodyTe;
    _tertiaryBodyHiController.text = content.tertiaryBodyHi;
    _heroImageUrl = content.heroImageUrl;
    _secondaryImageUrl = content.secondaryImageUrl;
    _tertiaryImageUrl = content.tertiaryImageUrl;
    _showHeroImage = content.showHeroImage;
    _showSecondarySection = content.showSecondarySection;
    _showTertiarySection = content.showTertiarySection;
    _autoShowForPublicUsers = content.autoShowForPublicUsers;
    _autoShowDurationSeconds = content.autoShowDurationSeconds;
    _autoShowFrequencyPerDay = content.autoShowFrequencyPerDay;
    _autoShowStartHour24 = content.autoShowStartHour24;
    _blocks = _syncBlocksWithLegacyImageUrls(
      List<FocusLandingBlock>.from(content.blocks),
      heroImageUrl: _heroImageUrl,
      secondaryImageUrl: _secondaryImageUrl,
    );
    _syncLegacyImageUrlsFromBlocks();

    setState(() {
      _isLoading = false;
      _previewImageVersion = DateTime.now().millisecondsSinceEpoch;
    });
  }

  Future<void> _uploadImage({required bool hero}) async {
    if (!widget.currentUser.canModerate) return;

    final file = await _mediaPicker.pickImageFromGallery();
    if (file == null) return;

    if (hero) {
      setState(() => _isUploadingHero = true);
    } else {
      setState(() => _isUploadingSecondary = true);
    }

    final url = await _repo.uploadImage(
      filePath: file.path,
      userId: widget.currentUser.id,
      slot: hero ? 'hero' : 'secondary',
    );

    if (!mounted) return;
    final uploadedUrl = url.url;
    if (hero) {
      setState(() {
        _isUploadingHero = false;
        if (uploadedUrl != null) {
          _heroImageUrl = uploadedUrl;
          _blocks = _syncBlocksWithLegacyImageUrls(
            _blocks,
            heroImageUrl: _heroImageUrl,
            secondaryImageUrl: _secondaryImageUrl,
          );
        }
      });
    } else {
      setState(() {
        _isUploadingSecondary = false;
        if (uploadedUrl != null) {
          _secondaryImageUrl = uploadedUrl;
          _blocks = _syncBlocksWithLegacyImageUrls(
            _blocks,
            heroImageUrl: _heroImageUrl,
            secondaryImageUrl: _secondaryImageUrl,
          );
        }
      });
    }

    if (uploadedUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(url.errorMessage ?? 'Image upload failed')),
      );
      return;
    }
    setState(
      () => _previewImageVersion = DateTime.now().millisecondsSinceEpoch,
    );

    await _telemetry.track(
      eventName: 'landing_content_image_uploaded',
      eventGroup: 'system',
      screen: 'landing_content_management',
      user: widget.currentUser,
      metadata: {'slot': hero ? 'hero' : 'secondary'},
    );
  }

  Future<void> _uploadTertiaryImage() async {
    if (!widget.currentUser.canModerate) return;
    final file = await _mediaPicker.pickImageFromGallery();
    if (file == null) return;
    setState(() => _isUploadingTertiary = true);
    final url = await _repo.uploadImage(
      filePath: file.path,
      userId: widget.currentUser.id,
      slot: 'tertiary',
    );
    if (!mounted) return;
    final uploadedUrl = url.url;
    setState(() {
      _isUploadingTertiary = false;
      if (uploadedUrl != null) _tertiaryImageUrl = uploadedUrl;
      _previewImageVersion = DateTime.now().millisecondsSinceEpoch;
    });
    if (uploadedUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(url.errorMessage ?? 'Image upload failed')),
      );
      return;
    }
    await _telemetry.track(
      eventName: 'landing_content_image_uploaded',
      eventGroup: 'system',
      screen: 'landing_content_management',
      user: widget.currentUser,
      metadata: {'slot': 'tertiary'},
    );
  }

  Future<void> _save() async {
    if (!widget.currentUser.canModerate) return;
    if (_isSaving) return;

    final introTitleEn = _introTitleEnController.text.trim();
    final introBodyEn = _introBodyEnController.text.trim();
    if (introTitleEn.isEmpty || introBodyEn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('English intro title and body are required'),
        ),
      );
      return;
    }
    final englishInputs = <String>[
      introTitleEn,
      introBodyEn,
      _secondaryTitleEnController.text,
      _secondaryBodyEnController.text,
      _tertiaryTitleEnController.text,
      _tertiaryBodyEnController.text,
    ];
    if (!EnglishContentNormalizer.areEnglishLike(englishInputs)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Landing content in English only.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final synced = _syncedImageStateForSave();
    final content = FocusLandingContent(
      introTitleEn: introTitleEn,
      introTitleTe: '',
      introTitleHi: '',
      introBodyEn: introBodyEn,
      introBodyTe: '',
      introBodyHi: '',
      heroImageUrl: synced.heroImageUrl,
      secondaryTitleEn: _secondaryTitleEnController.text.trim(),
      secondaryTitleTe: '',
      secondaryTitleHi: '',
      secondaryBodyEn: _secondaryBodyEnController.text.trim(),
      secondaryBodyTe: '',
      secondaryBodyHi: '',
      secondaryImageUrl: synced.secondaryImageUrl,
      tertiaryTitleEn: _tertiaryTitleEnController.text.trim(),
      tertiaryTitleTe: '',
      tertiaryTitleHi: '',
      tertiaryBodyEn: _tertiaryBodyEnController.text.trim(),
      tertiaryBodyTe: '',
      tertiaryBodyHi: '',
      tertiaryImageUrl: _tertiaryImageUrl.trim(),
      showHeroImage: _showHeroImage,
      showSecondarySection: _showSecondarySection,
      showTertiarySection: _showTertiarySection,
      autoShowForPublicUsers: _autoShowForPublicUsers,
      autoShowDurationSeconds: _autoShowDurationSeconds,
      autoShowFrequencyPerDay: _autoShowFrequencyPerDay,
      autoShowStartHour24: _autoShowStartHour24,
      blocks: synced.blocks,
    );

    final success = await _repo.saveContent(
      content: content,
      currentUser: widget.currentUser,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to save content')));
      return;
    }

    await _telemetry.track(
      eventName: 'landing_content_saved',
      eventGroup: 'system',
      screen: 'landing_content_management',
      user: widget.currentUser,
      metadata: {
        'show_hero_image': _showHeroImage,
        'show_secondary_section': _showSecondarySection,
      },
    );

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Landing content updated')));
  }

  FocusLandingContent _draftContent() {
    final synced = _syncedImageStateForSave();
    return FocusLandingContent(
      introTitleEn: _introTitleEnController.text.trim(),
      introTitleTe: '',
      introTitleHi: '',
      introBodyEn: _introBodyEnController.text.trim(),
      introBodyTe: '',
      introBodyHi: '',
      heroImageUrl: synced.heroImageUrl,
      secondaryTitleEn: _secondaryTitleEnController.text.trim(),
      secondaryTitleTe: '',
      secondaryTitleHi: '',
      secondaryBodyEn: _secondaryBodyEnController.text.trim(),
      secondaryBodyTe: '',
      secondaryBodyHi: '',
      secondaryImageUrl: synced.secondaryImageUrl,
      tertiaryTitleEn: _tertiaryTitleEnController.text.trim(),
      tertiaryTitleTe: '',
      tertiaryTitleHi: '',
      tertiaryBodyEn: _tertiaryBodyEnController.text.trim(),
      tertiaryBodyTe: '',
      tertiaryBodyHi: '',
      tertiaryImageUrl: _tertiaryImageUrl.trim(),
      showHeroImage: _showHeroImage,
      showSecondarySection: _showSecondarySection,
      showTertiarySection: _showTertiarySection,
      autoShowForPublicUsers: _autoShowForPublicUsers,
      autoShowDurationSeconds: _autoShowDurationSeconds,
      autoShowFrequencyPerDay: _autoShowFrequencyPerDay,
      autoShowStartHour24: _autoShowStartHour24,
      blocks: synced.blocks,
    );
  }

  _SyncedImageState _syncedImageStateForSave() {
    final syncedBlocks = _syncBlocksWithLegacyImageUrls(
      _blocks,
      heroImageUrl: _heroImageUrl,
      secondaryImageUrl: _secondaryImageUrl,
    );
    final heroFromBlock = _imageUrlFromBlockById(syncedBlocks, 'hero_image');
    final secondaryFromBlock = _imageUrlFromBlockById(
      syncedBlocks,
      'secondary_image',
    );
    return _SyncedImageState(
      blocks: syncedBlocks,
      heroImageUrl: heroFromBlock.isNotEmpty ? heroFromBlock : _heroImageUrl,
      secondaryImageUrl: secondaryFromBlock.isNotEmpty
          ? secondaryFromBlock
          : _secondaryImageUrl,
    );
  }

  void _syncLegacyImageUrlsFromBlocks() {
    final heroFromBlock = _imageUrlFromBlockById(_blocks, 'hero_image');
    final secondaryFromBlock = _imageUrlFromBlockById(
      _blocks,
      'secondary_image',
    );
    if (heroFromBlock.isNotEmpty) _heroImageUrl = heroFromBlock;
    if (secondaryFromBlock.isNotEmpty) _secondaryImageUrl = secondaryFromBlock;
  }

  List<FocusLandingBlock> _syncBlocksWithLegacyImageUrls(
    List<FocusLandingBlock> source, {
    required String heroImageUrl,
    required String secondaryImageUrl,
  }) {
    var next = List<FocusLandingBlock>.from(source);
    next = _upsertImageBlock(
      next,
      blockId: 'hero_image',
      imageUrl: heroImageUrl,
      insertIndex: 0,
    );
    next = _upsertImageBlock(
      next,
      blockId: 'secondary_image',
      imageUrl: secondaryImageUrl,
    );
    return next;
  }

  List<FocusLandingBlock> _upsertImageBlock(
    List<FocusLandingBlock> blocks, {
    required String blockId,
    required String imageUrl,
    int? insertIndex,
  }) {
    final normalized = imageUrl.trim();
    final index = blocks.indexWhere((block) => block.id == blockId);
    if (index >= 0) {
      final current = blocks[index];
      if (current.type == FocusLandingBlockType.image &&
          current.imageUrl == normalized) {
        return blocks;
      }
      final updated = current.copyWith(
        type: FocusLandingBlockType.image,
        imageUrl: normalized,
      );
      final next = List<FocusLandingBlock>.from(blocks);
      next[index] = updated;
      return next;
    }
    if (normalized.isEmpty) {
      return blocks;
    }
    final next = List<FocusLandingBlock>.from(blocks);
    final newBlock = FocusLandingBlock(
      id: blockId,
      type: FocusLandingBlockType.image,
      imageUrl: normalized,
    );
    if (insertIndex != null && insertIndex >= 0 && insertIndex <= next.length) {
      next.insert(insertIndex, newBlock);
    } else {
      next.add(newBlock);
    }
    return next;
  }

  String _imageUrlFromBlockById(List<FocusLandingBlock> blocks, String id) {
    for (final block in blocks) {
      if (block.id == id && block.type == FocusLandingBlockType.image) {
        return block.imageUrl.trim();
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.currentUser.canModerate) {
      return Scaffold(
        appBar: AppBar(title: const Text('Landing Content')),
        body: const Center(
          child: Text('Only admin and super admin can edit this content.'),
        ),
      );
    }

    final localizations = AppLocalizations(widget.currentLanguage);

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: Text(localizations.manageLandingContent),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimaryOf(context),
        actions: [
          TextButton.icon(
            onPressed: _isLoading
                ? null
                : () {
                    setState(() => _previewMode = !_previewMode);
                  },
            icon: Icon(
              _previewMode ? Icons.edit_note_rounded : Icons.preview_rounded,
              color: AppColors.onPrimaryOf(context),
            ),
            label: Text(
              _previewMode ? 'Edit' : 'Preview',
              style: TextStyle(color: AppColors.onPrimaryOf(context)),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _previewMode
          ? _buildPreviewPane(localizations)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.dividerOf(context)),
                  ),
                  child: Text(
                    'Editing as ${widget.currentUser.role.displayName}',
                    style: TextStyle(
                      color: AppColors.textPrimaryOf(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _buildSwitchTile(
                  title: localizations.showHeroImage,
                  value: _showHeroImage,
                  onChanged: (value) => setState(() => _showHeroImage = value),
                ),
                const SizedBox(height: 8),
                _buildImagePickerCard(
                  title: localizations.heroImage,
                  imageUrl: _heroImageUrl,
                  uploading: _isUploadingHero,
                  onUpload: () => _uploadImage(hero: true),
                ),
                const SizedBox(height: 14),
                _buildSectionTitle(context, localizations.introSection),
                _buildLangField(localizations.titleEn, _introTitleEnController),
                _buildLangField(
                  localizations.descEn,
                  _introBodyEnController,
                  maxLines: 4,
                ),
                const SizedBox(height: 14),
                _buildSwitchTile(
                  title: localizations.showSecondarySection,
                  value: _showSecondarySection,
                  onChanged: (value) =>
                      setState(() => _showSecondarySection = value),
                ),
                const SizedBox(height: 8),
                _buildImagePickerCard(
                  title: localizations.secondaryImage,
                  imageUrl: _secondaryImageUrl,
                  uploading: _isUploadingSecondary,
                  onUpload: () => _uploadImage(hero: false),
                ),
                const SizedBox(height: 14),
                _buildSectionTitle(context, localizations.secondarySection),
                _buildLangField(
                  localizations.titleEn,
                  _secondaryTitleEnController,
                ),
                _buildLangField(
                  localizations.descEn,
                  _secondaryBodyEnController,
                  maxLines: 4,
                ),
                const SizedBox(height: 8),
                if (!_showTertiarySection)
                  OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _showTertiarySection = true),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: const Text('Add Third Section'),
                  )
                else ...[
                  _buildSwitchTile(
                    title: 'Show Third Section',
                    value: _showTertiarySection,
                    onChanged: (value) =>
                        setState(() => _showTertiarySection = value),
                  ),
                  const SizedBox(height: 8),
                  _buildImagePickerCard(
                    title: 'Third Section Image',
                    imageUrl: _tertiaryImageUrl,
                    uploading: _isUploadingTertiary,
                    onUpload: _uploadTertiaryImage,
                  ),
                  const SizedBox(height: 14),
                  _buildSectionTitle(context, 'Third Section'),
                  _buildLangField(
                    localizations.titleEn,
                    _tertiaryTitleEnController,
                  ),
                  _buildLangField(
                    localizations.descEn,
                    _tertiaryBodyEnController,
                    maxLines: 4,
                  ),
                ],
                const SizedBox(height: 12),
                _buildSectionTitle(
                  context,
                  localizations.publicLandingSchedule,
                ),
                _buildSwitchTile(
                  title: localizations.autoShowLandingForPublic,
                  value: _autoShowForPublicUsers,
                  onChanged: (value) =>
                      setState(() => _autoShowForPublicUsers = value),
                ),
                const SizedBox(height: 8),
                _buildDropdownField<int>(
                  label: localizations.autoShowFrequency,
                  value: _autoShowFrequencyPerDay,
                  items: const [1, 2, 3, 4, 6],
                  itemLabel: _frequencyLabel,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _autoShowFrequencyPerDay = value);
                  },
                ),
                const SizedBox(height: 8),
                _buildDropdownField<int>(
                  label: localizations.landingDisplayDuration,
                  value: _autoShowDurationSeconds,
                  items: const [3, 4, 5, 6, 8, 10, 12, 15],
                  itemLabel: (value) =>
                      localizations.secondsLabel(value.toString()),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _autoShowDurationSeconds = value);
                  },
                ),
                const SizedBox(height: 8),
                _buildDropdownField<int>(
                  label: localizations.autoShowStartTime,
                  value: _autoShowStartHour24,
                  items: List<int>.generate(24, (index) => index),
                  itemLabel: _formatHourLabel,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _autoShowStartHour24 = value);
                  },
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(
                    _isSaving
                        ? localizations.saving
                        : localizations.saveChanges,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimaryOf(context),
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPreviewPane(AppLocalizations localizations) {
    final draft = _draftContent();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AppLanguage.values
              .map((lang) {
                final selected = _previewLanguage == lang;
                return ChoiceChip(
                  label: Text(lang.displayName),
                  selected: selected,
                  onSelected: (_) => setState(() => _previewLanguage = lang),
                );
              })
              .toList(growable: false),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.dividerOf(context)),
          ),
          child: Text(
            'Draft preview (${_previewLanguage.displayName})',
            style: TextStyle(
              color: AppColors.textPrimaryOf(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ..._buildDraftPreviewBlocks(draft),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_rounded),
          label: Text(localizations.saveChanges),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimaryOf(context),
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }

  Widget _previewFallbackHero() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.secondary],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.public_rounded,
        color: AppColors.onPrimaryOf(context),
        size: 42,
      ),
    );
  }

  Widget _previewContentCard({required String title, required String body}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.dividerOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimaryOf(context),
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              color: AppColors.textSecondaryOf(context),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.textPrimaryOf(context),
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildLangField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dividerOf(context)),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Text(title),
      ),
    );
  }

  Widget _buildImagePickerCard({
    required String title,
    required String imageUrl,
    required bool uploading,
    required VoidCallback onUpload,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dividerOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimaryOf(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (imageUrl.trim().isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 120,
                color: AppColors.surfaceTier2Of(context),
                child: OptimizedImage(
                  imageUrl: imageUrl,
                  cacheBuster: _previewImageVersion.toString(),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: 120,
                  errorWidget: const SizedBox(
                    height: 120,
                    child: Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
              ),
            )
          else
            Container(
              height: 90,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.dividerOf(context)),
              ),
              child: Text(
                'No image selected',
                style: TextStyle(color: AppColors.textSecondaryOf(context)),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: uploading ? null : onUpload,
            icon: uploading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_rounded),
            label: Text(uploading ? 'Uploading...' : 'Upload Image'),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T value) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dividerOf(context)),
      ),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(labelText: label, border: InputBorder.none),
        items: items
            .map(
              (entry) => DropdownMenuItem<T>(
                value: entry,
                child: Text(itemLabel(entry)),
              ),
            )
            .toList(growable: false),
        onChanged: onChanged,
      ),
    );
  }

  String _formatHourLabel(int hour24) {
    final suffix = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12:00 $suffix';
  }

  String _frequencyLabel(int frequency) {
    if (frequency == 1) {
      return AppLocalizations(widget.currentLanguage).oncePerDay;
    }
    if (frequency == 2) {
      return AppLocalizations(widget.currentLanguage).twicePerDay;
    }
    return '$frequency times per day';
  }

  List<Widget> _buildDraftPreviewBlocks(FocusLandingContent draft) {
    final widgets = <Widget>[];
    if (draft.showHeroImage) {
      if (draft.heroImageUrl.trim().isNotEmpty) {
        widgets.add(
          _DraftPreviewImage(
            imageUrl: draft.heroImageUrl,
            cacheBuster: _previewImageVersion.toString(),
            maxHeight: 260,
            surfaceColor: AppColors.surfaceOf(context),
            borderColor: AppColors.dividerOf(context),
            errorWidget: _previewFallbackHero(),
          ),
        );
      }
      widgets.add(
        _previewContentCard(
          title: draft.localizedIntroTitle(_previewLanguage),
          body: draft.localizedIntroBody(_previewLanguage),
        ),
      );
      widgets.add(const SizedBox(height: 12));
    }

    if (draft.showSecondarySection) {
      if (draft.secondaryImageUrl.trim().isNotEmpty) {
        widgets.add(
          _DraftPreviewImage(
            imageUrl: draft.secondaryImageUrl,
            cacheBuster: _previewImageVersion.toString(),
            maxHeight: 240,
            surfaceColor: AppColors.surfaceOf(context),
            borderColor: AppColors.dividerOf(context),
            errorWidget: const SizedBox.shrink(),
          ),
        );
      }
      widgets.add(
        _previewContentCard(
          title: draft.localizedSecondaryTitle(_previewLanguage),
          body: draft.localizedSecondaryBody(_previewLanguage),
        ),
      );
      widgets.add(const SizedBox(height: 12));
    }

    if (draft.showTertiarySection) {
      if (draft.tertiaryImageUrl.trim().isNotEmpty) {
        widgets.add(
          _DraftPreviewImage(
            imageUrl: draft.tertiaryImageUrl,
            cacheBuster: _previewImageVersion.toString(),
            maxHeight: 240,
            surfaceColor: AppColors.surfaceOf(context),
            borderColor: AppColors.dividerOf(context),
            errorWidget: const SizedBox.shrink(),
          ),
        );
      }
      widgets.add(
        _previewContentCard(
          title: draft.localizedTertiaryTitle(_previewLanguage),
          body: draft.localizedTertiaryBody(_previewLanguage),
        ),
      );
      widgets.add(const SizedBox(height: 12));
    }
    if (widgets.isEmpty) return [_previewFallbackHero()];
    if (widgets.isNotEmpty && widgets.last is SizedBox) widgets.removeLast();
    return widgets;
  }
}

class _DraftPreviewImage extends StatefulWidget {
  final String imageUrl;
  final String? cacheBuster;
  final double maxHeight;
  final Color surfaceColor;
  final Color borderColor;
  final Widget errorWidget;

  const _DraftPreviewImage({
    required this.imageUrl,
    this.cacheBuster,
    required this.maxHeight,
    required this.surfaceColor,
    required this.borderColor,
    required this.errorWidget,
  });

  @override
  State<_DraftPreviewImage> createState() => _DraftPreviewImageState();
}

class _SyncedImageState {
  final List<FocusLandingBlock> blocks;
  final String heroImageUrl;
  final String secondaryImageUrl;

  const _SyncedImageState({
    required this.blocks,
    required this.heroImageUrl,
    required this.secondaryImageUrl,
  });
}

class _DraftPreviewImageState extends State<_DraftPreviewImage> {
  static const double _defaultAspectRatio = 16 / 9;
  static const double _minAspectRatio = 0.65;
  static const double _maxAspectRatio = 2.4;
  static const double _minHeight = 140;
  double? _aspectRatio;

  @override
  void initState() {
    super.initState();
    _resolveAspectRatio();
  }

  @override
  void didUpdateWidget(covariant _DraftPreviewImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.cacheBuster != widget.cacheBuster) {
      _aspectRatio = null;
      _resolveAspectRatio();
    }
  }

  Future<void> _resolveAspectRatio() async {
    final provider = NetworkImage(
      OptimizedImage.resolveUrl(
        widget.imageUrl,
        cacheBuster: widget.cacheBuster,
      ),
    );
    final stream = provider.resolve(const ImageConfiguration());
    late ImageStreamListener listener;

    listener = ImageStreamListener(
      (ImageInfo image, bool _) {
        final width = image.image.width.toDouble();
        final height = image.image.height.toDouble();
        final ratio = height == 0 ? _defaultAspectRatio : width / height;
        final bounded = ratio.clamp(_minAspectRatio, _maxAspectRatio);
        if (mounted) {
          setState(() => _aspectRatio = bounded);
        }
        stream.removeListener(listener);
      },
      onError: (_, _) {
        if (mounted) {
          setState(() => _aspectRatio = _defaultAspectRatio);
        }
        stream.removeListener(listener);
      },
    );

    stream.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    final ratio = (_aspectRatio ?? _defaultAspectRatio).clamp(
      _minAspectRatio,
      _maxAspectRatio,
    );

    return Container(
      decoration: BoxDecoration(
        color: widget.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth =
                constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width - 32;
            final dynamicHeight = (availableWidth / ratio).clamp(
              _minHeight,
              widget.maxHeight,
            );

            return SizedBox(
              height: dynamicHeight,
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: OptimizedImage(
                  imageUrl: widget.imageUrl,
                  cacheBuster: widget.cacheBuster,
                  fit: BoxFit.contain,
                  width: availableWidth,
                  height: dynamicHeight,
                  errorWidget: widget.errorWidget,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
