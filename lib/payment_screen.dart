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
  String _captchaText = "۷۸۳۶۰";
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _refreshCaptcha();
  }

  void _refreshCaptcha() {
    setState(() {
      _captchaText = (_random.nextInt(90000) + 10000).toString();
    });
    print("کد امنیتی رفرش شد. کد جدید: $_captchaText");
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

  void _processPayment() {
    print("پردازش پرداخت برای ${widget.itemName} - مبلغ: ${widget.amount}");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'پرداخت برای "${widget.itemName}" با موفقیت انجام شد! (شبیه‌سازی)')),
    );
    Navigator.of(context).pop(true);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    IconData? prefixIcon,
    TextInputType keyboardType = TextInputType.number,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    String? Function(String?)? validator,
    bool obscureText = false,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      textAlign: (Localizations.localeOf(context).languageCode == 'fa' &&
              keyboardType == TextInputType.number)
          ? TextAlign.right
          : TextAlign.left,
      textDirection: (Localizations.localeOf(context).languageCode == 'fa' &&
              keyboardType == TextInputType.number)
          ? TextDirection.ltr
          : TextDirection.ltr,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: Colors.grey[600])
            : null,
      ),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      validator: validator,
      obscureText: obscureText,
      style: TextStyle(color: theme.colorScheme.onSurface),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(' پرداخت برای: ${widget.itemName}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildTextField(
                controller: _cardNumberController,
                labelText: "شماره کارت",
                hintText: "xxxx-xxxx-xxxx-xxxx",
                prefixIcon: Icons.credit_card,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16)
                ],
                validator: (value) =>
                    (value?.isEmpty ?? true) ? 'شماره کارت الزامی است' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _cvv2Controller,
                labelText: "CVV2",
                hintText: "xxx",
                prefixIcon: Icons.lock_outline,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4)
                ],
                validator: (value) =>
                    (value?.isEmpty ?? true) ? 'CVV2 الزامی است' : null,
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
                        LengthLimitingTextInputFormatter(2)
                      ],
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'الزامی';
                        final month = int.tryParse(value!);
                        if (month == null || month < 1 || month > 12)
                          return 'نامعتبر';
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
                        LengthLimitingTextInputFormatter(2)
                      ],
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'الزامی';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _dynamicPasswordController,
                labelText: "رمز پویا (OTP)",
                hintText: "رمز پویا را وارد کنید",
                prefixIcon: Icons.password_outlined,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8)
                ],
                obscureText: true,
                validator: (value) =>
                    (value?.isEmpty ?? true) ? 'رمز پویا الزامی است' : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    print("درخواست رمز پویا");
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'رمز پویا به شماره شما ارسال شد (شبیه‌سازی)')));
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
                      keyboardType: TextInputType.text,
                      inputFormatters: [LengthLimitingTextInputFormatter(5)],
                      validator: (value) => (value?.isEmpty ?? true)
                          ? 'کد امنیتی الزامی است'
                          : null,
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
                          border: Border.all(color: Colors.grey[600]!)),
                      child: Center(
                        child: Text(
                          _captchaText,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _refreshCaptcha,
                    tooltip: "بارگذاری مجدد کد",
                  )
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
              )
            ],
          ),
        ),
      ),
    );
  }
}
