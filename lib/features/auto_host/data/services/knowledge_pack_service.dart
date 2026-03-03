import 'package:bmb_mobile/features/auto_host/data/models/knowledge_pack.dart';

/// Central registry of all knowledge packs available for auto-bracket building.
/// These are the "smart content" pools that the Auto-Builder pulls from when
/// a host says e.g. "Host me a best 90s rock band tournament."
class KnowledgePackService {
  KnowledgePackService._();
  static final KnowledgePackService instance = KnowledgePackService._();

  /// All available knowledge packs.
  static const List<KnowledgePack> allPacks = [
    // ═══════════════════════════════════════════════════════════════
    // SPORTS
    // ═══════════════════════════════════════════════════════════════
    KnowledgePack(
      id: 'nfl_quarterbacks_2025',
      name: 'Best NFL Quarterback',
      description: 'Top NFL quarterbacks for a popularity / GOAT debate bracket.',
      category: 'sports',
      bracketType: 'voting',
      defaultSize: 16,
      items: [
        'Patrick Mahomes', 'Josh Allen', 'Lamar Jackson', 'Joe Burrow',
        'Jalen Hurts', 'Dak Prescott', 'Justin Herbert', 'Tua Tagovailoa',
        'Jordan Love', 'CJ Stroud', 'Brock Purdy', 'Jared Goff',
        'Trevor Lawrence', 'Kyler Murray', 'Baker Mayfield', 'Aaron Rodgers',
      ],
      keywords: ['nfl', 'quarterback', 'qb', 'football', 'nfl qb', 'best quarterback'],
      eventDateHint: 'september-february',
      isSeasonal: true,
    ),
    KnowledgePack(
      id: 'nba_players_2025',
      name: 'Best NBA Player',
      description: 'Top NBA players for a GOAT debate bracket.',
      category: 'sports',
      bracketType: 'voting',
      defaultSize: 16,
      items: [
        'Nikola Jokic', 'Luka Doncic', 'Giannis Antetokounmpo', 'Jayson Tatum',
        'Shai Gilgeous-Alexander', 'Anthony Edwards', 'Kevin Durant', 'Stephen Curry',
        'LeBron James', 'Joel Embiid', 'Devin Booker', 'Ja Morant',
        'Donovan Mitchell', 'Jimmy Butler', 'Damian Lillard', 'Anthony Davis',
      ],
      keywords: ['nba', 'basketball player', 'best nba', 'nba player', 'basketball'],
      eventDateHint: 'october-june',
      isSeasonal: true,
    ),
    KnowledgePack(
      id: 'nfl_teams',
      name: 'Best NFL Team',
      description: 'All 32 NFL teams for a popularity vote.',
      category: 'sports',
      bracketType: 'voting',
      defaultSize: 32,
      items: [
        'Kansas City Chiefs', 'San Francisco 49ers', 'Dallas Cowboys', 'Philadelphia Eagles',
        'Buffalo Bills', 'Baltimore Ravens', 'Detroit Lions', 'Miami Dolphins',
        'Cincinnati Bengals', 'Green Bay Packers', 'Cleveland Browns', 'Jacksonville Jaguars',
        'Houston Texans', 'New York Jets', 'Los Angeles Rams', 'Pittsburgh Steelers',
        'Minnesota Vikings', 'Tampa Bay Buccaneers', 'Seattle Seahawks', 'Denver Broncos',
        'Atlanta Falcons', 'Los Angeles Chargers', 'New Orleans Saints', 'New York Giants',
        'Chicago Bears', 'Las Vegas Raiders', 'Tennessee Titans', 'Indianapolis Colts',
        'Washington Commanders', 'Carolina Panthers', 'Arizona Cardinals', 'New England Patriots',
      ],
      keywords: ['nfl team', 'football team', 'best nfl team', 'favorite nfl'],
    ),
    KnowledgePack(
      id: 'nba_teams',
      name: 'Best NBA Team',
      description: 'All 30 NBA teams for a popularity bracket.',
      category: 'sports',
      bracketType: 'voting',
      defaultSize: 32,
      items: [
        'Los Angeles Lakers', 'Boston Celtics', 'Golden State Warriors', 'Chicago Bulls',
        'Miami Heat', 'Denver Nuggets', 'Milwaukee Bucks', 'Philadelphia 76ers',
        'Dallas Mavericks', 'Phoenix Suns', 'Brooklyn Nets', 'New York Knicks',
        'Cleveland Cavaliers', 'Toronto Raptors', 'San Antonio Spurs', 'Houston Rockets',
        'Memphis Grizzlies', 'Minnesota Timberwolves', 'Sacramento Kings', 'Indiana Pacers',
        'Atlanta Hawks', 'New Orleans Pelicans', 'Oklahoma City Thunder', 'Orlando Magic',
        'Portland Trail Blazers', 'Charlotte Hornets', 'Utah Jazz', 'Detroit Pistons',
        'Washington Wizards', 'Los Angeles Clippers',
      ],
      keywords: ['nba team', 'basketball team', 'best nba team', 'favorite nba team'],
    ),

    // ═══════════════════════════════════════════════════════════════
    // MUSIC
    // ═══════════════════════════════════════════════════════════════
    KnowledgePack(
      id: '90s_rock_bands',
      name: 'Best 90s Rock Band',
      description: 'The definitive 90s rock showdown — grunge, alternative, punk.',
      category: 'music',
      bracketType: 'voting',
      defaultSize: 16,
      items: [
        'Nirvana', 'Pearl Jam', 'Radiohead', 'Red Hot Chili Peppers',
        'Oasis', 'Green Day', 'Weezer', 'Soundgarden',
        'Alice in Chains', 'Smashing Pumpkins', 'Foo Fighters', 'Blink-182',
        'Stone Temple Pilots', 'Rage Against the Machine', 'Bush', 'Third Eye Blind',
      ],
      keywords: ['90s rock', '90s band', 'rock band', 'grunge', '90s music', 'nineties rock'],
    ),
    KnowledgePack(
      id: '80s_rock_bands',
      name: 'Best 80s Rock Band',
      description: 'Hair metal, new wave, and classic rock from the 1980s.',
      category: 'music',
      bracketType: 'voting',
      defaultSize: 16,
      items: [
        'Guns N\' Roses', 'Bon Jovi', 'Def Leppard', 'Van Halen',
        'Metallica', 'U2', 'AC/DC', 'The Cure',
        'Depeche Mode', 'Motley Crue', 'Iron Maiden', 'Aerosmith',
        'The Police', 'Journey', 'INXS', 'Duran Duran',
      ],
      keywords: ['80s rock', '80s band', 'hair metal', '80s music', 'eighties rock'],
    ),
    KnowledgePack(
      id: 'top_rappers',
      name: 'Best Rapper',
      description: 'The greatest MCs of all time — vote for the hip-hop GOAT.',
      category: 'music',
      bracketType: 'voting',
      defaultSize: 16,
      items: [
        'Kendrick Lamar', 'Eminem', 'Jay-Z', 'Tupac Shakur',
        'The Notorious B.I.G.', 'Nas', 'Lil Wayne', 'Drake',
        'Kanye West', 'J. Cole', 'Andre 3000', 'Ice Cube',
        'Snoop Dogg', 'Rakim', 'Missy Elliott', 'Lauryn Hill',
      ],
      keywords: ['rapper', 'hip hop', 'rap', 'best rapper', 'mc', 'hip-hop', 'goat rapper'],
    ),
    KnowledgePack(
      id: 'top_country_artists',
      name: 'Best Country Artist',
      description: 'Country music legends and modern stars.',
      category: 'music',
      bracketType: 'voting',
      defaultSize: 16,
      items: [
        'Johnny Cash', 'Dolly Parton', 'George Strait', 'Garth Brooks',
        'Willie Nelson', 'Hank Williams', 'Reba McEntire', 'Alan Jackson',
        'Luke Combs', 'Morgan Wallen', 'Chris Stapleton', 'Zach Bryan',
        'Carrie Underwood', 'Tim McGraw', 'Keith Urban', 'Blake Shelton',
      ],
      keywords: ['country', 'country music', 'country artist', 'country singer', 'nashville'],
    ),

    // ═══════════════════════════════════════════════════════════════
    // FOOD & DRINK
    // ═══════════════════════════════════════════════════════════════
    KnowledgePack(
      id: 'best_beer_brands',
      name: 'Best Beer Brand',
      description: 'The ultimate beer brand showdown — craft vs. classic.',
      category: 'food',
      bracketType: 'voting',
      defaultSize: 16,
      items: [
        'Guinness', 'Heineken', 'Corona', 'Blue Moon',
        'Sam Adams', 'Sierra Nevada', 'Modelo', 'Yuengling',
        'Lagunitas', 'Stone IPA', 'Dos Equis', 'Stella Artois',
        'Budweiser', 'Coors', 'Miller Lite', 'PBR',
      ],
      keywords: ['beer', 'beer brand', 'best beer', 'brew', 'brewery', 'craft beer'],
    ),
    KnowledgePack(
      id: 'best_pizza_chain',
      name: 'Best Pizza Chain',
      description: 'Which pizza chain serves the best slice?',
      category: 'food',
      bracketType: 'voting',
      defaultSize: 16,
      items: [
        'Domino\'s', 'Pizza Hut', 'Papa John\'s', 'Little Caesars',
        'Marco\'s Pizza', 'Jet\'s Pizza', 'Round Table', 'Blaze Pizza',
        'MOD Pizza', 'Sbarro', 'Cicis', 'Papa Murphy\'s',
        'Hungry Howie\'s', 'Donatos', 'Toppers', 'Mountain Mike\'s',
      ],
      keywords: ['pizza', 'pizza chain', 'best pizza', 'pizza brand'],
    ),
    KnowledgePack(
      id: 'best_wings_flavor',
      name: 'Best Wing Flavor',
      description: 'Perfect for bar nights — vote for the ultimate wing flavor.',
      category: 'food',
      bracketType: 'voting',
      defaultSize: 16,
      items: [
        'Buffalo', 'Honey BBQ', 'Garlic Parmesan', 'Lemon Pepper',
        'Mango Habanero', 'Carolina Gold', 'Teriyaki', 'Cajun',
        'Thai Chili', 'Sweet Chili', 'Nashville Hot', 'Old Bay',
        'Ranch', 'Jerk', 'Korean BBQ', 'Plain / Naked',
      ],
      keywords: ['wings', 'wing flavor', 'chicken wings', 'best wings', 'buffalo'],
    ),
    KnowledgePack(
      id: 'best_taco',
      name: 'Best Taco Type',
      description: 'Taco Tuesday showdown.',
      category: 'food',
      bracketType: 'voting',
      defaultSize: 16,
      items: [
        'Al Pastor', 'Carne Asada', 'Birria', 'Carnitas',
        'Fish Taco', 'Shrimp Taco', 'Barbacoa', 'Chicken Tinga',
        'Lengua', 'Chorizo', 'Ground Beef', 'Brisket',
        'Veggie', 'Bean & Cheese', 'Breakfast Taco', 'Street Corn',
      ],
      keywords: ['taco', 'tacos', 'taco tuesday', 'best taco', 'mexican food'],
    ),

    // ═══════════════════════════════════════════════════════════════
    // ENTERTAINMENT
    // ═══════════════════════════════════════════════════════════════
    KnowledgePack(
      id: 'best_marvel_movie',
      name: 'Best Marvel Movie',
      description: 'MCU showdown — which Marvel film is the GOAT?',
      category: 'entertainment',
      bracketType: 'voting',
      defaultSize: 16,
      items: [
        'Avengers: Endgame', 'Avengers: Infinity War', 'Black Panther', 'Spider-Man: No Way Home',
        'Iron Man', 'Guardians of the Galaxy', 'The Avengers', 'Captain America: Winter Soldier',
        'Thor: Ragnarok', 'Spider-Man: Homecoming', 'Doctor Strange', 'Captain America: Civil War',
        'Black Widow', 'Ant-Man', 'Shang-Chi', 'Deadpool & Wolverine',
      ],
      keywords: ['marvel', 'mcu', 'marvel movie', 'avengers', 'superhero movie'],
    ),
    KnowledgePack(
      id: 'best_90s_movie',
      name: 'Best 90s Movie',
      description: 'The 1990s were a golden era for film. Which movie wins?',
      category: 'entertainment',
      bracketType: 'voting',
      defaultSize: 16,
      items: [
        'The Shawshank Redemption', 'Pulp Fiction', 'Fight Club', 'The Matrix',
        'Forrest Gump', 'Goodfellas', 'Jurassic Park', 'Titanic',
        'The Big Lebowski', 'Saving Private Ryan', 'Se7en', 'The Silence of the Lambs',
        'Toy Story', 'Schindler\'s List', 'The Lion King', 'Scream',
      ],
      keywords: ['90s movie', 'nineties movie', '90s film', 'best 90s movie'],
    ),
    KnowledgePack(
      id: 'best_sitcom',
      name: 'Best Sitcom',
      description: 'Which sitcom is the funniest of all time?',
      category: 'entertainment',
      bracketType: 'voting',
      defaultSize: 16,
      items: [
        'The Office', 'Friends', 'Seinfeld', 'Parks and Recreation',
        'It\'s Always Sunny', 'Brooklyn Nine-Nine', 'Schitt\'s Creek', 'How I Met Your Mother',
        'Arrested Development', 'The Fresh Prince', 'Curb Your Enthusiasm', 'Modern Family',
        '30 Rock', 'Community', 'New Girl', 'Ted Lasso',
      ],
      keywords: ['sitcom', 'comedy show', 'funny show', 'best sitcom', 'tv comedy'],
    ),

    // ═══════════════════════════════════════════════════════════════
    // CULTURE & LIFESTYLE
    // ═══════════════════════════════════════════════════════════════
    KnowledgePack(
      id: 'best_car_brand',
      name: 'Best Car Brand',
      description: 'Dream garage showdown.',
      category: 'culture',
      bracketType: 'voting',
      defaultSize: 16,
      items: [
        'BMW', 'Mercedes-Benz', 'Toyota', 'Porsche',
        'Tesla', 'Ford', 'Chevrolet', 'Audi',
        'Lamborghini', 'Ferrari', 'Jeep', 'Honda',
        'Lexus', 'Range Rover', 'Dodge', 'Subaru',
      ],
      keywords: ['car', 'car brand', 'best car', 'automobile', 'vehicle', 'dream car'],
    ),
    KnowledgePack(
      id: 'best_dog_breed',
      name: 'Best Dog Breed',
      description: 'The most lovable dog breed — settled by popular vote.',
      category: 'culture',
      bracketType: 'voting',
      defaultSize: 16,
      items: [
        'Golden Retriever', 'Labrador Retriever', 'German Shepherd', 'French Bulldog',
        'Poodle', 'Bulldog', 'Beagle', 'Rottweiler',
        'Dachshund', 'Husky', 'Great Dane', 'Corgi',
        'Pitbull', 'Boxer', 'Doberman', 'Shih Tzu',
      ],
      keywords: ['dog', 'dog breed', 'best dog', 'puppy', 'dogs', 'pet'],
    ),

    // ═══════════════════════════════════════════════════════════════
    // MARCH MADNESS (SEASONAL)
    // ═══════════════════════════════════════════════════════════════
    KnowledgePack(
      id: 'march_madness_auto',
      name: 'March Madness Bracket',
      description: 'Auto-built 64-team NCAA March Madness bracket.',
      category: 'sports',
      bracketType: 'standard',
      defaultSize: 64,
      items: [], // Will be pulled from BracketTemplate.marchmadness.defaultTeams
      keywords: ['march madness', 'ncaa', 'ncaa tournament', 'college basketball', 'march', 'big dance'],
      eventDateHint: 'march',
      isSeasonal: true,
    ),
    KnowledgePack(
      id: 'nfl_weekly_pickem',
      name: 'NFL Weekly Pick\'Em',
      description: 'Auto-built weekly NFL pick\'em slate.',
      category: 'sports',
      bracketType: 'pickem',
      defaultSize: 16,
      items: [], // Dynamically populated from current NFL schedule
      keywords: ['nfl pick', 'pick em', 'pickem', 'weekly picks', 'football picks', 'nfl picks'],
      eventDateHint: 'september-february',
      isSeasonal: true,
    ),
    KnowledgePack(
      id: 'super_bowl_props',
      name: 'Super Bowl Props',
      description: 'Super Bowl prop bet bracket.',
      category: 'sports',
      bracketType: 'voting',
      defaultSize: 16,
      items: [
        'First Touchdown Scorer', 'Coin Toss Result', 'National Anthem Length',
        'Halftime Show First Song', 'First Penalty', 'MVP Winner',
        'Total Points Over/Under', 'First Team to Score', 'Longest Field Goal',
        'First Turnover', 'Gatorade Color', 'Will it Go to OT?',
        'Most Passing Yards', 'First Coach Challenge', 'Longest TD', 'First Sack',
      ],
      keywords: ['super bowl', 'superbowl', 'super bowl props', 'props', 'super bowl party'],
      eventDateHint: 'february',
      isSeasonal: true,
    ),
  ];

