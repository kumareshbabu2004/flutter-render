// ═══════════════════════════════════════════════════════════════════════════
// STRIPE PAYMENT LINKS CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════
//
// HOW TO USE:
// 1. Log into your Stripe Dashboard → Payment Links
// 2. Create a Payment Link for each product / subscription below
// 3. Paste the URL next to the corresponding key
// 4. That's it — zero code changes required!
//
// CREATING A PAYMENT LINK:
//   stripe.com/dashboard → Payment Links → + New
//   → Select product or create new → Set price & billing → Copy URL
//
// Subscription links = Recurring pricing in Stripe
// One-time links     = One-time pricing in Stripe
//
// ═══════════════════════════════════════════════════════════════════════════

class StripeConfig {
  StripeConfig._(); // prevent instantiation

  // ─── BMB+ INDIVIDUAL ─────────────────────────────────────────────────

  /// BMB+ Monthly — $9.99/month (Recurring)
  /// Unlocks hosting, saving, sharing, and earning from tournaments
  static const String bmbPlusMonthly = 'https://buy.stripe.com/3cI4gAahTbVe9gv8GM6Zy00';

  /// BMB+ Yearly — $99.99/year (Recurring annual)
  /// Same features as monthly, billed once per year — save ~17%
  static const String bmbPlusYearly = 'https://buy.stripe.com/9B69AU61D0cw78ncX26Zy01';

  // ─── BMB+ VIP ADD-ON ─────────────────────────────────────────────────

  /// BMB+ VIP — $2/month add-on (Recurring)
  /// Priority bracket visibility — like SEO for your brackets
  static const String bmbPlusVipMonthly = 'https://buy.stripe.com/3cIfZiblX5wQgIX2io6Zy05';

  // ─── BMB+biz BUSINESS ────────────────────────────────────────────────

  /// BMB+biz Monthly — $99/month (Recurring)
  /// Full business hosting package for bars, restaurants & venues
  static const String bmbBizMonthly = 'https://buy.stripe.com/eVqeVe0Hj6AU3WbcX26Zy06';

  /// BMB+biz Yearly — $899/year (Recurring annual)
  /// Same features as monthly, billed once per year — save ~24%
  static const String bmbBizYearly = 'https://buy.stripe.com/3cI7sM75Hf7q50f7CI6Zy04';

  // ─── BMB CREDITS ($0.12/credit PRICING) ────────────────────────────

  /// Starter — 50 credits for $6 (One-time)
  static const String buxStarter50 = 'https://buy.stripe.com/cNi28s75HaRagIX2io6Zy0b';

  /// Popular — 100 credits for $12 (One-time)
  static const String buxPopular100 = 'https://buy.stripe.com/fZu6oI61Dgbu50f9KQ6Zy0c';

  /// Value — 250 credits for $30 (One-time)
  static const String buxValue250 = 'https://buy.stripe.com/14A8wQfCdaRaakz6yE6Zy0d';

  /// Pro — 500 credits for $60 (One-time)
  static const String buxPro500 = 'https://buy.stripe.com/3cI3cw0Hj9N6gIX8GM6Zy0e';

  /// Whale — 1000 credits for $120 (One-time, best value)
  static const String buxWhale1000 = 'https://buy.stripe.com/00wbJ29dP9N678n5uA6Zy0f';

  // ─── MERCH / STORE PRODUCTS ───────────────────────────────────────────

  /// BMB Starter Kit — business kit (posters, sweatshirts, table tents, QR codes)
  static const String bmbStarterKit = '';
  // Example: 'https://buy.stripe.com/your_starter_kit_link'

  /// Generic merch checkout — send customer to BMB store
  static const String bmbStoreUrl = 'https://backmybracket.com/store';

  // ═══════════════════════════════════════════════════════════════════════
  // CONFIGURABLE PRICING — update these if you change prices in Stripe
  // These are display-only; the actual charge is set in your Stripe link.
  // ═══════════════════════════════════════════════════════════════════════

  // BMB+ Individual
  static const double bmbPlusMonthlyPrice = 9.99;
  static const double bmbPlusYearlyPrice = 99.99;

  // BMB+ VIP Add-on
  static const double bmbVipMonthlyPrice = 2.0;

  // BMB+biz Business
  static const double bmbBizMonthlyPrice = 99.0;
  static const double bmbBizYearlyPrice = 899.0;

  // ─── HELPER METHODS ───────────────────────────────────────────────────

  /// Returns the Payment Link URL for a credit package tier index (0–4).
  static String buxPackageLink(int tierIndex) {
    switch (tierIndex) {
      case 0:
        return buxStarter50;
      case 1:
        return buxPopular100;
      case 2:
        return buxValue250;
      case 3:
        return buxPro500;
      case 4:
        return buxWhale1000;
      default:
        return '';
    }
  }

  /// Check whether a specific link has been configured yet.
  static bool isConfigured(String link) => link.isNotEmpty;

  /// Returns true when at least one subscription link is live.
  static bool get hasAnySubscriptionLink =>
      isConfigured(bmbPlusMonthly) ||
      isConfigured(bmbPlusYearly) ||
      isConfigured(bmbPlusVipMonthly) ||
      isConfigured(bmbBizMonthly) ||
      isConfigured(bmbBizYearly);

  /// Returns true when at least one credit-purchase link is live.
  static bool get hasAnyCreditLink =>
      isConfigured(buxStarter50) ||
      isConfigured(buxPopular100) ||
      isConfigured(buxValue250) ||
      isConfigured(buxPro500) ||
      isConfigured(buxWhale1000);
}
