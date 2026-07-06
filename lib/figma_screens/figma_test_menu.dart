import 'package:flutter/material.dart';

import 'sri_lanka_customer_login_figma.dart';
import 'sri_lanka_customer_login_otp_figma.dart';
import 'sri_lanka_customer_register_figma.dart';
import 'sri_lanka_customer_register_otp_figma.dart';

import 'international_customer_login_figma.dart';
import 'international_customer_login_otp_figma.dart';
import 'international_customer_register_figma.dart';
import 'international_customer_register_otp_figma.dart';

import 'sri_lanka_vendor_login_figma.dart';
import 'sri_lanka_vendor_login_otp_figma.dart';
import 'sri_lanka_vendor_register_figma.dart';
import 'sri_lanka_vendor_register_otp_figma.dart';

import 'sri_lanka_vendor_forget_password_figma.dart';
import 'sri_lanka_vendor_forget_password_otp_figma.dart';

import 'new_password_update_sri_lanka_vendor_figma.dart';

import 'international_vendor_login_figma.dart';
import 'international_vendor_login_otp_figma.dart';
import 'international_vendor_register_figma.dart';
import 'international_vendor_register_otp_figma.dart';

import 'international_vendor_forget_password_figma.dart';
import 'international_vendor_forget_password_otp_figma.dart';

import 'new_password_update_international_vendor_figma.dart';

