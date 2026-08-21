import os

# --- PATCH 1: figma_auth_flow.dart ---
auth_file = 'lib/figma_screens/figma_auth_flow.dart'
if os.path.exists(auth_file):
    content = open(auth_file, 'r', encoding='utf-8').read()
    
    # Update NIC validation to be optional
    old_val = "    final nicErr = Validators.nic(nic);\n    if (nicErr != null) { _showError(nicErr); return; }"
    new_val = """    if (nic.isNotEmpty) {
      final nicErr = Validators.nic(nic);
      if (nicErr != null) { _showError(nicErr); return; }
    }"""
    content = content.replace(old_val, new_val)
    open(auth_file, 'w', encoding='utf-8').write(content)
    print("PATCHED figma_auth_flow.dart")

# --- PATCH 2: sri_lanka_customer_register_figma.dart ---
reg_file = 'lib/figma_screens/sri_lanka_customer_register_figma.dart'
if os.path.exists(reg_file):
    content = open(reg_file, 'r', encoding='utf-8').read()
    
    # 1. Update normalField signature and implementation
    old_normal_sig = """    Widget normalField({
      required double top,
      required double left,
      required double width,
      required double height,
      required IconData icon,
      required String hint,
      required TextEditingController controller,
      required FocusNode focusNode,
      TextInputType keyboardType = TextInputType.text,
      TextCapitalization textCapitalization = TextCapitalization.none,
      List<TextInputFormatter>? inputFormatters,
      int maxLines = 1,
    }) {"""
    new_normal_sig = """    Widget normalField({
      required double top,
      required double left,
      required double width,
      required double height,
      required IconData icon,
      required String hint,
      required TextEditingController controller,
      required FocusNode focusNode,
      TextInputType keyboardType = TextInputType.text,
      TextCapitalization textCapitalization = TextCapitalization.none,
      List<TextInputFormatter>? inputFormatters,
      int maxLines = 1,
      bool isRequired = false,
    }) {"""
    content = content.replace(old_normal_sig, new_normal_sig)
    
    old_normal_impl = """                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: TextField("""
    new_normal_impl = """                Expanded(
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: controller,
                        builder: (context, value, child) {
                          if (value.text.isNotEmpty) return const SizedBox.shrink();
                          return IgnorePointer(
                            child: RichText(
                              text: TextSpan(
                                text: hint,
                                style: TextStyle(
                                  color: const Color(0xFF4F4F4F),
                                  fontFamily: 'Inter',
                                  fontSize: fs(14.5),
                                  fontWeight: FontWeight.w600,
                                  height: 1.1,
                                ),
                                children: [
                                  if (isRequired)
                                    const TextSpan(
                                      text: ' *',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      Material(
                        color: Colors.transparent,
                        child: TextField("""
    content = content.replace(old_normal_impl, new_normal_impl)
    
    # Clear out the old hintText since we draw it ourselves now
    content = content.replace("hintText: hint,", "hintText: '',")
    
    # 2. Update dropdownField signature and implementation
    old_drop_sig = """    Widget dropdownField({
      required double top,
      required String title,
      required IconData icon,
      required VoidCallback? onTap,
    }) {"""
    new_drop_sig = """    Widget dropdownField({
      required double top,
      required String title,
      required IconData icon,
      required VoidCallback? onTap,
      bool isRequired = false,
      bool hasValue = false,
    }) {"""
    content = content.replace(old_drop_sig, new_drop_sig)
    
    old_drop_impl = """                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: const Color(0xFF4F4F4F),
                      fontFamily: 'Inter',
                      fontSize: fs(14.5),
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ),"""
    new_drop_impl = """                Expanded(
                  child: RichText(
                    text: TextSpan(
                      text: title,
                      style: TextStyle(
                        color: const Color(0xFF4F4F4F),
                        fontFamily: 'Inter',
                        fontSize: fs(14.5),
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                      children: [
                        if (isRequired && !hasValue)
                          const TextSpan(
                            text: ' *',
                            style: TextStyle(color: Colors.red),
                          ),
                      ],
                    ),
                  ),
                ),"""
    content = content.replace(old_drop_impl, new_drop_impl)
    
    # 3. Update nicCard hint and text
    content = content.replace("'NIC (Sri Lanka)'", "'NIC (Optional)'")
    # Leave hint "Enter your NIC" as is.
    
    # 4. Update the normalField calls to add isRequired: true
    content = content.replace("hint: 'Full Name',\n                              controller: _fullNameController,", "hint: 'Full Name',\n                              isRequired: true,\n                              controller: _fullNameController,")
    content = content.replace("hint: 'Phone Number',\n                              controller: _phoneController,", "hint: 'Phone Number',\n                              isRequired: true,\n                              controller: _phoneController,")
    content = content.replace("hint: 'Email Address',\n                              controller: _emailController,", "hint: 'Email Address',\n                              isRequired: true,\n                              controller: _emailController,")
    content = content.replace("hint: 'Precise Delivery Address',\n                              controller: _addressController,", "hint: 'Precise Delivery Address',\n                              isRequired: true,\n                              controller: _addressController,")
    
    # 5. Update dropdownField calls to add isRequired and hasValue
    prov_old = """                            dropdownField(
                              top: 306,
                              title: widget.selectedProvince?.isNotEmpty == true
                                  ? widget.selectedProvince!
                                  : 'Province',
                              icon: Icons.map_outlined,
                              onTap: widget.onProvinceTap,
                            ),"""
    prov_new = """                            dropdownField(
                              top: 306,
                              title: widget.selectedProvince?.isNotEmpty == true
                                  ? widget.selectedProvince!
                                  : 'Province',
                              icon: Icons.map_outlined,
                              onTap: widget.onProvinceTap,
                              isRequired: true,
                              hasValue: widget.selectedProvince?.isNotEmpty == true,
                            ),"""
    content = content.replace(prov_old, prov_new)
    
    dist_old = """                            dropdownField(
                              top: 357,
                              title: widget.selectedDistrict?.isNotEmpty == true
                                  ? widget.selectedDistrict!
                                  : 'District',
                              icon: Icons.travel_explore_rounded,
                              onTap: widget.onDistrictTap,
                            ),"""
    dist_new = """                            dropdownField(
                              top: 357,
                              title: widget.selectedDistrict?.isNotEmpty == true
                                  ? widget.selectedDistrict!
                                  : 'District',
                              icon: Icons.travel_explore_rounded,
                              onTap: widget.onDistrictTap,
                              isRequired: true,
                              hasValue: widget.selectedDistrict?.isNotEmpty == true,
                            ),"""
    content = content.replace(dist_old, dist_new)
    
    open(reg_file, 'w', encoding='utf-8').write(content)
    print("PATCHED sri_lanka_customer_register_figma.dart")
