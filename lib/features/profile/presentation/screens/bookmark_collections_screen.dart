import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/models/post.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/widgets/page_transitions.dart';
import '../../../../shared/widgets/slice_surface.dart';
import '../../../feed/presentation/screens/post_detail_screen.dart';
import '../../../../core/services/language_service.dart';
import '../../../../main.dart';
import '../../data/repositories/bookmark_collection_repository.dart';
import '../../../feed/data/repositories/post_repository.dart';

/// GAP-006: Screen that displays a user's named bookmark collections.
/// Supports creating, renaming, and deleting collections.
class BookmarkCollectionsScreen extends StatefulWidget {
  final User currentUser;

  const BookmarkCollectionsScreen({super.key, required this.currentUser});

  @override
  State<BookmarkCollectionsScreen> createState() =>
      _BookmarkCollectionsScreenState();
}

class _BookmarkCollectionsScreenState extends State<BookmarkCollectionsScreen> {
  final BookmarkCollectionRepository _repo = BookmarkCollectionRepository();
  List<BookmarkCollection> _collections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final result = await _repo.getCollections(widget.currentUser.id);
    if (!mounted) return;
    setState(() {
      _collections = result;
      _isLoading = false;
    });
  }

  Future<void> _createCollection() async {
    final name = await _showNameDialog();
    if (name == null || name.isEmpty) return;
    await _repo.createCollection(widget.currentUser.id, name: name);
    HapticFeedback.mediumImpact();
    _loadCollections();
  }

  Future<void> _renameCollection(BookmarkCollection coll) async {
    final name = await _showNameDialog(initial: coll.name);
    if (name == null || name.isEmpty) return;
    await _repo.renameCollection(widget.currentUser.id, coll.id, name: name);
    _loadCollections();
  }

  Future<void> _deleteCollection(BookmarkCollection coll) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Collection'),
        content: Text(
          'Delete "${coll.name}" and all ${coll.itemCount} saved post(s)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.destructiveBgOf(context),
            ),
            child: Text(
              'Delete',
              style: TextStyle(color: AppColors.onPrimaryOf(context)),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.deleteCollection(widget.currentUser.id, coll.id);
    HapticFeedback.mediumImpact();
    _loadCollections();
  }

  Future<String?> _showNameDialog({String? initial}) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(initial != null ? 'Rename Collection' : 'New Collection'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 40,
          decoration: InputDecoration(
            labelText: 'Collection name',
            filled: true,
            fillColor: AppColors.surfaceTier2Of(context),
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: const Text('Bookmark Collections'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimaryOf(context),
        actions: [
          IconButton(
            onPressed: _createCollection,
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New Collection',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _collections.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
              onRefresh: _loadCollections,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _collections.length,
                itemBuilder: (ctx, i) => _buildCollectionTile(_collections[i]),
              ),
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bookmark_border_rounded,
            size: 64,
            color: AppColors.textSecondaryOf(context).withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Collections Yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Create collections to organise your saved posts.',
            style: TextStyle(color: AppColors.textSecondaryOf(context)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _createCollection,
            icon: const Icon(Icons.add),
            label: const Text('Create Collection'),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionTile(BookmarkCollection coll) {
    return SliceCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.bookmark_rounded, color: AppColors.primary),
        ),
        title: Text(
          coll.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text('${coll.itemCount} saved'),
        onTap: () => Navigator.push(
          context,
          SmoothPageRoute(
            builder: (_) => _CollectionItemsScreen(
              collection: coll,
              currentUser: widget.currentUser,
              repo: _repo,
            ),
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (val) {
            if (val == 'rename') _renameCollection(coll);
            if (val == 'delete') _deleteCollection(coll);
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'rename', child: Text('Rename')),
            PopupMenuItem(
              value: 'delete',
              child: Text(
                'Delete',
                style: TextStyle(color: AppColors.destructiveFgOf(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Items view for a single collection
// ─────────────────────────────────────────────────────────────────────────────

class _CollectionItemsScreen extends StatefulWidget {
  final BookmarkCollection collection;
  final User currentUser;
  final BookmarkCollectionRepository repo;

  const _CollectionItemsScreen({
    required this.collection,
    required this.currentUser,
    required this.repo,
  });

  @override
  State<_CollectionItemsScreen> createState() => _CollectionItemsScreenState();
}

class _CollectionItemsScreenState extends State<_CollectionItemsScreen> {
  final PostRepository _postRepo = PostRepository();
  List<Post> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final postIds = await widget.repo.getPostIdsInCollection(
      widget.currentUser.id,
      widget.collection.id,
    );
    final posts = <Post>[];
    for (final id in postIds) {
      final p = await _postRepo.getPostById(id);
      if (p != null) posts.add(p);
    }
    if (mounted) {
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: Text(widget.collection.name),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimaryOf(context),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty
          ? const Center(child: Text('No posts in this collection.'))
          : RefreshIndicator(
              onRefresh: _loadItems,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _posts.length,
                itemBuilder: (ctx, i) => _buildItem(_posts[i]),
              ),
            ),
    );
  }

  Widget _buildItem(Post post) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        title: Text(
          post.caption.length > 80
              ? '${post.caption.substring(0, 80)}...'
              : post.caption,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(post.authorName),
        trailing: IconButton(
          icon: Icon(
            Icons.bookmark_remove_rounded,
            color: AppColors.destructiveFgOf(context),
          ),
          onPressed: () async {
            await widget.repo.removeFromCollection(
              widget.currentUser.id,
              widget.collection.id,
              post.id,
            );
            setState(() => _posts.remove(post));
          },
        ),
        onTap: () async {
          final ls =
              FocusTodayApp.languageService ?? await LanguageService.init();
          FocusTodayApp.languageService ??= ls;
          if (!mounted) return;
          Navigator.push(
            context,
            SmoothPageRoute(
              builder: (_) => PostDetailScreen(
                post: post,
                currentUser: widget.currentUser,
                currentLanguage: ls.currentLanguage,
              ),
            ),
          );
        },
      ),
    );
  }
}
