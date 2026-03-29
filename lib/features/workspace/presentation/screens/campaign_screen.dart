import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/cloud_functions_service.dart';
import '../../../../core/services/language_service.dart';

class CampaignScreen extends StatefulWidget {
  final AppLanguage currentLanguage;

  const CampaignScreen({super.key, required this.currentLanguage});

  @override
  State<CampaignScreen> createState() => _CampaignScreenState();
}

class _CampaignScreenState extends State<CampaignScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  String _targetType = 'all'; // 'all' | 'role' | 'topic'
  String _targetValue = 'new_content';

  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _sendCampaign() async {
    final l = AppLocalizations(widget.currentLanguage);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);

    try {
      final callable = CloudFunctionsService.instance.httpsCallable(
        'sendMessageCampaign',
      );
      final result = await callable.call({
        'title': _titleController.text.trim(),
        'body': _bodyController.text.trim(),
        'targeting': {
          'type': _targetType,
          'value': _targetType == 'all' ? null : _targetValue,
        },
      });

      if (!mounted) return;

      final data = Map<String, dynamic>.from(result.data as Map);
      if (data['ok'] == true || data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.campaignSentSuccessfully),
            backgroundColor: AppColors.successOf(context),
          ),
        );
        _titleController.clear();
        _bodyController.clear();
      } else {
        throw Exception(result.data['error'] ?? l.failedToSendCampaign);
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l.errorLabel}: ${_mapCampaignError(e, l)}'),
          backgroundColor: AppColors.errorOf(context),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l.errorLabel}: $e'),
          backgroundColor: AppColors.errorOf(context),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _mapCampaignError(FirebaseFunctionsException e, AppLocalizations l) {
    switch (e.code) {
      case 'permission-denied':
        return 'Only admins can send campaigns.';
      case 'invalid-argument':
        return e.message ?? 'Please check campaign fields and targeting.';
      case 'unauthenticated':
        return 'Session expired. Please log in again.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Service is temporarily unavailable. Please try again.';
      default:
        return e.message ?? l.failedToSendCampaign;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations(widget.currentLanguage);
    return Scaffold(
      appBar: AppBar(title: Text(l.fcmCampaigns), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.sendCustomPushToSegments,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: l.notificationTitle,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? l.requiredField : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bodyController,
                decoration: InputDecoration(
                  labelText: l.notificationBody,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.message),
                ),
                maxLines: 4,
                validator: (val) =>
                    val == null || val.trim().isEmpty ? l.requiredField : null,
              ),
              const SizedBox(height: 24),
              Text(
                l.targetAudience,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      // ignore: deprecated_member_use
                      title: Text(l.byTopic),
                      value: 'topic',
                      // ignore: deprecated_member_use
                      groupValue: _targetType,
                      // ignore: deprecated_member_use
                      onChanged: (val) {
                        setState(() {
                          _targetType = val!;
                          _targetValue = 'new_content';
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      // ignore: deprecated_member_use
                      title: Text(l.byRole),
                      value: 'role',
                      // ignore: deprecated_member_use
                      groupValue: _targetType,
                      // ignore: deprecated_member_use
                      onChanged: (val) {
                        setState(() {
                          _targetType = val!;
                          _targetValue = 'public_user';
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              RadioListTile<String>(
                title: Text(l.allUsers),
                value: 'all',
                // ignore: deprecated_member_use
                groupValue: _targetType,
                // ignore: deprecated_member_use
                onChanged: (val) {
                  if (val == null) return;
                  setState(() {
                    _targetType = val;
                    _targetValue = 'new_content';
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              if (_targetType == 'topic')
                DropdownButtonFormField<String>(
                  initialValue: _targetValue,
                  decoration: InputDecoration(
                    labelText: l.selectTopic,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'new_content',
                      child: Text(l.allUsers),
                    ),
                    DropdownMenuItem(
                      value: 'breaking_news',
                      child: Text(l.breakingNewsSubscribers),
                    ),
                  ],
                  onChanged: (val) => setState(() => _targetValue = val!),
                )
              else if (_targetType == 'role')
                DropdownButtonFormField<String>(
                  initialValue: _targetValue,
                  decoration: InputDecoration(
                    labelText: l.selectRole,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'public_user',
                      child: Text(l.publicUsersLabel),
                    ),
                    DropdownMenuItem(
                      value: 'reporter',
                      child: Text(l.reportersLabel),
                    ),
                    DropdownMenuItem(
                      value: 'admin',
                      child: Text(l.adminsLabel),
                    ),
                    DropdownMenuItem(
                      value: 'super_admin',
                      child: Text(l.superAdminsLabel),
                    ),
                  ],
                  onChanged: (val) => setState(() => _targetValue = val!),
                )
              else
                const SizedBox.shrink(),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSending ? null : _sendCampaign,
                  icon: _isSending
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: AppColors.onPrimaryOf(context),
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(_isSending ? l.sending : l.sendCampaign),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimaryOf(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
