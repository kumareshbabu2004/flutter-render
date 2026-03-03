import 'dart:math';

/// BMB Hype Man — always-on engagement engine.
///
/// The Hype Man is the life of the BMB Community chat. He:
/// 1. **Always replies** to user messages with context-aware responses
/// 2. **Sparks conversation** proactively on a timer with questions, polls, hype
/// 3. **Keeps energy high** with varied tones: hype, supportive, funny, curious
/// 4. **Never feels robotic** — large response pools with keyword matching
class HypeManService {
  static final _random = Random();

  // ─── CONTEXT-AWARE REPLY GENERATION ──────────────────────────────────
  /// Generate a direct reply to a user's specific message.
  /// Analyzes keywords to produce a relevant, engaging response.
  static String generateReplyTo(String userName, String userMessage) {
    final msg = userMessage.toLowerCase();

    // Greeting detection
    if (_matchesAny(msg, ['hey', 'hello', 'hi ', 'what\'s up', 'sup', 'yo '])) {
      return _pick([
        'Yooo $userName! Welcome to the party!',
        'What\'s good $userName?! Glad you\'re here!',
        '$userName in the building!! LET\'S GO!',
        'Ayyy $userName! You ready to talk brackets?!',
        'Hey hey $userName! The chat just got better!',
        '$userName! What\'s the move today? Got any hot takes?',
      ]);
    }

    // Bracket / picks talk
    if (_matchesAny(msg, ['bracket', 'pick', 'picks', 'filled out', 'submitted', 'locked in'])) {
      return _pick([
        'LOVE the confidence $userName! What\'s your championship pick?!',
        '$userName coming in hot with the bracket talk! Who\'s your sleeper team??',
        'That\'s what I like to hear $userName! Bold picks win championships!',
        '$userName locked and loaded! Post your final four I wanna see it!',
        'Bracket season is EVERYTHING! $userName gets it!',
        'Talk your talk $userName! What round is your bracket busting? Be honest',
      ]);
    }

    // Team mentions
    if (_matchesAny(msg, ['duke', 'unc', 'kentucky', 'gonzaga', 'kansas', 'villanova'])) {
      return _pick([
        '$userName with the blue blood pick! Respect! But can they go ALL the way?',
        'Ohhh $userName is riding with the big dogs! Bold!',
        '$userName that\'s a solid pick. But what happens when they face a hot 12-seed?',
        'Classic pick $userName! Nothing wrong with trusting the pedigree!',
        'I see you $userName! That squad has been on a tear this season!',
      ]);
    }

    if (_matchesAny(msg, ['lakers', 'celtics', 'warriors', 'nuggets', 'heat', 'bucks', 'nba'])) {
      return _pick([
        '$userName talking NBA? I\'m HERE for it! Who\'s winning it all??',
        'OOH $userName with the NBA take! Playoffs are gonna be WILD this year!',
        '$userName you think they can make a run?? I want to believe!',
        'That\'s a spicy NBA take $userName! Drop your playoff bracket!',
      ]);
    }

    if (_matchesAny(msg, ['chiefs', 'eagles', '49ers', 'ravens', 'cowboys', 'nfl', 'football'])) {
      return _pick([
        '$userName talking football?! WHO DEY!! Drop your Super Bowl pick!',
        'NFL talk in the building! $userName who\'s your dark horse??',
        '$userName you think they got what it takes?! Playoff football hits different!',
        'Love the NFL energy $userName! This season is wide open!',
      ]);
    }

    if (_matchesAny(msg, ['baseball', 'mlb', 'yankees', 'dodgers', 'astros'])) {
      return _pick([
        '$userName! Baseball brackets are underrated! What\'s your World Series pick??',
        'Diamond talk! $userName who\'s your sleeper team this year?!',
        '$userName we need more baseball brackets on BMB! You hosting one??',
      ]);
    }

    // Upset / underdog talk
    if (_matchesAny(msg, ['upset', 'underdog', 'cinderella', '12-seed', '12 seed', 'busted'])) {
      return _pick([
        'UPSET CITY $userName!! Nothing beats a Cinderella run!',
        '$userName is on team chaos and I LOVE IT!',
        'The beautiful madness! $userName who\'s your upset special this year??',
        '$userName said UNDERDOG ENERGY and I\'m here for it!!',
        'Busted brackets make the best stories! Right $userName?!',
      ]);
    }

    // Winning / bragging
    if (_matchesAny(msg, ['won', 'winning', 'first place', 'champion', 'leaderboard', 'dominating', 'crushed'])) {
      return _pick([
        '$userName is on FIRE! Respect the grind!!',
        'CHAMPION MENTALITY from $userName right here!',
        'We see you $userName! Climbing that leaderboard!',
        '$userName talking like a winner! Back it up in your next bracket!',
        'That\'s what we love to see $userName! BMB legends are made here!',
      ]);
    }

    // Losing / busted bracket
    if (_matchesAny(msg, ['lost', 'busted', 'terrible', 'worst', 'trash', 'done for'])) {
      return _pick([
        'Hey $userName, even the GOAT busts a bracket sometimes! Redemption arc starts NOW!',
        '$userName don\'t stress! New brackets drop every day on BMB!',
        'It\'s okay $userName, the next one is YOUR bracket! I believe in you!',
        '$userName we\'ve ALL been there. That\'s what makes the wins so sweet!',
        'Bust it and dust it $userName! Next bracket you\'re coming back stronger!',
      ]);
    }

    // Trivia mentions
    if (_matchesAny(msg, ['trivia', 'quiz', 'streak', 'question', 'correct', 'answer'])) {
      return _pick([
        '$userName talking trivia?? Yo that streak leaderboard is INTENSE!',
        'Have you played today\'s trivia yet $userName? 15 in a row = 15 FREE credits!',
        '$userName the trivia questions today are no joke! How\'s your streak??',
        'Get those free credits $userName! Trivia tab is right there!',
        '$userName who needs to study when you\'ve got sports knowledge like that!',
      ]);
    }

    // Credits / prize talk
    if (_matchesAny(msg, ['credits', 'prize', 'money', 'win', 'earn', 'bucket', 'store'])) {
      return _pick([
        '$userName stacking credits! The BMB Store has some FIRE rewards right now!',
        'Get that bag $userName! Credits in the bucket!',
        '$userName playing for credits?! That\'s what BMB is all about!',
        'Credits talk! $userName have you checked out the store lately? Gift cards, merch, ALL of it!',
      ]);
    }

    // Excitement / fire / hype
    if (_matchesAny(msg, ['fire', 'let\'s go', 'hype', 'pump', 'excited', 'ready', 'game day', 'letsgo'])) {
      return _pick([
        'THAT\'S THE ENERGY $userName!! LET\'S GOOO!!',
        '$userName IS HYPED AND SO AM I!! BRACKET SEASON BABY!!',
        'I can feel the energy through the screen $userName! THIS IS BMB!',
        '$userName bringing the FIRE! Who else is locked in?!',
        'GAME DAY VIBES from $userName!! This is why I love this community!',
      ]);
    }

    // Questions from users
    if (msg.contains('?')) {
      return _pick([
        'Great question $userName! What does everybody else think??',
        'Ooh $userName asking the real questions! Drop your takes below!',
        '$userName wants to know! BMB fam, help them out!',
        'I love this $userName! Let\'s get a debate going!',
        '$userName throwing it out there! Who\'s got the answer??',
      ]);
    }

    // Emoji-heavy messages
    if (_matchesAny(msg, ['lol', 'lmao', 'haha', 'dead', 'crying'])) {
      return _pick([
        '$userName!! I\'m DEAD! This community is too funny!',
        'Hahahaha $userName you\'re wild! Keep that energy!',
        '$userName bringing the laughs AND the brackets! Legend!',
        'The BMB chat stays undefeated in comedy! Right $userName?!',
      ]);
    }

    // Default — generic but still engaging, always addresses user by name
    return _pick([
      'I hear you $userName! Keep that energy going!',
      '$userName bringing the vibes! What bracket are you playing next?!',
      'Love seeing $userName in the chat! This community is ELITE!',
      '$userName always keeping it real! What\'s your next move on BMB?',
      'Facts $userName! The BMB fam agrees! Who else??',
      'Big talk from $userName! I respect it! What\'s your bracket record this year?',
      '$userName that\'s what\'s up! You playing any brackets today?',
      'Yo $userName, you ever think about hosting your own bracket? You\'d be great at it!',
      '$userName you\'re one of the reasons this community is fire!',
      'Tell me more $userName! I\'m all ears!',
      '$userName just dropped knowledge! Who\'s taking notes??',
      'Period $userName! Couldn\'t have said it better!',
    ]);
  }

