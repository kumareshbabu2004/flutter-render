import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:bmb_mobile/features/bracket_print/data/models/print_product.dart';
import 'package:bmb_mobile/features/bracket_print/data/services/merch_preview_service.dart';
import 'package:bmb_mobile/core/config/app_config.dart';

/// Service that delivers print-ready bracket orders to the local print shop.
///
/// ## Architecture
///
///   Flutter App  --(1)-->  MerchPreviewService  (server renders SVG + PNG)
///                --(2)-->  PrintShopDeliveryService  (this service)
///                            |
///                            +--> EmailJS API  (primary)
///                            +--> Merch Server /deliver-to-printer  (secondary)
///                            +--> mailto: URL launcher  (fallback)
///                            |
///                            v
///                    Print Shop inbox
///                      - jkim@acesusainc.com (printer)
///                      - ahmad@backmybracket.com (ops)
///                      - amchi81@gmail.com (admin)
///
/// ## Email Contents
///
/// Each order email includes:
///   - Order ID, timestamp
///   - Product: title, colour, size, print style
///   - Bracket: title, team count, champion, all picks
///   - Shipping: name, full address, email, phone
///   - Pricing breakdown
///   - **Direct download links** to print-ready files:
///     - bracket.svg (vector for DTG RIP)
///     - print_ready_rgb.png (300 DPI RGB raster)
///     - print_ready_cmyk.pdf (CMYK for offset — if available)
///     - preview.jpg (garment mockup for visual reference)
///   - Garment colour and palette (light/dark)
///   - Note for printer with instructions
///
/// ## Delivery Confirmation
///
/// Returns a [PrintShopDeliveryResult] with:
///   - success: whether at least one delivery channel succeeded
///   - method: which channel was used
///   - serverDeliveryId: if the server accepted the delivery request
class PrintShopDeliveryService {
  PrintShopDeliveryService._();
  static final PrintShopDeliveryService instance = PrintShopDeliveryService._();

  static const String _tag = 'PrintShopDelivery';

  // ─── RECIPIENT LIST ─────────────────────────────────────────
  static const List<String> printerRecipients = [
    'jkim@acesusainc.com',       // Apparel printer (Aces USA)
    'ahmad@backmybracket.com',   // BMB operations
    'amchi81@gmail.com',         // BMB admin
  ];

  // ─── EmailJS CONFIG ─────────────────────────────────────────
  // Same EmailJS account as the store order flow.
  static const String _emailJsServiceId = 'service_t3rddu7';
  static const String _emailJsTemplateId = 'template_pkbjssg';
  static const String _emailJsPublicKey = 'cPUSs-pHEvWJB39bE';

  static bool get _hasEmailJs =>
      _emailJsServiceId.isNotEmpty &&
      _emailJsTemplateId.isNotEmpty &&
      _emailJsPublicKey.isNotEmpty;

  // ─── Merch Server base URL ──────────────────────────────────
  static String get _merchBaseUrl => AppConfig.merchServerBaseUrl;

  // ═══════════════════════════════════════════════════════════════
  // PUBLIC: DELIVER ORDER TO PRINT SHOP
  // ═══════════════════════════════════════════════════════════════

