import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../shared/models/user.dart';

const List<String> _indianStates = [
  'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
  'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
  'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya',
  'Mizoram', 'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim',
  'Tamil Nadu', 'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand',
  'West Bengal', 'Andaman and Nicobar Islands', 'Chandigarh',
  'Dadra and Nagar Haveli and Daman and Diu', 'Delhi',
  'Jammu and Kashmir', 'Ladakh', 'Lakshadweep', 'Puducherry',
];

/// Apply as Reporter form screen (GAP-003) — shown to publicUser role
class ReporterApplicationScreen extends StatefulWidget {
  final User currentUser;

  const ReporterApplicationScreen({super.key, required this.currentUser});

  @override
  State<ReporterApplicationScreen> createState() => _ReporterApplicationScreenState();
}

class _ReporterApplicationScreenState extends State<ReporterApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _qualificationCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _motivationCtrl = TextEditingController();
  String? _selectedState;
  bool _isLoading = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.currentUser.displayName;
    _phoneCtrl.text = widget.currentUser.phoneNumber;
    _selectedState = widget.currentUser.state;
    if (widget.currentUser.district != null) {
      _districtCtrl.text = widget.currentUser.district!;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _districtCtrl.dispose();
    _qualificationCtrl.dispose();
    _experienceCtrl.dispose();
    _motivationCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.currentUser.role != UserRole.publicUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Only public users can submit reporter applications.',
          ),
        ),
      );
      return;
    }
    if (_selectedState == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your state')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check if already applied
      final existing = await FirestoreService.reporterApplications
          .where('applicant_id', isEqualTo: widget.currentUser.id)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You already have a pending application.'),
            ),
          );
        }
        return;
      }

      final trimmedName = _nameCtrl.text.trim();
      final trimmedDistrict = _districtCtrl.text.trim();
      final selectedState = _selectedState!;
      final submittedAt = FieldValue.serverTimestamp();

      // Keep profile basics in sync with the latest application details.
      await FirestoreService.users.doc(widget.currentUser.id).set({
        'display_name': trimmedName,
        'district': trimmedDistrict,
        'state': selectedState,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirestoreService.reporterApplications.add({
        'applicant_id': widget.currentUser.id,
        'full_name': trimmedName,
        'phone': _phoneCtrl.text.trim(),
        'district': trimmedDistrict,
        'state': selectedState,
        'qualification': _qualificationCtrl.text.trim(),
        'experience': _experienceCtrl.text.trim(),
        'motivation': _motivationCtrl.text.trim(),
        'status': 'pending',
        'submitted_at': submittedAt,
        'applicant_profile': {
          'display_name': trimmedName,
          'phone_number': _phoneCtrl.text.trim(),
          'district': trimmedDistrict,
          'state': selectedState,
          'preferred_language': widget.currentUser.preferredLanguage,
          'role': widget.currentUser.role.toApiString(),
        },
      });

      if (mounted) setState(() => _submitted = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting application: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _SuccessView(onDone: () => Navigator.pop(context));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Apply as Reporter'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.75)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.edit_note_rounded, color: Colors.white, size: 40),
                    SizedBox(height: 10),
                    Text(
                      'Become a Reporter',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Fill in the form below. Admins will review your application.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _field(controller: _nameCtrl, label: 'Full Name', icon: Icons.person_outline, required: true),
              const SizedBox(height: 14),

              _field(
                controller: _phoneCtrl,
                label: 'Phone Number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
              ),
              const SizedBox(height: 14),

              // State
              DropdownButtonFormField<String>(
                initialValue: _selectedState,
                decoration: const InputDecoration(
                  labelText: 'State *',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                ),
                items: _indianStates
                    .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedState = v),
                validator: (v) => v == null ? 'State is required' : null,
                isExpanded: true,
              ),
              const SizedBox(height: 14),

              _field(controller: _districtCtrl, label: 'District *', icon: Icons.map_outlined, required: true),
              const SizedBox(height: 14),

              _field(controller: _qualificationCtrl, label: 'Qualification / Education *', icon: Icons.school_outlined, required: true),
              const SizedBox(height: 14),

              _field(controller: _experienceCtrl, label: 'Relevant Experience', icon: Icons.work_outline),
              const SizedBox(height: 14),

              TextFormField(
                controller: _motivationCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Why do you want to be a Reporter? *',
                  prefixIcon: Icon(Icons.chat_bubble_outline),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (v) =>
                    v == null || v.trim().length < 20 ? 'Please write at least 20 characters' : null,
              ),
              const SizedBox(height: 32),

              FilledButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_isLoading ? 'Submitting...' : 'Submit Application'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      validator: required
          ? (v) => v == null || v.trim().isEmpty ? '${label.replaceAll(' *', '')} is required' : null
          : null,
    );
  }
}

class _SuccessView extends StatelessWidget {
  final VoidCallback onDone;
  const _SuccessView({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_outline_rounded, size: 72, color: Colors.green.shade600),
              ),
              const SizedBox(height: 24),
              const Text(
                'Application Submitted!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Your application is under review. You will be notified once an admin reviews your request.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              FilledButton(onPressed: onDone, child: const Text('Done')),
            ],
          ),
        ),
      ),
    );
  }
}