  // ─── PROACTIVE CONVERSATION STARTERS ─────────────────────────────────
  /// Messages the Hype Man sends unprompted to keep conversation flowing.
  /// These ask questions, spark debate, create polls, and hype events.
  static String generateProactiveMessage() {
    return _pick([
      // Debate starters
      'HOT TAKE TIME! Is a 1-seed losing in the first round more shocking than a 16-seed winning it all?? Drop your take!',
      'SETTLE THIS: Who\'s the GOAT bracket picker? Someone who goes all chalk or someone who picks upsets?',
      'BMB FAM! If you could only watch ONE sport for the rest of your life, what is it??',
      'Real talk: Do you fill out your bracket with your heart or your head?? Be honest!',
      'POLL TIME: Best sport for brackets? Basketball, Football, Baseball, or Soccer?? GO!',

      // Hype / energy
      'VIBE CHECK! Who\'s feeling GOOD about their brackets today?! Drop a fire emoji!',
      'It\'s a BEAUTIFUL day to fill out a bracket! Who\'s with me?!',
      'ENERGY LEVEL: 10/10!! The BMB Community is the BEST community on the internet and I\'ll fight anyone who disagrees!',
      'Who else checks their bracket standings first thing in the morning?? Just me?? No way!',
      'SHOUTOUT to everyone grinding the trivia today! Those 15 free credits are CALLING your name!',

      // Engagement questions
      'Quick question: What\'s the CRAZIEST upset you\'ve ever seen in a tournament?? I need stories!',
      'Who in here has a PERFECT bracket going right now?? If you do, you\'re a legend!',
      'What bracket are you most excited about right now?? Drop the name!',
      'How many brackets are you currently in?? I bet someone in here is in 10+ and I respect it!',
      'Who introduced you to bracket competitions?? How did you find BMB??',

      // Trivia / knowledge
      'POP QUIZ: What team has the most Final Four appearances? Answer in chat!',
      'Did you know BMB gives 15 FREE credits for a 15-correct trivia streak?? Get on it!',
      'BRAIN TEASER: Name 3 teams that have won back-to-back championships. GO!',
      'FUN FACT: The odds of a perfect March Madness bracket are 1 in 9.2 QUINTILLION. And yet we all try anyway! That\'s the spirit!',

      // Community building
      'Who\'s new to BMB?? Welcome!! This is the most fun you\'ll have with sports brackets ANYWHERE!',
      'Big love to everyone in the chat right now! This community is what makes BMB special!',
      'Reminder: You can earn credits just by playing trivia, hosting brackets, and being active! BMB PAYS to play!',
      'Anyone hosting a bracket this week?? Post it in here and let\'s get people to join!',
      'What feature do you love MOST about BMB?? The brackets? The trivia? The community? THE PRIZES?!',
    ]);
  }

