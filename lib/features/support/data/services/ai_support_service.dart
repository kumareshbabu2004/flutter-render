import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// AI-powered support service with BMB knowledge base, intent matching,
/// and escalation to tech support tickets.
class AiSupportService {
  AiSupportService._();
  static final instance = AiSupportService._();

  final _rng = Random();

  // ── TICKET DESTINATION (primary) ────────────────────────────────────
  // Secondary backup address is stored server-side only — never in UI.
  static const _primarySupportEmail = 'tech@backmybracket.com';

  // ── TICKET STORAGE ─────────────────────────────────────────────────
  final List<SupportTicket> _tickets = [];
  List<SupportTicket> get tickets => List.unmodifiable(_tickets);

  // ── KNOWLEDGE BASE ─────────────────────────────────────────────────
  // Each entry: (keywords[], answer)
  static final List<_KBEntry> _knowledgeBase = [
    // Joining / Entry
    _KBEntry(
      keywords: ['join', 'enter', 'sign up', 'bracket', 'participate'],
      answer:
          'To join a bracket, tap "Join Now" on any live bracket from the Home tab. '
          'Free brackets let you join instantly. Credit-based brackets require '
          'credits from your BMB Bucket. You\'ll always see a confirmation before '
          'any credits are deducted.',
    ),
    // BMB Bucket / Credits
    _KBEntry(
      keywords: ['bucket', 'credits', 'buy credits', 'purchase', 'balance', 'payment'],
      answer:
          'Your BMB Bucket holds your credits. Purchase them via credit card, '
          'Apple Pay, or Google Pay. Credits are used for bracket contributions, '
          'rewards, and the BMB Store. You can also turn on Auto-Replenish to '
          'automatically add 10 credits when your bucket drops to 10 or below.',
    ),
    // Hosting
    _KBEntry(
      keywords: ['host', 'create bracket', 'tournament', 'bracket builder', 'build'],
      answer:
          'Any user can build brackets using the Bracket Builder (tap the "+" button). '
          'However, saving, sharing, and hosting tournaments requires a BMB+ membership. '
          'As a host, you set the rules, contribution amount, and reward structure.',
    ),
    // BMB+
    _KBEntry(
      keywords: ['bmb plus', 'bmb+', 'premium', 'membership', 'subscription', 'upgrade'],
      answer:
          'BMB+ is our premium membership. Members get unlimited tournaments, '
          'revenue sharing, analytics, a premium badge, and priority support. '
          'You can upgrade from the Profile menu or the in-app upgrade prompts.',
    ),
    // Chat
    _KBEntry(
      keywords: ['chat', 'message', 'conversation', 'talk'],
      answer:
          'Each tournament has a private chat room. Tap the chat bubble icon on '
          'any bracket card. Community Chat is available for general discussions, '
          'bracket shoutouts, trivia, and giveaways.',
    ),
    // Winners / Prize
    _KBEntry(
      keywords: ['winner', 'prize', 'reward', 'champion', 'payout', 'credits awarded'],
      answer:
          'Winners are determined by the bracket host. Once all games are complete, '
          'the host must tap "Confirm Winner & Award Credits" in the Results Manager. '
          'Reward credits are NOT distributed until the host explicitly confirms. '
          'Custom rewards (dinners, merch, experiences) are also awarded through the host.',
    ),
    // Store
    _KBEntry(
      keywords: ['store', 'gift card', 'merch', 'merchandise', 'redeem', 'shop'],
      answer:
          'The BMB Store lets you redeem credits for real products: digital gift cards '
          '(Amazon, Visa, DoorDash, Starbucks, Nike, Uber Eats), BMB merchandise, '
          'digital items (avatar frames, bracket themes), and custom bracket products '
          '(posters, canvases, t-shirts, mugs with your picks).',
    ),
    // Gift cards
    _KBEntry(
      keywords: ['gift card', 'code', 'redemption', 'amazon', 'visa'],
      answer:
          'Gift card codes are delivered instantly to your in-app inbox after redemption. '
          'You can copy the code and use it at the respective merchant. Codes are also '
          'saved in your order history for safekeeping.',
    ),
    // Profile / Settings
    _KBEntry(
      keywords: ['profile', 'settings', 'account', 'display name', 'edit', 'photo', 'avatar'],
      answer:
          'Go to Profile tab > Account Settings to change your display name, address, '
          'and state abbreviation. For your profile photo, select "Profile Photo" from '
          'the profile menu to choose from our avatar collection.',
    ),
    // Transfers
    _KBEntry(
      keywords: ['transfer', 'send credits', 'give credits', 'gift'],
      answer:
          'Credits CANNOT be exchanged, sent, gifted, or transferred between users '
          'under any circumstances. All credit movements happen exclusively between '
          'individual users and the BMB platform. This is stated in our Terms of Service.',
    ),
    // Not enough credits
    _KBEntry(
      keywords: ['not enough', 'insufficient', 'low balance', 'need more credits'],
      answer:
          'If you don\'t have enough credits, you\'ll see a "Fill My Bucket" prompt. '
          'If Auto-Replenish is enabled and your balance drops to 10 or below, credits '
          'are purchased automatically. You can also manually add credits from the BMB Bucket screen.',
    ),
    // Gambling / Legal
    _KBEntry(
      keywords: ['gambling', 'legal', 'cash out', 'real money', 'cash'],
      answer:
          'BMB is NOT a gambling platform. It\'s entertainment and skill-based. '
          'Credits are virtual with no real-world monetary value and cannot be converted '
          'to cash. There are no peer-to-peer transfers, no cash-out, and all outcomes '
          'are skill-based, not chance-based.',
    ),
    // Giveaway
    _KBEntry(
      keywords: ['giveaway', 'spin', 'spinner', 'free credits', 'bonus'],
      answer:
          'Giveaways are hosted within bracket tournaments. When a host triggers a giveaway, '
          'all eligible participants are entered. The spinner selects a winner who receives '
          'bonus credits instantly. Results are announced in the Community Chat.',
    ),
    // Squares
    _KBEntry(
      keywords: ['squares', 'squares game', 'grid', 'football squares'],
      answer:
          'Squares is our classic grid game. Pick your squares, and scores from '
          'real games determine winners each quarter. Access Squares from the profile '
          'menu or the Squares Hub on the dashboard.',
    ),
    // Favorites
    _KBEntry(
      keywords: ['favorite', 'team', 'athlete', 'alert', 'notification'],
      answer:
          'Set your favorite teams and athletes in My Favorites (Profile menu > My Favorites '
          'or Account Settings). Toggle Score Alerts on/off to receive breaking news, '
          'injury updates, and live score notifications for your favorites.',
    ),
    // Referral
    _KBEntry(
      keywords: ['refer', 'referral', 'invite', 'friend'],
      answer:
          'Share your referral link from Profile menu > Refer a Friend. When your friend '
          'signs up and joins their first bracket, you both receive bonus credits!',
    ),
    // Refund
    _KBEntry(
      keywords: ['refund', 'cancel', 'money back', 'return'],
      answer:
          'Bracket contributions are refundable until the first game starts. After that, '
          'credits are locked in. For BMB+ subscription issues, contact us through this '
          'chat and we\'ll escalate to our tech team.',
    ),
    // Password / Login
    _KBEntry(
      keywords: ['password', 'login', 'sign in', 'forgot', 'reset', 'locked out'],
      answer:
          'If you\'re having trouble logging in, try resetting your password from the '
          'login screen. If you\'re still locked out, I can create a tech support ticket '
          'for our team to help you regain access. Just say "create a ticket".',
    ),
    // Bug / Error
    _KBEntry(
      keywords: ['bug', 'error', 'crash', 'broken', 'not working', 'glitch', 'freeze', 'issue'],
      answer:
          'Sorry to hear you\'re experiencing an issue! I can create a tech support ticket '
          'so our engineering team can investigate. Just describe the problem and say '
          '"create a ticket" or tap the escalate button below.',
    ),
    // Custom rewards
    _KBEntry(
      keywords: ['custom reward', 'dinner', 'sneakers', 'backpack', 'jersey', 'experience'],
      answer:
          'Custom rewards are special prizes set by bracket hosts — things like dinners '
          'with athletes, rare sneakers, Patagonia backpacks, signed jerseys, and more. '
          'They appear on the bracket card and detail page. Winners are contacted by the '
          'host to arrange delivery/pickup.',
    ),
    // VIP
    _KBEntry(
      keywords: ['vip', 'vip boost', 'featured'],
      answer:
          'VIP Boosted brackets get premium placement on the dashboard with a purple glow. '
          'Hosts with BMB+ can boost brackets for increased visibility. VIP status shows '
          'a diamond badge on the bracket card.',
    ),
    // Leaderboard
    _KBEntry(
      keywords: ['leaderboard', 'ranking', 'rank', 'score', 'points'],
      answer:
          'Every bracket has a live leaderboard showing participant rankings based on '
          'correct picks. Access it from the bracket detail page. Top performers get '
          'bragging rights and any prize credits set by the host!',
    ),
  ];