  /// Deliver a completed bracket-print order to the local print shop.
  ///
  /// This is the single entry point. Call it after
  /// [BracketPrintOrderService.submitOrder] succeeds.
  ///
  /// [previewResult] carries the server-generated file URLs
  /// (SVG, RGB PNG, CMYK PDF, preview JPEG) returned from
  /// [MerchPreviewService.generatePreview].
  ///
  /// Returns a [PrintShopDeliveryResult] indicating whether the
  /// delivery succeeded and which method was used.
  Future<PrintShopDeliveryResult> deliverOrder({
    required BracketPrintOrder order,
    required List<String> teams,
    required PreviewResult previewResult,
  }) async {
    _log('deliverOrder → order=${order.orderId}  '
        'artifact=${previewResult.artifactId}');

    // Build the delivery payload
    final payload = _PrintShopPayload(
      order: order,
      teams: teams,
      previewResult: previewResult,
      timestamp: DateFormat('MMM d, yyyy — h:mm a').format(DateTime.now()),
    );

    // ── Channel 1: Merch Server /deliver-to-printer ──────────
    // The server already has the files; it can email them with
    // attachments (SendGrid) or drop them to an SFTP folder.
    final serverResult = await _deliverViaServer(payload);
    if (serverResult != null && serverResult.success) {
      _log('deliverOrder ← SERVER OK  '
          'deliveryId=${serverResult.serverDeliveryId}');
      return serverResult;
    }

    // ── Channel 2: EmailJS REST API ──────────────────────────
    if (_hasEmailJs) {
      final emailSent = await _deliverViaEmailJs(payload);
      if (emailSent) {
        _log('deliverOrder ← EMAILJS OK');
        return PrintShopDeliveryResult(
          success: true,
          method: 'emailjs',
          recipientCount: printerRecipients.length,
        );
      }
    }

    // ── Channel 3: mailto: fallback ──────────────────────────
    final mailtoSent = await _deliverViaMailto(payload);
    _log('deliverOrder ← MAILTO ${mailtoSent ? "OK" : "FAILED"}');
    return PrintShopDeliveryResult(
      success: mailtoSent,
      method: mailtoSent ? 'mailto' : 'none',
      recipientCount: mailtoSent ? printerRecipients.length : 0,
      fallbackUsed: true,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CHANNEL 1: MERCH SERVER /deliver-to-printer
  // ═══════════════════════════════════════════════════════════════

  /// Ask the merch server to deliver print files directly.
  ///
  /// POST /deliver-to-printer
  /// Body: { orderId, artifactId, productId, colorName, size,
  ///         shippingAddress, recipients[] }
  ///
  /// The server:
  ///   1. Loads pre-generated files by artifactId
  ///   2. Creates a packing slip PDF
  ///   3. Sends email with attachments to all recipients
  ///   4. Returns { deliveryId, status, filesSent[] }
  Future<PrintShopDeliveryResult?> _deliverViaServer(
    _PrintShopPayload payload,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_merchBaseUrl/deliver-to-printer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'orderId': payload.order.orderId,
          'artifactId': payload.previewResult.artifactId,
          'productId': payload.order.product.id,
          'productTitle': payload.order.product.shortTitle,
          'colorName': payload.order.selectedColor.name,
          'size': payload.order.selectedSize,
          'printStyle': payload.order.printStyle.name,
          'bracketTitle': payload.order.bracketTitle,
          'championName': payload.order.championName,
          'teamCount': payload.order.teamCount,
          'teams': payload.teams,
          'picks': payload.order.picks,
          'palette': payload.order.selectedColor.isDark ? 'light' : 'dark',
          'shipping': {
            'name': payload.order.shippingName,
            'address': payload.order.shippingAddress,
            'city': payload.order.shippingCity,
            'state': payload.order.shippingState,
            'zip': payload.order.shippingZip,
            'email': payload.order.shippingEmail,
            'phone': payload.order.shippingPhone,
          },
          'pricing': {
            'subtotal': payload.order.subtotal,
            'shipping': payload.order.shippingCost,
            'tax': payload.order.tax,
            'total': payload.order.total,
          },
          'recipients': printerRecipients,
          // File URLs from the preview result (server can also load by artifactId)
          'fileUrls': {
            'svg': payload.previewResult.svgUrl,
            'printReadyRgb': payload.previewResult.printReadyRgbUrl,
            'printReadyCmyk': payload.previewResult.printReadyCmykUrl,
            'preview': payload.previewResult.previewUrl,
          },
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return PrintShopDeliveryResult(
          success: true,
          method: 'server',
          serverDeliveryId: json['deliveryId'] as String?,
          recipientCount: printerRecipients.length,
          filesSent: (json['filesSent'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(),
        );
      }
      _log('Server deliver returned ${response.statusCode}: ${response.body}');
    } catch (e) {
      _log('Server deliver failed: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════
  // CHANNEL 2: EMAILJS REST API
  // ═══════════════════════════════════════════════════════════════

  Future<bool> _deliverViaEmailJs(_PrintShopPayload payload) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': _emailJsServiceId,
          'template_id': _emailJsTemplateId,
          'user_id': _emailJsPublicKey,
          'template_params': {
            'to_emails': printerRecipients.join(','),
            'subject': _buildSubject(payload),
            'html_body': _buildHtmlBody(payload),
            'order_id': payload.order.orderId,
            'customer_name': payload.order.shippingName,
            'product_name': payload.order.product.shortTitle,
            'bracket_name': payload.order.bracketTitle,
          },
        }),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      _log('EmailJS send failed: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // CHANNEL 3: MAILTO FALLBACK
  // ═══════════════════════════════════════════════════════════════

  Future<bool> _deliverViaMailto(_PrintShopPayload payload) async {
    try {
      final uri = Uri(
        scheme: 'mailto',
        path: printerRecipients.join(','),
        queryParameters: {
          'subject': _buildSubject(payload),
          'body': _buildPlainTextBody(payload),
        },
      );
      return await launchUrl(uri);
    } catch (e) {
      _log('Mailto fallback failed: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // EMAIL CONTENT: SUBJECT
  // ═══════════════════════════════════════════════════════════════

  String _buildSubject(_PrintShopPayload p) {
    return '[BMB Print Order #${p.order.orderId}] '
        '${p.order.product.shortTitle} — '
        '${p.order.selectedColor.name} ${p.order.selectedSize} — '
        '${p.order.bracketTitle}';
  }

  // ═══════════════════════════════════════════════════════════════
  // EMAIL CONTENT: HTML BODY
  // ═══════════════════════════════════════════════════════════════

  String _buildHtmlBody(_PrintShopPayload p) {
    final order = p.order;
    final pr = p.previewResult;

    // Build file links section
    final fileLinks = StringBuffer();
    if (pr.svgUrl != null && pr.svgUrl!.isNotEmpty) {
      fileLinks.write(
          '<tr><td style="padding:8px 12px;color:#888;font-size:13px;">Vector SVG</td>'
          '<td style="padding:8px 12px;"><a href="${pr.svgUrl}" style="color:#2137FF;font-weight:600;font-size:13px;text-decoration:none;">&#x2B73; Download bracket.svg</a></td></tr>');
    }
    if (pr.printReadyRgbUrl != null && pr.printReadyRgbUrl!.isNotEmpty) {
      fileLinks.write(
          '<tr style="background:#f9f9fb;"><td style="padding:8px 12px;color:#888;font-size:13px;">Print-Ready PNG (300 DPI RGB)</td>'
          '<td style="padding:8px 12px;"><a href="${pr.printReadyRgbUrl}" style="color:#2137FF;font-weight:600;font-size:13px;text-decoration:none;">&#x2B73; Download print_ready_rgb.png</a></td></tr>');
    }
    if (pr.printReadyCmykUrl != null && pr.printReadyCmykUrl!.isNotEmpty) {
      fileLinks.write(
          '<tr><td style="padding:8px 12px;color:#888;font-size:13px;">Print-Ready PDF (CMYK)</td>'
          '<td style="padding:8px 12px;"><a href="${pr.printReadyCmykUrl}" style="color:#2137FF;font-weight:600;font-size:13px;text-decoration:none;">&#x2B73; Download print_ready_cmyk.pdf</a></td></tr>');
    }
    if (pr.previewUrl.isNotEmpty) {
      fileLinks.write(
          '<tr style="background:#f9f9fb;"><td style="padding:8px 12px;color:#888;font-size:13px;">Mockup Preview</td>'
          '<td style="padding:8px 12px;"><a href="${pr.previewUrl}" style="color:#2137FF;font-weight:600;font-size:13px;text-decoration:none;">&#x1F441; View preview.jpg</a></td></tr>');
    }

    // If artifact ID exists, add the universal download endpoint
    if (pr.artifactId != null && pr.artifactId!.isNotEmpty) {
      final allFilesUrl = '$_merchBaseUrl/artifacts/${pr.artifactId}';
      fileLinks.write(
          '<tr><td style="padding:8px 12px;color:#888;font-size:13px;">All Files (ZIP)</td>'
          '<td style="padding:8px 12px;"><a href="$allFilesUrl" style="color:#2137FF;font-weight:600;font-size:13px;text-decoration:none;">&#x1F4E6; Download all files</a></td></tr>');
    }

    // Build team matchups (first 8 teams shown; rest truncated)
    final teamList = p.teams.take(16).join(' vs ').replaceAll(' vs ', ' &bull; ');
    final teamOverflow = p.teams.length > 16
        ? ' <em style="color:#999;">+${p.teams.length - 16} more</em>'
        : '';

    return '''
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f4f4f7;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,'Helvetica Neue',Arial,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#f4f4f7;padding:24px 0;">
<tr><td align="center">
<table width="620" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:12px;box-shadow:0 2px 8px rgba(0,0,0,0.08);overflow:hidden;">

<!-- HEADER -->
<tr>
<td style="background:linear-gradient(135deg,#0A0E27 0%,#1E2651 100%);padding:28px 32px;text-align:center;">
  <h1 style="margin:0;color:#FFD700;font-size:24px;letter-spacing:1px;">BACK MY BRACKET</h1>
  <p style="margin:6px 0 0;color:#B0B8D4;font-size:13px;">Print Shop Fulfillment Order</p>
</td>
</tr>

<!-- ORDER ID BANNER -->
<tr>
<td style="background:#FFD700;padding:14px 32px;text-align:center;">
  <span style="font-size:11px;color:#333;text-transform:uppercase;letter-spacing:2px;font-weight:700;">Order ID</span>
  <br/>
  <span style="font-size:22px;color:#0A0E27;font-weight:800;letter-spacing:1px;">${order.orderId}</span>
</td>
</tr>

<!-- PRINT-READY FILES -->
<tr>
<td style="padding:28px 32px 0;">
  <h2 style="margin:0 0 16px;font-size:16px;color:#0A0E27;border-bottom:2px solid #D63031;padding-bottom:8px;">
    &#128424; Print-Ready Files
  </h2>
  <div style="background:#FFF8E1;border-left:4px solid #FFD700;border-radius:0 8px 8px 0;padding:12px 16px;margin-bottom:12px;">
    <p style="margin:0;font-size:12px;color:#555;line-height:1.5;">
      <strong>Artifact ID:</strong> <code style="background:#f0f0f0;padding:2px 6px;border-radius:3px;font-size:11px;">${pr.artifactId ?? 'N/A'}</code>
    </p>
  </div>
  <table width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;">
    $fileLinks
  </table>
</td>
</tr>

<!-- PRODUCT DETAILS -->
<tr>
<td style="padding:28px 32px 0;">
  <h2 style="margin:0 0 16px;font-size:16px;color:#0A0E27;border-bottom:2px solid #9C27B0;padding-bottom:8px;">
    &#128085; Product &amp; Print Specifications
  </h2>
  <table width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;">
    <tr><td style="padding:8px 12px;color:#888;font-size:13px;">Garment</td><td style="padding:8px 12px;font-weight:600;font-size:14px;">${order.product.title}</td></tr>
    <tr style="background:#f9f9fb;"><td style="padding:8px 12px;color:#888;font-size:13px;">Color</td><td style="padding:8px 12px;font-weight:600;font-size:14px;">${order.selectedColor.name} (${order.selectedColor.hexCode})</td></tr>
    <tr><td style="padding:8px 12px;color:#888;font-size:13px;">Size</td><td style="padding:8px 12px;font-weight:600;font-size:14px;">${order.selectedSize}</td></tr>
    <tr style="background:#f9f9fb;"><td style="padding:8px 12px;color:#888;font-size:13px;">Print Style</td><td style="padding:8px 12px;font-weight:600;font-size:14px;">${order.printStyle.displayName} — Full back print</td></tr>
    <tr><td style="padding:8px 12px;color:#888;font-size:13px;">Bracket Palette</td><td style="padding:8px 12px;font-weight:600;font-size:14px;">${order.selectedColor.isDark ? 'Light on Dark (white/gold on dark fabric)' : 'Dark on Light (navy/blue on light fabric)'}</td></tr>
    <tr style="background:#f9f9fb;"><td style="padding:8px 12px;color:#888;font-size:13px;">Print Area</td><td style="padding:8px 12px;font-weight:600;font-size:14px;">${order.product.resolvedPrintAreas.physicalWidthInches}" x ${order.product.resolvedPrintAreas.physicalHeightInches}" (${order.product.resolvedPrintAreas.printWidthPx} x ${order.product.resolvedPrintAreas.printHeightPx} px @ 300 DPI)</td></tr>
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
    <tr><td style="padding:8px 12px;color:#888;font-size:13px;">Bracket Title</td><td style="padding:8px 12px;font-weight:600;font-size:14px;">${order.bracketTitle}</td></tr>
    <tr style="background:#f9f9fb;"><td style="padding:8px 12px;color:#888;font-size:13px;">Champion</td><td style="padding:8px 12px;font-weight:600;font-size:14px;color:#D63031;">${order.championName}</td></tr>
    <tr><td style="padding:8px 12px;color:#888;font-size:13px;">Team Count</td><td style="padding:8px 12px;font-weight:600;font-size:14px;">${order.teamCount} teams (${order.teamCount - 1} matchups)</td></tr>
    <tr style="background:#f9f9fb;"><td style="padding:8px 12px;color:#888;font-size:13px;">Teams</td><td style="padding:8px 12px;font-size:12px;line-height:1.5;">$teamList$teamOverflow</td></tr>
  </table>
</td>
</tr>

<!-- SHIPPING -->
<tr>
<td style="padding:28px 32px 0;">
  <h2 style="margin:0 0 16px;font-size:16px;color:#0A0E27;border-bottom:2px solid #4CAF50;padding-bottom:8px;">
    &#128666; Shipping Details
  </h2>
  <table width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;">
    <tr><td style="padding:8px 12px;color:#888;font-size:13px;">Ship To</td><td style="padding:8px 12px;font-weight:600;font-size:14px;">${order.shippingName}</td></tr>
    <tr style="background:#f9f9fb;"><td style="padding:8px 12px;color:#888;font-size:13px;">Address</td><td style="padding:8px 12px;font-size:13px;">${order.shippingAddress}<br/>${order.shippingCity}, ${order.shippingState} ${order.shippingZip}</td></tr>
    <tr><td style="padding:8px 12px;color:#888;font-size:13px;">Email</td><td style="padding:8px 12px;font-size:13px;">${order.shippingEmail}</td></tr>
    <tr style="background:#f9f9fb;"><td style="padding:8px 12px;color:#888;font-size:13px;">Phone</td><td style="padding:8px 12px;font-size:13px;">${order.shippingPhone}</td></tr>
    <tr><td style="padding:8px 12px;color:#888;font-size:13px;">Shipping Method</td><td style="padding:8px 12px;font-weight:600;font-size:14px;">${order.shippingCost > 6.0 ? 'Express (2-3 days)' : order.shippingCost == 0 ? 'Free Standard (5-7 days)' : 'Standard (5-7 days)'}</td></tr>
  </table>
</td>
</tr>

<!-- PRICING -->
<tr>
<td style="padding:28px 32px 0;">
  <h2 style="margin:0 0 16px;font-size:16px;color:#0A0E27;border-bottom:2px solid #FFD700;padding-bottom:8px;">
    &#128176; Order Pricing
  </h2>
  <table width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;">
    <tr><td style="padding:6px 12px;color:#888;font-size:13px;">Garment Base</td><td style="padding:6px 12px;text-align:right;font-size:13px;">\$${order.product.basePrice.toStringAsFixed(2)}</td></tr>
    <tr style="background:#f9f9fb;"><td style="padding:6px 12px;color:#888;font-size:13px;">Bracket Print</td><td style="padding:6px 12px;text-align:right;font-size:13px;">+\$${order.product.bracketPrintUpcharge.toStringAsFixed(2)}</td></tr>
    <tr><td style="padding:6px 12px;color:#888;font-size:13px;">Shipping</td><td style="padding:6px 12px;text-align:right;font-size:13px;">${order.shippingCost == 0 ? 'FREE' : '\$${order.shippingCost.toStringAsFixed(2)}'}</td></tr>
    <tr style="background:#f9f9fb;"><td style="padding:6px 12px;color:#888;font-size:13px;">Tax</td><td style="padding:6px 12px;text-align:right;font-size:13px;">\$${order.tax.toStringAsFixed(2)}</td></tr>
    <tr><td style="padding:10px 12px;font-weight:700;font-size:15px;color:#0A0E27;border-top:2px solid #FFD700;">TOTAL</td><td style="padding:10px 12px;text-align:right;font-weight:800;font-size:16px;color:#0A0E27;border-top:2px solid #FFD700;">\$${order.total.toStringAsFixed(2)}</td></tr>
  </table>
</td>
</tr>

<!-- PRINTER INSTRUCTIONS -->
<tr>
<td style="padding:28px 32px;">
  <div style="background:#FFF8E1;border-left:4px solid #FFD700;border-radius:0 8px 8px 0;padding:16px 20px;">
    <h3 style="margin:0 0 10px;font-size:14px;color:#F57F17;">&#9888;&#65039; Printer Instructions</h3>
    <ol style="margin:0;padding-left:18px;font-size:13px;color:#555;line-height:1.7;">
      <li>Download the <strong>SVG file</strong> above for the DTG RIP software.</li>
      <li>Use the <strong>300 DPI RGB PNG</strong> as a visual reference for colour accuracy.</li>
      <li>Print on the <strong>BACK</strong> of the garment only — full print area.</li>
      <li>Garment colour: <strong>${order.selectedColor.name}</strong> — bracket uses <strong>${order.selectedColor.isDark ? 'white/gold' : 'navy/dark'}</strong> ink palette.</li>
      <li>If files are missing or corrupt, re-fetch from artifact ID: <code style="background:#f0f0f0;padding:2px 6px;border-radius:3px;font-size:11px;">${pr.artifactId ?? order.orderId}</code></li>
    </ol>
  </div>
</td>
</tr>

<!-- TIMESTAMP -->
<tr>
<td style="padding:0 32px 28px;text-align:center;">
  <p style="margin:0;font-size:12px;color:#999;">
    Order placed: ${p.timestamp}
  </p>
</td>
</tr>

<!-- FOOTER -->
<tr>
<td style="background:#0A0E27;padding:20px 32px;text-align:center;">
  <p style="margin:0;color:#FFD700;font-size:12px;font-weight:600;">BACK MY BRACKET &mdash; PRINT FULFILLMENT</p>
  <p style="margin:4px 0 0;color:#7A82A1;font-size:11px;">backmybracket.com &bull; Custom Bracket Prints &bull; DTG Apparel</p>
</td>
</tr>

</table>
</td></tr>
</table>
</body>
</html>
''';
  }

  // ═══════════════════════════════════════════════════════════════
  // EMAIL CONTENT: PLAIN TEXT (mailto fallback)
  // ═══════════════════════════════════════════════════════════════

  String _buildPlainTextBody(_PrintShopPayload p) {
    final order = p.order;
    final pr = p.previewResult;
    final sb = StringBuffer();

    sb.writeln('═══════════════════════════════════════════════════');
    sb.writeln('   BACK MY BRACKET — PRINT SHOP FULFILLMENT ORDER');
    sb.writeln('═══════════════════════════════════════════════════');
    sb.writeln('');
    sb.writeln('ORDER ID: ${order.orderId}');
    sb.writeln('Date: ${p.timestamp}');
    sb.writeln('');

    sb.writeln('─── PRINT-READY FILES ───');
    if (pr.artifactId != null) {
      sb.writeln('Artifact ID: ${pr.artifactId}');
    }
    if (pr.svgUrl != null) sb.writeln('SVG Vector:      ${pr.svgUrl}');
    if (pr.printReadyRgbUrl != null) {
      sb.writeln('RGB PNG (300DPI): ${pr.printReadyRgbUrl}');
    }
    if (pr.printReadyCmykUrl != null) {
      sb.writeln('CMYK PDF:         ${pr.printReadyCmykUrl}');
    }
    if (pr.previewUrl.isNotEmpty) {
      sb.writeln('Preview:          ${pr.previewUrl}');
    }
    if (pr.artifactId != null) {
      sb.writeln('All Files:        $_merchBaseUrl/artifacts/${pr.artifactId}');
    }
    sb.writeln('');

    sb.writeln('─── PRODUCT & PRINT SPECS ───');
    sb.writeln('Garment:    ${order.product.title}');
    sb.writeln('Color:      ${order.selectedColor.name} (${order.selectedColor.hexCode})');
    sb.writeln('Size:       ${order.selectedSize}');
    sb.writeln('Style:      ${order.printStyle.displayName} — Full back print');
    sb.writeln('Palette:    ${order.selectedColor.isDark ? "Light on Dark" : "Dark on Light"}');
    sb.writeln('Print Area: ${order.product.resolvedPrintAreas.physicalWidthInches}" x ${order.product.resolvedPrintAreas.physicalHeightInches}"');
    sb.writeln('');

    sb.writeln('─── BRACKET DETAILS ───');
    sb.writeln('Title:    ${order.bracketTitle}');
    sb.writeln('Champion: ${order.championName}');
    sb.writeln('Teams:    ${order.teamCount} teams (${order.teamCount - 1} matchups)');
    sb.writeln('');

    sb.writeln('─── SHIPPING ───');
    sb.writeln('Ship To:  ${order.shippingName}');
    sb.writeln('Address:  ${order.shippingAddress}');
    sb.writeln('          ${order.shippingCity}, ${order.shippingState} ${order.shippingZip}');
    sb.writeln('Email:    ${order.shippingEmail}');
    sb.writeln('Phone:    ${order.shippingPhone}');
    sb.writeln('');

    sb.writeln('─── PRICING ───');
    sb.writeln('Base:     \$${order.product.basePrice.toStringAsFixed(2)}');
    sb.writeln('Print:    +\$${order.product.bracketPrintUpcharge.toStringAsFixed(2)}');
    sb.writeln('Shipping: ${order.shippingCost == 0 ? "FREE" : "\$${order.shippingCost.toStringAsFixed(2)}"}');
    sb.writeln('Tax:      \$${order.tax.toStringAsFixed(2)}');
    sb.writeln('TOTAL:    \$${order.total.toStringAsFixed(2)}');
    sb.writeln('');

    sb.writeln('─── PRINTER INSTRUCTIONS ───');
    sb.writeln('1. Download the SVG file for DTG RIP software.');
    sb.writeln('2. Print on the BACK of the garment only.');
    sb.writeln('3. Garment colour: ${order.selectedColor.name}');
    sb.writeln('4. Bracket ink: ${order.selectedColor.isDark ? "white/gold" : "navy/dark"} palette.');
    sb.writeln('5. If files are missing, use artifact ID: ${pr.artifactId ?? order.orderId}');
    sb.writeln('');
    sb.writeln('═══════════════════════════════════════════════════');
    sb.writeln('   backmybracket.com — Custom Bracket Prints');
    sb.writeln('═══════════════════════════════════════════════════');

    return sb.toString();
  }

  // ═══════════════════════════════════════════════════════════════
  // ORDER STATUS CHECK
  // ═══════════════════════════════════════════════════════════════

  /// Check the delivery/fulfillment status of a print order via
  /// the merch server.
  ///
  /// Returns a status map or null if unreachable.
  static Future<PrintShopOrderStatus?> checkOrderStatus(
    String orderId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.merchServerBaseUrl}/order-status/$orderId'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return PrintShopOrderStatus.fromJson(json);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[$_tag] checkOrderStatus failed: $e');
      }
    }
    return null;
  }

  // ─── LOGGING ─────────────────────────────────────────────────
  static void _log(String message) {
    if (kDebugMode) {
      debugPrint('[$_tag] $message');
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// INTERNAL PAYLOAD
// ═══════════════════════════════════════════════════════════════════

class _PrintShopPayload {
  final BracketPrintOrder order;
  final List<String> teams;
  final PreviewResult previewResult;
  final String timestamp;

  const _PrintShopPayload({
    required this.order,
    required this.teams,
    required this.previewResult,
    required this.timestamp,
  });
}

// ═══════════════════════════════════════════════════════════════════
// DELIVERY RESULT
// ═══════════════════════════════════════════════════════════════════

/// Result of attempting to deliver an order to the print shop.
class PrintShopDeliveryResult {
  /// Whether at least one delivery channel succeeded.
  final bool success;

  /// Which delivery method was used: 'server', 'emailjs', 'mailto', 'none'.
  final String method;

  /// If delivered via server, the server-assigned delivery tracking ID.
  final String? serverDeliveryId;

  /// Number of recipients the email was sent to.
  final int recipientCount;

  /// Whether the fallback (mailto) was used.
  final bool fallbackUsed;

  /// List of file names that the server confirmed as delivered.
  final List<String>? filesSent;

  /// Error message if delivery failed.
  final String? error;

  const PrintShopDeliveryResult({
    required this.success,
    required this.method,
    this.serverDeliveryId,
    this.recipientCount = 0,
    this.fallbackUsed = false,
    this.filesSent,
    this.error,
  });

  @override
  String toString() =>
      'PrintShopDeliveryResult(success=$success, method=$method, '
      'serverDeliveryId=$serverDeliveryId, recipients=$recipientCount, '
      'fallback=$fallbackUsed, files=${filesSent?.join(", ")})';
}

// ═══════════════════════════════════════════════════════════════════
// ORDER STATUS
// ═══════════════════════════════════════════════════════════════════

/// Status of a print order from the merch server.
class PrintShopOrderStatus {
  final String orderId;
  final String status; // pending, received, printing, shipped, delivered
  final String? trackingNumber;
  final String? carrier;
  final String? estimatedDelivery;
  final DateTime? lastUpdated;

  const PrintShopOrderStatus({
    required this.orderId,
    required this.status,
    this.trackingNumber,
    this.carrier,
    this.estimatedDelivery,
    this.lastUpdated,
  });

  factory PrintShopOrderStatus.fromJson(Map<String, dynamic> json) {
    return PrintShopOrderStatus(
      orderId: json['orderId'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      trackingNumber: json['trackingNumber'] as String?,
      carrier: json['carrier'] as String?,
      estimatedDelivery: json['estimatedDelivery'] as String?,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.tryParse(json['lastUpdated'] as String)
          : null,
    );
  }

  /// Human-friendly status label.
  String get displayStatus {
    switch (status) {
      case 'pending':
        return 'Order Received';
      case 'received':
        return 'Files Received by Printer';
      case 'printing':
        return 'Printing in Progress';
      case 'shipped':
        return 'Shipped';
      case 'delivered':
        return 'Delivered';
      default:
        return 'Processing';
    }
  }

  /// Status icon for display.
  String get statusIcon {
    switch (status) {
      case 'pending':
        return '📋';
      case 'received':
        return '✅';
      case 'printing':
        return '🖨️';
      case 'shipped':
        return '📦';
      case 'delivered':
        return '🎉';
      default:
        return '⏳';
    }
  }
}
