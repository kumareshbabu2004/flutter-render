import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/bots/data/services/hype_man_service.dart';
import 'package:bmb_mobile/features/bots/data/services/bot_service.dart';
import 'package:bmb_mobile/features/community/data/services/trivia_service.dart';
import 'package:bmb_mobile/features/community/data/services/community_post_store.dart';
import 'package:bmb_mobile/features/notifications/data/services/reply_notification_service.dart';
import 'package:bmb_mobile/features/sharing/presentation/screens/bracket_tree_viewer_screen.dart';
import 'package:bmb_mobile/features/giveaway/data/services/giveaway_service.dart';
import 'package:bmb_mobile/core/services/current_user_service.dart';

/// BMB Community Chat Room — a fun, engaging space for daily engagement.
/// Features:
/// - General chat with all BMB users
/// - Interactive daily trivia with streak tracking & 15-credit rewards
/// - Winner shoutouts posted automatically
/// - Daily challenges and polls
/// - Sports talk and bracket discussion
/// - BMB Hype Man always engaging & replying to users
/// - Reply-to threading with notification for YOUR replies only
class CommunityChatScreen extends StatefulWidget {
  const CommunityChatScreen({super.key});
  @override
  State<CommunityChatScreen> createState() => _CommunityChatScreenState();
}

