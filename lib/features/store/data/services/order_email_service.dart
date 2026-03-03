import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

/// Service that sends a structured HTML order email to the fulfillment team
/// when a bracket-print order is approved.
///
/// Recipients:
///   1. jkim@acesusainc.com      — Apparel printer
///   2. ahmad@backmybracket.com  — BMB operations
///   3. amchi81@gmail.com        — BMB admin
///
/// Each email contains:
///   - Order ID
///   - Customer first & last name
///   - Street address, city, state, ZIP
///   - Product selected (poster, canvas, tee, mug)
///   - Size & color
///   - Bracket name, team count, bracket ID
///   - Timestamp
///   - Note to printer about vector file requirement
///
/// Delivery methods (in priority order):
///   1. EmailJS REST API (if service ID configured — production)
///   2. Custom backend endpoint (Firebase Functions / Node / Python)
///   3. mailto: URL launcher (fallback — opens user's email client)
class OrderEmailService {
  OrderEmailService._();
  static final OrderEmailService instance = OrderEmailService._();

  // ─── RECIPIENT LIST ───────────────────────────────────────────
  static const List<String> recipients = [
    'jkim@acesusainc.com',
    'ahmad@backmybracket.com',
    'amchi81@gmail.com',
  ];

  // ─── EMAIL API CONFIG ─────────────────────────────────────────
  // EmailJS (free tier: 200 emails/month — perfect for order volume)
  // Sign up at https://www.emailjs.com/
  // Create a service (Gmail/Outlook), create a template, get IDs
  static const String _emailJsServiceId = 'service_t3rddu7';
  static const String _emailJsTemplateId = 'template_pkbjssg';
  static const String _emailJsPublicKey = 'cPUSs-pHEvWJB39bE';

  // Custom backend endpoint (alternative to EmailJS)
  static const String _backendEmailEndpoint = ''; // e.g. 'https://us-central1-bmb-app.cloudfunctions.net/sendOrderEmail'

  /// Checks if EmailJS is configured.
  static bool get _hasEmailJs =>
      _emailJsServiceId.isNotEmpty &&
      _emailJsTemplateId.isNotEmpty &&
      _emailJsPublicKey.isNotEmpty;

  /// Checks if a custom backend endpoint is configured.
  static bool get _hasBackendEndpoint => _backendEmailEndpoint.isNotEmpty;

  // ─── ORDER DATA MODEL ─────────────────────────────────────────

  /// Sends the order confirmation email to all recipients.
  ///
  /// Returns `true` if at least one delivery method succeeded.
  Future<OrderEmailResult> sendOrderEmail({
    required String orderId,
    required String customerFirstName,
    required String customerLastName,
    required String streetAddress,
    required String city,
    required String state,
    required String zip,
    required String productName,
    required int creditsCost,
    required String bracketId,
    required String bracketName,
    required int teamCount,
    String? selectedSize,
    String? selectedColor,
    String? customerEmail,
    String? phoneNumber,
  }) async {
    final timestamp = DateFormat('MMM d, yyyy — h:mm a').format(DateTime.now());

    final orderData = OrderEmailData(
      orderId: orderId,
      customerFirstName: customerFirstName,
      customerLastName: customerLastName,
      streetAddress: streetAddress,
      city: city,
      state: state,
      zip: zip,
      productName: productName,
      creditsCost: creditsCost,
      bracketId: bracketId,
      bracketName: bracketName,
      teamCount: teamCount,
      selectedSize: selectedSize,
      selectedColor: selectedColor,
      customerEmail: customerEmail,
      phoneNumber: phoneNumber,
      timestamp: timestamp,
    );

    // Try delivery methods in priority order
    // 1. EmailJS
    if (_hasEmailJs) {
      final sent = await _sendViaEmailJs(orderData);
      if (sent) {
        return OrderEmailResult(success: true, method: 'emailjs');
      }
    }

    // 2. Custom backend
    if (_hasBackendEndpoint) {
      final sent = await _sendViaBackend(orderData);
      if (sent) {
        return OrderEmailResult(success: true, method: 'backend');
      }
    }

    // 3. Fallback: mailto URL
    final sent = await _sendViaMailto(orderData);
    return OrderEmailResult(
      success: sent,
      method: sent ? 'mailto' : 'none',
      fallbackUsed: true,
    );
  }