  // ── GREETING ───────────────────────────────────────────────────────
  static const List<String> _greetings = [
    'Hey there! I\'m BMB Support Bot. How can I help you today?',
    'Welcome to BMB Support! What can I help you with?',
    'Hi! I\'m here to help with anything Back My Bracket related. What\'s up?',
  ];

  String get greeting => _greetings[_rng.nextInt(_greetings.length)];

  // ── INTENT MATCHING ────────────────────────────────────────────────
  /// Returns an AI response for the user's message.
  /// If no match, suggests creating a ticket.
  Future<AiResponse> getResponse(String userMessage) async {
    // Simulate AI "thinking" time
    await Future.delayed(Duration(milliseconds: 800 + _rng.nextInt(1200)));

    final lower = userMessage.toLowerCase().trim();

    // Check for explicit ticket request
    if (_wantsTicket(lower)) {
      return AiResponse(
        message: 'Absolutely! I\'ll help you create a tech support ticket. '
            'Please describe your issue in the form below and our team will '
            'get back to you within 24 hours.',
        action: AiAction.showTicketForm,
      );
    }

    // Check for greeting
    if (_isGreeting(lower)) {
      return AiResponse(
        message: 'Hey! I can help with brackets, credits, the BMB Store, '
            'account settings, giveaways, and more. What do you need help with?',
      );
    }

    // Check for thank you
    if (_isThankYou(lower)) {
      return AiResponse(
        message: 'You\'re welcome! Is there anything else I can help with? '
            'If not, have an awesome day and enjoy your brackets!',
      );
    }

    // Match against knowledge base
    final match = _findBestMatch(lower);
    if (match != null) {
      return AiResponse(
        message: match.answer,
        followUp: 'Did that answer your question? If not, I can create a '
            'tech support ticket for our team to look into it.',
      );
    }

    // No match — offer escalation
    return AiResponse(
      message: 'Hmm, I\'m not sure about that one. I can create a tech support '
          'ticket so our team can help you directly. Would you like me to do that?',
      action: AiAction.suggestTicket,
    );
  }

