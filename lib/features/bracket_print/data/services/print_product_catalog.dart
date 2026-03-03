import 'package:flutter/material.dart';
import 'package:bmb_mobile/features/bracket_print/data/models/print_product.dart';

/// BMB Print Product Catalog — sourced from Shopify store.
/// Products can be toggled active/inactive without code changes.
class PrintProductCatalog {
  // ═══════════════════════════════════════════════════════════════════
  // COLOR DEFINITIONS — mapped from Shopify product variants
  // ═══════════════════════════════════════════════════════════════════

  static const _black = GarmentColor(
      name: 'Black', color: Color(0xFF000000), hexCode: '#000000', isDark: true);
  static const _graphiteHeather = GarmentColor(
      name: 'Graphite Heather', color: Color(0xFF4A4A4A), hexCode: '#4A4A4A', isDark: true);
  static const _vintageHeather = GarmentColor(
      name: 'Vintage Heather', color: Color(0xFFA3A3A3), hexCode: '#A3A3A3', isDark: false);
  static const _trueNavy = GarmentColor(
      name: 'True Navy', color: Color(0xFF1E3A5F), hexCode: '#1E3A5F', isDark: true);
  static const _trueRed = GarmentColor(
      name: 'True Red', color: Color(0xFFC81D25), hexCode: '#C81D25', isDark: true);
  static const _trueRoyal = GarmentColor(
      name: 'True Royal', color: Color(0xFF2457A5), hexCode: '#2457A5', isDark: true);
  // ── DM130 "Frost" tri-blend colours ─────────────────────────────
  // Hex values sourced from the official District DM130 swatch chart
  // to match actual fabric appearance (heathered/marled tri-blend).
  static const _blackFrost = GarmentColor(
      name: 'Black Frost', color: Color(0xFF2B2B2A), hexCode: '#2B2B2A', isDark: true);
  static const _heatherCharcoal = GarmentColor(
      name: 'Heather Charcoal', color: Color(0xFF555555), hexCode: '#555555', isDark: true);
  static const _greyHeather = GarmentColor(
      name: 'Grey Heather', color: Color(0xFF999999), hexCode: '#999999', isDark: false);
  static const _newNavy = GarmentColor(
      name: 'New Navy', color: Color(0xFF1B2A4A), hexCode: '#1B2A4A', isDark: true);
  static const _navyFrost = GarmentColor(
      name: 'Navy Frost', color: Color(0xFF2F3E53), hexCode: '#2F3E53', isDark: true);
  static const _royalFrost = GarmentColor(
      name: 'Royal Frost', color: Color(0xFF416F99), hexCode: '#416F99', isDark: true);
  static const _redFrost = GarmentColor(
      name: 'Red Frost', color: Color(0xFFC73A3B), hexCode: '#C73A3B', isDark: true);
  static const _maritimeFrost = GarmentColor(
      name: 'Maritime Frost', color: Color(0xFF648DA8), hexCode: '#648DA8', isDark: true);
  static const _blushFrost = GarmentColor(
      name: 'Blush Frost', color: Color(0xFFE69A9A), hexCode: '#E69A9A', isDark: false);
  static const _fuschiaFrost = GarmentColor(
      name: 'Fuschia Frost', color: Color(0xFFAF4A67), hexCode: '#AF4A67', isDark: true);
  static const _greenFrost = GarmentColor(
      name: 'Green Frost', color: Color(0xFF49965F), hexCode: '#49965F', isDark: true);
  static const _turquoiseFrost = GarmentColor(
      name: 'Turquoise Frost', color: Color(0xFF5DA7B4), hexCode: '#5DA7B4', isDark: false);
  static const _blackTwist = GarmentColor(
      name: 'Black Twist', color: Color(0xFF1A1A1A), hexCode: '#1A1A1A', isDark: true);
  static const _darkRoyalTwist = GarmentColor(
      name: 'Dark Royal Twist', color: Color(0xFF1A3A6B), hexCode: '#1A3A6B', isDark: true);
  static const _graphite = GarmentColor(
      name: 'Graphite', color: Color(0xFF555555), hexCode: '#555555', isDark: true);
  static const _ltGraphiteTwist = GarmentColor(
      name: 'Light Graphite Twist', color: Color(0xFF8A8A8A), hexCode: '#8A8A8A', isDark: false);
  static const _shadowGrey = GarmentColor(
      name: 'Shadow Grey', color: Color(0xFF6B6B6B), hexCode: '#6B6B6B', isDark: true);
  static const _blackHeather = GarmentColor(
      name: 'Black Heather', color: Color(0xFF2A2A2A), hexCode: '#2A2A2A', isDark: true);
  static const _royalHeather = GarmentColor(
      name: 'Royal Heather', color: Color(0xFF3A5A9B), hexCode: '#3A5A9B', isDark: true);
  static const _shadowGreyHeather = GarmentColor(
      name: 'Shadow Grey Heather', color: Color(0xFF7A7A7A), hexCode: '#7A7A7A', isDark: false);
  static const _softBeige = GarmentColor(
      name: 'Soft Beige', color: Color(0xFFE8D8C8), hexCode: '#E8D8C8', isDark: false);
  static const _trueNavyHeather = GarmentColor(
      name: 'True Navy Heather', color: Color(0xFF2A3A5A), hexCode: '#2A3A5A', isDark: true);