  // ─── EMAIL JS ─────────────────────────────────────────────────
  Future<bool> _sendViaEmailJs(OrderEmailData data) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': _emailJsServiceId,
          'template_id': _emailJsTemplateId,
          'user_id': _emailJsPublicKey,
          'template_params': {
            'to_emails': recipients.join(','),
            'subject': _buildSubject(data),
            'html_body': _buildHtmlBody(data),
            'order_id': data.orderId,
            'customer_name': '${data.customerFirstName} ${data.customerLastName}',
            'product_name': data.productName,
            'bracket_name': data.bracketName,
          },
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('EmailJS send failed: $e');
      return false;
    }
  }

  // ─── CUSTOM BACKEND ───────────────────────────────────────────
  Future<bool> _sendViaBackend(OrderEmailData data) async {
    try {
      final response = await http.post(
        Uri.parse(_backendEmailEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'recipients': recipients,
          'subject': _buildSubject(data),
          'html_body': _buildHtmlBody(data),
          'order_data': data.toMap(),
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('Backend email send failed: $e');
      return false;
    }
  }

  // ─── MAILTO FALLBACK ──────────────────────────────────────────
  Future<bool> _sendViaMailto(OrderEmailData data) async {
    try {
      final subject = _buildSubject(data);
      final body = _buildPlainTextBody(data);
      final uri = Uri(
        scheme: 'mailto',
        path: recipients.join(','),
        queryParameters: {
          'subject': subject,
          'body': body,
        },
      );
      return await launchUrl(uri);
    } catch (e) {
      if (kDebugMode) debugPrint('Mailto fallback failed: $e');
      return false;
    }
  }

  // ─── EMAIL CONTENT BUILDERS ───────────────────────────────────

  String _buildSubject(OrderEmailData d) {
    return 'BMB Print Order #${d.orderId} — ${d.productName} — ${d.customerFirstName} ${d.customerLastName}';
  }

  /// Beautiful HTML email body for the printer / fulfillment team.
  String _buildHtmlBody(OrderEmailData d) {
    final sizeRow = d.selectedSize != null
        ? '<tr><td style="padding:8px 12px;color:#888;font-size:13px;">Size</td><td style="padding:8px 12px;font-weight:600;font-size:14px;">${d.selectedSize}</td></tr>'
        : '';
    final colorRow = d.selectedColor != null
        ? '<tr><td style="padding:8px 12px;color:#888;font-size:13px;">Color</td><td style="padding:8px 12px;font-weight:600;font-size:14px;">${d.selectedColor}</td></tr>'
        : '';
    final emailRow = d.customerEmail != null
        ? '<tr><td style="padding:8px 12px;color:#888;font-size:13px;">Customer Email</td><td style="padding:8px 12px;font-weight:600;font-size:14px;">${d.customerEmail}</td></tr>'
        : '';
    final phoneRow = d.phoneNumber != null
        ? '<tr><td style="padding:8px 12px;color:#888;font-size:13px;">Phone</td><td style="padding:8px 12px;font-weight:600;font-size:14px;">${d.phoneNumber}</td></tr>'
        : '';

    return '''
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f4f4f7;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,'Helvetica Neue',Arial,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#f4f4f7;padding:24px 0;">
<tr><td align="center">
<table width="600" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:12px;box-shadow:0 2px 8px rgba(0,0,0,0.08);overflow:hidden;">

<!-- HEADER -->
<tr>
<td style="background:linear-gradient(135deg,#0A0E27 0%,#1E2651 100%);padding:28px 32px;text-align:center;">
  <h1 style="margin:0;color:#FFD700;font-size:22px;letter-spacing:1px;">BACK MY BRACKET</h1>
  <p style="margin:6px 0 0;color:#B0B8D4;font-size:13px;">Custom Print Order — Fulfillment Request</p>
</td>
</tr>

<!-- ORDER ID BANNER -->
<tr>
<td style="background:#FFD700;padding:14px 32px;text-align:center;">
  <span style="font-size:11px;color:#333;text-transform:uppercase;letter-spacing:2px;font-weight:700;">Order ID</span>
  <br/>
  <span style="font-size:20px;color:#0A0E27;font-weight:800;letter-spacing:1px;">${d.orderId}</span>
</td>
</tr>

<!-- CUSTOMER DETAILS -->
<tr>
<td style="padding:28px 32px 0;">
  <h2 style="margin:0 0 16px;font-size:16px;color:#0A0E27;border-bottom:2px solid #FFD700;padding-bottom:8px;">
    &#128100; Customer Information
  </h2>
  <table width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;">
    <tr><td style="padding:8px 12px;color:#888;font-size:13px;">First Name</td><td style="padding:8px 12px;font-weight:600;font-size:14px;">${d.customerFirstName}</td></tr>
    <tr style="background:#f9f9fb;"><td style="padding:8px 12px;color:#888;font-size:13px;">Last Name</td><td style="padding:8px 12px;font-weight:600;font-size:14px;">${d.customerLastName}</td></tr>
    <tr><td style="padding:8px 12px;color:#888;font-size:13px;">Street Address</td><td style="padding:8px 12px;font-weight:600;font-size:14px;">${d.streetAddress}</td></tr>
    <tr style="background:#f9f9fb;"><td style="padding:8px 12px;color:#888;font-size:13px;">City</td><td style="padding:8px 12px;font-weight:600;font-size:14px;">${d.city}</td></tr>
    <tr><td style="padding:8px 12px;color:#888;font-size:13px;">State</td><td style="padding:8px 12px;font-weight:600;font-size:14px;">${d.state}</td></tr>
    <tr style="background:#f9f9fb;"><td style="padding:8px 12px;color:#888;font-size:13px;">ZIP Code</td><td style="padding:8px 12px;font-weight:600;font-size:14px;">${d.zip}</td></tr>
    $emailRow
    $phoneRow
  </table>
</td>
</tr>

<!-- PRODUCT DETAILS -->
<tr>
<td style="padding:28px 32px 0;">
  <h2 style="margin:0 0 16px;font-size:16px;color:#0A0E27;border-bottom:2px solid #9C27B0;padding-bottom:8px;">
    &#128717; Product Details
  </h2>
  <table width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;">
    <tr><td style="padding:8px 12px;color:#888;font-size:13px;">Product</td><td style="padding:8px 12px;font-weight:600;font-size:14px;">${d.productName}</td></tr>
    <tr style="background:#f9f9fb;"><td style="padding:8px 12px;color:#888;font-size:13px;">Credits Charged</td><td style="padding:8px 12px;font-weight:600;font-size:14px;">${d.creditsCost} BMB credits</td></tr>
    $sizeRow
    $colorRow
  </table>
</td>
</tr>

<!-- BRACKET DETAILS -->
<tr>
<td style="padding:28px 32px 0;">
  <h2 style="margin:0 0 16px;font-size:16px;color:#0A0E27;border-bottom:2px solid #2137FF;padding-bottom:8px;">
    &#127942; Bracket Details
  </h2>
  <table width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;">
    <tr><td style="padding:8px 12px;color:#888;font-size:13px;">Bracket Name</td><td style="padding:8px 12px;font-weight:600;font-size:14px;">${d.bracketName}</td></tr>
    <tr style="background:#f9f9fb;"><td style="padding:8px 12px;color:#888;font-size:13px;">Bracket ID</td><td style="padding:8px 12px;font-weight:600;font-size:14px;font-family:monospace;">${d.bracketId}</td></tr>
    <tr><td style="padding:8px 12px;color:#888;font-size:13px;">Team Count</td><td style="padding:8px 12px;font-weight:600;font-size:14px;">${d.teamCount} teams</td></tr>
    <tr style="background:#f9f9fb;"><td style="padding:8px 12px;color:#888;font-size:13px;">Total Matchups</td><td style="padding:8px 12px;font-weight:600;font-size:14px;">${d.teamCount - 1} games</td></tr>
  </table>
</td>
</tr>

<!-- PRINTER NOTE -->
<tr>
<td style="padding:28px 32px;">
  <div style="background:#FFF8E1;border-left:4px solid #FFD700;border-radius:0 8px 8px 0;padding:16px 20px;">
    <h3 style="margin:0 0 8px;font-size:14px;color:#F57F17;">&#9888;&#65039; Note for Printer</h3>
    <p style="margin:0;font-size:13px;color:#555;line-height:1.6;">
      This order requires a <strong>vector file (.ai or .eps)</strong> of the customer's bracket picks.
      Please use <strong>Bracket ID: ${d.bracketId}</strong> to pull the bracket artwork from the BMB system.
      <br/><br/>
      The vector file with the customer's bracket selections will be provided separately by the BMB team.
      Do not begin printing until the vector file is received and approved.
    </p>
  </div>
</td>
</tr>

<!-- ORDER TIMESTAMP -->
<tr>
<td style="padding:0 32px 28px;text-align:center;">
  <p style="margin:0;font-size:12px;color:#999;">
    Order placed: ${d.timestamp}
  </p>
</td>
</tr>

<!-- FOOTER -->
<tr>
<td style="background:#0A0E27;padding:20px 32px;text-align:center;">
  <p style="margin:0;color:#FFD700;font-size:12px;font-weight:600;">BACK MY BRACKET</p>
  <p style="margin:4px 0 0;color:#7A82A1;font-size:11px;">backmybracket.com &bull; Custom Bracket Prints</p>
</td>
</tr>

</table>
</td></tr>
</table>
</body>
</html>
''';
  }

  /// Plain-text body for mailto fallback.
  String _buildPlainTextBody(OrderEmailData d) {
    final sb = StringBuffer();
    sb.writeln('═══════════════════════════════════════════');
    sb.writeln('   BACK MY BRACKET — CUSTOM PRINT ORDER');
    sb.writeln('═══════════════════════════════════════════');
    sb.writeln('');
    sb.writeln('ORDER ID: ${d.orderId}');
    sb.writeln('Date: ${d.timestamp}');
    sb.writeln('');
    sb.writeln('─── CUSTOMER INFORMATION ───');
    sb.writeln('First Name: ${d.customerFirstName}');
    sb.writeln('Last Name:  ${d.customerLastName}');
    sb.writeln('Address:    ${d.streetAddress}');
    sb.writeln('City:       ${d.city}');
    sb.writeln('State:      ${d.state}');
    sb.writeln('ZIP Code:   ${d.zip}');
    if (d.customerEmail != null) sb.writeln('Email:      ${d.customerEmail}');
    if (d.phoneNumber != null) sb.writeln('Phone:      ${d.phoneNumber}');
    sb.writeln('');
    sb.writeln('─── PRODUCT DETAILS ───');
    sb.writeln('Product:  ${d.productName}');
    sb.writeln('Credits:  ${d.creditsCost} BMB credits');
    if (d.selectedSize != null) sb.writeln('Size:     ${d.selectedSize}');
    if (d.selectedColor != null) sb.writeln('Color:    ${d.selectedColor}');
    sb.writeln('');
    sb.writeln('─── BRACKET DETAILS ───');
    sb.writeln('Bracket:      ${d.bracketName}');
    sb.writeln('Bracket ID:   ${d.bracketId}');
    sb.writeln('Team Count:   ${d.teamCount} teams');
    sb.writeln('Matchups:     ${d.teamCount - 1} games');
    sb.writeln('');
    sb.writeln('─── NOTE FOR PRINTER ───');
    sb.writeln('This order requires a VECTOR FILE (.ai or .eps) of the');
    sb.writeln('customer\'s bracket picks. Use Bracket ID: ${d.bracketId}');
    sb.writeln('to pull the bracket artwork from the BMB system.');
    sb.writeln('');
    sb.writeln('The vector file will be provided separately by BMB.');
    sb.writeln('Do NOT begin printing until the vector file is received.');
    sb.writeln('');
    sb.writeln('═══════════════════════════════════════════');
    sb.writeln('   backmybracket.com — Custom Bracket Prints');
    sb.writeln('═══════════════════════════════════════════');
    return sb.toString();
  }
}

// ─── DATA MODEL ───────────────────────────────────────────────────

class OrderEmailData {
  final String orderId;
  final String customerFirstName;
  final String customerLastName;
  final String streetAddress;
  final String city;
  final String state;
  final String zip;
  final String productName;
  final int creditsCost;
  final String bracketId;
  final String bracketName;
  final int teamCount;
  final String? selectedSize;
  final String? selectedColor;
  final String? customerEmail;
  final String? phoneNumber;
  final String timestamp;

  const OrderEmailData({
    required this.orderId,
    required this.customerFirstName,
    required this.customerLastName,
    required this.streetAddress,
    required this.city,
    required this.state,
    required this.zip,
    required this.productName,
    required this.creditsCost,
    required this.bracketId,
    required this.bracketName,
    required this.teamCount,
    this.selectedSize,
    this.selectedColor,
    this.customerEmail,
    this.phoneNumber,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'order_id': orderId,
    'customer_first_name': customerFirstName,
    'customer_last_name': customerLastName,
    'street_address': streetAddress,
    'city': city,
    'state': state,
    'zip': zip,
    'product_name': productName,
    'credits_cost': creditsCost,
    'bracket_id': bracketId,
    'bracket_name': bracketName,
    'team_count': teamCount,
    'selected_size': selectedSize,
    'selected_color': selectedColor,
    'customer_email': customerEmail,
    'phone_number': phoneNumber,
    'timestamp': timestamp,
  };
}

// ─── RESULT MODEL ────────────────────────────────────────────────

class OrderEmailResult {
  final bool success;
  final String method; // 'emailjs', 'backend', 'mailto', 'none'
  final bool fallbackUsed;

  const OrderEmailResult({
    required this.success,
    required this.method,
    this.fallbackUsed = false,
  });
}