  /// Find packs that match a voice command or search query.
  /// Returns packs sorted by keyword match relevance (best first).
  List<KnowledgePack> search(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return allPacks;

    final scored = <MapEntry<KnowledgePack, int>>[];
    for (final pack in allPacks) {
      int score = 0;
      // Exact keyword match
      for (final kw in pack.keywords) {
        if (q.contains(kw)) score += 10;
        if (kw.contains(q)) score += 5;
      }
      // Name match
      if (pack.name.toLowerCase().contains(q)) score += 8;
      // Category match
      if (pack.category.toLowerCase().contains(q)) score += 3;
      // Description match
      if (pack.description.toLowerCase().contains(q)) score += 2;

      if (score > 0) scored.add(MapEntry(pack, score));
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }

  /// Find the single best-matching pack for a voice command.
  KnowledgePack? bestMatch(String query) {
    final results = search(query);
    return results.isNotEmpty ? results.first : null;
  }

  /// Get all packs for a specific category.
  List<KnowledgePack> forCategory(String category) =>
      allPacks.where((p) => p.category == category).toList();

  /// Get all seasonal packs (relevant at specific times of year).
  List<KnowledgePack> get seasonalPacks =>
      allPacks.where((p) => p.isSeasonal).toList();

  /// Get all available categories.
  List<String> get categories =>
      allPacks.map((p) => p.category).toSet().toList()..sort();
}
