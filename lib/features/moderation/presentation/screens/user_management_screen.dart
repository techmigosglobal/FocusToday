import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/language_service.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../core/services/feedback_service.dart';
import '../../../../core/services/user_sync_service.dart';
import '../../../../core/utils/debouncer.dart';
import '../../data/repositories/user_repository.dart';

/// User Management Screen
/// Allows SuperAdmin to view all users, filter by role, search, and change roles.
/// Admin can also access this screen but can only assign reporter/publicUser roles.
class UserManagementScreen extends StatefulWidget {
  final User currentUser;

  const UserManagementScreen({super.key, required this.currentUser});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  final UserRepository _userRepo = UserRepository();
  late TabController _tabController;
  final Debouncer _searchDebouncer = Debouncer();

  List<User> _allUsers = [];
  List<User> _filteredUsers = [];
  bool _isLoading = true;
  int _totalUsers = 0;
  String? _activeRoleFilter;
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<UserSyncEvent>? _userSyncSubscription;
  Timer? _userRefreshDebounce;

  AppLocalizations get _l => AppLocalizations(
    AppLanguage.fromCode(widget.currentUser.preferredLanguage),
  );

  bool get _isSuperAdmin => widget.currentUser.role == UserRole.superAdmin;

  // Tab filter mapping — super admin users are hidden from UI as requested.
  List<String?> get _tabRoles => _isSuperAdmin
      ? [null, 'admin', 'reporter', 'publicUser']
      : [null, 'reporter', 'publicUser'];
  List<String> get _tabLabels => _isSuperAdmin
      ? [_l.all, _l.admin, _l.reporter, _l.publicUsers]
      : [_l.all, _l.reporter, _l.publicUsers];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _listenToUserSync();
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _userSyncSubscription?.cancel();
    _userRefreshDebounce?.cancel();
    _searchController.dispose();
    _searchDebouncer.dispose();
    super.dispose();
  }

  void _listenToUserSync() {
    _userSyncSubscription = UserSyncService.stream.listen((_) {
      if (!mounted) return;
      _userRefreshDebounce?.cancel();
      _userRefreshDebounce = Timer(const Duration(milliseconds: 250), () {
        if (mounted) _loadUsers();
      });
    });
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _activeRoleFilter = _tabRoles[_tabController.index];
    _searchController.clear();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final result = await _userRepo.getAllUsers(
        page: 1,
        limit: 50,
        role: _activeRoleFilter,
      );
      if (mounted) {
        setState(() {
          final visibleUsers = (result['users'] as List<User>)
              .where((u) => u.role != UserRole.superAdmin)
              .toList();
          _allUsers = visibleUsers;
          _filteredUsers = List.from(_allUsers);
          _totalUsers = visibleUsers.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${_l.failedToLoadUsers}: $e')));
      }
    }
  }

  void _filterBySearch(String query) {
    if (query.isEmpty) {
      setState(() => _filteredUsers = List.from(_allUsers));
      return;
    }
    final lower = query.toLowerCase();
    setState(() {
      _filteredUsers = _allUsers.where((u) {
        return u.displayName.toLowerCase().contains(lower) ||
            (u.email?.toLowerCase().contains(lower) ?? false) ||
            u.phoneNumber.contains(lower) ||
            u.id.toLowerCase().contains(lower);
      }).toList();
    });
  }

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  String _last10Digits(String value) {
    final digits = _digitsOnly(value);
    if (digits.length <= 10) return digits;
    return digits.substring(digits.length - 10);
  }

  User? _findExistingUserByPhone(List<User> users, String inputPhone) {
    final target = _last10Digits(inputPhone);
    if (target.isEmpty) return null;

    for (final user in users) {
      if (_last10Digits(user.phoneNumber) == target) {
        return user;
      }
    }
    return null;
  }

  Future<void> _refreshAfterUserMutation(UserRole targetRole) async {
    final targetRoleFilter = targetRole.toApiString();
    final shouldSwitchTab =
        _activeRoleFilter != null && _activeRoleFilter != targetRoleFilter;

    if (shouldSwitchTab) {
      final targetIndex = _tabRoles.indexOf(targetRoleFilter);
      if (targetIndex >= 0 && targetIndex != _tabController.index) {
        _tabController.animateTo(targetIndex);
        return;
      }
    }

    await _loadUsers();
  }

  bool _canDeleteUser(User user) {
    if (user.id == widget.currentUser.id) return false;
    if (user.role == UserRole.superAdmin) return false;

    if (_isSuperAdmin) return true;

    return user.role == UserRole.reporter || user.role == UserRole.publicUser;
  }

  Future<void> _deleteUser(User user) async {
    if (!_canDeleteUser(user)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_l.deleteUserTitle),
        content: Text(_l.deleteUserPrompt(user.displayName, user.phoneNumber)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructiveBgOf(context),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(_l.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    FeedbackService.warning();
    final success = await _userRepo.deleteUser(user.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? _l.userDeletedSuccessfully(user.displayName)
              : _l.failedToDeleteUser,
        ),
        backgroundColor: success
            ? AppColors.successOf(context)
            : AppColors.errorOf(context),
      ),
    );

    if (success) {
      await _loadUsers();
    }
  }

  Future<void> _changeUserRole(User user) async {
    UserRole? selectedRole = user.role;
    final isSuperAdmin = widget.currentUser.role == UserRole.superAdmin;

    // Admins can only assign reporter or publicUser roles
    final allowedRoles = isSuperAdmin
        ? [UserRole.admin, UserRole.reporter, UserRole.publicUser]
        : [UserRole.reporter, UserRole.publicUser];

    // Admins cannot change superAdmin or admin users
    if (!isSuperAdmin &&
        (user.role == UserRole.superAdmin || user.role == UserRole.admin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l.onlySuperAdminsCanChangeAdminRoles)),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_l.changeRole),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.email ?? _l.noEmail,
                style: TextStyle(
                  color: AppColors.textSecondaryOf(context),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _l.selectNewRole,
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              RadioGroup<UserRole>(
                groupValue: selectedRole,
                onChanged: (v) => setDialogState(() => selectedRole = v),
                child: Column(
                  children: allowedRoles
                      .map(
                        (role) => RadioListTile<UserRole>(
                          title: Text(_roleDisplayName(role)),
                          subtitle: Text(
                            _roleDescription(role),
                            style: const TextStyle(fontSize: 12),
                          ),
                          value: role,
                          dense: true,
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_l.cancel),
            ),
            FilledButton(
              onPressed: selectedRole == user.role
                  ? null
                  : () => Navigator.pop(context, true),
              child: Text(_l.updateRole),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true &&
        selectedRole != null &&
        selectedRole != user.role) {
      FeedbackService.success();
      final success = await _userRepo.updateUserRole(user.id, selectedRole!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? _l.userRoleUpdated(
                      user.displayName,
                      _roleDisplayName(selectedRole!),
                    )
                  : _l.failedToUpdateRole,
            ),
            backgroundColor: success ? AppColors.secondary : AppColors.error,
          ),
        );
        if (success) {
          await _refreshAfterUserMutation(selectedRole!);
        }
      }
    }
  }

  String _roleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return _l.superAdminsLabel;
      case UserRole.admin:
        return _l.admin;
      case UserRole.reporter:
        return _l.reporter;
      case UserRole.publicUser:
        return _l.publicUser;
    }
  }

  String _roleDescription(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return _l.fullSystemAccessUserManagement;
      case UserRole.admin:
        return _l.contentModerationPostManagement;
      case UserRole.reporter:
        return _l.createAndPublishContent;
      case UserRole.publicUser:
        return _l.viewCommentInteract;
    }
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return AppColors.infoOf(context);
      case UserRole.admin:
        return AppColors.accent;
      case UserRole.reporter:
        return AppColors.primary;
      case UserRole.publicUser:
        return AppColors.secondary;
    }
  }

  IconData _roleIcon(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return Icons.shield;
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.reporter:
        return Icons.edit_note;
      case UserRole.publicUser:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: Text(_l.userManagement),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimaryOf(context),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (query) =>
                      _searchDebouncer.run(() => _filterBySearch(query)),
                  style: TextStyle(color: AppColors.onPrimaryOf(context)),
                  decoration: InputDecoration(
                    hintText: _l.searchUsersPlaceholder,
                    hintStyle: TextStyle(
                      color: AppColors.onPrimaryOf(
                        context,
                      ).withValues(alpha: 0.6),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppColors.onPrimaryOf(
                        context,
                      ).withValues(alpha: 0.7),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: AppColors.onPrimaryOf(
                                context,
                              ).withValues(alpha: 0.7),
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _filterBySearch('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.onPrimaryOf(
                      context,
                    ).withValues(alpha: 0.15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              // Tab bar
              TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: AppColors.onPrimaryOf(context),
                labelColor: AppColors.onPrimaryOf(context),
                unselectedLabelColor: AppColors.onPrimaryOf(
                  context,
                ).withValues(alpha: 0.65),
                tabAlignment: TabAlignment.start,
                tabs: _tabLabels.map((label) => Tab(text: label)).toList(),
              ),
            ],
          ),
        ),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.onPrimaryOf(context).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _l.totalUsersCount(_totalUsers),
                style: TextStyle(
                  color: AppColors.onPrimaryOf(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadUsers,
                child: _filteredUsers.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) =>
                            _buildUserCard(_filteredUsers[index]),
                      ),
              ),
      ),
      // SuperAdmin can add admins/reporters; Admin can add reporters
      floatingActionButton:
          (widget.currentUser.role == UserRole.superAdmin ||
              widget.currentUser.role == UserRole.admin)
          ? FloatingActionButton.extended(
              onPressed: _showAddUserDialog,
              icon: const Icon(Icons.person_add),
              label: Text(_isSuperAdmin ? _l.addUser : _l.addReporter),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimaryOf(context),
            )
          : null,
    );
  }

  /// Add User dialog — SuperAdmin can add admin/reporter, Admin can add reporter
  Future<void> _showAddUserDialog() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    UserRole selectedRole = UserRole.reporter;

    // SuperAdmin can pick admin or reporter; Admin can only pick reporter
    final allowedRoles = _isSuperAdmin
        ? [UserRole.admin, UserRole.reporter]
        : [UserRole.reporter];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.person_add, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(_isSuperAdmin ? _l.addUser : _l.addReporter),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Phone number (required — primary identifier)
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: InputDecoration(
                      labelText: _l.phoneNumberRequiredLabel,
                      hintText: _l.tenDigitMobileNumber,
                      prefixIcon: const Icon(Icons.phone_outlined),
                      prefixText: '+91 ',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return _l.phoneNumberRequired;
                      }
                      if (v.trim().length < 10) {
                        return _l.enterValidTenDigitNumber;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: _l.fullNameRequiredLabel,
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? _l.nameIsRequired
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: _l.emailOptionalLabel,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                  ),
                  // Role selector — only shown for SuperAdmin with multiple choices
                  if (allowedRoles.length > 1) ...[
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _l.assignRole,
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(height: 4),
                    RadioGroup<UserRole>(
                      groupValue: selectedRole,
                      onChanged: (v) => setDialogState(() => selectedRole = v!),
                      child: Column(
                        children: allowedRoles
                            .map(
                              (role) => RadioListTile<UserRole>(
                                title: Text(_roleDisplayName(role)),
                                subtitle: Text(
                                  _roleDescription(role),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                value: role,
                                dense: true,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_l.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: Text(_l.addRole(_roleDisplayName(selectedRole))),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      HapticFeedback.mediumImpact();
      final phone = phoneCtrl.text.trim();
      try {
        // Check if user already exists with this phone number
        final existingUsers = await _userRepo.searchUsers(phone);
        final existingUser = _findExistingUserByPhone(existingUsers, phone);

        if (existingUser != null) {
          // User exists — update their role
          final success = await _userRepo.updateUserRole(
            existingUser.id,
            selectedRole,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  success
                      ? _l.updatedToRoleForExistingUser(
                          existingUser.displayName,
                          phone,
                          _roleDisplayName(selectedRole),
                        )
                      : _l.failedToUpdateExistingUserRole,
                ),
                backgroundColor: success
                    ? AppColors.successOf(context)
                    : AppColors.errorOf(context),
              ),
            );
            if (success) {
              await _refreshAfterUserMutation(selectedRole);
            }
          }
        } else {
          // Create new user with assigned role — use phone-based ID for
          // consistency with the login flow (phone_XXXXXXXXXX).
          final normalizedPhone = _digitsOnly(phone);
          final userId = 'phone_${_last10Digits(normalizedPhone)}';
          final createdUser = await _userRepo.createUser(
            id: userId,
            displayName: nameCtrl.text.trim(),
            email: emailCtrl.text.trim().isNotEmpty
                ? emailCtrl.text.trim()
                : null,
            phoneNumber: phone,
            role: selectedRole,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  createdUser != null
                      ? _l.userAddedAsRole(
                          nameCtrl.text.trim(),
                          phone,
                          _roleDisplayName(selectedRole),
                        )
                      : _l.failedToAddUser,
                ),
                backgroundColor: createdUser != null
                    ? AppColors.successOf(context)
                    : AppColors.errorOf(context),
              ),
            );
            if (createdUser != null) {
              await _refreshAfterUserMutation(selectedRole);
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_l.failedToAddUser}: $e'),
              backgroundColor: AppColors.errorOf(context),
            ),
          );
        }
      }
    }

    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
  }

  Widget _buildEmptyState() {
    return EmptyStateWidget(
      icon: Icons.people_outline,
      title: _searchController.text.isNotEmpty
          ? _l.noUsersMatchSearch
          : _l.noUsersFound,
      subtitle: _searchController.text.isNotEmpty
          ? _l.tryDifferentSearchKeywords
          : _l.usersWillAppearOnceRegistered,
    );
  }

  Widget _buildUserCard(User user) {
    final isSelf = user.id == widget.currentUser.id;
    final roleColor = _roleColor(user.role);
    final secondaryText = AppColors.textSecondaryOf(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelf
            ? BorderSide(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 2,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isSelf ? null : () => _showUserDetails(user),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: roleColor.withValues(alpha: 0.15),
                backgroundImage:
                    user.profilePicture != null &&
                        user.profilePicture!.isNotEmpty
                    ? NetworkImage(user.profilePicture!)
                    : null,
                child:
                    user.profilePicture == null || user.profilePicture!.isEmpty
                    ? Icon(_roleIcon(user.role), color: roleColor, size: 24)
                    : null,
              ),
              const SizedBox(width: 14),

              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelf) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'You',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email ?? user.phoneNumber,
                      style: TextStyle(fontSize: 12, color: secondaryText),
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Show location for reporters and public users
                    if ((user.role == UserRole.reporter ||
                            user.role == UserRole.publicUser) &&
                        (user.area != null || user.district != null))
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 12,
                              color: secondaryText.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                [user.area, user.district, user.state]
                                    .where((s) => s != null && s.isNotEmpty)
                                    .join(', '),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: secondaryText.withValues(alpha: 0.85),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Role badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_roleIcon(user.role), size: 14, color: roleColor),
                    const SizedBox(width: 4),
                    Text(
                      _roleDisplayName(user.role),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: roleColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Edit icon (not for self)
              if (!isSelf) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: secondaryText.withValues(alpha: 0.65),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Show user details bottom sheet (with location info for admin/superAdmin)
  Future<void> _showUserDetails(User user) async {
    final fullUser = await _userRepo.getUserById(user.id);
    if (!mounted) return;
    final detailUser = fullUser ?? user;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final roleColor = _roleColor(detailUser.role);
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondaryOf(
                    context,
                  ).withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Avatar and name
              CircleAvatar(
                radius: 36,
                backgroundColor: roleColor.withValues(alpha: 0.15),
                backgroundImage:
                    detailUser.profilePicture != null &&
                        detailUser.profilePicture!.isNotEmpty
                    ? NetworkImage(detailUser.profilePicture!)
                    : null,
                child:
                    detailUser.profilePicture == null ||
                        detailUser.profilePicture!.isEmpty
                    ? Icon(
                        _roleIcon(detailUser.role),
                        color: roleColor,
                        size: 30,
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                detailUser.displayName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _roleDisplayName(detailUser.role),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: roleColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Details list
              _buildDetailRow(
                Icons.email,
                _l.email,
                detailUser.email ?? _l.notSet,
              ),
              _buildDetailRow(
                Icons.phone,
                _l.phoneNumber,
                detailUser.phoneNumber.isNotEmpty
                    ? detailUser.phoneNumber
                    : _l.notSet,
              ),
              _buildDetailRow(
                Icons.location_on,
                _l.area,
                (detailUser.area != null && detailUser.area!.isNotEmpty)
                    ? detailUser.area!
                    : _l.notSet,
              ),
              _buildDetailRow(
                Icons.map,
                _l.district,
                (detailUser.district != null && detailUser.district!.isNotEmpty)
                    ? detailUser.district!
                    : _l.notSet,
              ),
              _buildDetailRow(
                Icons.flag,
                _l.stateLabel,
                (detailUser.state != null && detailUser.state!.isNotEmpty)
                    ? detailUser.state!
                    : _l.notSet,
              ),
              _buildDetailRow(
                Icons.calendar_today,
                _l.joined,
                _formatDate(detailUser.createdAt),
              ),

              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _changeUserRole(detailUser);
                      },
                      child: Text(_l.changeRole),
                    ),
                  ),
                  if (_canDeleteUser(detailUser)) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.destructiveBgOf(context),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _deleteUser(detailUser);
                        },
                        child: Text(_l.deleteUserTitle),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final d = date.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    final secondaryText = AppColors.textSecondaryOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: secondaryText),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: secondaryText),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