class FigmaTestMenu extends StatelessWidget {
  const FigmaTestMenu({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _replace(BuildContext context, Widget screen) {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _successPage(String label) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Figma Screens Test')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Sri Lanka Customer Login ─────────────────────────────────────
          ElevatedButton(
            onPressed: () => _push(context, _buildSriLankaCustomerLogin(context)),
            child: const Text('Sri Lanka Customer Login'),
          ),
          const SizedBox(height: 12),

          // ── Sri Lanka Customer Login OTP ─────────────────────────────────
          ElevatedButton(
            onPressed: () => _push(
              context,
              SrilankacustomerloginotpWidget(
                onVerifyOtp: (_) => _replace(
                  context,
                  _successPage('Customer Dashboard\n(Sri Lanka Login OTP success)'),
                ),
              ),
            ),
            child: const Text('Sri Lanka Customer Login OTP'),
          ),
          const SizedBox(height: 12),

          // ── Sri Lanka Customer Register ──────────────────────────────────
          ElevatedButton(
            onPressed: () => _push(context, _buildSriLankaCustomerRegister(context)),
            child: const Text('Sri Lanka Customer Register'),
          ),
          const SizedBox(height: 12),

          // ── Sri Lanka Customer Register OTP ──────────────────────────────
          ElevatedButton(
            onPressed: () => _push(
              context,
              SrilankacustomerregistrationotpWidget(
                onVerifyOtp: (_) => _replace(
                  context,
                  _successPage('Customer Dashboard\n(Sri Lanka Register OTP success)'),
                ),
              ),
            ),
            child: const Text('Sri Lanka Customer Register OTP'),
          ),
          const SizedBox(height: 12),

          // ── International Customer Login ─────────────────────────────────
          ElevatedButton(
            onPressed: () => _push(context, _buildInternationalCustomerLogin(context)),
            child: const Text('International Customer Login'),
          ),
          const SizedBox(height: 12),

          // ── International Customer Login OTP ─────────────────────────────
          ElevatedButton(
            onPressed: () => _push(
              context,
              InternationalcustomerloginotpWidget(
                onVerifyOtp: (_) => _replace(
                  context,
                  _successPage('Customer Dashboard\n(International Login OTP success)'),
                ),
              ),
            ),
            child: const Text('International Customer Login OTP'),
          ),
          const SizedBox(height: 12),

          // ── International Customer Register ──────────────────────────────
          ElevatedButton(
            onPressed: () => _push(context, _buildInternationalCustomerRegister(context)),
            child: const Text('International Customer Register'),
          ),
          const SizedBox(height: 12),

          // ── International Customer Register OTP ──────────────────────────
          ElevatedButton(
            onPressed: () => _push(
              context,
              InternationalcustomerregistrationotpWidget(
                onVerifyOtp: (_) => _replace(
                  context,
                  _successPage('Customer Dashboard\n(International Register OTP success)'),
                ),
              ),
            ),
            child: const Text('International Customer Register OTP'),
          ),
          const SizedBox(height: 12),

          // ── Sri Lanka Vendor Login ────────────────────────────────────────
          ElevatedButton(
            onPressed: () => _push(context, _buildSriLankaVendorLogin(context)),
            child: const Text('Sri Lanka Vendor Login'),
          ),
          const SizedBox(height: 12),

          // ── Sri Lanka Vendor Login OTP ────────────────────────────────────
          ElevatedButton(
            onPressed: () => _push(
              context,
              SrilankavendorloginotpWidget(
                onVerifyOtp: (_) => _replace(
                  context,
                  _successPage('Vendor Dashboard\n(Sri Lanka Login OTP success)'),
                ),
              ),
            ),
            child: const Text('Sri Lanka Vendor Login OTP'),
          ),
          const SizedBox(height: 12),

          // ── International Vendor Login ────────────────────────────────────
          ElevatedButton(
            onPressed: () => _push(context, _buildInternationalVendorLogin(context)),
            child: const Text('International Vendor Login'),
          ),
          const SizedBox(height: 12),

          // ── International Vendor Login OTP ────────────────────────────────
          ElevatedButton(
            onPressed: () => _push(
              context,
              InternationalvendorloginotpWidget(
                onVerifyOtp: (_) => _replace(
                  context,
                  _successPage('Vendor Dashboard\n(International Login OTP success)'),
                ),
              ),
            ),
            child: const Text('International Vendor Login OTP'),
          ),
          const SizedBox(height: 12),

          // ── Sri Lanka Vendor Register ─────────────────────────────────────
          ElevatedButton(
            onPressed: () => _push(context, _buildSriLankaVendorRegister(context)),
            child: const Text('Sri Lanka Vendor Register'),
          ),
          const SizedBox(height: 12),

          // ── International Vendor Register ─────────────────────────────────
          ElevatedButton(
            onPressed: () => _push(context, _buildInternationalVendorRegister(context)),
            child: const Text('International Vendor Register'),
          ),
          const SizedBox(height: 12),

          // ── Sri Lanka Vendor Register OTP ─────────────────────────────────
          ElevatedButton(
            onPressed: () => _push(
              context,
              SrilankavendorregistrationotpWidget(
                onVerifyOtp: (_) => _replace(
                  context,
                  _successPage('Vendor Dashboard\n(Sri Lanka Register OTP success)'),
                ),
              ),
            ),
            child: const Text('Sri Lanka Vendor Register OTP'),
          ),
          const SizedBox(height: 12),

          // ── International Vendor Register OTP ────────────────────────────
          ElevatedButton(
            onPressed: () => _push(
              context,
              InternationalvendorregistrationotpWidget(
                onVerifyOtp: (_) => _replace(
                  context,
                  _successPage('Vendor Dashboard\n(International Register OTP success)'),
                ),
              ),
            ),
            child: const Text('International Vendor Register OTP'),
          ),
          const SizedBox(height: 12),

          // ── Sri Lanka Vendor Forgot Password ─────────────────────────────
          ElevatedButton(
            onPressed: () => _push(context, _buildSriLankaForgotPassword(context)),
            child: const Text('Sri Lanka Vendor Forget Password'),
          ),
          const SizedBox(height: 12),

          // ── International Vendor Forgot Password ─────────────────────────
          ElevatedButton(
            onPressed: () => _push(context, _buildInternationalForgotPassword(context)),
            child: const Text('International Vendor Forget Password'),
          ),
          const SizedBox(height: 12),

          // ── Sri Lanka Vendor Forgot Password OTP ─────────────────────────
          ElevatedButton(
            onPressed: () => _push(
              context,
              SrilankavendorforgetpasswordotpWidget(
                onSignIn: () => _replace(context, _buildSriLankaVendorLogin(context)),
              ),
            ),
            child: const Text('Sri Lanka Vendor Forget Password OTP'),
          ),
          const SizedBox(height: 12),

          // ── International Vendor Forgot Password OTP ─────────────────────
          ElevatedButton(
            onPressed: () => _push(
              context,
              InternationalvendorforgetpasswordotpWidget(
                onSignIn: () => _replace(context, _buildInternationalVendorLogin(context)),
              ),
            ),
            child: const Text('International Vendor Forget Password OTP'),
          ),
          const SizedBox(height: 12),

          // ── Sri Lanka Vendor New Password Update ──────────────────────────
          ElevatedButton(
            onPressed: () => _push(
              context,
              NewpasswordupdatesrilankavendorWidget(
                onUpdatePassword: () =>
                    _replace(context, _buildSriLankaVendorLogin(context)),
              ),
            ),
            child: const Text('Sri Lanka Vendor New Password Update'),
          ),
          const SizedBox(height: 12),

          // ── International Vendor New Password Update ──────────────────────
          ElevatedButton(
            onPressed: () => _push(
              context,
              NewpasswordupdateforinternationalvendorWidget(
                onUpdatePassword: () =>
                    _replace(context, _buildInternationalVendorLogin(context)),
              ),
            ),
            child: const Text('International Vendor New Password Update'),
          ),
        ],
      ),
    );
  }

  // ── builder helpers ──────────────────────────────────────────────────────

  Widget _buildSriLankaCustomerLogin(BuildContext context) {
    return SrilankacustomerloginWidget(
      onSendOtp: () => _replace(
        context,
        SrilankacustomerloginotpWidget(
          onVerifyOtp: (_) => _replace(
            context,
            _successPage('Customer Dashboard\n(Sri Lanka Login OTP success)'),
          ),
        ),
      ),
      onRegister: () => _replace(context, _buildSriLankaCustomerRegister(context)),
      onVendorLogin: () => _replace(context, _buildSriLankaVendorLogin(context)),
      onCountryTap: () => _replace(context, _buildInternationalCustomerLogin(context)),
    );
  }

  Widget _buildInternationalCustomerLogin(BuildContext context) {
    return InternationalcustomerloginWidget(
      onSendOtp: () => _replace(
        context,
        InternationalcustomerloginotpWidget(
          onVerifyOtp: (_) => _replace(
            context,
            _successPage('Customer Dashboard\n(International Login OTP success)'),
          ),
        ),
      ),
      onRegister: () => _replace(context, _buildInternationalCustomerRegister(context)),
      onVendorLogin: () => _replace(context, _buildInternationalVendorLogin(context)),
      onCountryTap: () => _replace(context, _buildSriLankaCustomerLogin(context)),
    );
  }

  Widget _buildSriLankaCustomerRegister(BuildContext context) {
    return SrilankacustomerregisteraccountWidget(
      onBack: () => _replace(context, _buildSriLankaCustomerLogin(context)),
      onSignIn: () => _replace(context, _buildSriLankaCustomerLogin(context)),
      onCountryTap: () => _replace(context, _buildInternationalCustomerRegister(context)),
      onCreateAccount: () => _replace(
        context,
        SrilankacustomerregistrationotpWidget(
          onVerifyOtp: (_) => _replace(
            context,
            _successPage('Customer Dashboard\n(Sri Lanka Register OTP success)'),
          ),
        ),
      ),
    );
  }

  Widget _buildInternationalCustomerRegister(BuildContext context) {
    return InternationalcustomerregisteraccountWidget(
      onBack: () => _replace(context, _buildInternationalCustomerLogin(context)),
      onSignIn: () => _replace(context, _buildInternationalCustomerLogin(context)),
      onCountryTap: () => _replace(context, _buildSriLankaCustomerRegister(context)),
      onCreateAccount: () => _replace(
        context,
        InternationalcustomerregistrationotpWidget(
          onVerifyOtp: (_) => _replace(
            context,
            _successPage('Customer Dashboard\n(International Register OTP success)'),
          ),
        ),
      ),
    );
  }

  Widget _buildSriLankaVendorLogin(BuildContext context) {
    return SrilankavendorloginWidget(
      onSignIn: () => _replace(
        context,
        SrilankavendorloginotpWidget(
          onVerifyOtp: (_) => _replace(
            context,
            _successPage('Vendor Dashboard\n(Sri Lanka Login OTP success)'),
          ),
        ),
      ),
      onRegister: () => _replace(context, _buildSriLankaVendorRegister(context)),
      onCustomerLogin: () => _replace(context, _buildSriLankaCustomerLogin(context)),
      onForgotPassword: () => _push(context, _buildSriLankaForgotPassword(context)),
      onCountryTap: () => _replace(context, _buildInternationalVendorLogin(context)),
    );
  }

  Widget _buildInternationalVendorLogin(BuildContext context) {
    return InternationalvendorloginWidget(
      onSignIn: () => _replace(
        context,
        InternationalvendorloginotpWidget(
          onVerifyOtp: (_) => _replace(
            context,
            _successPage('Vendor Dashboard\n(International Login OTP success)'),
          ),
        ),
      ),
      onRegister: () => _replace(context, _buildInternationalVendorRegister(context)),
      onCustomerLogin: () => _replace(context, _buildInternationalCustomerLogin(context)),
      onForgotPassword: () => _push(context, _buildInternationalForgotPassword(context)),
      onCountryTap: () => _replace(context, _buildSriLankaVendorLogin(context)),
    );
  }

  Widget _buildSriLankaVendorRegister(BuildContext context) {
    return SrilankavendorregistrationWidget(
      onBack: () => _replace(context, _buildSriLankaVendorLogin(context)),
      onSignIn: () => _replace(context, _buildSriLankaVendorLogin(context)),
      onCountryTap: () => _replace(context, _buildInternationalVendorRegister(context)),
      onCreateAccount: () => _replace(
        context,
        SrilankavendorregistrationotpWidget(
          onVerifyOtp: (_) => _replace(
            context,
            _successPage('Vendor Dashboard\n(Sri Lanka Register OTP success)'),
          ),
        ),
      ),
    );
  }

  Widget _buildInternationalVendorRegister(BuildContext context) {
    return InternationalvendorregistrationWidget(
      onBack: () => _replace(context, _buildInternationalVendorLogin(context)),
      onSignIn: () => _replace(context, _buildInternationalVendorLogin(context)),
      onCountryTap: () => _replace(context, _buildSriLankaVendorRegister(context)),
      onCreateAccount: () => _replace(
        context,
        InternationalvendorregistrationotpWidget(
          onVerifyOtp: (_) => _replace(
            context,
            _successPage('Vendor Dashboard\n(International Register OTP success)'),
          ),
        ),
      ),
    );
  }

  Widget _buildSriLankaForgotPassword(BuildContext context) {
    return SrilankavendorforgetpasswordWidget(
      onBack: () => Navigator.maybePop(context),
      onSignIn: () => _replace(context, _buildSriLankaVendorLogin(context)),
      onSendResetCode: () => _push(
        context,
        SrilankavendorforgetpasswordotpWidget(
          onSignIn: () => _replace(context, _buildSriLankaVendorLogin(context)),
        ),
      ),
    );
  }

  Widget _buildInternationalForgotPassword(BuildContext context) {
    return InternationalvendorforgetpasswordWidget(
      onBack: () => Navigator.maybePop(context),
      onSignIn: () => _replace(context, _buildInternationalVendorLogin(context)),
      onSendResetCode: () => _push(
        context,
        InternationalvendorforgetpasswordotpWidget(
          onSignIn: () => _replace(context, _buildInternationalVendorLogin(context)),
        ),
      ),
    );
  }
}
