/// BMB Companion persona definitions — real human faces, matched voices.
class CompanionPersona {
  final String id;
  final String name;
  final String nickname;
  final String tagline;
  final String description;
  final String circleAsset; // local asset path for circular avatar
  final String fullAsset; // local asset path for full portrait
  final String voiceIntroUrl; // remote URL for intro voice clip
  final String voiceStyle; // description of voice delivery style

  const CompanionPersona({
    required this.id,
    required this.name,
    required this.nickname,
    required this.tagline,
    required this.description,
    required this.circleAsset,
    required this.fullAsset,
    required this.voiceIntroUrl,
    required this.voiceStyle,
  });

  /// The three launch companions.
  static const List<CompanionPersona> all = [jake, marcus, alex];

  static const jake = CompanionPersona(
    id: 'jake',
    name: 'Jake',
    nickname: 'The Hype Man',
    tagline: 'LET\'S GO! Your bracket is about to be legendary!',
    description:
        'High-energy sports fanatic. Jake is the guy at the bar in the Merritt '
        '#81 jersey who knows every stat and makes everything more exciting. '
        'He delivers tips fast, loud, and with contagious hype.',
    circleAsset: 'assets/companions/jake_circle.png',
    fullAsset: 'assets/companions/jake_full.png',
    voiceIntroUrl: 'https://www.genspark.ai/api/files/s/fx4cBaKN',
    voiceStyle: 'Young energetic Caucasian male, fast-paced, hype-man delivery',
  );

  static const marcus = CompanionPersona(
    id: 'marcus',
    name: 'Marcus',
    nickname: 'The Analyst',
    tagline: 'I study the matchups, I know the numbers, and I got the picks.',
    description:
        'Cool, confident, and always three steps ahead. Marcus is the guy in '
        'the man-cave who breaks down every matchup with precision. Deep voice, '
        'swagger, and he backs up every call with the data.',
    circleAsset: 'assets/companions/marcus_circle.png',
    fullAsset: 'assets/companions/marcus_full.png',
    voiceIntroUrl: 'https://www.genspark.ai/api/files/s/K6MteC9n',
    voiceStyle: 'Deep energetic African American male, confident swagger',
  );

  static const alex = CompanionPersona(
    id: 'alex',
    name: 'Alex',
    nickname: 'The Sleeper',
    tagline: 'Don\'t let the smile fool you. I know more about your team than you do.',
    description:
        'Sharp, witty, and full of surprises. Alex is the woman at the sports '
        'bar who shocks everyone with her depth of knowledge. She delivers tips '
        'with a confident smirk and a little competitive edge.',
    circleAsset: 'assets/companions/alex_circle.png',
    fullAsset: 'assets/companions/alex_full.png',
    voiceIntroUrl: 'https://www.genspark.ai/api/files/s/AlkC5JiV',
    voiceStyle: 'Sharp witty female, confident with competitive edge',
  );

  /// Context-aware guide messages per companion per bracket-builder step.
  /// Returns a map of stepIndex -> message.
  Map<int, String> get bracketGuideMessages {
    switch (id) {
      case 'jake':
        return _jakeMessages;
      case 'marcus':
        return _marcusMessages;
      case 'alex':
        return _alexMessages;
      default:
        return _jakeMessages;
    }
  }

  static const _jakeMessages = {
    0: 'Yo! Let\'s build something EPIC! Pick your bracket type — Standard is the crowd favorite!',
    1: 'Give it a name that POPS! Something everyone\'s gonna remember!',
    2: 'Fill in those teams! Use the search to find the real squads or go custom!',
    3: 'Entry time! Free gets more players in, credits make it competitive. Your call, champ!',
    4: 'PRIZE TIME! This is what everyone plays for. Make it count!',
    5: 'Set that go-live date! Once this drops, it\'s GAME ON!',
    6: 'Look at that! Your bracket is FIRE! Hit confirm and let\'s get this party started!',
  };

  static const _marcusMessages = {
    0: 'What\'s up. First things first — pick your bracket format. Standard is the proven winner.',
    1: 'Name it something clean. This is how people find your tournament.',
    2: 'Add your teams. I\'d use the search — get the real matchups locked in.',
    3: 'Entry setup. Free builds volume, credits build stakes. Think about what fits your group.',
    4: 'Prize selection. This drives engagement. Pick something that makes people show up.',
    5: 'Set your go-live. Give people enough notice to get their picks in.',
    6: 'Everything checks out. Review it one more time and lock it in.',
  };

  static const _alexMessages = {
    0: 'Hey! Pick your bracket type. Standard works for most — but Custom is where it gets fun.',
    1: 'Make the name memorable. Trust me, a good name gets more people to join.',
    2: 'Team time! Search for real teams or type your own. I won\'t judge... much.',
    3: 'Free or paid entry? Free is great for casual, credits if you want skin in the game.',
    4: 'Now the good part — what\'s the winner getting? Make it worth fighting for.',
    5: 'Pick your launch date. Pro tip: give people at least a day to find it and join.',
    6: 'Looking solid! Double-check everything and let\'s make it official.',
  };
}
