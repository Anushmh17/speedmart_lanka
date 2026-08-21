import os

vendor_file = 'lib/figma_screens/sri_lanka_vendor_register_figma.dart'
if os.path.exists(vendor_file):
    content = open(vendor_file, 'r', encoding='utf-8').read()
    
    # 1. Update darkField signature
    old_dark_sig = """    Widget darkField({
      required double top,
      required double left,
      required double width,
      required double height,
      required String hint,
      required TextEditingController controller,
      required FocusNode focusNode,
      TextInputType keyboardType = TextInputType.text,
      TextCapitalization textCapitalization = TextCapitalization.none,
      List<TextInputFormatter>? inputFormatters,
      bool obscureText = false,
      Widget? suffix,
    }) {"""
    new_dark_sig = """    Widget darkField({
      required double top,
      required double left,
      required double width,
      required double height,
      required String hint,
      required TextEditingController controller,
      required FocusNode focusNode,
      TextInputType keyboardType = TextInputType.text,
      TextCapitalization textCapitalization = TextCapitalization.none,
      List<TextInputFormatter>? inputFormatters,
      bool obscureText = false,
      Widget? suffix,
      bool isRequired = false,
    }) {"""
    content = content.replace(old_dark_sig, new_dark_sig)
    
    # 2. Update darkField implementation
    old_dark_impl = """                  Expanded(
                    child: Center(
                      child: TextField("""
    new_dark_impl = """                  Expanded(
                    child: Center(
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
                                      color: const Color(0xFFCACACA),
                                      fontFamily: 'Inter',
                                      fontSize: fs(15),
                                      fontWeight: FontWeight.w600,
                                      height: 1,
                                      letterSpacing: 0,
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
                          TextField("""
    content = content.replace(old_dark_impl, new_dark_impl)
    
    # Clear out the hintText
    content = content.replace("hintText: hint,", "hintText: '',")
    
    # Fix the missing brackets for Stack
    old_dark_end = """                        ),
                      ),
                    ),
                  ),
                  if (suffix != null) ...["""
    new_dark_end = """                        ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (suffix != null) ...["""
    content = content.replace(old_dark_end, new_dark_end)
    
    # 3. Update dropdownField signature
    old_drop_sig = """    Widget dropdownField({
      required double top,
      required double left,
      required double width,
      required String title,
      required VoidCallback? onTap,
      bool isSriLanka = false,
      bool showArrow = true,
    }) {"""
    new_drop_sig = """    Widget dropdownField({
      required double top,
      required double left,
      required double width,
      required String title,
      required VoidCallback? onTap,
      bool isSriLanka = false,
      bool showArrow = true,
      bool isRequired = false,
      bool hasValue = false,
    }) {"""
    content = content.replace(old_drop_sig, new_drop_sig)
    
    # 4. Update dropdownField implementation
    old_drop_impl = """                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFFCACACA),
                      fontFamily: 'Inter',
                      fontSize: fs(15),
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ),"""
    new_drop_impl = """                Expanded(
                  child: RichText(
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      text: title,
                      style: TextStyle(
                        color: const Color(0xFFCACACA),
                        fontFamily: 'Inter',
                        fontSize: fs(15),
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
    
    # 5. Apply isRequired: true to necessary fields
    content = content.replace("hint: 'Email Address',\n                              controller: _emailController,", "hint: 'Email Address',\n                              isRequired: true,\n                              controller: _emailController,")
    content = content.replace("hint: 'Full Name',\n                              controller: _fullNameController,", "hint: 'Full Name',\n                              isRequired: true,\n                              controller: _fullNameController,")
    content = content.replace("hint: 'Phone Number',\n                              controller: _phoneController,", "hint: 'Phone Number',\n                              isRequired: true,\n                              controller: _phoneController,")
    content = content.replace("hint: 'NIC',\n                              controller: _nicController,", "hint: 'NIC',\n                              isRequired: true,\n                              controller: _nicController,")
    
    content = content.replace("hint: 'Shop Name',\n                              controller: _shopNameController,", "hint: 'Shop Name',\n                              isRequired: true,\n                              controller: _shopNameController,")
    content = content.replace("hint: 'Shop Address / Location',\n                              controller: _shopAddressController,", "hint: 'Shop Address / Location',\n                              isRequired: true,\n                              controller: _shopAddressController,")
    content = content.replace("hint: 'Password',\n                              controller: _passwordController,", "hint: 'Password',\n                              isRequired: true,\n                              controller: _passwordController,")
    content = content.replace("hint: 'Confirm Password',\n                              controller: _confirmPasswordController,", "hint: 'Confirm Password',\n                              isRequired: true,\n                              controller: _confirmPasswordController,")
    
    prov_old = """                            dropdownField(
                              top: 408,
                              left: 177,
                              width: 155,
                              title: widget.selectedProvince?.isNotEmpty == true
                                  ? widget.selectedProvince!
                                  : 'Province',
                              onTap: widget.onProvinceTap,
                            ),"""
    prov_new = """                            dropdownField(
                              top: 408,
                              left: 177,
                              width: 155,
                              title: widget.selectedProvince?.isNotEmpty == true
                                  ? widget.selectedProvince!
                                  : 'Province',
                              onTap: widget.onProvinceTap,
                              isRequired: true,
                              hasValue: widget.selectedProvince?.isNotEmpty == true,
                            ),"""
    content = content.replace(prov_old, prov_new)
    
    dist_old = """                            dropdownField(
                              top: 408,
                              left: 7,
                              width: 161,
                              title: widget.selectedDistrict?.isNotEmpty == true
                                  ? widget.selectedDistrict!
                                  : 'District',
                              onTap: widget.onDistrictTap,
                            ),"""
    dist_new = """                            dropdownField(
                              top: 408,
                              left: 7,
                              width: 161,
                              title: widget.selectedDistrict?.isNotEmpty == true
                                  ? widget.selectedDistrict!
                                  : 'District',
                              onTap: widget.onDistrictTap,
                              isRequired: true,
                              hasValue: widget.selectedDistrict?.isNotEmpty == true,
                            ),"""
    content = content.replace(dist_old, dist_new)
    
    open(vendor_file, 'w', encoding='utf-8').write(content)
    print("PATCHED sri_lanka_vendor_register_figma.dart")