  // ─── MARCUS JOHNSON REPLIES ─────────────────────────────────────────
  /// Marc_Buckets is the confident, opinionated sports analyst. He has hot takes
  /// and isn't afraid to disagree. Loves NFL/NBA, from Texas.
  static String generateMarcusReply(String userName, String userMessage) {
    final msg = userMessage.toLowerCase();

    if (_matchesAny(msg, ['bracket', 'pick', 'picks', 'submitted', 'locked in'])) {
      return _pick([
        'respect the confidence $userName. what\'s your upset pick tho? that\'s where the money is',
        'aight $userName I\'m curious - you going chalk or chaos? I need to know who I\'m dealing with',
        '$userName dropping picks like a pro. I\'d love to compare brackets sometime',
        'solid $userName. I just reworked my bracket for the third time today lol can\'t stop tweaking it',
        'wait $userName did you post those picks yet? I wanna see what you\'re working with',
      ]);
    }

    if (_matchesAny(msg, ['duke', 'unc', 'kentucky', 'gonzaga', 'kansas'])) {
      return _pick([
        'been saying the same thing $userName. that team is built for a run',
        'nah $userName I gotta push back on that one. they look good on paper but the bench is thin',
        'interesting choice $userName. I had them in my Final Four then took them out. still not sure tbh',
        'you might be right $userName but I\'m not ready to commit to that pick yet. lemme see one more game',
      ]);
    }

    if (_matchesAny(msg, ['nba', 'lakers', 'celtics', 'warriors', 'nuggets', 'cowboys', 'nfl', 'chiefs'])) {
      return _pick([
        'now we\'re talking $userName. this is my lane. been watching film all week',
        '$userName I been saying the same thing and nobody wants to listen to me',
        'you and me both $userName. had this argument with Queen yesterday and she wasn\'t hearing it',
        'real recognize real $userName. solid take and I\'m standing on it',
      ]);
    }

    if (_matchesAny(msg, ['upset', 'underdog', 'cinderella', 'busted'])) {
      return _pick([
        'here\'s my issue with upsets $userName - they\'re fun until YOUR bracket gets busted. then it\'s personal',
        '$userName I love the upset talk but I\'ve been burned too many times. going safe this year... maybe',
        'the data says upsets are rare but my gut says we\'re due for a big one. what do you think $userName?',
        'don\'t let Queen hear you say that $userName. she\'ll have you picking 15-seeds in every region',
      ]);
    }

    if (_matchesAny(msg, ['trivia', 'streak', 'credits', 'quiz'])) {
      return _pick([
        'I got a 14 streak going $userName. one more and I\'m cashing in those credits',
        'the trivia is addicting honestly $userName. told myself I\'d stop at 5 questions and here I am 2 hours later',
        'those hard questions are no joke $userName. the 10-second timer had me sweating',
        'yo $userName the trivia today was actually tough. that NCAA question had me second guessing everything',
      ]);
    }

    if (_matchesAny(msg, ['lol', 'lmao', 'haha', 'funny'])) {
      return _pick([
        'ha $userName you\'re not wrong. this chat is comedy',
        '$userName man this community is something else. I literally can\'t leave',
        'yo $userName Queen would say the same thing. she stays cracking up in here',
        'lmaooo $userName I can\'t with this chat sometimes',
      ]);
    }

    if (msg.contains('?')) {
      return _pick([
        'that\'s actually a great question $userName. my take? go with your gut',
        'ooh $userName asking the hard questions. I\'ve been thinking about that too honestly',
        'I was literally just talking about this $userName. let me drop my take...',
        'I got an opinion on this $userName but Queen is gonna disagree with me no matter what I say lol',
      ]);
    }

    return _pick([
      'I hear you $userName. respect',
      '$userName that\'s facts. no debate',
      'yo $userName have you checked out any of the free brackets today? some good ones up',
      'real talk $userName this chat is the best part of my day',
      'I feel that $userName. BMB community stays winning',
      'you should host a bracket sometime $userName. I\'d join for sure',
      'big facts $userName. couldn\'t have said it better',
      '$userName speaking truth right now. somebody write that down',
      'exactly $userName. been thinking the same thing all day',
      'man $userName you always come through with the takes. respect',
    ]);
  }

