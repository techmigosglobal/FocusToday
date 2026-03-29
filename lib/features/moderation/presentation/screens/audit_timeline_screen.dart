import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/services/firestore_service.dart';

class AuditTimelineScreen extends StatefulWidget {
  /// Optional: filter audit logs by specific post ID
  final String? postId;

  const AuditTimelineScreen({super.key, this.postId});

  @override
  State<AuditTimelineScreen> createState() => _AuditTimelineScreenState();
}

class _AuditTimelineScreenState extends State<AuditTimelineScreen> {
  static const int _pageSize = 40;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _items = const [];
  final Map<String, String> _actorNameById = {};
  QueryDocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  String _eventFilter = 'all';
  String _entityFilter = 'all';
  final Set<String> _expandedIds = <String>{};
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _fetchPage(reset: true);
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore) return;
    final position = _scrollController.position;
    final triggerOffset = position.maxScrollExtent - 320;
    if (position.pixels >= triggerOffset) {
      _fetchPage(reset: false);
    }
  }

  Future<void> _fetchPage({required bool reset}) async {
    if (_isLoadingMore || (_isLoading && !reset)) return;
    if (!reset && !_hasMore) return;

    if (!mounted) return;
    setState(() {
      if (reset) {
        _isLoading = true;
        _errorMessage = null;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      Query<Map<String, dynamic>> query = FirestoreService.auditLogs;
      if (widget.postId != null) {
        query = query.where('post_id', isEqualTo: widget.postId);
      }
      if (_eventFilter != 'all') {
        query = query.where('event_type', isEqualTo: _eventFilter);
      }
      if (_entityFilter != 'all') {
        query = query.where('entity_type', isEqualTo: _entityFilter);
      }
      query = query.orderBy('created_at', descending: true).limit(_pageSize);
      if (!reset && _lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }
      final snapshot = await query.get();
      final nextRows = snapshot.docs
          .map((d) => _normalizeAuditDoc(d.id, d.data()))
          .toList(growable: false);
      await _hydrateActorNames(nextRows);
      if (!mounted) return;
      setState(() {
        _items = reset ? nextRows : [..._items, ...nextRows];
        _lastDoc = snapshot.docs.isEmpty ? _lastDoc : snapshot.docs.last;
        _hasMore = snapshot.docs.length == _pageSize;
        if (reset) _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (reset) {
          _items = const [];
        }
        _hasMore = false;
        _errorMessage =
            'Unable to load audit logs right now. Pull to retry.\n$error';
      });
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Map<String, dynamic> _normalizeAuditDoc(String id, Map<String, dynamic> raw) {
    final item = <String, dynamic>{'id': id, ...raw};
    item['event_type'] =
        item['event_type'] ?? item['type'] ?? item['action'] ?? 'event';
    item['entity_type'] =
        item['entity_type'] ??
        (item['post_id'] != null
            ? 'post'
            : item['target_user_id'] != null
            ? 'user'
            : 'system');
    item['entity_id'] =
        item['entity_id'] ??
        item['post_id'] ??
        item['target_user_id'] ??
        item['id'];
    item['summary'] = (item['summary'] ?? '').toString().trim().isNotEmpty
        ? item['summary']
        : _legacySummary(item);
    item['metadata'] = item['metadata'] ?? _legacyMetadata(item);
    return item;
  }

  Map<String, dynamic> _legacyMetadata(Map<String, dynamic> item) {
    final map = <String, dynamic>{...item};
    map.remove('id');
    map.remove('event_type');
    map.remove('entity_type');
    map.remove('entity_id');
    map.remove('summary');
    map.remove('before');
    map.remove('after');
    map.remove('created_at');
    return map;
  }

  String _legacySummary(Map<String, dynamic> item) {
    final eventType = (item['event_type'] ?? '').toString();
    if (eventType == 'post_moderated') {
      final status = (item['status'] ?? item['metadata']?['status'] ?? '')
          .toString();
      return status.isEmpty ? 'Post moderated' : 'Post moderated: $status';
    }
    if (eventType == 'role_changed') {
      final role = (item['new_role'] ?? item['metadata']?['new_role'] ?? '')
          .toString();
      return role.isEmpty ? 'Role changed' : 'Role changed to $role';
    }
    if (eventType == 'user_created') {
      return 'User created';
    }
    if (eventType == 'post_deleted') {
      return 'Post deleted';
    }
    return eventType.isEmpty ? 'Event recorded' : eventType;
  }

  String _eventDisplayName(String raw) {
    if (raw.trim().isEmpty || raw == 'all') return 'All events';
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              part.substring(0, 1).toUpperCase() +
              part.substring(1).toLowerCase(),
        )
        .join(' ');
  }

  String _entityDisplayName(String raw) {
    if (raw.trim().isEmpty || raw == 'all') return 'All entities';
    return raw.substring(0, 1).toUpperCase() + raw.substring(1).toLowerCase();
  }

  ({IconData icon, Color color}) _eventStyle(String eventType) {
    switch (eventType) {
      case 'post_moderated':
        return (icon: Icons.gavel_rounded, color: Colors.orange.shade700);
      case 'post_deleted':
        return (icon: Icons.delete_sweep_rounded, color: Colors.red.shade600);
      case 'user_created':
        return (
          icon: Icons.person_add_alt_1_rounded,
          color: Colors.green.shade700,
        );
      case 'role_changed':
        return (
          icon: Icons.admin_panel_settings_rounded,
          color: Colors.indigo.shade500,
        );
      default:
        return (icon: Icons.history_rounded, color: Colors.blueGrey.shade500);
    }
  }

  String _formatDate(DateTime createdAt) {
    return DateFormat('dd MMM, hh:mm a').format(createdAt);
  }

  String _compactCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(count >= 10000 ? 0 : 1)}K';
    }
    return '$count';
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
    );
  }

  Future<void> _hydrateActorNames(List<Map<String, dynamic>> source) async {
    final actorIds = source
        .map(
          (item) => (item['actor_id'] ?? item['performed_by'] ?? '')
              .toString()
              .trim(),
        )
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (actorIds.isEmpty) return;

    for (final actorId in actorIds) {
      if (_actorNameById.containsKey(actorId)) continue;
      try {
        final userDoc = await FirestoreService.users.doc(actorId).get();
        final name = (userDoc.data()?['display_name'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          _actorNameById[actorId] = name;
        }
      } catch (_) {
        // Keep fallback value.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations(
      AppLanguage.fromCode(Localizations.localeOf(context).languageCode),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l.auditTimeline),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(
                children: [
                  _buildSummaryHeader(),
                  _buildFilters(context),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
                      child: Material(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onErrorContainer,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: _items.isEmpty
                        ? ListView(
                            controller: _scrollController,
                            children: [
                              SizedBox(height: 180),
                              Center(
                                child: Text(
                                  _errorMessage == null
                                      ? l.noAuditLogsYet
                                      : 'No logs available right now',
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            itemCount: _items.length + (_isLoadingMore ? 1 : 0),
                            itemBuilder: (_, index) {
                              if (index >= _items.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              final item = _items[index];
                              final id = item['id'].toString();
                              final type = (item['event_type'] ?? 'event')
                                  .toString();
                              final entityType =
                                  (item['entity_type'] ?? 'system').toString();
                              final entityId = (item['entity_id'] ?? '-')
                                  .toString();
                              final summary = (item['summary'] ?? type)
                                  .toString();
                              final metadata = (item['metadata'] is Map)
                                  ? Map<String, dynamic>.from(
                                      item['metadata'] as Map,
                                    )
                                  : const <String, dynamic>{};
                              final actor =
                                  (item['actor_id'] ??
                                          item['performed_by'] ??
                                          item['reviewed_by'] ??
                                          '-')
                                      .toString();
                              final actorLabel = _actorNameById[actor] ?? actor;
                              final created = FirestoreService.toDateTime(
                                item['created_at'],
                              );
                              final eventStyle = _eventStyle(type);
                              return Card(
                                margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                                child: ExpansionTile(
                                  key: ValueKey(id),
                                  initiallyExpanded: _expandedIds.contains(id),
                                  tilePadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 2,
                                  ),
                                  childrenPadding: const EdgeInsets.fromLTRB(
                                    12,
                                    0,
                                    12,
                                    12,
                                  ),
                                  onExpansionChanged: (expanded) {
                                    setState(() {
                                      if (expanded) {
                                        _expandedIds.add(id);
                                      } else {
                                        _expandedIds.remove(id);
                                      }
                                    });
                                  },
                                  leading: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: eventStyle.color
                                        .withValues(alpha: 0.12),
                                    child: Icon(
                                      eventStyle.icon,
                                      color: eventStyle.color,
                                      size: 18,
                                    ),
                                  ),
                                  title: Text(
                                    summary,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${l.actorLabel(actorLabel)} • ${_entityDisplayName(entityType)}: $entityId',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Text(
                                    _formatDate(created),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  children: [
                                    if (metadata.isNotEmpty)
                                      Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest
                                              .withValues(alpha: 0.35),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        padding: const EdgeInsets.all(10),
                                        child: SelectableText(
                                          metadata.entries
                                              .map(
                                                (e) => '${e.key}: ${e.value}',
                                              )
                                              .join('\n'),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      )
                                    else
                                      Text(
                                        'No metadata',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    final eventOptions = <String>{
      'all',
      ..._items
          .map((item) => (item['event_type'] ?? '').toString())
          .where((v) => v.isNotEmpty),
    }.toList(growable: false)..sort();
    final entityOptions = <String>{
      'all',
      ..._items
          .map((item) => (item['entity_type'] ?? '').toString())
          .where((v) => v.isNotEmpty),
    }.toList(growable: false)..sort();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _eventFilter,
              decoration: const InputDecoration(
                labelText: 'Event',
                isDense: true,
              ),
              items: eventOptions
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_eventDisplayName(value)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) async {
                if (value == null || value == _eventFilter) return;
                setState(() {
                  _eventFilter = value;
                  _lastDoc = null;
                  _hasMore = true;
                });
                await _fetchPage(reset: true);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _entityFilter,
              decoration: const InputDecoration(
                labelText: 'Entity',
                isDense: true,
              ),
              items: entityOptions
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_entityDisplayName(value)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) async {
                if (value == null || value == _entityFilter) return;
                setState(() {
                  _entityFilter = value;
                  _lastDoc = null;
                  _hasMore = true;
                });
                await _fetchPage(reset: true);
              },
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Reset filters',
            onPressed: (_eventFilter == 'all' && _entityFilter == 'all')
                ? null
                : () async {
                    setState(() {
                      _eventFilter = 'all';
                      _entityFilter = 'all';
                      _lastDoc = null;
                      _hasMore = true;
                    });
                    await _fetchPage(reset: true);
                  },
            icon: const Icon(Icons.filter_alt_off_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader() {
    final eventCount = _items
        .map((item) => (item['event_type'] ?? '').toString())
        .where((v) => v.isNotEmpty)
        .toSet()
        .length;
    final actorCount = _items
        .map(
          (item) => (item['actor_id'] ?? item['performed_by'] ?? '')
              .toString()
              .trim(),
        )
        .where((v) => v.isNotEmpty)
        .toSet()
        .length;

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildStatChip(
              icon: Icons.history_rounded,
              label: 'Logs',
              value: _compactCount(_items.length),
            ),
            _buildStatChip(
              icon: Icons.category_rounded,
              label: 'Events',
              value: _compactCount(eventCount),
            ),
            _buildStatChip(
              icon: Icons.person_rounded,
              label: 'Actors',
              value: _compactCount(actorCount),
            ),
            if (_hasMore)
              _buildStatChip(
                icon: Icons.sync_rounded,
                label: 'Feed',
                value: 'Live',
              ),
          ],
        ),
      ),
    );
  }
}
