import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/models/post.dart';
import '../../data/repositories/bookmark_collection_repository.dart';

/// Bottom-sheet that lets the user pick which named bookmark collection
/// to save (or unsave) a post into. Also lets them create a new collection inline.
Future<void> showSaveToCollectionSheet({
  required BuildContext context,
  required Post post,
  required String userId,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _SaveSheetBody(post: post, userId: userId),
  );
}

class _SaveSheetBody extends StatefulWidget {
  final Post post;
  final String userId;
  const _SaveSheetBody({required this.post, required this.userId});

  @override
  State<_SaveSheetBody> createState() => _SaveSheetBodyState();
}

class _SaveSheetBodyState extends State<_SaveSheetBody> {
  final BookmarkCollectionRepository _repo = BookmarkCollectionRepository();
  List<BookmarkCollection> _collections = [];
  final Set<String> _savedIn = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final colls = await _repo.getCollections(widget.userId);
    final checks = await Future.wait(
      colls.map(
        (c) => _repo.isPostInCollection(widget.userId, c.id, widget.post.id),
      ),
    );
    if (!mounted) return;
    setState(() {
      _collections = colls;
      for (int i = 0; i < colls.length; i++) {
        if (checks[i]) _savedIn.add(colls[i].id);
      }
      _loading = false;
    });
  }

  Future<void> _toggleCollection(BookmarkCollection coll) async {
    final alreadyIn = _savedIn.contains(coll.id);
    setState(() {
      if (alreadyIn) {
        _savedIn.remove(coll.id);
      } else {
        _savedIn.add(coll.id);
      }
    });
    if (alreadyIn) {
      await _repo.removeFromCollection(widget.userId, coll.id, widget.post.id);
    } else {
      await _repo.addToCollection(widget.userId, coll.id, widget.post);
    }
  }

  Future<void> _createAndAdd() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('New Collection'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 40,
          decoration: InputDecoration(
            labelText: 'Name',
            counterText: '',
            filled: true,
            fillColor: AppColors.surfaceTier2Of(context),
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
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final id = await _repo.createCollection(widget.userId, name: name);
    if (id != null) {
      await _repo.addToCollection(widget.userId, id, widget.post);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.dividerOf(context),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Save to Collection',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  onPressed: _createAndAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New'),
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_collections.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No collections yet — create one above!',
                  style: TextStyle(color: AppColors.textSecondaryOf(context)),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                itemCount: _collections.length,
                separatorBuilder: (_, _) => const SizedBox(height: 0),
                itemBuilder: (_, i) {
                  final c = _collections[i];
                  final saved = _savedIn.contains(c.id);
                  return ListTile(
                    leading: Icon(
                      saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: saved
                          ? AppColors.primary
                          : AppColors.textSecondaryOf(context),
                    ),
                    title: Text(c.name),
                    trailing: Text(
                      '${c.itemCount}',
                      style: TextStyle(color: AppColors.textMutedOf(context)),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () => _toggleCollection(c),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