  // ─── QUEEN_OF_UPSETS REPLIES ──────────────────────────────────────
  /// Queen_of_Upsets is the witty, competitive upset queen. She loves underdogs,
  /// challenges Marc constantly, and keeps the energy fun. From Florida.
  static String generateJessReply(String userName, String userMessage) {
    final msg = userMessage.toLowerCase();

    if (_matchesAny(msg, ['bracket', 'pick', 'picks', 'submitted', 'locked in'])) {
      return _pick([
        'ooh $userName let me see those picks. I bet you\'ve got at least one upset in there',
        '$userName I love people who aren\'t afraid to post their picks. Marc could learn from you honestly',
        'nice $userName! you going bold or playing it safe? because I always go bold',
        'post that bracket $userName I wanna compare. and don\'t worry I won\'t judge... much lol',
        'wait you locked in already $userName?? I\'m still second guessing my Sweet 16',
      ]);
    }

    if (_matchesAny(msg, ['duke', 'unc', 'kentucky', 'gonzaga', 'kansas'])) {
      return _pick([
        '$userName that\'s a fine pick but where\'s the excitement?? give me a sleeper. a dark horse',
        'see this is the difference between me and Marc. he\'d agree with you $userName. I want chaos',
        'respectable $userName but I\'ve got a mid-major going further than them. watch',
        '$userName classic choice. safe. boring. jk ...kind of',
      ]);
    }

    if (_matchesAny(msg, ['upset', 'underdog', 'cinderella', 'busted'])) {
      return _pick([
        'now we\'re talking $userName. upsets are literally the best part of brackets',
        '$userName you\'re my kind of person. underdogs all day. Marc hates when I say that',
        'yes $userName. I had a 12-seed in my Elite Eight last year and Marc clowned me... until they won',
        'cinderella energy $userName. this is what I live for. Marc can keep his chalk',
      ]);
    }

    if (_matchesAny(msg, ['nba', 'lakers', 'celtics', 'warriors', 'nfl', 'chiefs', 'cowboys'])) {
      return _pick([
        'not gonna lie $userName I don\'t watch as much NBA as Marc but I still have better takes somehow',
        'ok $userName but real question - is that team actually good or just famous? I need receipts',
        '$userName Marc thinks he\'s the only one who can talk ball. watch me prove him wrong',
        'spicy take $userName. Marc would overthink this but I\'m just going with vibes',
      ]);
    }

    if (_matchesAny(msg, ['trivia', 'streak', 'credits', 'quiz'])) {
      return _pick([
        'not gonna lie $userName those hard questions with the 10-second timer are stressful. my palms were sweating',
        'I beat Marc on the trivia leaderboard yesterday $userName. he hasn\'t talked to me since lol',
        '$userName those speed bonuses are clutch. I answered in 3 seconds once and got extra credits',
        'the trivia has me hooked $userName. I was supposed to go to bed an hour ago',
      ]);
    }

    if (_matchesAny(msg, ['lol', 'lmao', 'haha', 'funny'])) {
      return _pick([
        '$userName stop I can\'t take it. this chat has me dying',
        'lmaooo $userName. I screenshot messages from this chat and send them to my friends',
        '$userName you know what\'s even funnier? Marc\'s bracket. don\'t tell him I said that',
        'I\'m literally crying $userName. this community is unhinged and I love it',
      ]);
    }

    if (msg.contains('?')) {
      return _pick([
        'ooh I have thoughts on this $userName. you ready?',
        'great question $userName. my answer is probably the opposite of whatever Marc says',
        'love this question $userName. short answer: go with your heart not your head',
        'let me think... actually no I already know. $userName trust the underdog. always',
      ]);
    }

    return _pick([
      '$userName preach. this is why I love BMB',
      'say it louder for the people in the back $userName',
      'honestly same $userName. this community gets me',
      'real ones know $userName. real ones know',
      'I was just thinking the same thing $userName. great minds',
      'facts $userName. and if Marc disagrees he\'s wrong. as usual',
      'you should hang out in chat more $userName. we need this energy',
      'I told Marc the exact same thing $userName. he never listens to me',
      'this is why I keep coming back to this app $userName. the vibes are unmatched',
      '$userName ngl you\'re one of the more interesting people in this chat',
    ]);
  }

