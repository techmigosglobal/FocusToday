import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/language_service.dart';
import '../../../../shared/models/user.dart';
import '../../../../main.dart';
import '../../data/models/partner.dart';
import '../../data/repositories/enrollment_repository.dart';

/// Indian states list for dropdown
const List<String> _indianStates = [
  'Andhra Pradesh',
  'Arunachal Pradesh',
  'Assam',
  'Bihar',
  'Chhattisgarh',
  'Goa',
  'Gujarat',
  'Haryana',
  'Himachal Pradesh',
  'Jharkhand',
  'Karnataka',
  'Kerala',
  'Madhya Pradesh',
  'Maharashtra',
  'Manipur',
  'Meghalaya',
  'Mizoram',
  'Nagaland',
  'Odisha',
  'Punjab',
  'Rajasthan',
  'Sikkim',
  'Tamil Nadu',
  'Telangana',
  'Tripura',
  'Uttar Pradesh',
  'Uttarakhand',
  'West Bengal',
  'Andaman and Nicobar Islands',
  'Chandigarh',
  'Dadra and Nagar Haveli and Daman and Diu',
  'Delhi',
  'Jammu and Kashmir',
  'Ladakh',
  'Lakshadweep',
  'Puducherry',
];

/// Partner Enrollment Screen — Open membership form
class EnrollmentScreen extends StatefulWidget {
  final User? currentUser;

  const EnrollmentScreen({super.key, this.currentUser});

  @override
  State<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends State<EnrollmentScreen> {
  final EnrollmentRepository _repo = EnrollmentRepository();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _districtController = TextEditingController();
  final _professionController = TextEditingController();
  final _institutionController = TextEditingController();
  final _worshipController = TextEditingController();
  String? _selectedState;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill from current user if available
    if (widget.currentUser != null) {
      _nameController.text = widget.currentUser!.displayName;
      _phoneController.text = widget.currentUser!.phoneNumber;
      if (widget.currentUser!.district != null) {
        _districtController.text = widget.currentUser!.district!;
      }
      if (widget.currentUser!.state != null) {
        _selectedState = widget.currentUser!.state;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _districtController.dispose();
    _professionController.dispose();
    _institutionController.dispose();
    _worshipController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedState == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a state')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final partner = Partner(
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        district: _districtController.text.trim(),
        state: _selectedState!,
        profession: _professionController.text.trim(),
        institution: _institutionController.text.trim().isEmpty
            ? null
            : _institutionController.text.trim(),
        placeOfWorship: _worshipController.text.trim().isEmpty
            ? null
            : _worshipController.text.trim(),
        userId: widget.currentUser?.id,
      );

      final success = await _repo.submitEnrollment(
        partner: partner,
        actorId: widget.currentUser?.id,
      );
      if (mounted && success) _showSuccess();
      if (mounted && !success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Please try again')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString().contains('409') ? 'Phone number already enrolled' : 'Please try again'}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: AppColors.secondary,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Welcome to CRII!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'You have been enrolled as a Focus Today partner successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondaryOf(context)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang =
        FocusTodayApp.languageService?.currentLanguage ?? AppLanguage.english;
    final l = AppLocalizations(lang);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.becomePartner),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.handshake_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l.partnerEnrollment,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.partnerEnrollmentSubtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l.fullName,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),

              // Phone
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  labelText: l.phoneNumber,
                  prefixIcon: const Icon(Icons.phone_outlined),
                  prefixText: '+91 ',
                ),
                validator: (v) => v == null || v.trim().length < 10
                    ? 'Valid phone number is required'
                    : null,
              ),
              const SizedBox(height: 16),

              // State dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedState,
                decoration: InputDecoration(
                  labelText: l.stateLabel,
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
                items: _indianStates
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedState = v),
                validator: (v) => v == null ? 'State is required' : null,
                isExpanded: true,
              ),
              const SizedBox(height: 16),

              // District
              TextFormField(
                controller: _districtController,
                decoration: InputDecoration(
                  labelText: l.district,
                  prefixIcon: const Icon(Icons.map_outlined),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'District is required'
                    : null,
              ),
              const SizedBox(height: 16),

              // Profession
              TextFormField(
                controller: _professionController,
                decoration: InputDecoration(
                  labelText: l.profession,
                  prefixIcon: const Icon(Icons.work_outline),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Profession is required'
                    : null,
              ),
              const SizedBox(height: 16),

              // Institution
              TextFormField(
                controller: _institutionController,
                decoration: InputDecoration(
                  labelText: l.institutionOrg,
                  prefixIcon: const Icon(Icons.business_outlined),
                  hintText: l.optional,
                ),
              ),
              const SizedBox(height: 16),

              // Place of worship
              TextFormField(
                controller: _worshipController,
                decoration: InputDecoration(
                  labelText: l.placeOfWorship,
                  prefixIcon: const Icon(Icons.church_outlined),
                  hintText: l.optional,
                ),
              ),
              const SizedBox(height: 32),

              // Submit
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.how_to_reg),
                label: Text(_isLoading ? l.submitting : l.enrollNow),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
