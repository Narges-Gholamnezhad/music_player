// lib/payment_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

class PaymentScreen extends StatefulWidget {
  final double amount;
  final String itemName;

  const PaymentScreen({
    super.key,
    required this.amount,
    required this.itemName,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cvv2Controller = TextEditingController();
  final TextEditingController _expMonthController = TextEditingController();
  final TextEditingController _expYearController = TextEditingController();
  final TextEditingController _dynamicPasswordController =
      TextEditingController();
  final TextEditingController _captchaController = TextEditingController();

  final Random _random = Random();
  String _captchaText = "78360";

  @override
  void initState() {
    super.initState();
    _refreshCaptcha();
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cvv2Controller.dispose();
    _expMonthController.dispose();
    _expYearController.dispose();
    _dynamicPasswordController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  void _refreshCaptcha() {
    setState(() {
      _captchaText = (_random.nextInt(90000) + 10000).toString();
    });
  }

  bool _luhnIsValid(String digitsOnly) {
    int sum = 0;
    bool alternate = false;
    for (int i = digitsOnly.length - 1; i >= 0; i--) {
      int n = digitsOnly.codeUnitAt(i) - 48;
      if (alternate) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  void _processPayment() {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً خطاهای فرم را برطرف کنید.')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('پرداخت برای "${widget.itemName}" با موفقیت انجام شد!')),
    );
    Navigator.of(context).pop(true);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    IconData? prefixIcon,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    String? Function(String?)? validator,
    bool obscureText = false,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      validator: validator,
      obscureText: obscureText,
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: Colors.grey[600])
            : null,
      ),
      style: TextStyle(color: theme.colorScheme.onSurface),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('پرداخت برای: ${widget.itemName}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildTextField(
                controller: _cardNumberController,
                labelText: "شماره کارت",
                hintText: "XXXXXXXXXXXXXXXX",
                prefixIcon: Icons.credit_card,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16),
                ],
                validator: (value) {
                  final v = (value ?? '').trim();
                  if (v.isEmpty) return 'شماره کارت الزامی است';
                  if (v.length != 16) return 'شماره کارت باید ۱۶ رقمی باشد';
                  if (!_luhnIsValid(v)) return 'شماره کارت نامعتبر است';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _cvv2Controller,
                labelText: "CVV2",
                hintText: "XXX یا XXXX",
                prefixIcon: Icons.lock_outline,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                validator: (value) {
                  final v = (value ?? '').trim();
                  if (v.isEmpty) return 'CVV2 الزامی است';
                  if (v.length < 3 || v.length > 4)
                    return 'CVV2 باید ۳ یا ۴ رقم باشد';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _buildTextField(
                      controller: _expMonthController,
                      labelText: "ماه انقضا",
                      hintText: "MM",
                      prefixIcon: Icons.calendar_today_outlined,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                      validator: (value) {
                        final v = (value ?? '').trim();
                        if (v.isEmpty) return 'ماه الزامی است';
                        if (v.length != 2) return 'ماه باید دو رقمی باشد';
                        final m = int.tryParse(v);
                        if (m == null || m < 1 || m > 12)
                          return 'ماه نامعتبر (۱ تا ۱۲)';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _expYearController,
                      labelText: "سال انقضا",
                      hintText: "YY",
                      prefixIcon: Icons.calendar_today_outlined,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                      validator: (value) {
                        final v = (value ?? '').trim();
                        if (v.isEmpty) return 'سال الزامی است';
                        if (v.length != 2) return 'سال باید دو رقمی باشد';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _dynamicPasswordController,
                labelText: "رمز پویا",
                hintText: "6-8",
                prefixIcon: Icons.password_outlined,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                obscureText: true,
                validator: (value) {
                  final v = (value ?? '').trim();
                  if (v.isEmpty) return 'رمز پویا الزامی است';
                  if (v.length < 6 || v.length > 8)
                    return 'باید ۶ تا ۸ رقم باشد';
                  return null;
                },
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('رمز پویا به شماره شما ارسال شد')),
                    );
                  },
                  child: const Text("دریافت رمز پویا"),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildTextField(
                      controller: _captchaController,
                      labelText: "کد امنیتی",
                      hintText: "کد را وارد کنید",
                      prefixIcon: Icons.shield_outlined,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(5),
                      ],
                      validator: (value) {
                        final v = (value ?? '').trim();
                        if (v.isEmpty) return 'کد امنیتی الزامی است';
                        if (v != _captchaText) return 'کد امنیتی نادرست است';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.grey[600]!),
                      ),
                      child: Center(
                        child: Text(
                          _captchaText,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _refreshCaptcha,
                    tooltip: "بارگذاری مجدد کد",
                  ),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                ),
                child: Text(
                  "پرداخت",
                  style: TextStyle(fontSize: 18, color: colorScheme.onPrimary),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  "شما می‌توانید رمز اینترنتی را از برنامه همراه بانک دریافت نمایید.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
