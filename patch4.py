import os

file_path = 'lib/shared/presentation/screens/profile_screen.dart'
if os.path.exists(file_path):
    content = open(file_path, 'r', encoding='utf-8').read()
    
    # 1. Add _nicCtrl
    content = content.replace("  late TextEditingController _businessNameCtrl;", "  late TextEditingController _businessNameCtrl;\n  late TextEditingController _nicCtrl;")
    
    # 2. Init _nicCtrl
    content = content.replace("    _businessNameCtrl = TextEditingController();", "    _businessNameCtrl = TextEditingController();\n    _nicCtrl = TextEditingController();")
    
    # 3. Dispose _nicCtrl
    content = content.replace("    _businessNameCtrl.dispose();", "    _businessNameCtrl.dispose();\n    _nicCtrl.dispose();")
    
    # 4. Load _nicCtrl
    content = content.replace("      _businessNameCtrl.text = user.businessName ?? '';", "      _businessNameCtrl.text = user.businessName ?? '';\n      _nicCtrl.text = user.nic ?? '';")
    
    # 5. Check _hasChanges
    content = content.replace("        _businessNameCtrl.text.trim() != (user.businessName ?? '') ||", "        _businessNameCtrl.text.trim() != (user.businessName ?? '') ||\n        _nicCtrl.text.trim() != (user.nic ?? '') ||")
    
    # 6. Validate in _handleSave (around line 302)
    validate_old = """  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final online = await ConnectivityService.instance.isOnline();"""
    validate_new = """  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final userx = ref.read(currentUserProvider);
    if (userx != null) {
      final nicText = _nicCtrl.text.trim();
      if (nicText.isNotEmpty) {
        final nicErr = Validators.nic(nicText);
        if (nicErr != null) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(nicErr), backgroundColor: Colors.red));
          return;
        }
      } else if (userx.role == UserRole.vendor) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('NIC is required for vendor accounts.'), backgroundColor: Colors.red));
        return;
      }
    }

    final online = await ConnectivityService.instance.isOnline();"""
    content = content.replace(validate_old, validate_new)
    
    # 7. updateProfile args
    update_old = """      await ref.read(authProvider.notifier).updateProfile(
            fullName: _nameCtrl.text.trim(),
            phone: phone,"""
    update_new = """      await ref.read(authProvider.notifier).updateProfile(
            fullName: _nameCtrl.text.trim(),
            phone: phone,
            nic: _nicCtrl.text.trim(),"""
    content = content.replace(update_old, update_new)
    
    open(file_path, 'w', encoding='utf-8').write(content)
    print("PATCHED script generated!")