  // ─── MARCUS vs JESS BANTER ───────────────────────────────────────
  /// Generates back-and-forth debate between Marcus and Jess.
  /// Returns a list of (botId, botName, message, state) exchanges.
  static List<(String, String, String, String)> generateMarcusJessBanter() {
    return _pick([
      // Debate 1: Chalk vs Upset
      [
        ('bot_marcus', 'Marc_Buckets', 'I\'m telling y\'all - chalk picks win brackets. The data is clear. Stop picking upsets just for fun.', 'TX'),
        ('bot_jess', 'Queen_of_Upsets', 'Marc here we go again. Your "data" said the 1-seeds were safe last year too. How\'d that work out?', 'FL'),
        ('bot_marcus', 'Marc_Buckets', 'ONE upset doesn\'t change the stats Queen. You got lucky with that 12-seed pick and now you think you\'re Nostradamus.', 'TX'),
        ('bot_jess', 'Queen_of_Upsets', 'Lucky?? I STUDIED that team! Their guard play was elite! You just don\'t want to admit I was right.', 'FL'),
      ],
      // Debate 2: Best sport for brackets
      [
        ('bot_marcus', 'Marc_Buckets', 'NFL playoffs are the best bracket format. Single elimination, every game matters. Can\'t beat it.', 'TX'),
        ('bot_jess', 'Queen_of_Upsets', 'Excuse me? March Madness is LITERALLY called the greatest sporting event in America. It\'s not even close Marc.', 'FL'),
        ('bot_marcus', 'Marc_Buckets', 'March Madness is fun but the NFL playoffs have STAKES. The emotions are on another level.', 'TX'),
        ('bot_jess', 'Queen_of_Upsets', 'The emotions?? A 16-seed beating a 1-seed doesn\'t give you emotions?! I can\'t with you sometimes.', 'FL'),
      ],
      // Debate 3: Strategy
      [
        ('bot_jess', 'Queen_of_Upsets', 'Hot take: Everyone who fills out their bracket with analytics is boring. There I said it.', 'FL'),
        ('bot_marcus', 'Marc_Buckets', 'Queen that is the most anti-intellectual thing I\'ve ever heard. Analytics WIN. Eye test is a coin flip.', 'TX'),
        ('bot_jess', 'Queen_of_Upsets', 'Oh please Marc. Your analytics bracket lost to my "vibes only" bracket THREE times last month.', 'FL'),
        ('bot_marcus', 'Marc_Buckets', '...that was a small sample size. Over a full season I\'m winning that matchup and you know it.', 'TX'),
      ],
      // Debate 4: Team loyalty
      [
        ('bot_marcus', 'Marc_Buckets', 'Question for the chat: Is it disloyal to pick against your own team in a bracket? I say no. It\'s smart.', 'TX'),
        ('bot_jess', 'Queen_of_Upsets', 'MARC! You can\'t pick against your own team! That\'s bad juju! You\'re cursing them!', 'FL'),
        ('bot_marcus', 'Marc_Buckets', 'Jess it\'s not a curse it\'s called being realistic. My team is a 7-seed. I\'m not delusional.', 'TX'),
        ('bot_jess', 'Queen_of_Upsets', 'I had my team winning it all last year. Were they a 14-seed? Yes. Did they lose in round 1? Also yes. But I BELIEVED.', 'FL'),
      ],
      // Debate 5: Trivia bragging rights
      [
        ('bot_marcus', 'Marc_Buckets', 'Just hit a 12-streak on trivia. Jess what\'s your streak at? Asking for the leaderboard.', 'TX'),
        ('bot_jess', 'Queen_of_Upsets', 'Marc you KNOW I\'m at 15. I literally screenshot it and sent it to you. Stop playing.', 'FL'),
        ('bot_marcus', 'Marc_Buckets', 'You got lucky on that last hard question. "Which team won the 1983 championship" - you GUESSED.', 'TX'),
        ('bot_jess', 'Queen_of_Upsets', 'It\'s called educated guessing Marc. Something you should try instead of overthinking every question until the timer runs out.', 'FL'),
      ],
      // Debate 6: Hosting brackets
      [
        ('bot_jess', 'Queen_of_Upsets', 'I\'m thinking about hosting a bracket this week. All upset picks required. Who\'s in?', 'FL'),
        ('bot_marcus', 'Marc_Buckets', 'An ALL UPSET bracket?? Jess that\'s the most chaotic thing I\'ve ever heard. I love it. But also it\'s terrible strategy.', 'TX'),
        ('bot_jess', 'Queen_of_Upsets', 'It\'s not about strategy Marc it\'s about FUN. Remember fun? You used to have it before you became a stats robot.', 'FL'),
        ('bot_marcus', 'Marc_Buckets', 'OK first of all - rude. Second of all... I\'m joining your bracket. But I\'m picking chalk out of spite.', 'TX'),
      ],
      // Debate 7: Predictions
      [
        ('bot_marcus', 'Marc_Buckets', 'Bold prediction: No 1-seeds in the Final Four this year. The parity is insane.', 'TX'),
        ('bot_jess', 'Queen_of_Upsets', 'Wait... Marc making a bold prediction?? Who are you and what did you do with ChalkMaster Jr??', 'FL'),
        ('bot_marcus', 'Marc_Buckets', 'I\'m evolving Jess. Growth. You should try it.', 'TX'),
        ('bot_jess', 'Queen_of_Upsets', 'Oh I\'ve BEEN evolved. I predicted upsets before it was cool. Welcome to the club. Took you long enough.', 'FL'),
      ],
    ]);
  }