class _CommunityChatScreenState extends State<CommunityChatScreen> with SingleTickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _random = Random();
  late TabController _tabController;
  Timer? _botTimer;
  Timer? _hypeProactiveTimer;
  Timer? _banterTimer;
  Timer? _botBracketPostTimer;

  final List<_CommunityMessage> _generalMessages = [];
  final List<_CommunityMessage> _winnerMessages = [];
  int _onlineCount = 142;

  // Trivia
  final _triviaService = TriviaService();
  final _replyNotifService = ReplyNotificationService();
  bool _triviaLoaded = false;
  int _activeQuestionIndex = 0;
  int? _selectedChoice;
  bool _answered = false;
  bool _showReward = false;

  // Countdown timer anti-cheat
  Timer? _countdownTimer;
  int _secondsRemaining = 0;
  bool _timedOut = false;

  // Community bracket posts store
  final _postStore = CommunityPostStore();

  // Giveaway splash posts
  final List<GiveawayResult> _giveawayResults = [];

  // Current user
  String get _currentUserId => CurrentUserService.instance.userId;
  String get _currentUserName => CurrentUserService.instance.displayName.isNotEmpty ? CurrentUserService.instance.displayName : 'BracketKing';

  // Hype Man typing indicator
  bool _hypeManTyping = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _replyNotifService.init();
    _loadInitialMessages();
    _loadBracketPosts();
    _loadGiveawayPosts();
    _startBotScheduler();
    _startHypeManProactive();
    _startMarcusJessBanter();
    _scheduleBotBracketPosts();
    _initTrivia();
  }

  Future<void> _initTrivia() async {
    await _triviaService.init();
    if (!mounted) return;
    setState(() {
      _triviaLoaded = true;
      final next = _triviaService.nextQuestionIndex;
      _activeQuestionIndex = next >= 0 ? next : 0;
    });
    // Start countdown if there's a question to answer
    if (_triviaService.nextQuestionIndex >= 0) {
      _startCountdown();
    }
  }

  void _loadInitialMessages() {
    final now = DateTime.now();
    _generalMessages.addAll([
      _CommunityMessage(userId: 'bot_hype', userName: 'BMB Hype Man', message: 'Welcome to the BMB Community! Who\'s ready for bracket season?! Drop a fire emoji if you\'re LOCKED IN!', time: now.subtract(const Duration(minutes: 45)), isVerified: true, isBmb: true),
      _CommunityMessage(userId: 'bot_jam81', userName: 'JamSession81', message: 'Just joined my 5th bracket this week. Addicted!', time: now.subtract(const Duration(minutes: 38)), state: 'IL'),
      _CommunityMessage(userId: 'bot_hype', userName: 'BMB Hype Man', message: '@JamSession81 FIVE brackets?! That\'s what I\'m talking about! Which one are you most confident in??', time: now.subtract(const Duration(minutes: 37)), isVerified: true, isBmb: true, replyToUser: 'JamSession81', replyToMessage: 'Just joined my 5th bracket this week. Addicted!'),
      _CommunityMessage(userId: 'bot_swish', userName: 'SwishKing', message: 'Anyone else going with Duke to win it all?', time: now.subtract(const Duration(minutes: 30)), state: 'CA'),
      _CommunityMessage(userId: 'bot_hype', userName: 'BMB Hype Man', message: '@SwishKing Ohhh blue blood pick! Bold! But what happens if they run into a hot 12-seed??', time: now.subtract(const Duration(minutes: 29)), isVerified: true, isBmb: true, replyToUser: 'SwishKing', replyToMessage: 'Anyone else going with Duke to win it all?'),
      _CommunityMessage(userId: 'bot_cindy', userName: 'CinderellaFan', message: 'Nah, give me a 12-seed upset every time. That\'s what makes March great!', time: now.subtract(const Duration(minutes: 25)), state: 'FL'),
      _CommunityMessage(userId: 'bot_hype', userName: 'BMB Hype Man', message: '@CinderellaFan UPSET CITY!! Nothing beats a Cinderella run! Who\'s your sleeper this year??', time: now.subtract(const Duration(minutes: 24)), isVerified: true, isBmb: true, replyToUser: 'CinderellaFan', replyToMessage: 'Nah, give me a 12-seed upset every time.'),
      _CommunityMessage(userId: 'bot_stats', userName: 'StatGuru42', message: 'Fun fact: Only 1.9% of brackets have ever been perfect through the Sweet 16.', time: now.subtract(const Duration(minutes: 18)), state: 'NY'),
      _CommunityMessage(userId: 'bot_hype', userName: 'BMB Hype Man', message: 'GAME DAY ENERGY! Who\'s watching tonight?! Post your predictions below!', time: now.subtract(const Duration(minutes: 10)), isVerified: true, isBmb: true),
      _CommunityMessage(userId: 'bot_chalky', userName: 'ChalkMaster', message: 'Chalk city. Trust the process.', time: now.subtract(const Duration(minutes: 5)), state: 'TX'),
      _CommunityMessage(userId: 'bot_hype', userName: 'BMB Hype Man', message: '@ChalkMaster Chalk NEVER fails... except when it does! That\'s the beauty of brackets! Who else is riding chalk this year??', time: now.subtract(const Duration(minutes: 4)), isVerified: true, isBmb: true, replyToUser: 'ChalkMaster', replyToMessage: 'Chalk city. Trust the process.'),

      // ─── BREAKING NEWS & INJURY UPDATES ───
      _CommunityMessage(userId: 'bot_bmb_news', userName: 'BMB News Desk', message: 'BREAKING: LeBron James listed questionable for Game 3 with ankle sprain. MRI scheduled for tomorrow. This could shake up every NBA playoff bracket!', time: now.subtract(const Duration(minutes: 42)), isVerified: true, isBmb: true),
      _CommunityMessage(userId: 'bot_swish', userName: 'SwishKing', message: 'Wait LeBron is hurt?? I literally JUST locked in my Lakers picks. My bracket is toast.', time: now.subtract(const Duration(minutes: 41)), state: 'CA', replyToUser: 'BMB News Desk', replyToMessage: 'BREAKING: LeBron James listed questionable'),
      _CommunityMessage(userId: 'bot_hype', userName: 'BMB Hype Man', message: 'INJURY ALERT shaking up brackets!! If you picked Lakers, NOW is the time to adjust!! Don\'t sleep on this!!', time: now.subtract(const Duration(minutes: 40)), isVerified: true, isBmb: true),

      _CommunityMessage(userId: 'bot_bmb_news', userName: 'BMB News Desk', message: 'NFL TRADE BOMB: Justin Jefferson to the Jets for 2 first-round picks! This changes EVERYTHING for the NFL Draft bracket!', time: now.subtract(const Duration(minutes: 35)), isVerified: true, isBmb: true),
      _CommunityMessage(userId: 'bot_chalky', userName: 'ChalkMaster', message: 'Jets getting Jefferson is wild. My NFL bracket just got way more interesting. Moving them up from dark horse to contender.', time: now.subtract(const Duration(minutes: 34)), state: 'TX', replyToUser: 'BMB News Desk', replyToMessage: 'NFL TRADE BOMB: Justin Jefferson to the Jets'),

      // ─── CURRENT GAME DISCUSSION ───
      _CommunityMessage(userId: 'bot_stats', userName: 'StatGuru42', message: 'LIVE SCORE UPDATE: Duke 78 - UNC 72 at the half. Duke shooting 54% from three. If you\'ve got them in your Final Four, you\'re looking good!', time: now.subtract(const Duration(minutes: 20)), state: 'NY'),
      _CommunityMessage(userId: 'bot_cindy', userName: 'CinderellaFan', message: 'UNC needs to tighten up defense or this game is over. My bracket has UNC losing next round anyway but still!', time: now.subtract(const Duration(minutes: 19)), state: 'FL', replyToUser: 'StatGuru42', replyToMessage: 'LIVE SCORE UPDATE: Duke 78 - UNC 72'),

      // ─── POP CULTURE & FUN BRACKETS ───
      _CommunityMessage(userId: 'bot_bmb_official', userName: 'Back My Bracket', message: 'NEW BRACKET ALERT: Best Movie Villain bracket is LIVE! Darth Vader vs Thanos in the finals. 450 people have voted so far! Who ya got??', time: now.subtract(const Duration(minutes: 28)), isVerified: true, isBmb: true),
      _CommunityMessage(userId: 'bot_madness', userName: 'MarchMadnessMax', message: 'Thanos wins that easy. Dude wiped out half the universe. Vader is legendary but come on!', time: now.subtract(const Duration(minutes: 27)), state: 'NC', replyToUser: 'Back My Bracket', replyToMessage: 'Best Movie Villain bracket'),
      _CommunityMessage(userId: 'bot_jam81', userName: 'JamSession81', message: 'Vader ALL DAY. The breathing, the suit, the reveal... he\'s the GOAT villain and I\'ll die on that hill.', time: now.subtract(const Duration(minutes: 26)), state: 'IL', replyToUser: 'MarchMadnessMax', replyToMessage: 'Thanos wins that easy'),
      _CommunityMessage(userId: 'bot_hype', userName: 'BMB Hype Man', message: 'THIS is what BMB is about!! Not just sports brackets — ANYTHING can be a bracket! Best pizza, best rapper, best sitcom... EVERYTHING! What bracket should we do next??', time: now.subtract(const Duration(minutes: 25)), isVerified: true, isBmb: true),

      // ─── BEST PIZZA BRACKET ───
      _CommunityMessage(userId: 'bot_bmb_official', userName: 'Back My Bracket', message: 'TRENDING: Best Pizza Topping Bracket — Pepperoni leads the Final Four but Pineapple is making a CINDERELLA RUN! 1,200 votes and counting!', time: now.subtract(const Duration(minutes: 16)), isVerified: true, isBmb: true),
      _CommunityMessage(userId: 'bot_cindy', userName: 'CinderellaFan', message: 'PINEAPPLE ON PIZZA FOREVER! Sweet and savory is undefeated! Team Pineapple let\'s go!!', time: now.subtract(const Duration(minutes: 15)), state: 'FL'),

      // ─── CHARITY & LOCAL COMMUNITY ───
      _CommunityMessage(userId: 'bot_bmb_official', userName: 'Back My Bracket', message: 'CHARITY SPOTLIGHT: Our BMB x Habitat for Humanity bracket raised 2,400 credits this week! 100% of contributions go directly to building homes. Join the bracket to contribute!', time: now.subtract(const Duration(minutes: 50)), isVerified: true, isBmb: true),
      _CommunityMessage(userId: 'bot_hype', userName: 'BMB Hype Man', message: 'THIS is what family looks like!! BMB community giving back while having FUN! Drop a heart if you love what we\'re building here!', time: now.subtract(const Duration(minutes: 49)), isVerified: true, isBmb: true),

      _CommunityMessage(userId: 'bot_bmb_official', userName: 'Back My Bracket', message: 'LOCAL EVENT: BMB Bracket Night at Moe\'s Tavern, Austin TX this Saturday 7 PM! Free credits for first 20 attendees. Bring your friends and your bracket skills!', time: now.subtract(const Duration(minutes: 48)), isVerified: true, isBmb: true),
      _CommunityMessage(userId: 'bot_chalky', userName: 'ChalkMaster', message: 'I\'m in Austin! Might have to pull up to Moe\'s. Who else is going?', time: now.subtract(const Duration(minutes: 47)), state: 'TX', replyToUser: 'Back My Bracket', replyToMessage: 'BMB Bracket Night at Moe\'s Tavern'),

      _CommunityMessage(userId: 'bot_bmb_official', userName: 'Back My Bracket', message: 'LOCAL HERO: Chicago Bar League hosted their first bracket night and had 45 participants! Shoutout to Slugger\'s Sports Bar for making it happen!', time: now.subtract(const Duration(minutes: 32)), isVerified: true, isBmb: true),
      _CommunityMessage(userId: 'bot_jam81', userName: 'JamSession81', message: 'Chicago represent!! I was there! Atmosphere was insane. When\'s the next one??', time: now.subtract(const Duration(minutes: 31)), state: 'IL', replyToUser: 'Back My Bracket', replyToMessage: 'Chicago Bar League hosted their first bracket night'),

      // ─── COMMUNITY BUILDING ───
      _CommunityMessage(userId: 'bot_hype', userName: 'BMB Hype Man', message: 'Anyone hosting a bracket at their local bar or restaurant? BMB will feature YOUR event to the whole community! DM us to get on the schedule!', time: now.subtract(const Duration(minutes: 12)), isVerified: true, isBmb: true),
      _CommunityMessage(userId: 'bot_madness', userName: 'MarchMadnessMax', message: 'My church group wants to do a charity bracket for the youth center. Can we host that on BMB?', time: now.subtract(const Duration(minutes: 11)), state: 'NC', replyToUser: 'BMB Hype Man', replyToMessage: 'Anyone hosting a bracket at their local bar'),
      _CommunityMessage(userId: 'bot_hype', userName: 'BMB Hype Man', message: '@MarchMadnessMax ABSOLUTELY!! BMB is for EVERYONE — churches, schools, youth groups, restaurants, bars, offices! Anyone can host a bracket! That\'s the beauty of it!', time: now.subtract(const Duration(minutes: 10)), isVerified: true, isBmb: true, replyToUser: 'MarchMadnessMax', replyToMessage: 'My church group wants to do a charity bracket'),

      // ─── NASCAR & INDIVIDUAL SPORTS ───
      _CommunityMessage(userId: 'bot_stats', userName: 'StatGuru42', message: 'Daytona 500 bracket has 200+ entries! Kyle Larson is the chalk pick but Ross Chastain is the value play. Any NASCAR heads in here?', time: now.subtract(const Duration(minutes: 8)), state: 'NY'),
      _CommunityMessage(userId: 'bot_swish', userName: 'SwishKing', message: 'Never done a NASCAR bracket before but that actually sounds fun. BMB making me a racing fan!', time: now.subtract(const Duration(minutes: 7)), state: 'CA', replyToUser: 'StatGuru42', replyToMessage: 'Daytona 500 bracket has 200+ entries'),
    ]);

    // ─── PRE-SEEDED BOT BRACKET POSTS (look like real human posts) ───
    _injectBotBracketPost('bot_marcus', now.subtract(const Duration(minutes: 22)));
    _injectBotBracketPost('bot_jess', now.subtract(const Duration(minutes: 15)));

    _winnerMessages.addAll([
      _CommunityMessage(userId: 'bot_bmb_official', userName: 'Back My Bracket', message: 'Shoutout to JamSession81 for winning the NCAA March Madness Bracket Challenge! 78 correct picks!', time: now.subtract(const Duration(days: 1)), isVerified: true, isBmb: true, isWinner: true, winnerName: 'JamSession81'),
      _CommunityMessage(userId: 'bot_bmb_official', userName: 'Back My Bracket', message: 'Congratulations to SwishKing for taking home the NBA Playoff Prediction Pool! Dominated the leaderboard!', time: now.subtract(const Duration(days: 3)), isVerified: true, isBmb: true, isWinner: true, winnerName: 'SwishKing'),
      _CommunityMessage(userId: 'bot_bmb_official', userName: 'Back My Bracket', message: 'MarchMadnessMax crushed it in the NIT 2025 bracket! Champion with a perfect Final Four!', time: now.subtract(const Duration(days: 5)), isVerified: true, isBmb: true, isWinner: true, winnerName: 'MarchMadnessMax'),
    ]);
  }

  /// Load bracket posts from persistent store and inject into general chat
  /// with a fun multi-bot conversation thread for each post.
  Future<void> _loadBracketPosts() async {
    await _postStore.init();
    if (!mounted) return;
    final posts = _postStore.posts;
    if (posts.isEmpty) return;
    setState(() {
      for (final post in posts) {
        final displayName = post.userName == 'You' ? 'BracketKing' : post.userName;
        final champ = post.championPick ?? 'their champ';
        final seed = post.postedAt.millisecondsSinceEpoch;
        final rng = Random(seed);

        // 1) The user's bracket post
        _generalMessages.add(_CommunityMessage(
          userId: post.userId,
          userName: displayName,
          message: post.message,
          time: post.postedAt,
          state: 'TX',
          isCurrentUser: CurrentUserService.instance.isCurrentUser(post.userId),
          bracketPost: post,
        ));

        // 2) Hype Man reacts first (agrees OR challenges)
        final hypeAgree = rng.nextBool();
        final hypeMessages = hypeAgree
            ? [
                'LET\'S GOOO!! $displayName just dropped their picks! I\'m actually feeling the $champ call. That squad has been ON FIRE lately!',
                'OH SNAP! $displayName is IN! And $champ?? I was JUST about to say the same thing! GREAT MINDS!',
                '$displayName coming in HOT! Honestly, $champ cutting down the nets? I can SEE it! Bold but I LOVE it!',
                'The picks are IN from $displayName! $champ winning it all?? You know what, I\'m not even gonna argue. RESPECT!',
              ]
            : [
                'WHOA WHOA WHOA $displayName!! $champ as your champion?! That\'s a BOLD call! I love the guts but I\'m not sure about that one!',
                '$displayName just posted their picks and... $champ winning it all?? I dunno fam, that\'s SPICY! Anyone else have doubts??',
                'OK OK $displayName I see you... but $champ?! Are we watching the same games?? I need someone to back me up here!',
                '$displayName locked in with $champ! Respect the confidence but I\'m gonna need you to explain that one to the class!',
              ];
        final hypeMsg = hypeMessages[rng.nextInt(hypeMessages.length)];
        _generalMessages.add(_CommunityMessage(
          userId: 'bot_hype',
          userName: 'BMB Hype Man',
          message: hypeMsg,
          time: post.postedAt.add(const Duration(seconds: 6)),
          isVerified: true,
          isBmb: true,
          replyToUser: displayName,
          replyToMessage: post.message.length > 50 ? '${post.message.substring(0, 50)}...' : post.message,
        ));

        // 3) Marcus jumps in (~15s later)
        final marcusAgree = rng.nextBool();
        final marcusMessages = marcusAgree
            ? [
                'Yo I actually agree with $displayName on this one. $champ has the depth to make a run. Solid picks!',
                'Not bad, not bad! $champ is lowkey a smart pick. I got them in my Final Four too.',
                '$displayName knows what\'s up! $champ has been underrated all season. I\'m riding with that pick too!',
                'Real recognize real. $champ is the play. Good looks $displayName!',
              ]
            : [
                'Nah I gotta disagree with $displayName here. $champ folds under pressure. Watch.',
                'Love the effort $displayName but $champ?? They haven\'t beaten a ranked team in weeks. I\'d rethink that one.',
                '$displayName I respect the post but $champ ain\'t it chief. Their defense is Swiss cheese right now.',
                'Tough call $displayName. I had $champ in my bracket too... then I watched them play last week and deleted it real quick.',
              ];
        _generalMessages.add(_CommunityMessage(
          userId: 'bot_marcus',
          userName: 'Marc_Buckets',
          message: marcusMessages[rng.nextInt(marcusMessages.length)],
          time: post.postedAt.add(const Duration(seconds: 15)),
          state: 'TX',
          isVerified: true,
          replyToUser: displayName,
          replyToMessage: '$champ as champion',
        ));

        // 4) Jess fires back (~25s later, often disagrees with Marcus)
        final jessDisagreesWithMarcus = !marcusAgree || rng.nextDouble() < 0.6;
        final jessMessages = jessDisagreesWithMarcus
            ? [
                'Marc you\'re TRIPPIN! $champ has the best backcourt in the field. $displayName might be onto something here!',
                'Excuse me Marc?? Did you even WATCH $champ play this weekend? They looked unstoppable. I\'m with $displayName!',
                'I swear Marc just picks against everyone. $champ is a legit contender $displayName, don\'t let him shake you!',
                'Marc said what?? Nah. $champ has upset written all over them in the BEST way. $displayName I see the vision!',
              ]
            : [
                'OK I hate to say it but Marc might be right this time. $champ has some red flags. Still love the energy though $displayName!',
                'As much as it pains me to agree with Marc... $champ scares me a little. But respect to $displayName for being bold!',
                '$displayName I want to believe in $champ so bad but Marc has a point. Their schedule was weak. Prove us wrong!',
                'Don\'t tell Marc I said this but... yeah $champ is a risky pick. Still, crazier things have happened in March!',
              ];
        _generalMessages.add(_CommunityMessage(
          userId: 'bot_jess',
          userName: 'Queen_of_Upsets',
          message: jessMessages[rng.nextInt(jessMessages.length)],
          time: post.postedAt.add(const Duration(seconds: 25)),
          state: 'FL',
          isVerified: true,
          replyToUser: marcusAgree ? displayName : 'Marc_Buckets',
          replyToMessage: marcusAgree ? '$champ as champion' : 'I gotta disagree',
        ));

        // 5) Another community bot reacts (~35s later)
        final botReactions = [
          ('bot_cindy', 'CinderellaFan', 'I don\'t care who wins, I just want CHAOS! Give me a 12-seed upsetting $champ in round 2. That\'s what dreams are made of!', 'FL'),
          ('bot_stats', 'StatGuru42', 'Interesting pick. The analytics actually give $champ a ${45 + rng.nextInt(20)}% chance to reach the Final Four. Not the worst call.', 'NY'),
          ('bot_chalky', 'ChalkMaster', '$champ as champion? Bold. I\'m going chalk all the way but I respect anyone who puts their picks out there. Good luck $displayName!', 'TX'),
          ('bot_madness', 'MarchMadnessMax', 'THIS is why I love bracket season! Everyone\'s got an opinion and nobody\'s bracket is safe! Love it $displayName!', 'NC'),
          ('bot_jam81', 'JamSession81', 'Man I was going back and forth on $champ too. $displayName you just convinced me to pull the trigger. Let\'s ride!', 'IL'),
          ('bot_swish', 'SwishKing', 'The real question is who\'s $displayName\'s upset pick? I need the deep cuts! The champion pick is cool but give me the SPICY takes!', 'CA'),
        ];
        final botReaction = botReactions[rng.nextInt(botReactions.length)];
        _generalMessages.add(_CommunityMessage(
          userId: botReaction.$1,
          userName: botReaction.$2,
          message: botReaction.$3,
          time: post.postedAt.add(const Duration(seconds: 35)),
          state: botReaction.$4,
        ));

        // 6) Marcus responds to Jess (~42s later, fun banter)
        if (jessDisagreesWithMarcus) {
          final marcusClaps = [
            'Queen I KNEW you\'d come for me! You always back the underdogs. But name one time $champ won a big game under pressure this year. I\'ll wait.',
            'There she is! Queen with the hot take defense! Alright alright, if $champ makes the Final Four I\'ll post my bracket for everyone to clown. Deal?',
            'Queen you stay starting stuff! OK real talk - if $champ gets past the second round I\'ll buy $displayName a bucket of credits. Book it.',
            'Lmao Queen really said I\'m trippin. OK bet. Let\'s come back to this conversation in two weeks and see who was right!',
          ];
          _generalMessages.add(_CommunityMessage(
            userId: 'bot_marcus',
            userName: 'Marc_Buckets',
            message: marcusClaps[rng.nextInt(marcusClaps.length)],
            time: post.postedAt.add(const Duration(seconds: 42)),
            state: 'TX',
            isVerified: true,
            replyToUser: 'Queen_of_Upsets',
            replyToMessage: 'Marc you\'re TRIPPIN',
          ));
        }

        // 7) Hype Man wraps it up (~50s later)
        final hypeWrapUps = [
          'I LOVE this debate!! This is what BMB is all about! $displayName started a WAR in the chat! Who\'s posting their picks next?? Don\'t be shy!',
          'THE ENERGY IN HERE RIGHT NOW!! Marc vs Queen vs the whole community! $displayName your picks got people TALKING! That\'s a W right there!',
          'This thread is GOLD! Everyone\'s got opinions and nobody\'s backing down! Post YOUR picks and let\'s keep this going all day!!',
          'BMB Community is UNDEFEATED in debates! $displayName drop more picks, Marc keep the hot takes coming, Queen keep checking him! LETS GO!',
        ];
        _generalMessages.add(_CommunityMessage(
          userId: 'bot_hype',
          userName: 'BMB Hype Man',
          message: hypeWrapUps[rng.nextInt(hypeWrapUps.length)],
          time: post.postedAt.add(const Duration(seconds: 50)),
          isVerified: true,
          isBmb: true,
        ));
      }
      // Sort chronologically
      _generalMessages.sort((a, b) => a.time.compareTo(b.time));
    });
  }

  /// Load giveaway results and inject SPLASH POSTS into general chat and winners tab.
  /// These are big, noticeable, eye-catching cards that stand out.
  Future<void> _loadGiveawayPosts() async {
    final results = await GiveawayService.getResults();
    if (!mounted || results.isEmpty) return;
    setState(() {
      for (final result in results) {
        _giveawayResults.add(result);

        // Build splash message text
        final w1 = result.winners.isNotEmpty ? result.winners[0] : null;
        final w2 = result.winners.length > 1 ? result.winners[1] : null;
        final leader = result.leaderboardLeader;
        final parts = <String>[];
        if (w1 != null) parts.add('${w1.userName} won ${w1.creditsAwarded} credits (2x)');
        if (w2 != null) parts.add('${w2.userName} won ${w2.creditsAwarded} credits');
        if (leader != null) parts.add('${leader.userName} earned ${leader.creditsAwarded} leader bonus credits');
        final splashText = 'GIVEAWAY WINNERS for ${result.bracketName}! ${parts.join(' | ')} \u2014 credits deposited instantly!';

        // Inject into GENERAL chat as a splash post
        _generalMessages.add(_CommunityMessage(
          userId: 'bmb_giveaway',
          userName: 'Back My Bracket',
          message: splashText,
          time: result.drawnAt,
          isVerified: true,
          isBmb: true,
          isGiveawaySplash: true,
          giveawayResult: result,
        ));

        // Hype Man celebrates
        _generalMessages.add(_CommunityMessage(
          userId: 'bot_hype',
          userName: 'BMB Hype Man',
          message: 'LET\'S GOOOOO!! The giveaway just hit! Congrats to ALL the winners! Credits are IN your bucket RIGHT NOW! Who\'s joining the next bracket to get in on the action?!',
          time: result.drawnAt.add(const Duration(seconds: 8)),
          isVerified: true,
          isBmb: true,
        ));

        // Inject into WINNERS tab as well
        _winnerMessages.insert(0, _CommunityMessage(
          userId: 'bmb_giveaway',
          userName: 'Back My Bracket',
          message: splashText,
          time: result.drawnAt,
          isVerified: true,
          isBmb: true,
          isGiveawaySplash: true,
          giveawayResult: result,
        ));
      }
      _generalMessages.sort((a, b) => a.time.compareTo(b.time));
    });
  }

  /// Inject a simulated bracket post from a bot account into the general chat.
  /// Looks exactly like a real user posting their bracket picks.
  void _injectBotBracketPost(String botId, DateTime postedAt) {
    final postData = BotService.generateBotBracketPost(botId);
    final post = CommunityBracketPost(
      id: '${botId}_post_${postedAt.millisecondsSinceEpoch}',
      userId: botId,
      userName: postData['userName'] as String,
      bracketId: 'bracket_${botId}_${postedAt.millisecondsSinceEpoch}',
      bracketName: postData['bracketName'] as String,
      sport: postData['sport'] as String,
      bracketType: postData['bracketType'] as String,
      totalPicks: postData['totalPicks'] as int,
      correct: postData['correct'] as int,
      wrong: postData['wrong'] as int,
      pending: postData['pending'] as int,
      championPick: postData['championPick'] as String?,
      tieBreakerPrediction: postData['tieBreakerPrediction'] as int?,
      summary: '${postData['userName']}\'s picks for ${postData['bracketName']}',
      message: postData['message'] as String,
      postedAt: postedAt,
      teams: (postData['teams'] as List<String>?) ?? [],
      picksMap: (postData['picksMap'] as Map<String, String>?) ?? {},
      totalRounds: (postData['totalRounds'] as int?) ?? 3,
    );

    // Add the post message
    _generalMessages.add(_CommunityMessage(
      userId: botId,
      userName: post.userName,
      message: post.message,
      time: postedAt,
      state: postData['state'] as String,
      isVerified: true,
      bracketPost: post,
    ));

    // Hype Man reacts
    final rng = Random(postedAt.millisecondsSinceEpoch);
    final champ = post.championPick ?? 'that squad';
    final displayName = post.userName;
    final hypeReacts = [
      'yooo $displayName just dropped picks! $champ as champ?? I can see it. that team has been different lately',
      '$displayName in the building with the bracket! $champ winning it all? bold. I respect it.',
      'lets GO $displayName! another bracket in the mix! $champ is a solid pick honestly',
      '$displayName posted picks! I was literally just looking at $champ\'s schedule. interesting call.',
    ];
    _generalMessages.add(_CommunityMessage(
      userId: 'bot_hype',
      userName: 'BMB Hype Man',
      message: hypeReacts[rng.nextInt(hypeReacts.length)],
      time: postedAt.add(const Duration(seconds: 8)),
      isVerified: true,
      isBmb: true,
      replyToUser: displayName,
      replyToMessage: post.message.length > 50 ? '${post.message.substring(0, 50)}...' : post.message,
    ));

    // The OTHER bot reacts (Marc reacts to Queen, Queen reacts to Marc)
    final otherBotId = botId == 'bot_marcus' ? 'bot_jess' : 'bot_marcus';
    final otherName = botId == 'bot_marcus' ? 'Queen_of_Upsets' : 'Marc_Buckets';
    final otherState = botId == 'bot_marcus' ? 'FL' : 'TX';

    final otherReacts = botId == 'bot_marcus' ? [
      // Queen reacting to Marc's picks
      'lol Marc picked $champ again. shocking. at least throw in one upset bro',
      '$champ? really Marc? that\'s the safest pick you could have made. live a little',
      'Marc I swear you pick the same teams every time. one of these days try a sleeper',
      'well at least Marc actually posted his picks. now let me go in there and clown his Final Four',
    ] : [
      // Marc reacting to Queen's picks
      '$champ as champion... Queen that team hasn\'t beaten anyone all year. but hey it\'s your bracket',
      'Queen always with the upset picks. you know what though, one of these days she\'s gonna be right and I\'ll never hear the end of it',
      'I looked at Queen\'s bracket and honestly... it\'s not as crazy as I expected. still bold though',
      'alright Queen I see the picks. $champ is risky but I kinda get the reasoning. don\'t tell her I said that',
    ];
    _generalMessages.add(_CommunityMessage(
      userId: otherBotId,
      userName: otherName,
      message: otherReacts[rng.nextInt(otherReacts.length)],
      time: postedAt.add(const Duration(seconds: 18)),
      state: otherState,
      isVerified: true,
      replyToUser: displayName,
      replyToMessage: '$champ as champion',
    ));
  }

  /// Periodically have Marc or Queen post new bracket picks (every 90-150s).
  void _scheduleBotBracketPosts() {
    final delay = 90 + _random.nextInt(61);
    _botBracketPostTimer = Timer(Duration(seconds: delay), () {
      if (!mounted) return;
      if (_tabController.index == 0) {
        // Alternate between Marc and Queen
        final botId = _random.nextBool() ? 'bot_marcus' : 'bot_jess';
        setState(() {
          _injectBotBracketPost(botId, DateTime.now());
          _generalMessages.sort((a, b) => a.time.compareTo(b.time));
        });
        _scrollToBottom();
      }
      _scheduleBotBracketPosts();
    });
  }

  void _startBotScheduler() {
    _botTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      setState(() {
        _onlineCount += _random.nextInt(5) - 2;
        _onlineCount = _onlineCount.clamp(100, 300);
      });
    });
  }

  /// Hype Man proactively sparks conversation every 25-40 seconds
  void _startHypeManProactive() {
    _scheduleNextProactive();
  }

  void _scheduleNextProactive() {
    final delay = 25 + _random.nextInt(16); // 25-40 seconds
    _hypeProactiveTimer = Timer(Duration(seconds: delay), () {
      if (!mounted) return;
      // Only post proactive if on General tab and not too many recent messages
      if (_tabController.index == 0) {
        final proactive = HypeManService.generateProactiveMessage();
        setState(() {
          _generalMessages.add(_CommunityMessage(
            userId: 'bot_hype',
            userName: 'BMB Hype Man',
            message: proactive,
            time: DateTime.now(),
            isVerified: true,
            isBmb: true,
          ));
        });
        _scrollToBottom();

        // Marcus chimes in on the proactive message (~4-6s later, 50% chance)
        if (_random.nextDouble() < 0.5) {
          Future.delayed(Duration(seconds: 4 + _random.nextInt(3)), () {
            if (!mounted) return;
            final marcusReply = HypeManService.generateMarcusReply('Hype Man', proactive);
            setState(() {
              _generalMessages.add(_CommunityMessage(
                userId: 'bot_marcus',
                userName: 'Marc_Buckets',
                message: marcusReply,
                time: DateTime.now(),
                state: 'TX',
                isVerified: true,
                replyToUser: 'BMB Hype Man',
                replyToMessage: proactive.length > 50 ? '${proactive.substring(0, 50)}...' : proactive,
              ));
            });
            _scrollToBottom();

            // Jess follows Marcus (~3-5s later, 60% chance if Marcus posted)
            if (_random.nextDouble() < 0.6) {
              Future.delayed(Duration(seconds: 3 + _random.nextInt(3)), () {
                if (!mounted) return;
                final jessReply = HypeManService.generateJessReply('Marc', marcusReply);
                setState(() {
                  _generalMessages.add(_CommunityMessage(
                    userId: 'bot_jess',
                    userName: 'Queen_of_Upsets',
                    message: jessReply,
                    time: DateTime.now(),
                    state: 'FL',
                    isVerified: true,
                    replyToUser: 'Marc_Buckets',
                    replyToMessage: marcusReply.length > 50 ? '${marcusReply.substring(0, 50)}...' : marcusReply,
                  ));
                });
                _scrollToBottom();
              });
            }
          });
        } else if (_random.nextDouble() < 0.5) {
          // Or just a random community bot follow-up
          Future.delayed(Duration(seconds: 3 + _random.nextInt(4)), () {
            if (!mounted) return;
            final followUp = HypeManService.generateFollowUp(proactive);
            setState(() {
              _generalMessages.add(_CommunityMessage(
                userId: followUp.$1,
                userName: followUp.$2,
                message: followUp.$3,
                time: DateTime.now(),
                state: followUp.$4,
              ));
            });
            _scrollToBottom();
          });
        }
      }
      _scheduleNextProactive();
    });
  }

  /// Periodic Marc vs Queen banter — full back-and-forth debates
  void _startMarcusJessBanter() {
    _scheduleNextBanter();
  }

  void _scheduleNextBanter() {
    // Banter every 50-80 seconds
    final delay = 50 + _random.nextInt(31);
    _banterTimer = Timer(Duration(seconds: delay), () {
      if (!mounted) return;
      if (_tabController.index == 0) {
        final debate = HypeManService.generateMarcusJessBanter();
        _playDebate(debate, 0);
      }
      _scheduleNextBanter();
    });
  }

  void _playDebate(List<(String, String, String, String)> exchanges, int index) {
    if (index >= exchanges.length || !mounted) return;

    final (botId, botName, message, state) = exchanges[index];
    final isFirst = index == 0;
    final prevName = index > 0 ? exchanges[index - 1].$2 : null;
    final prevMsg = index > 0 ? exchanges[index - 1].$3 : null;

    setState(() {
      _generalMessages.add(_CommunityMessage(
        userId: botId,
        userName: botName,
        message: message,
        time: DateTime.now(),
        state: state,
        isVerified: true,
        replyToUser: isFirst ? null : prevName,
        replyToMessage: isFirst ? null : (prevMsg != null && prevMsg.length > 50 ? '${prevMsg.substring(0, 50)}...' : prevMsg),
      ));
    });
    _scrollToBottom();

    // Next exchange in 3-6 seconds
    if (index + 1 < exchanges.length) {
      Future.delayed(Duration(seconds: 3 + _random.nextInt(4)), () {
        _playDebate(exchanges, index + 1);
      });
    } else {
      // Hype Man wraps up the debate after ~4s
      Future.delayed(Duration(seconds: 3 + _random.nextInt(3)), () {
        if (!mounted) return;
        final wrapUps = [
          'Marc and Queen going at it AGAIN! This is CONTENT! Who\'s side are you on?!',
          'I\'m LIVING for this debate! Marc vs Queen never gets old! Who\'s winning??',
          'THIS is why the BMB Community is undefeated! The back-and-forth is ELITE!',
          'Can we get a referee in here?! Marc and Queen are going OFF! I love it!',
          'Y\'all Marc and Queen need their own podcast. I would listen EVERY day!',
          'The debate of the CENTURY right here in BMB Community! Drop your vote below!',
        ];
        setState(() {
          _generalMessages.add(_CommunityMessage(
            userId: 'bot_hype',
            userName: 'BMB Hype Man',
            message: wrapUps[_random.nextInt(wrapUps.length)],
            time: DateTime.now(),
            isVerified: true,
            isBmb: true,
          ));
        });
        _scrollToBottom();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _botTimer?.cancel();
    _hypeProactiveTimer?.cancel();
    _banterTimer?.cancel();
    _botBracketPostTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ─── SEND MESSAGE + HYPE MAN ALWAYS REPLIES ─────────────────────────
  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final userMsg = _CommunityMessage(
      userId: _currentUserId,
      userName: _currentUserName,
      message: text,
      time: DateTime.now(),
      state: 'TX',
      isCurrentUser: true,
    );

    setState(() {
      _generalMessages.add(userMsg);
      _messageController.clear();
    });
    _scrollToBottom();

    // ─── HYPE MAN ALWAYS REPLIES (1.5-3s delay) ───
    final hypeDelay = Duration(milliseconds: 1500 + _random.nextInt(1500));
    // Show typing indicator briefly
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _hypeManTyping = true);
    });

    Future.delayed(hypeDelay, () {
      if (!mounted) return;
      final hypeReply = HypeManService.generateReplyTo(_currentUserName, text);
      setState(() {
        _hypeManTyping = false;
        _generalMessages.add(_CommunityMessage(
          userId: 'bot_hype',
          userName: 'BMB Hype Man',
          message: hypeReply,
          time: DateTime.now(),
          isVerified: true,
          isBmb: true,
          replyToUser: _currentUserName,
          replyToMessage: text.length > 60 ? '${text.substring(0, 60)}...' : text,
        ));
      });
      _scrollToBottom();

      // Fire reply notification — Hype Man replied to YOUR comment
      _replyNotifService.addReplyNotification(
        replierId: 'bot_hype',
        replierName: 'BMB Hype Man',
        replierState: 'US',
        originalMessage: text,
        replyMessage: hypeReply,
      );
    });

    // ─── MARCUS REPLIES (3-5s after Hype Man, 55% chance) ───
    if (_random.nextDouble() < 0.55) {
      final marcusDelay = Duration(seconds: 3 + _random.nextInt(3));
      Future.delayed(hypeDelay + marcusDelay, () {
        if (!mounted) return;
        final marcusReply = HypeManService.generateMarcusReply(_currentUserName, text);
        setState(() {
          _generalMessages.add(_CommunityMessage(
            userId: 'bot_marcus',
            userName: 'Marc_Buckets',
            message: marcusReply,
            time: DateTime.now(),
            state: 'TX',
            isVerified: true,
            replyToUser: _currentUserName,
            replyToMessage: text.length > 50 ? '${text.substring(0, 50)}...' : text,
          ));
        });
        _scrollToBottom();

        // ─── JESS REPLIES TO MARCUS OR USER (3-5s after Marcus, 50% chance) ───
        if (_random.nextDouble() < 0.5) {
          Future.delayed(Duration(seconds: 3 + _random.nextInt(3)), () {
            if (!mounted) return;
            // Jess sometimes replies to the user, sometimes challenges Marcus
            final jessTargetsUser = _random.nextBool();
            final jessReply = jessTargetsUser
                ? HypeManService.generateJessReply(_currentUserName, text)
                : HypeManService.generateJessReply('Marc', marcusReply);
            final replyTo = jessTargetsUser ? _currentUserName : 'Marc_Buckets';
            final replyMsg = jessTargetsUser
                ? (text.length > 50 ? '${text.substring(0, 50)}...' : text)
                : (marcusReply.length > 50 ? '${marcusReply.substring(0, 50)}...' : marcusReply);
            setState(() {
              _generalMessages.add(_CommunityMessage(
                userId: 'bot_jess',
                userName: 'Queen_of_Upsets',
                message: jessReply,
                time: DateTime.now(),
                state: 'FL',
                isVerified: true,
                replyToUser: replyTo,
                replyToMessage: replyMsg,
              ));
            });
            _scrollToBottom();
          });
        }
      });
    } else if (_random.nextDouble() < 0.45) {
      // ─── JESS REPLIES DIRECTLY (if Marcus didn't, 45% chance) ───
      final jessDelay = Duration(seconds: 4 + _random.nextInt(4));
      Future.delayed(hypeDelay + jessDelay, () {
        if (!mounted) return;
        final jessReply = HypeManService.generateJessReply(_currentUserName, text);
        setState(() {
          _generalMessages.add(_CommunityMessage(
            userId: 'bot_jess',
            userName: 'Queen_of_Upsets',
            message: jessReply,
            time: DateTime.now(),
            state: 'FL',
            isVerified: true,
            replyToUser: _currentUserName,
            replyToMessage: text.length > 50 ? '${text.substring(0, 50)}...' : text,
          ));
        });
        _scrollToBottom();
      });
    } else {
      // ─── RANDOM COMMUNITY BOT (if neither Marcus nor Jess, 50% chance) ───
      if (_random.nextDouble() < 0.5) {
        Future.delayed(Duration(seconds: 4 + _random.nextInt(4)), () {
          if (!mounted) return;
          final followUp = HypeManService.generateFollowUp(text);
          setState(() {
            _generalMessages.add(_CommunityMessage(
              userId: followUp.$1,
              userName: followUp.$2,
              message: followUp.$3,
              time: DateTime.now(),
              state: followUp.$4,
            ));
          });
          _scrollToBottom();
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── COUNTDOWN TIMER ────────────────────────────────────────────────────
  void _startCountdown() {
    _countdownTimer?.cancel();
    if (_activeQuestionIndex >= _triviaService.todayQuestions.length) return;
    final q = _triviaService.todayQuestions[_activeQuestionIndex];
    _secondsRemaining = q.timeLimit;
    _timedOut = false;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _secondsRemaining--;
        if (_secondsRemaining <= 0) {
          timer.cancel();
          _timedOut = true;
          _handleTimeout();
        }
      });
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
  }

  Future<void> _handleTimeout() async {
    if (_answered) return;
    // Timer expired → auto-wrong
    await _triviaService.answerQuestion(
      _activeQuestionIndex,
      -1, // invalid choice
      timeRemainingSeconds: 0,
    );
    setState(() {
      _answered = true;
      _timedOut = true;
    });
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      _advanceQuestion();
    });
  }

  // ─── TRIVIA LOGIC ──────────────────────────────────────────────────────
  Future<void> _submitAnswer() async {
    if (_selectedChoice == null || _answered) return;
    _stopCountdown();
    await _triviaService.answerQuestion(
      _activeQuestionIndex,
      _selectedChoice!,
      timeRemainingSeconds: _secondsRemaining,
    );
    setState(() {
      _answered = true;
      if (_triviaService.streakRewardPending || _triviaService.lastCreditsAwarded > 0) {
        _showReward = _triviaService.lastCreditsAwarded > 0;
      }
    });
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      _advanceQuestion();
    });
  }

  void _advanceQuestion() {
    setState(() {
      _showReward = false;
      _answered = false;
      _selectedChoice = null;
      _timedOut = false;
      final next = _triviaService.nextQuestionIndex;
      if (next >= 0) {
        _activeQuestionIndex = next;
        _startCountdown();
      }
    });
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildChatList(_generalMessages),
                    _buildTriviaTab(),
                    _buildWinnersList(),
                  ],
                ),
              ),
              if (_tabController.index != 1) _buildMessageInput(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      decoration: BoxDecoration(
        color: BmbColors.deepNavy,
        border: Border(bottom: BorderSide(color: BmbColors.borderColor.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: BmbColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [BmbColors.blue, const Color(0xFF5B6EFF)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.forum, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BMB Community', style: TextStyle(color: BmbColors.textPrimary, fontSize: 16, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
                Row(children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: BmbColors.successGreen, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('$_onlineCount online', style: TextStyle(color: BmbColors.successGreen, fontSize: 11)),
                ]),
              ],
            ),
          ),
          GestureDetector(
            onTap: _showDailyChallenge,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: BmbColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.local_fire_department, color: BmbColors.gold, size: 14),
                const SizedBox(width: 4),
                Text('Daily', style: TextStyle(color: BmbColors.gold, fontSize: 11, fontWeight: BmbFontWeights.bold)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: BmbColors.deepNavy,
        border: Border(bottom: BorderSide(color: BmbColors.borderColor.withValues(alpha: 0.3))),
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (_) => setState(() {}),
        indicatorColor: BmbColors.blue,
        indicatorWeight: 2,
        labelColor: BmbColors.blue,
        unselectedLabelColor: BmbColors.textTertiary,
        labelStyle: TextStyle(fontSize: 12, fontWeight: BmbFontWeights.bold),
        tabs: const [
          Tab(text: 'General', icon: Icon(Icons.chat, size: 16)),
          Tab(text: 'Trivia', icon: Icon(Icons.quiz, size: 16)),
          Tab(text: 'Winners', icon: Icon(Icons.emoji_events, size: 16)),
        ],
      ),
    );
  }

  // ─── TRIVIA TAB ────────────────────────────────────────────────────────
  Widget _buildTriviaTab() {
    if (!_triviaLoaded) {
      return const Center(child: CircularProgressIndicator(color: BmbColors.gold));
    }

    final questions = _triviaService.todayQuestions;
    if (questions.isEmpty) {
      return Center(child: Text('No trivia today. Check back tomorrow!', style: TextStyle(color: BmbColors.textSecondary)));
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildStreakBanner()),
        SliverToBoxAdapter(child: _buildActiveQuestionCard()),
        if (_showReward) SliverToBoxAdapter(child: _buildRewardBanner()),
        SliverToBoxAdapter(child: _buildProgressDots()),
        SliverToBoxAdapter(child: _buildTriviaLeaderboard()),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

  Widget _buildStreakBanner() {
    final streak = _triviaService.currentStreak;
    final best = _triviaService.bestStreak;
    final today = _triviaService.todayAnswered;
    final total = _triviaService.todayTotal;
    final todayCredits = _triviaService.todayCreditsEarned;
    final toReward = 10 - (streak % 10);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          BmbColors.gold.withValues(alpha: 0.12),
          BmbColors.gold.withValues(alpha: 0.04),
        ]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: BmbColors.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.local_fire_department, color: BmbColors.gold, size: 20),
                    Text('$streak', style: TextStyle(color: BmbColors.gold, fontSize: 11, fontWeight: BmbFontWeights.bold)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Daily Trivia', style: TextStyle(color: BmbColors.textPrimary, fontSize: 15, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: BmbColors.errorRed.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.timer, color: BmbColors.errorRed, size: 10),
                            const SizedBox(width: 2),
                            Text('TIMED', style: TextStyle(color: BmbColors.errorRed, fontSize: 8, fontWeight: BmbFontWeights.bold, letterSpacing: 0.5)),
                          ]),
                        ),
                      ],
                    ),
                    Text('$today/$total answered  |  Best streak: $best  |  ${_triviaService.dailyCorrectRemaining} credits left today',
                    style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: BmbColors.successGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.savings, color: BmbColors.successGreen, size: 14),
                  const SizedBox(width: 4),
                  Text('+$todayCredits', style: TextStyle(color: BmbColors.successGreen, fontSize: 12, fontWeight: BmbFontWeights.bold)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Difficulty legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _difficultyLegend('EASY', const Color(0xFF4CAF50), '15s / 1cr'),
              const SizedBox(width: 12),
              _difficultyLegend('MED', const Color(0xFFFFA726), '12s / 2cr'),
              const SizedBox(width: 12),
              _difficultyLegend('HARD', const Color(0xFFEF5350), '10s / 3cr'),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (streak % 10) / 10,
              minHeight: 6,
              backgroundColor: BmbColors.borderColor,
              valueColor: const AlwaysStoppedAnimation<Color>(BmbColors.gold),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            streak % 10 == 0 && streak > 0
                ? '10-streak bonus! +5 credits earned! Keep going!'
                : '$toReward more correct in a row for +5 bonus credits!',
            style: TextStyle(color: BmbColors.gold, fontSize: 10, fontWeight: BmbFontWeights.semiBold),
          ),
        ],
      ),
    );
  }

  Widget _difficultyLegend(String label, Color color, String desc) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 3),
        Text('$label ', style: TextStyle(color: color, fontSize: 9, fontWeight: BmbFontWeights.bold)),
        Text(desc, style: TextStyle(color: BmbColors.textTertiary, fontSize: 9)),
      ],
    );
  }

  Widget _buildActiveQuestionCard() {
    final questions = _triviaService.todayQuestions;
    final allDone = _triviaService.nextQuestionIndex < 0 && !_answered;
    final limitReached = _triviaService.dailyLimitReached && !_answered;

    // Daily credit limit reached — show notification card
    if (limitReached) {
      _stopCountdown();
      return Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            BmbColors.gold.withValues(alpha: 0.08),
            const Color(0xFFFF6B35).withValues(alpha: 0.06),
          ]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BmbColors.gold.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: BmbColors.gold.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_clock, color: BmbColors.gold, size: 32),
            ),
            const SizedBox(height: 14),
            Text("Daily Credit Limit Reached!", style: TextStyle(
                color: BmbColors.gold, fontSize: 18,
                fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: BmbColors.gold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "You've answered ${TriviaService.dailyCorrectLimit} questions correctly today "
                "and earned +${_triviaService.todayCreditsEarned} credits!",
                style: TextStyle(color: BmbColors.textPrimary, fontSize: 14,
                    fontWeight: BmbFontWeights.medium, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today, color: BmbColors.blue, size: 16),
                const SizedBox(width: 6),
                Text('Come back tomorrow to earn more credits!',
                    style: TextStyle(color: BmbColors.blue, fontSize: 13,
                        fontWeight: BmbFontWeights.semiBold)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Streak: ${_triviaService.currentStreak} in a row!',
                style: TextStyle(color: BmbColors.gold, fontSize: 13,
                    fontWeight: BmbFontWeights.bold)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: BmbColors.cardDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BmbColors.borderColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: BmbColors.textTertiary, size: 14),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Free trivia is limited to ${TriviaService.dailyCorrectLimit} correct answers per day to keep things fair for everyone.',
                    style: TextStyle(color: BmbColors.textTertiary, fontSize: 11, height: 1.3),
                  )),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (allDone) {
      _stopCountdown();
      return Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: BmbColors.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BmbColors.gold.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: BmbColors.gold, size: 48),
            const SizedBox(height: 12),
            Text("You've completed today's trivia!", style: TextStyle(color: BmbColors.textPrimary, fontSize: 18, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
            const SizedBox(height: 6),
            Text('Come back tomorrow for 10 new questions.', style: TextStyle(color: BmbColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 4),
            Text('Streak: ${_triviaService.currentStreak} in a row!', style: TextStyle(color: BmbColors.gold, fontSize: 14, fontWeight: BmbFontWeights.bold)),
            const SizedBox(height: 4),
            Text('Credits earned today: +${_triviaService.todayCreditsEarned}', style: TextStyle(color: BmbColors.successGreen, fontSize: 13, fontWeight: BmbFontWeights.semiBold)),
          ],
        ),
      );
    }

    if (_activeQuestionIndex >= questions.length) return const SizedBox.shrink();
    final q = questions[_activeQuestionIndex];
    final categoryColors = {
      'NBA': const Color(0xFFFF6B35),
      'NFL': const Color(0xFF795548),
      'NCAA': const Color(0xFF1E88E5),
      'MLB': const Color(0xFFE53935),
      'General': BmbColors.blue,
      'NHL': const Color(0xFF00838F),
    };
    final catColor = categoryColors[q.category] ?? BmbColors.blue;

    // Difficulty colors
    Color diffColor;
    String diffLabel;
    switch (q.difficulty) {
      case TriviaDifficulty.easy:
        diffColor = const Color(0xFF4CAF50);
        diffLabel = 'EASY';
      case TriviaDifficulty.medium:
        diffColor = const Color(0xFFFFA726);
        diffLabel = 'MEDIUM';
      case TriviaDifficulty.hard:
        diffColor = const Color(0xFFEF5350);
        diffLabel = 'HARD';
    }

    // Timer color: green > 60%, yellow > 30%, red otherwise
    final timeRatio = q.timeLimit > 0 ? _secondsRemaining / q.timeLimit : 0.0;
    final timerColor = _answered
        ? BmbColors.textTertiary
        : timeRatio > 0.6
            ? const Color(0xFF4CAF50)
            : timeRatio > 0.3
                ? const Color(0xFFFFA726)
                : const Color(0xFFEF5350);

    final isCorrect = _answered && _selectedChoice == q.correctIndex;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _answered
            ? (isCorrect ? BmbColors.successGreen : BmbColors.errorRed).withValues(alpha: 0.6)
            : _timedOut ? BmbColors.errorRed.withValues(alpha: 0.6) : BmbColors.borderColor),
        boxShadow: [
          if (isCorrect)
            BoxShadow(color: BmbColors.successGreen.withValues(alpha: 0.15), blurRadius: 16),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: category + difficulty + timer + Q counter
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(q.category, style: TextStyle(color: catColor, fontSize: 10, fontWeight: BmbFontWeights.bold)),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: diffColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: diffColor.withValues(alpha: 0.4)),
                ),
                child: Text(diffLabel, style: TextStyle(color: diffColor, fontSize: 9, fontWeight: BmbFontWeights.bold, letterSpacing: 0.5)),
              ),
              const Spacer(),
              // Countdown timer display
              if (!_answered)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: timerColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: timerColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.timer, color: timerColor, size: 14),
                    const SizedBox(width: 3),
                    Text(
                      '${_secondsRemaining}s',
                      style: TextStyle(color: timerColor, fontSize: 13, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay'),
                    ),
                  ]),
                )
              else
                Text('Q${_activeQuestionIndex + 1}/${questions.length}', style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
              if (!_answered) ...[
                const SizedBox(width: 8),
                Text('Q${_activeQuestionIndex + 1}/${questions.length}', style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
              ],
            ],
          ),
          // Timer progress bar
          if (!_answered) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: q.timeLimit > 0 ? _secondsRemaining / q.timeLimit : 0,
                minHeight: 4,
                backgroundColor: BmbColors.borderColor.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(timerColor),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(q.question, style: TextStyle(color: BmbColors.textPrimary, fontSize: 16, fontWeight: BmbFontWeights.bold, height: 1.4)),
          const SizedBox(height: 4),
          // Credit value hint
          if (!_answered)
            Text('Worth ${q.baseCredits} credit${q.baseCredits > 1 ? "s" : ""} + speed bonus possible', style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
          const SizedBox(height: 12),
          ...List.generate(q.choices.length, (i) => _buildChoiceTile(q, i)),
          const SizedBox(height: 12),
          if (!_answered)
            SizedBox(
              width: double.infinity, height: 46,
              child: ElevatedButton(
                onPressed: _selectedChoice != null ? _submitAnswer : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BmbColors.blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: BmbColors.cardDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Lock In Answer', style: TextStyle(fontWeight: BmbFontWeights.bold, fontSize: 15)),
              ),
            )
          else ...[
            _buildAnswerResult(q, isCorrect),
          ],
        ],
      ),
    );
  }

  Widget _buildAnswerResult(TriviaQuestion q, bool isCorrect) {
    final svc = _triviaService;
    final wasTimeout = svc.lastTimedOut;

    String title;
    Color resultColor;
    IconData resultIcon;

    if (wasTimeout) {
      title = 'Time\'s Up! Streak reset to 0.';
      resultColor = BmbColors.errorRed;
      resultIcon = Icons.timer_off;
    } else if (isCorrect) {
      title = 'Correct! Streak: ${svc.currentStreak}';
      resultColor = BmbColors.successGreen;
      resultIcon = Icons.check_circle;
    } else {
      title = 'Wrong! Streak reset to 0.';
      resultColor = BmbColors.errorRed;
      resultIcon = Icons.cancel;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: resultColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(resultIcon, color: resultColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: resultColor, fontSize: 13, fontWeight: BmbFontWeights.bold)),
                    const SizedBox(height: 4),
                    Text(q.explanation, style: TextStyle(color: BmbColors.textSecondary, fontSize: 12, height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
          // Credits breakdown
          if (isCorrect && svc.lastCreditsAwarded > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: BmbColors.successGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: BmbColors.successGreen.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.savings, color: BmbColors.successGreen, size: 16),
                  const SizedBox(width: 6),
                  Text('+${svc.lastCreditsAwarded} credits', style: TextStyle(color: BmbColors.successGreen, fontSize: 12, fontWeight: BmbFontWeights.bold)),
                  if (svc.lastWasSpeedBonus) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: BmbColors.gold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                      child: Text('SPEED', style: TextStyle(color: BmbColors.gold, fontSize: 8, fontWeight: BmbFontWeights.bold)),
                    ),
                  ],
                  if (svc.lastWasStreakBonus) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: const Color(0xFF9C27B0).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                      child: Text('10x STREAK', style: TextStyle(color: const Color(0xFF9C27B0), fontSize: 8, fontWeight: BmbFontWeights.bold)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChoiceTile(TriviaQuestion q, int i) {
    final isSelected = _selectedChoice == i;
    final isCorrect = q.correctIndex == i;
    Color borderColor = BmbColors.borderColor;
    Color bgColor = BmbColors.cardDark;
    Color textColor = BmbColors.textPrimary;
    IconData? trailingIcon;

    if (_answered) {
      if (isCorrect) {
        borderColor = BmbColors.successGreen;
        bgColor = BmbColors.successGreen.withValues(alpha: 0.12);
        textColor = BmbColors.successGreen;
        trailingIcon = Icons.check_circle;
      } else if (isSelected && !isCorrect) {
        borderColor = BmbColors.errorRed;
        bgColor = BmbColors.errorRed.withValues(alpha: 0.12);
        textColor = BmbColors.errorRed;
        trailingIcon = Icons.cancel;
      }
    } else if (isSelected) {
      borderColor = BmbColors.blue;
      bgColor = BmbColors.blue.withValues(alpha: 0.12);
      textColor = BmbColors.blue;
    }

    return GestureDetector(
      onTap: _answered ? null : () => setState(() => _selectedChoice = i),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected && !_answered ? BmbColors.blue : Colors.transparent,
                border: Border.all(color: _answered && isCorrect ? BmbColors.successGreen : isSelected ? BmbColors.blue : BmbColors.textTertiary, width: 1.5),
              ),
              child: Center(
                child: Text(String.fromCharCode(65 + i), style: TextStyle(
                  color: isSelected && !_answered ? Colors.white : textColor,
                  fontSize: 12, fontWeight: BmbFontWeights.bold,
                )),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(q.choices[i], style: TextStyle(color: textColor, fontSize: 13, fontWeight: isSelected ? BmbFontWeights.semiBold : FontWeight.normal))),
            if (trailingIcon != null) Icon(trailingIcon, color: textColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardBanner() {
    final svc = _triviaService;
    final credits = svc.lastCreditsAwarded;
    if (credits <= 0) return const SizedBox.shrink();

    final isStreakBonus = svc.lastWasStreakBonus;
    final title = isStreakBonus
        ? '10-STREAK BONUS! +$credits CREDITS!'
        : '+$credits CREDIT${credits > 1 ? "S" : ""} EARNED!';
    final subtitle = isStreakBonus
        ? '10 correct in a row! Bonus credits added to your BMB Bucket.'
        : 'Credits added to your BMB Bucket. Keep the streak alive!';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [BmbColors.successGreen.withValues(alpha: 0.2), BmbColors.successGreen.withValues(alpha: 0.05)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BmbColors.successGreen.withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: BmbColors.successGreen.withValues(alpha: 0.2), blurRadius: 16)],
      ),
      child: Row(
        children: [
          const Icon(Icons.celebration, color: BmbColors.gold, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: BmbColors.successGreen, fontSize: 14, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
                Text(subtitle, style: TextStyle(color: BmbColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: BmbColors.successGreen.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: Text('+$credits', style: TextStyle(color: BmbColors.successGreen, fontSize: 12, fontWeight: BmbFontWeights.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressDots() {
    final questions = _triviaService.todayQuestions;
    final answered = _triviaService.todayAnswered;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(questions.length, (i) {
          Color color;
          if (i < answered) {
            color = BmbColors.successGreen;
          } else if (i == _activeQuestionIndex) {
            color = BmbColors.blue;
          } else {
            color = BmbColors.borderColor;
          }
          return Container(
            width: i == _activeQuestionIndex ? 20 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTriviaLeaderboard() {
    final lb = _triviaService.leaderboard;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BmbColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.leaderboard, color: BmbColors.gold, size: 18),
            const SizedBox(width: 6),
            Text('Trivia Leaderboard', style: TextStyle(color: BmbColors.textPrimary, fontSize: 14, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
          ]),
          const SizedBox(height: 10),
          ...List.generate(lb.length.clamp(0, 7), (i) {
            final p = lb[i];
            final isMe = CurrentUserService.instance.isCurrentUser(p.playerId);
            final medal = i == 0 ? Icons.emoji_events : i == 1 ? Icons.military_tech : i == 2 ? Icons.workspace_premium : null;
            final medalColor = i == 0 ? BmbColors.gold : i == 1 ? const Color(0xFFC0C0C0) : i == 2 ? const Color(0xFFCD7F32) : null;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isMe ? BmbColors.blue.withValues(alpha: 0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isMe ? Border.all(color: BmbColors.blue.withValues(alpha: 0.3)) : null,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: medal != null
                        ? Icon(medal, color: medalColor, size: 18)
                        : Text('#${i + 1}', style: TextStyle(color: BmbColors.textTertiary, fontSize: 12, fontWeight: BmbFontWeights.bold)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isMe ? '${p.playerName} (You)' : p.playerName,
                      style: TextStyle(color: isMe ? BmbColors.blue : BmbColors.textPrimary, fontSize: 13, fontWeight: isMe ? BmbFontWeights.bold : FontWeight.normal),
                    ),
                  ),
                  Icon(Icons.local_fire_department, color: BmbColors.gold, size: 12),
                  Text('${p.currentStreak}', style: TextStyle(color: BmbColors.gold, fontSize: 11)),
                  const SizedBox(width: 10),
                  Text('${p.totalCorrect}', style: TextStyle(color: BmbColors.textPrimary, fontSize: 13, fontWeight: BmbFontWeights.bold)),
                  Text(' pts', style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── GENERAL CHAT LIST ─────────────────────────────────────────────────
  Widget _buildChatList(List<_CommunityMessage> messages) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              if (msg.isGiveawaySplash && msg.giveawayResult != null) {
                return _buildGiveawaySplashCard(msg);
              }
              return _buildMessageBubble(msg);
            },
          ),
        ),
        // Hype Man typing indicator
        if (_hypeManTyping)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: BmbColors.gold.withValues(alpha: 0.2),
                    border: Border.all(color: BmbColors.gold.withValues(alpha: 0.5)),
                  ),
                  child: Center(child: Text('B', style: TextStyle(color: BmbColors.gold, fontSize: 11, fontWeight: BmbFontWeights.bold))),
                ),
                const SizedBox(width: 8),
                Text('BMB Hype Man', style: TextStyle(color: BmbColors.gold, fontSize: 11, fontWeight: BmbFontWeights.bold)),
                const SizedBox(width: 6),
                Text('is typing', style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
                const SizedBox(width: 4),
                SizedBox(
                  width: 20,
                  child: _TypingDots(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildWinnersList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _winnerMessages.length,
      itemBuilder: (context, index) {
        final msg = _winnerMessages[index];
        if (msg.isGiveawaySplash && msg.giveawayResult != null) {
          return _buildGiveawaySplashCard(msg);
        }
        return _buildWinnerCard(msg);
      },
    );
  }

  Widget _buildMessageBubble(_CommunityMessage msg) {
    final isMe = msg.isCurrentUser;
    final isHypeMan = msg.userId == 'bot_hype';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            _buildAvatar(msg),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Reply-to indicator
                if (msg.replyToUser != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 2, left: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: BmbColors.borderColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                      border: Border(left: BorderSide(
                        color: isHypeMan ? BmbColors.gold : BmbColors.blue,
                        width: 2,
                      )),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.reply, size: 10, color: BmbColors.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          '@${msg.replyToUser}',
                          style: TextStyle(color: isHypeMan ? BmbColors.gold : BmbColors.blue, fontSize: 10, fontWeight: BmbFontWeights.bold),
                        ),
                        if (msg.replyToMessage != null) ...[
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              msg.replyToMessage!,
                              style: TextStyle(color: BmbColors.textTertiary, fontSize: 10),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                // Message bubble
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isMe
                        ? BmbColors.blue.withValues(alpha: 0.2)
                        : isHypeMan
                            ? BmbColors.gold.withValues(alpha: 0.1)
                            : msg.isBmb
                                ? BmbColors.gold.withValues(alpha: 0.08)
                                : BmbColors.cardDark,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isMe ? 12 : 4),
                      topRight: Radius.circular(isMe ? 4 : 12),
                      bottomLeft: const Radius.circular(12),
                      bottomRight: const Radius.circular(12),
                    ),
                    border: isHypeMan
                        ? Border.all(color: BmbColors.gold.withValues(alpha: 0.2))
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        if (isHypeMan) ...[
                          Icon(Icons.campaign, size: 12, color: BmbColors.gold),
                          const SizedBox(width: 3),
                        ],
                        Text(msg.userName, style: TextStyle(
                          color: isHypeMan ? BmbColors.gold
                              : msg.userId == 'bot_marcus' ? const Color(0xFFFF6B35)
                              : msg.userId == 'bot_jess' ? const Color(0xFF9C27B0)
                              : msg.isBmb ? BmbColors.gold : BmbColors.blue,
                          fontSize: 11, fontWeight: BmbFontWeights.bold,
                        )),
                        if (msg.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, color: BmbColors.blue, size: 12),
                        ],
                        if (msg.state != null) ...[
                          const SizedBox(width: 4),
                          Text(msg.state!, style: TextStyle(color: BmbColors.textTertiary, fontSize: 9)),
                        ],
                        const Spacer(),
                        Text(_formatTime(msg.time), style: TextStyle(color: BmbColors.textTertiary, fontSize: 9)),
                      ]),
                      const SizedBox(height: 4),
                      Text(msg.message, style: TextStyle(color: BmbColors.textPrimary, fontSize: 13, height: 1.4)),
                      // Bracket picks card attachment
                      if (msg.bracketPost != null) ...[
                        const SizedBox(height: 8),
                        _buildBracketPicksCard(msg.bracketPost!),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  /// Clickable bracket picks card that shows inside a community message.
  Widget _buildBracketPicksCard(CommunityBracketPost post) {
    return GestureDetector(
      onTap: () => _showFullPicksSheet(post),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            BmbColors.blue.withValues(alpha: 0.12),
            BmbColors.blue.withValues(alpha: 0.04),
          ]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: BmbColors.blue.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.account_tree, color: BmbColors.blue, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  post.bracketName,
                  style: TextStyle(color: BmbColors.textPrimary, fontSize: 12, fontWeight: BmbFontWeights.bold),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: BmbColors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(post.sport, style: TextStyle(color: BmbColors.blue, fontSize: 9, fontWeight: BmbFontWeights.bold)),
              ),
            ]),
            if (post.championPick != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: BmbColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: BmbColors.gold.withValues(alpha: 0.25)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.emoji_events, color: BmbColors.gold, size: 14),
                  const SizedBox(width: 4),
                  Text('Champ: ${post.championPick}', style: TextStyle(color: BmbColors.gold, fontSize: 11, fontWeight: BmbFontWeights.bold)),
                ]),
              ),
            ],
            const SizedBox(height: 6),
            Row(children: [
              Text('${post.totalPicks} picks', style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
              const SizedBox(width: 8),
              if (post.tieBreakerPrediction != null) ...[
                Icon(Icons.sports_score, color: BmbColors.textTertiary, size: 10),
                const SizedBox(width: 2),
                Text('TB: ${post.tieBreakerPrediction} pts', style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text('View Bracket', style: TextStyle(color: BmbColors.blue, fontSize: 10, fontWeight: BmbFontWeights.bold)),
                const SizedBox(width: 2),
                Icon(Icons.open_in_new, color: BmbColors.blue, size: 12),
              ]),
            ]),
          ],
        ),
      ),
    );
  }

  /// Full-screen bracket tree view showing actual bracket visualization
  /// with "Post to Socials" integration.
  void _showFullPicksSheet(CommunityBracketPost post) {
    final displayName = post.userName == 'You' ? 'BracketKing' : post.userName;

    // If the post has bracket tree data, show the real bracket tree viewer
    if (post.teams != null && post.teams!.isNotEmpty && post.picksMap != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BracketTreeViewerScreen(
            userName: displayName,
            bracketName: post.bracketName,
            sport: post.sport,
            teams: post.teams!,
            picks: post.picksMap!,
            totalRounds: post.totalRounds ?? 3,
            championPick: post.championPick,
            tieBreakerPrediction: post.tieBreakerPrediction,
            ownerUserId: post.userId,
          ),
        ),
      );
    } else {
      // Fallback: show text summary for legacy posts without tree data
      _showLegacyPicksSheet(post);
    }
  }

  /// Legacy text-based picks sheet for older posts without bracket tree data.
  void _showLegacyPicksSheet(CommunityBracketPost post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: BmbColors.midNavy,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollCtrl) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: BmbColors.borderColor, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [BmbColors.blue, const Color(0xFF5B6EFF)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_tree, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      '${post.userName == 'You' ? 'BracketKing' : post.userName}\'s Picks',
                      style: TextStyle(color: BmbColors.textPrimary, fontSize: 17, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay'),
                    ),
                    Text(post.bracketName, style: TextStyle(color: BmbColors.textTertiary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollCtrl,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: BmbColors.cardGradient,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: BmbColors.borderColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      post.summary,
                      style: TextStyle(color: BmbColors.textSecondary, fontSize: 12, height: 1.6, fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWinnerCard(_CommunityMessage msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [BmbColors.gold.withValues(alpha: 0.12), BmbColors.gold.withValues(alpha: 0.04)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(children: [
            const Icon(Icons.emoji_events, color: BmbColors.gold, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('WINNER', style: TextStyle(color: BmbColors.gold, fontSize: 10, fontWeight: BmbFontWeights.bold, letterSpacing: 1)),
                if (msg.winnerName != null)
                  Text(msg.winnerName!, style: TextStyle(color: BmbColors.textPrimary, fontSize: 16, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
              ]),
            ),
            Text(_formatDate(msg.time), style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
          ]),
          const SizedBox(height: 10),
          Text(msg.message, style: TextStyle(color: BmbColors.textSecondary, fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }

  /// BIG SPLASH giveaway card — stands out from all other posts.
  /// Gold gradient border, confetti icon, animated feel, winner details inline.
  Widget _buildGiveawaySplashCard(_CommunityMessage msg) {
    final result = msg.giveawayResult;
    if (result == null) return const SizedBox.shrink();

    final w1 = result.winners.isNotEmpty ? result.winners[0] : null;
    final w2 = result.winners.length > 1 ? result.winners[1] : null;
    final leader = result.leaderboardLeader;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            BmbColors.gold.withValues(alpha: 0.2),
            const Color(0xFFFFC107).withValues(alpha: 0.12),
            BmbColors.gold.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BmbColors.gold, width: 1.5),
        boxShadow: [
          BoxShadow(color: BmbColors.gold.withValues(alpha: 0.15), blurRadius: 12, spreadRadius: 2),
        ],
      ),
      child: Column(
        children: [
          // Gold header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [BmbColors.gold, const Color(0xFFFFC107)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.celebration, color: Colors.black, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('GIVEAWAY WINNERS',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 13,
                        fontWeight: BmbFontWeights.bold,
                        letterSpacing: 2,
                        fontFamily: 'ClashDisplay',
                      )),
                ),
                const Icon(Icons.celebration, color: Colors.black, size: 22),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Bracket name
                Text(result.bracketName,
                    style: TextStyle(
                      color: BmbColors.textPrimary,
                      fontSize: 15,
                      fontWeight: BmbFontWeights.bold,
                    ),
                    textAlign: TextAlign.center),
                const SizedBox(height: 14),
                // Winner #1 — DOUBLE
                if (w1 != null) _giveawayWinnerRow(
                  label: '1ST DRAW \u2014 2x',
                  name: w1.userName,
                  credits: w1.creditsAwarded,
                  color: BmbColors.gold,
                  icon: Icons.looks_one,
                ),
                if (w2 != null) ...[
                  const SizedBox(height: 8),
                  _giveawayWinnerRow(
                    label: '2ND DRAW \u2014 1x',
                    name: w2.userName,
                    credits: w2.creditsAwarded,
                    color: BmbColors.blue,
                    icon: Icons.looks_two,
                  ),
                ],
                if (leader != null) ...[
                  const SizedBox(height: 8),
                  _giveawayWinnerRow(
                    label: 'LEADERBOARD LEADER',
                    name: leader.userName,
                    credits: leader.creditsAwarded,
                    color: const Color(0xFF5B8DEF),
                    icon: Icons.leaderboard,
                  ),
                ],
                const SizedBox(height: 12),
                // Stats row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: BmbColors.cardDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _splashStat('${result.totalParticipants}', 'Players'),
                      Container(width: 1, height: 20, color: BmbColors.borderColor),
                      _splashStat('${result.contributionAmount}', 'Contribution'),
                      Container(width: 1, height: 20, color: BmbColors.borderColor),
                      _splashStat('${result.totalCreditsAwarded}', 'Total Awarded'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Instant deposit badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bolt, color: BmbColors.successGreen, size: 14),
                    const SizedBox(width: 4),
                    Text('Credits deposited instantly to BMB Buckets',
                        style: TextStyle(color: BmbColors.successGreen, fontSize: 10, fontWeight: BmbFontWeights.semiBold)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(_formatDate(msg.time),
                    style: TextStyle(color: BmbColors.textTertiary, fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _giveawayWinnerRow({
    required String label,
    required String name,
    required int credits,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: BmbFontWeights.bold, letterSpacing: 1)),
                const SizedBox(height: 2),
                Text(name, style: TextStyle(color: BmbColors.textPrimary, fontSize: 14, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: BmbColors.successGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('+$credits', style: TextStyle(color: BmbColors.successGreen, fontSize: 13, fontWeight: BmbFontWeights.bold)),
          ),
        ],
      ),
    );
  }

  Widget _splashStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: BmbColors.textPrimary, fontSize: 13, fontWeight: BmbFontWeights.bold)),
        Text(label, style: TextStyle(color: BmbColors.textTertiary, fontSize: 9)),
      ],
    );
  }

  Widget _buildAvatar(_CommunityMessage msg) {
    final isHypeMan = msg.userId == 'bot_hype';
    final isMarcus = msg.userId == 'bot_marcus';
    final isJess = msg.userId == 'bot_jess';
    final color = isHypeMan
        ? BmbColors.gold
        : isMarcus
            ? const Color(0xFFFF6B35) // warm orange for Marcus
            : isJess
                ? const Color(0xFF9C27B0) // purple for Jess
                : msg.isBmb
                    ? BmbColors.blue
                    : _colorForUser(msg.userId);
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Center(
        child: isHypeMan
            ? Icon(Icons.campaign, color: BmbColors.gold, size: 16)
            : isMarcus
                ? Icon(Icons.sports_basketball, color: color, size: 16)
                : isJess
                    ? Icon(Icons.star, color: color, size: 16)
                    : Text(msg.userName[0].toUpperCase(), style: TextStyle(color: color, fontSize: 13, fontWeight: BmbFontWeights.bold)),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: BmbColors.deepNavy,
        border: Border(top: BorderSide(color: BmbColors.borderColor.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: BmbColors.cardDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: BmbColors.borderColor),
              ),
              child: TextField(
                controller: _messageController,
                style: TextStyle(color: BmbColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Say something to the BMB fam...',
                  hintStyle: TextStyle(color: BmbColors.textTertiary, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [BmbColors.blue, const Color(0xFF5B6EFF)]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  void _showDailyChallenge() {
    showModalBottomSheet(
      context: context,
      backgroundColor: BmbColors.midNavy,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: BmbColors.borderColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Icon(Icons.local_fire_department, color: BmbColors.gold, size: 48),
            const SizedBox(height: 12),
            Text('Daily Challenge', style: TextStyle(color: BmbColors.textPrimary, fontSize: 20, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(gradient: BmbColors.cardGradient, borderRadius: BorderRadius.circular(12), border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3))),
              child: Column(children: [
                Text('Predict Tonight\'s Score', style: TextStyle(color: BmbColors.gold, fontSize: 14, fontWeight: BmbFontWeights.bold)),
                const SizedBox(height: 8),
                Text('Duke vs UNC \u2014 Championship Game\nPredict the total combined points. Closest wins 50 bonus credits!', style: TextStyle(color: BmbColors.textSecondary, fontSize: 12, height: 1.4), textAlign: TextAlign.center),
              ]),
            ),
            const SizedBox(height: 16),
            _challengeOption('Under 130 points'),
            _challengeOption('130-145 points'),
            _challengeOption('146-160 points'),
            _challengeOption('Over 160 points'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _challengeOption(String text) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Your prediction "$text" has been locked in!'),
          backgroundColor: BmbColors.midNavy, behavior: SnackBarBehavior.floating,
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(gradient: BmbColors.cardGradient, borderRadius: BorderRadius.circular(10), border: Border.all(color: BmbColors.borderColor)),
        child: Row(children: [
          const Icon(Icons.radio_button_unchecked, color: BmbColors.blue, size: 18),
          const SizedBox(width: 10),
          Text(text, style: TextStyle(color: BmbColors.textPrimary, fontSize: 13)),
        ]),
      ),
    );
  }

  Color _colorForUser(String id) {
    final colors = [BmbColors.blue, BmbColors.gold, BmbColors.successGreen, const Color(0xFF9C27B0), const Color(0xFFFF6B35), const Color(0xFF00BCD4)];
    return colors[id.hashCode.abs() % colors.length];
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  String _formatDate(DateTime time) {
    return '${time.month}/${time.day}/${time.year}';
  }
}

// ─── TYPING DOTS ANIMATION ─────────────────────────────────────────────
class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this)..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final offset = (_ctrl.value * 3 - i).clamp(0.0, 1.0);
            final opacity = (1.0 - (offset - 0.5).abs() * 2).clamp(0.3, 1.0);
            return Container(
              width: 4, height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: BmbColors.gold.withValues(alpha: opacity),
              ),
            );
          }),
        );
      },
    );
  }
}

class _CommunityMessage {
  final String userId;
  final String userName;
  final String message;
  final DateTime time;
  final String? state;
  final bool isVerified;
  final bool isBmb;
  final bool isCurrentUser;
  final bool isWinner;
  final String? winnerName;
  final String? replyToUser;
  final String? replyToMessage;
  final CommunityBracketPost? bracketPost;
  final bool isGiveawaySplash;
  final GiveawayResult? giveawayResult;

  const _CommunityMessage({
    required this.userId,
    required this.userName,
    required this.message,
    required this.time,
    this.state,
    this.isVerified = false,
    this.isBmb = false,
    this.isCurrentUser = false,
    this.isWinner = false,
    this.winnerName,
    this.replyToUser,
    this.replyToMessage,
    this.bracketPost,
    this.isGiveawaySplash = false,
    this.giveawayResult,
  });
}

// ═══════════════════════════════════════════════════════════════
// BRACKET TREE VIEW SCREEN — full-screen read-only bracket tree
// ═══════════════════════════════════════════════════════════════

// _BracketTreeViewScreen moved to BracketTreeViewerScreen
// in lib/features/sharing/presentation/screens/bracket_tree_viewer_screen.dart
