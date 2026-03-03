class UserProfile {
  final String id;
  final String username;
  final String? displayName;
  final String? bio;
  final String? profileImageUrl;
  final double rating;
  final int reviewCount;
  final bool isVerified;
  final bool isTopHost;
  final bool isBmbPlus;
  final bool isBmbVip; // BMB+ VIP: 2 credits/month for front bracket placement
  final int totalPools;
  final int wins;
  final double earnings;
  final int bmbCredits;
  final int hostedTournaments;
  final int joinedTournaments;
  final bool isAdmin;

  // ─── ADDRESS FIELDS ───────────────────────────────────────────────────
  final String? streetAddress;
  final String? city;
  final String? stateAbbr; // Two-letter US state abbreviation (e.g. "TX")
  final String? zipCode;

  const UserProfile({
    required this.id,
    required this.username,
    this.displayName,
    this.bio,
    this.profileImageUrl,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.isVerified = false,
    this.isTopHost = false,
    this.isBmbPlus = false,
    this.isBmbVip = false,
    this.totalPools = 0,
    this.wins = 0,
    this.earnings = 0.0,
    this.bmbCredits = 0,
    this.hostedTournaments = 0,
    this.joinedTournaments = 0,
    this.isAdmin = false,
    this.streetAddress,
    this.city,
    this.stateAbbr,
    this.zipCode,
  });

  String get displayNameOrUsername => displayName ?? username;

  /// The state abbreviation used everywhere across the platform
  /// next to the user's name (e.g. "BracketKing  TX").
  String? get location => stateAbbr;

  /// Full formatted address line.
  String? get fullAddress {
    final parts = <String>[];
    if (streetAddress != null) parts.add(streetAddress!);
    if (city != null && stateAbbr != null) {
      parts.add('$city, $stateAbbr');
    } else if (city != null) {
      parts.add(city!);
    } else if (stateAbbr != null) {
      parts.add(stateAbbr!);
    }
    if (zipCode != null) parts.add(zipCode!);
    return parts.isEmpty ? null : parts.join(' ');
  }

  /// All 50 US state abbreviations for validation/dropdown.
  static const List<String> usStates = [
    'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
    'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
    'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
    'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
    'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY',
    'DC',
  ];

  /// Full state name map for display purposes.
  static const Map<String, String> stateNames = {
    'AL': 'Alabama', 'AK': 'Alaska', 'AZ': 'Arizona', 'AR': 'Arkansas',
    'CA': 'California', 'CO': 'Colorado', 'CT': 'Connecticut',
    'DE': 'Delaware', 'FL': 'Florida', 'GA': 'Georgia', 'HI': 'Hawaii',
    'ID': 'Idaho', 'IL': 'Illinois', 'IN': 'Indiana', 'IA': 'Iowa',
    'KS': 'Kansas', 'KY': 'Kentucky', 'LA': 'Louisiana', 'ME': 'Maine',
    'MD': 'Maryland', 'MA': 'Massachusetts', 'MI': 'Michigan',
    'MN': 'Minnesota', 'MS': 'Mississippi', 'MO': 'Missouri',
    'MT': 'Montana', 'NE': 'Nebraska', 'NV': 'Nevada',
    'NH': 'New Hampshire', 'NJ': 'New Jersey', 'NM': 'New Mexico',
    'NY': 'New York', 'NC': 'North Carolina', 'ND': 'North Dakota',
    'OH': 'Ohio', 'OK': 'Oklahoma', 'OR': 'Oregon', 'PA': 'Pennsylvania',
    'RI': 'Rhode Island', 'SC': 'South Carolina', 'SD': 'South Dakota',
    'TN': 'Tennessee', 'TX': 'Texas', 'UT': 'Utah', 'VT': 'Vermont',
    'VA': 'Virginia', 'WA': 'Washington', 'WV': 'West Virginia',
    'WI': 'Wisconsin', 'WY': 'Wyoming', 'DC': 'Washington D.C.',
  };
}
