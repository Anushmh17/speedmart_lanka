import os

file_path = 'lib/features/shared/presentation/screens/profile_screen.dart'
if os.path.exists(file_path):
    content = open(file_path, 'r', encoding='utf-8').read()
    
    # 1. Add _nicCtrl
    content = content.replace("  late TextEditingController _phoneCtrl;", "  late TextEditingController _phoneCtrl;\n  late TextEditingController _nicCtrl;")
    
    # 2. Init _nicCtrl
    content = content.replace("    _phoneCtrl = TextEditingController();", "    _phoneCtrl = TextEditingController();\n    _nicCtrl = TextEditingController();")
    
    # 3. Dispose _nicCtrl
    content = content.replace("    _phoneCtrl.dispose();", "    _phoneCtrl.dispose();\n    _nicCtrl.dispose();")
    
    # 4. Load _nicCtrl
    content = content.replace("      _phoneCtrl.text = user.phone;", "      _phoneCtrl.text = user.phone;\n      _nicCtrl.text = user.nic ?? '';")
    
    # 5. Check _hasProfileChanges
    content = content.replace("final samePhone = _phoneCtrl.text.trim() == user.phone;", "final samePhone = _phoneCtrl.text.trim() == user.phone;\n    final sameNic = _nicCtrl.text.trim() == (user.nic ?? '');")
    content = content.replace("          !samePhone ||\n          !sameBusinessName", "          !samePhone ||\n          !sameNic ||\n          !sameBusinessName")
    content = content.replace("      return !sameName || !samePhone || !samePickedImage;", "      return !sameName || !samePhone || !sameNic || !samePickedImage;")
    
    # 6. Validate in _handleSave (around line 270)
    validate_old = """    if (!_hasProfileChanges) {
      setState(() => _isEditing = false);
      ref.read(bottomNavVisibilityProvider.notifier).setManualHidden(false);
      return;
    }

    if (!_formKey.currentState!.validate()) return;"""
    validate_new = """    if (!_hasProfileChanges) {
      setState(() => _isEditing = false);
      ref.read(bottomNavVisibilityProvider.notifier).setManualHidden(false);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final nicText = _nicCtrl.text.trim();
    if (nicText.isNotEmpty) {
      final nicErr = Validators.nic(nicText);
      if (nicErr != null) {
        Theme3Toast.showError(context, nicErr);
        return;
      }
    } else if (user.role == UserRole.vendor) {
      Theme3Toast.showError(context, 'NIC is required for vendor accounts.');
      return;
    }"""
    content = content.replace(validate_old, validate_new)
    
    # 7. updateProfile args
    update_old = """      await ref.read(authProvider.notifier).updateProfile(
        fullName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),"""
    update_new = """      await ref.read(authProvider.notifier).updateProfile(
        fullName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        nic: _nicCtrl.text.trim(),"""
    content = content.replace(update_old, update_new)
    
    # 8. Modify the text field in _buildEditablePersonalFields
    field_old = """      Theme3AppTextField(
        label: 'NIC',
        controller: TextEditingController(text: user.nic ?? 'Not provided'),
        prefixIcon: Icons.badge_outlined,
        suffixIcon: Icons.lock_outline_rounded,
        readOnly: true,
      ),"""
    field_new = """      Theme3AppTextField(
        label: 'NIC',
        controller: _nicCtrl,
        prefixIcon: Icons.badge_outlined,
      ),"""
    content = content.replace(field_old, field_new)
    
    open(file_path, 'w', encoding='utf-8').write(content)
    print("PATCHED profile_screen.dart")