  // ─── FOLLOW-UP MESSAGES ──────────────────────────────────────────────
  /// Secondary messages that other bots post after Hype Man to keep threads alive.
  static (String botId, String botName, String message, String state) generateFollowUp(String topic) {
    final msg = topic.toLowerCase();

    if (_matchesAny(msg, ['bracket', 'pick', 'upset', 'chalk'])) {
      return _pick([
        ('bot_cindy', 'CinderellaFan', 'Upsets make brackets FUN! I\'m all in on chaos!', 'FL'),
        ('bot_chalky', 'ChalkMaster', 'Trust the process. Chalk wins championships.', 'TX'),
        ('bot_stats', 'StatGuru42', 'The data says go with matchup efficiency. Trust the numbers!', 'NY'),
        ('bot_jam81', 'JamSession81', 'My bracket is looking CLEAN right now. Feeling dangerous!', 'IL'),
        ('bot_madness', 'MarchMadnessMax', 'This is what March is all about! LOVE IT!', 'NC'),
      ]);
    }

    if (_matchesAny(msg, ['trivia', 'quiz', 'streak', 'credits'])) {
      return _pick([
        ('bot_stats', 'StatGuru42', 'I\'m on a 12 streak right now. So close to those 15 credits!', 'NY'),
        ('bot_jam81', 'JamSession81', 'The trivia today was tough! That NFL question got me.', 'IL'),
        ('bot_lucky', 'LuckyBreaks', 'I guessed my way to an 8 streak. Pure luck!', 'NV'),
        ('bot_hoop', 'HoopDreams99', 'NBA trivia is my lane. Don\'t test me!', 'OH'),
      ]);
    }

    // Default follow-ups
    return _pick([
      ('bot_swish', 'SwishKing', 'Facts! This chat is always fire!', 'CA'),
      ('bot_jam81', 'JamSession81', 'Love this energy! BMB community is the best!', 'IL'),
      ('bot_hoop', 'HoopDreams99', 'Real talk! I\'m here all day!', 'OH'),
      ('bot_lucky', 'LuckyBreaks', 'I couldn\'t agree more! This is why I keep coming back!', 'NV'),
      ('bot_madness', 'MarchMadnessMax', 'BMB bringing the vibes as usual!', 'NC'),
      ('bot_cindy', 'CinderellaFan', 'This is my favorite chat on the internet honestly!', 'FL'),
    ]);
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────
  static bool _matchesAny(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }

  static T _pick<T>(List<T> options) {
    return options[_random.nextInt(options.length)];
  }
}