  // ═══════════════════════════════════════════════════════════════════
  // STANDARD SIZE LIST
  // ═══════════════════════════════════════════════════════════════════
  static const _stdSizes = ['XS', 'S', 'M', 'L', 'XL', '2X', '3X', '4X'];

  // ═══════════════════════════════════════════════════════════════════
  // PRODUCT CATALOG
  // ═══════════════════════════════════════════════════════════════════

  static final List<PrintProduct> _allProducts = [
    // ─── Product 1: Sport-Tek Grid Iron Tech Fleece Hoodie ──────
    PrintProduct(
      id: 'bp_grid_iron',
      shopifyId: '9208241586344',
      title: 'BMB - Sport-Tek Grid Iron Tech Fleece Hoodie',
      shortTitle: 'Grid Iron Hoodie',
      type: PrintProductType.hoodie,
      basePrice: 45.00,
      bracketPrintUpcharge: 15.00,
      colors: [_black, _graphiteHeather, _vintageHeather, _trueNavy, _trueRed, _trueRoyal],
      sizes: _stdSizes,
      frontImageUrl:
          'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/ST250-Blk-BMB-Print.png?v=1764016361',
      description: '7.1-oz, 100% polyester. Three-panel hood. Printed BMB Logo front.',
      canPrintBracket: true,
      backImageAsset: 'assets/garment_backs/st250_black_back.png',
      colorImageUrls: {
        'Black': 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/ST250-Blk-BMB-Print.png?v=1764016361',
        'Graphite Heather': 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/ST250-GrphtHthr-BMB-Print.png?v=1764016375',
        'Vintage Heather': 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/ST250-VtgHthr-BMB-Print.png?v=1764016388',
        'True Navy': 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/ST250-Nvy-BMB-Print.png?v=1764016411',
        'True Red': 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/ST250-Red-BMB-Print.png?v=1764016422',
        'True Royal': 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/ST250-Ryl-BMB-Print.png?v=1764016438',
      },
      // ── Schema v3: colour strategy ──
      colorStrategy: ColorStrategy.exactMockup,
      colorMockups: {
        'Black': ColorMockups(frontUrl: 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/ST250-Blk-BMB-Print.png?v=1764016361'),
        'Graphite Heather': ColorMockups(frontUrl: 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/ST250-GrphtHthr-BMB-Print.png?v=1764016375'),
        'Vintage Heather': ColorMockups(frontUrl: 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/ST250-VtgHthr-BMB-Print.png?v=1764016388'),
        'True Navy': ColorMockups(frontUrl: 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/ST250-Nvy-BMB-Print.png?v=1764016411'),
        'True Red': ColorMockups(frontUrl: 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/ST250-Red-BMB-Print.png?v=1764016422'),
        'True Royal': ColorMockups(frontUrl: 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/ST250-Ryl-BMB-Print.png?v=1764016438'),
      },
      // ── Schema v2: structured mockups + print areas ──
      mockups: ProductMockups(
        front: MockupImage(
          localFile: null,
          fallbackUrl: 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/ST250-Blk-BMB-Print.png?v=1764016361',
        ),
        back: MockupImage(
          localFile: 'assets/garment_backs/st250_black_back.png',
          fallbackUrl: 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/ST250-Blk-BMB-Print.png?v=1764016361',
        ),
      ),
      printAreas: ProductPrintAreas(
        front: PrintAreaRect(x: 0.22, y: 0.28, w: 0.56, h: 0.40),
        back:  PrintAreaRect(x: 0.18, y: 0.30, w: 0.64, h: 0.52),
        physicalWidthInches: 11.0,
        physicalHeightInches: 13.0,
      ),
      defaultPreviewView: 'back',
      printOn: PrintOn(front: false, back: true),
    ),

    // ─── Product 2: Perfect Tri Tee ─────────────────────────────
    PrintProduct(
      id: 'bp_tri_tee',
      shopifyId: '9202022514856',
      title: 'BMB - Perfect Tri Tee',
      shortTitle: 'Perfect Tri Tee',
      type: PrintProductType.tShirt,
      basePrice: 20.00,
      bracketPrintUpcharge: 12.00,
      colors: [
        _black, _blackFrost, _heatherCharcoal, _greyHeather, _newNavy,
        _navyFrost, _royalFrost, _redFrost, _maritimeFrost, _blushFrost,
        _fuschiaFrost, _greenFrost, _turquoiseFrost,
      ],
      sizes: _stdSizes,
      frontImageUrl:
          'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/DM130DTG-BLK-BMB_Print_2aabe22c-f983-4653-91b7-53bea6453096.png?v=1763586395',
      description: '4.9-oz, 50/25/25 poly/combed ring spun/rayon. Printed BMB Logo.',
      canPrintBracket: true,
      backImageAsset: 'assets/garment_backs/dm130_black_back.png',
      // ── Schema v3: colour strategy (tintBase — only Black CDN available) ──
      colorStrategy: ColorStrategy.tintBase,
      colorMockups: const {},
      // ── Per-colour hex overrides sourced from DM130 vendor swatch chart ──
      // These override GarmentColor.hexCode for tint accuracy so that
      // "Royal Frost" looks like Royal Frost, not "bluish black".
      colorHexByName: const {
        'Black':             '#000000',  // base colour — no tint applied
        'Black Frost':       '#2B2B2A',
        'Heather Charcoal':  '#555555',
        'Grey Heather':      '#8A8C8E',
        'New Navy':          '#1B2A4A',
        'Navy Frost':        '#2F3E53',
        'Royal Frost':       '#416F99',
        'Red Frost':         '#C73A3B',
        'Maritime Frost':    '#648DA8',
        'Blush Frost':       '#E69A9A',
        'Fuschia Frost':     '#AF4A67',
        'Green Frost':       '#49965F',
        'Turquoise Frost':   '#5DA7B4',
      },
      tintAlpha: kTintBaseAlpha, // 0.72 — tuned for DM130 tri-blend fabric
      // ── Schema v2: structured mockups + print areas ──
      mockups: ProductMockups(
        front: MockupImage(
          localFile: null,
          fallbackUrl: 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/DM130DTG-BLK-BMB_Print_2aabe22c-f983-4653-91b7-53bea6453096.png?v=1763586395',
        ),
        back: MockupImage(
          localFile: 'assets/garment_backs/dm130_black_back.png',
          fallbackUrl: 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/DM130DTG-BLK-BMB_Print_2aabe22c-f983-4653-91b7-53bea6453096.png?v=1763586395',
        ),
      ),
      printAreas: ProductPrintAreas(
        front: PrintAreaRect(x: 0.22, y: 0.22, w: 0.56, h: 0.48),
        back:  PrintAreaRect(x: 0.20, y: 0.22, w: 0.60, h: 0.56),
        physicalWidthInches: 12.0,
        physicalHeightInches: 14.0,
      ),
      defaultPreviewView: 'back',
      printOn: PrintOn(front: false, back: true),
    ),

    // ─── Product 3: New Era Street Lounge French Terry Hoodie ───
    PrintProduct(
      id: 'bp_street_lounge',
      shopifyId: '9202019598504',
      title: 'BMB - New Era Street Lounge French Terry Hoodie',
      shortTitle: 'Street Lounge Hoodie',
      type: PrintProductType.hoodie,
      basePrice: 55.00,
      bracketPrintUpcharge: 15.00,
      colors: [_black, _blackTwist, _darkRoyalTwist, _graphite, _ltGraphiteTwist, _trueNavy],
      sizes: _stdSizes,
      frontImageUrl:
          'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA500-Black-BMB_EMB.png?v=1763679839',
      description: '9.4-oz, 52/48 cotton/poly French Terry. Embroidered BMB Logo.',
      canPrintBracket: true,
      backImageAsset: 'assets/garment_backs/nea500_black_back.png',
      colorImageUrls: {
        'Black': 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA500-Black-BMB_EMB.png?v=1763679839',
        'Black Twist': 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA500-BlackTwist-BMB_EMB.png?v=1763680302',
        'Light Graphite Twist': 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA500-LtGrphtTwst-BMB_EMB.png?v=1763680415',
        'Dark Royal Twist': 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA500-RylTwst-BMB_EMB.png?v=1763680494',
        'Graphite': 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA500-Grpht-BMB_EMB.png?v=1763680750',
        'True Navy': 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA500-Navy-BMB_EMB.png?v=1763680765',
      },
      // ── Schema v3: colour strategy ──
      colorStrategy: ColorStrategy.exactMockup,
      colorMockups: {
        'Black': ColorMockups(frontUrl: 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA500-Black-BMB_EMB.png?v=1763679839'),
        'Black Twist': ColorMockups(frontUrl: 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA500-BlackTwist-BMB_EMB.png?v=1763680302'),
        'Light Graphite Twist': ColorMockups(frontUrl: 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA500-LtGrphtTwst-BMB_EMB.png?v=1763680415'),
        'Dark Royal Twist': ColorMockups(frontUrl: 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA500-RylTwst-BMB_EMB.png?v=1763680494'),
        'Graphite': ColorMockups(frontUrl: 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA500-Grpht-BMB_EMB.png?v=1763680750'),
        'True Navy': ColorMockups(frontUrl: 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA500-Navy-BMB_EMB.png?v=1763680765'),
      },
      // ── Schema v2: structured mockups + print areas ──
      mockups: ProductMockups(
        front: MockupImage(
          localFile: null,
          fallbackUrl: 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA500-Black-BMB_EMB.png?v=1763679839',
        ),
        back: MockupImage(
          localFile: 'assets/garment_backs/nea500_black_back.png',
          fallbackUrl: 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA500-Black-BMB_EMB.png?v=1763679839',
        ),
      ),
      printAreas: ProductPrintAreas(
        front: PrintAreaRect(x: 0.22, y: 0.28, w: 0.56, h: 0.40),
        back:  PrintAreaRect(x: 0.18, y: 0.30, w: 0.64, h: 0.52),
        physicalWidthInches: 11.0,
        physicalHeightInches: 13.0,
      ),
      defaultPreviewView: 'back',
      printOn: PrintOn(front: false, back: true),
    ),

    // ─── Product 4: New Era On The Go Tri-Blend Hoodie ──────────
    PrintProduct(
      id: 'bp_on_the_go',
      shopifyId: '9202016387240',
      title: 'BMB - New Era On The Go Tri-Blend Hoodie',
      shortTitle: 'On The Go Hoodie',
      type: PrintProductType.hoodie,
      basePrice: 45.00,
      bracketPrintUpcharge: 15.00,
      colors: [_black, _graphite, _shadowGrey, _trueNavy],
      sizes: _stdSizes,
      frontImageUrl:
          'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA137-Blk-BMBPrint.png?v=1763681258',
      description: '4-oz, 55/34/11 cotton/poly/rayon. Printed BMB Logo.',
      canPrintBracket: true,
      backImageAsset: 'assets/garment_backs/nea137_black_back.png',
      colorImageUrls: {
        'Black': 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA137-Blk-BMBPrint.png?v=1763681258',
        'Graphite': 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA137-Grpht-BMBPrint.png?v=1763681664',
        'True Navy': 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA137-Navy-BMBPrint.png?v=1763681680',
        'Shadow Grey': 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA137-ShdwGry-BMBPrint.png?v=1763681717',
      },
      // ── Schema v3: colour strategy ──
      colorStrategy: ColorStrategy.exactMockup,
      colorMockups: {
        'Black': ColorMockups(frontUrl: 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA137-Blk-BMBPrint.png?v=1763681258'),
        'Graphite': ColorMockups(frontUrl: 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA137-Grpht-BMBPrint.png?v=1763681664'),
        'True Navy': ColorMockups(frontUrl: 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA137-Navy-BMBPrint.png?v=1763681680'),
        'Shadow Grey': ColorMockups(frontUrl: 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA137-ShdwGry-BMBPrint.png?v=1763681717'),
      },
      // ── Schema v2: structured mockups + print areas ──
      mockups: ProductMockups(
        front: MockupImage(
          localFile: null,
          fallbackUrl: 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA137-Blk-BMBPrint.png?v=1763681258',
        ),
        back: MockupImage(
          localFile: 'assets/garment_backs/nea137_black_back.png',
          fallbackUrl: 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA137-Blk-BMBPrint.png?v=1763681258',
        ),
      ),
      printAreas: ProductPrintAreas(
        front: PrintAreaRect(x: 0.22, y: 0.28, w: 0.56, h: 0.40),
        back:  PrintAreaRect(x: 0.18, y: 0.30, w: 0.64, h: 0.52),
        physicalWidthInches: 11.0,
        physicalHeightInches: 13.0,
      ),
      defaultPreviewView: 'back',
      printOn: PrintOn(front: false, back: true),
    ),

    // ─── Product 5: New Era All Day Tri-Blend Fleece Hoodie ─────
    PrintProduct(
      id: 'bp_all_day',
      shopifyId: '9201709580456',
      title: 'BMB - New Era All Day Tri-Blend Fleece Hoodie',
      shortTitle: 'All Day Hoodie',
      type: PrintProductType.hoodie,
      basePrice: 55.00,
      bracketPrintUpcharge: 15.00,
      colors: [_blackHeather, _royalHeather, _shadowGreyHeather, _softBeige, _trueNavyHeather],
      sizes: _stdSizes,
      frontImageUrl:
          'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA510-Black_Heather-BMB_PRINT_36b0a2af-33d2-48b7-9f01-ce4d8495ad7f.png?v=1763585903',
      description: '7.1-oz, 55/34/11 cotton/poly/rayon. Printed BMB Logo.',
      canPrintBracket: true,
      backImageAsset: 'assets/garment_backs/nea510_blackheather_back.png',
      colorImageUrls: {
        'Soft Beige': 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA510-Soft_Beige-BMB_PRINT_b3e22505-0688-4379-b4ad-811582f0b091.png?v=1763585819',
        'Royal Heather': 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA510-Royal_Heather-BMB_PRINT.png?v=1763585819',
        'True Navy Heather': 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA510-Navy_Heather-BMB_PRINT_d6ff134d-3363-444b-956e-4b2733a86d32.png?v=1763585819',
        'Shadow Grey Heather': 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA510-Shadow_Grey_Heather-BMB_PRINT_6bc5d009-4640-40ff-af8b-d65d6138e062.png?v=1763585819',
        'Black Heather': 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA510-Black_Heather-BMB_PRINT_36b0a2af-33d2-48b7-9f01-ce4d8495ad7f.png?v=1763585903',
      },
      // ── Schema v3: colour strategy ──
      colorStrategy: ColorStrategy.exactMockup,
      colorMockups: {
        'Black Heather': ColorMockups(frontUrl: 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA510-Black_Heather-BMB_PRINT_36b0a2af-33d2-48b7-9f01-ce4d8495ad7f.png?v=1763585903'),
        'Royal Heather': ColorMockups(frontUrl: 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA510-Royal_Heather-BMB_PRINT.png?v=1763585819'),
        'Shadow Grey Heather': ColorMockups(frontUrl: 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA510-Shadow_Grey_Heather-BMB_PRINT_6bc5d009-4640-40ff-af8b-d65d6138e062.png?v=1763585819'),
        'Soft Beige': ColorMockups(frontUrl: 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA510-Soft_Beige-BMB_PRINT_b3e22505-0688-4379-b4ad-811582f0b091.png?v=1763585819'),
        'True Navy Heather': ColorMockups(frontUrl: 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA510-Navy_Heather-BMB_PRINT_d6ff134d-3363-444b-956e-4b2733a86d32.png?v=1763585819'),
      },
      // ── Schema v2: structured mockups + print areas ──
      mockups: ProductMockups(
        front: MockupImage(
          localFile: null,
          fallbackUrl: 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA510-Black_Heather-BMB_PRINT_36b0a2af-33d2-48b7-9f01-ce4d8495ad7f.png?v=1763585903',
        ),
        back: MockupImage(
          localFile: 'assets/garment_backs/nea510_blackheather_back.png',
          fallbackUrl: 'https://cdn.shopify.com/s/files/1/0729/9206/3656/files/NEA510-Black_Heather-BMB_PRINT_36b0a2af-33d2-48b7-9f01-ce4d8495ad7f.png?v=1763585903',
        ),
      ),
      printAreas: ProductPrintAreas(
        front: PrintAreaRect(x: 0.22, y: 0.28, w: 0.56, h: 0.40),
        back:  PrintAreaRect(x: 0.18, y: 0.30, w: 0.64, h: 0.52),
        physicalWidthInches: 11.0,
        physicalHeightInches: 13.0,
      ),
      defaultPreviewView: 'back',
      printOn: PrintOn(front: false, back: true),
    ),
  ];

  /// Get all bracket-printable products.
  static List<PrintProduct> get printableProducts =>
      _allProducts.where((p) => p.canPrintBracket).toList();

  /// Get all products (including accessories).
  static List<PrintProduct> get allProducts => List.unmodifiable(_allProducts);

  /// Get a product by internal ID.
  static PrintProduct? getById(String id) {
    try {
      return _allProducts.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get a product by Shopify ID.
  static PrintProduct? getByShopifyId(String shopifyId) {
    try {
      return _allProducts.firstWhere((p) => p.shopifyId == shopifyId);
    } catch (_) {
      return null;
    }
  }

  /// Shipping options.
  static const standardShipping = 5.99;
  static const expressShipping = 12.99;
  static const freeShippingThreshold = 100.0;
  static const taxRate = 0.0825; // 8.25% (Texas default, adjust per state)
}