  bool _wantsTicket(String msg) {
    return msg.contains('ticket') ||
        msg.contains('escalate') ||
        msg.contains('real person') ||
        msg.contains('human') ||
        msg.contains('agent') ||
        msg.contains('tech support') ||
        msg.contains('email support') ||
        msg.contains('talk to someone');
  }

  bool _isGreeting(String msg) {
    return msg == 'hi' ||
        msg == 'hey' ||
        msg == 'hello' ||
        msg == 'yo' ||
        msg == 'sup' ||
        msg.startsWith('hi ') ||
        msg.startsWith('hey ') ||
        msg.startsWith('hello ');
  }

  bool _isThankYou(String msg) {
    return msg.contains('thank') ||
        msg.contains('thanks') ||
        msg.contains('thx') ||
        msg.contains('appreciate') ||
        msg == 'ty';
  }

  _KBEntry? _findBestMatch(String msg) {
    int bestScore = 0;
    _KBEntry? bestEntry;

    for (final entry in _knowledgeBase) {
      int score = 0;
      for (final kw in entry.keywords) {
        if (msg.contains(kw)) {
          // Longer keywords get higher scores
          score += kw.length;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestEntry = entry;
      }
    }
    // Require a minimum match threshold
    return bestScore >= 3 ? bestEntry : null;
  }

  // ── TICKET SUBMISSION ──────────────────────────────────────────────
  /// Submits a tech support ticket. Returns ticket ID.
  Future<String> submitTicket({
    required String subject,
    required String description,
    required String userEmail,
    String? userName,
    String? category,
    List<String> chatHistory = const [],
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));

    final ticketId = 'BMB-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final ticket = SupportTicket(
      id: ticketId,
      subject: subject,
      description: description,
      userEmail: userEmail,
      userName: userName,
      category: category ?? 'General',
      chatHistory: chatHistory,
      createdAt: DateTime.now(),
      status: TicketStatus.open,
      sentTo: _primarySupportEmail,
    );

    _tickets.add(ticket);
    await _persistTicket(ticket);

    return ticketId;
  }

  Future<void> _persistTicket(SupportTicket ticket) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList('bmb_support_tickets') ?? [];
    existing.add('${ticket.id}|${ticket.subject}|${ticket.status.name}|${ticket.createdAt.toIso8601String()}');
    await prefs.setStringList('bmb_support_tickets', existing);
  }

  /// Suggested quick topics for the chat
  static const List<String> quickTopics = [
    'How do I join a bracket?',
    'My credits are missing',
    'How does the store work?',
    'I found a bug',
    'Cancel my subscription',
    'How do giveaways work?',
  ];

  /// Categories for ticket form
  static const List<String> ticketCategories = [
    'Account Issue',
    'Credits / Billing',
    'Bracket Problem',
    'Bug Report',
    'Feature Request',
    'Store / Redemption',
    'BMB+ Subscription',
    'Other',
  ];
}

// ── MODELS ─────────────────────────────────────────────────────────

class _KBEntry {
  final List<String> keywords;
  final String answer;
  const _KBEntry({required this.keywords, required this.answer});
}

class AiResponse {
  final String message;
  final String? followUp;
  final AiAction action;
  const AiResponse({
    required this.message,
    this.followUp,
    this.action = AiAction.none,
  });
}

enum AiAction { none, suggestTicket, showTicketForm }

class SupportTicket {
  final String id;
  final String subject;
  final String description;
  final String userEmail;
  final String? userName;
  final String category;
  final List<String> chatHistory;
  final DateTime createdAt;
  final TicketStatus status;
  final String sentTo;

  const SupportTicket({
    required this.id,
    required this.subject,
    required this.description,
    required this.userEmail,
    this.userName,
    required this.category,
    required this.chatHistory,
    required this.createdAt,
    required this.status,
    required this.sentTo,
  });
}

enum TicketStatus { open, inProgress, resolved, closed }
