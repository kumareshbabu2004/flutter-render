# Product Requirements Document (PRD)
## Back My Bracket (BMB) - Mobile Application
### Version 2.1.0 | Confidential

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Product Vision & Mission](#2-product-vision--mission)
3. [Target Audience](#3-target-audience)
4. [Platform & Technology](#4-platform--technology)
5. [Information Architecture](#5-information-architecture)
6. [Feature Specifications](#6-feature-specifications)
   - 6.1 [Authentication & Onboarding](#61-authentication--onboarding)
   - 6.2 [Dashboard & Navigation](#62-dashboard--navigation)
   - 6.3 [Bracket Board (Live Feed)](#63-bracket-board-live-feed)
   - 6.4 [Game Types](#64-game-types)
   - 6.5 [Bracket Builder](#65-bracket-builder)
   - 6.6 [Tournament Lifecycle](#66-tournament-lifecycle)
   - 6.7 [Scoring & Leaderboard](#67-scoring--leaderboard)
   - 6.8 [Squares Game Mode](#68-squares-game-mode)
   - 6.9 [BMB Credits Economy](#69-bmb-credits-economy)
   - 6.10 [BMB Store & Gift Cards](#610-bmb-store--gift-cards)
   - 6.11 [Bracket Print / "Back It" Merchandise](#611-bracket-print--back-it-merchandise)
   - 6.12 [Charity Brackets](#612-charity-brackets)
   - 6.13 [Chat System](#613-chat-system)
   - 6.14 [AI Auto-Host / Auto-Pilot](#614-ai-auto-host--auto-pilot)
   - 6.15 [Bot Ecosystem](#615-bot-ecosystem)
   - 6.16 [Companion System (Hype Man)](#616-companion-system-hype-man)
   - 6.17 [Host Reviews & Ratings](#617-host-reviews--ratings)
   - 6.18 [Community & Social](#618-community--social)
   - 6.19 [Sharing & Deep Links](#619-sharing--deep-links)
   - 6.20 [Notifications & Inbox](#620-notifications--inbox)
   - 6.21 [Referral Program](#621-referral-program)
   - 6.22 [Promo Codes](#622-promo-codes)
   - 6.23 [Subscriptions (BMB+ / VIP)](#623-subscriptions-bmb--vip)
   - 6.24 [Business Hub](#624-business-hub)
   - 6.25 [Giveaway Spinner](#625-giveaway-spinner)
   - 6.26 [Admin Panel](#626-admin-panel)
   - 6.27 [Favorites & Personalization](#627-favorites--personalization)
   - 6.28 [Live Sports Ticker](#628-live-sports-ticker)
   - 6.29 [Settings & Legal](#629-settings--legal)
   - 6.30 [AI Support Chat](#630-ai-support-chat)
7. [Data Models](#7-data-models)
8. [Credit Economy & Monetization](#8-credit-economy--monetization)
8.5. [Third-Party API Integrations](#85-third-party-api-integrations)
9. [User Flows](#9-user-flows)
10. [Non-Functional Requirements](#10-non-functional-requirements)
11. [Risk & Mitigation](#11-risk--mitigation)
12. [Glossary](#12-glossary)
13. [Design System](#13-design-system)
14. [Scoring Engine Deep-Dive](#14-scoring-engine-deep-dive)
15. [Bracket Template Specifications](#15-bracket-template-specifications)
16. [Future Roadmap](#16-future-roadmap-planned-features)
17. [Appendix A: Service Inventory](#17-appendix-a-service-inventory)
18. [Appendix B: Screen Inventory](#18-appendix-b-screen-inventory-all-56-screens)
19. [Appendix C: Persistence Architecture](#19-appendix-c-persistence-architecture)

---

## 1. Executive Summary

**Back My Bracket (BMB)** is a social tournament bracket platform that lets anyone create, host, join, and compete in bracket-style competitions across every sport and cultural topic imaginable. The platform combines the thrill of March Madness-style bracket picks with a credits-based economy, real merchandise, charity fundraising, and AI-powered automation to deliver the most intuitive bracket experience in the world.

**Key Value Propositions:**
- **Host or Join** bracket tournaments for any sport or topic (NFL Playoffs, Best Pizza, 90s Rock Bands)
- **Seven game types** in one platform: Bracket, Pick'Em, Squares, Voting, Props, Survivor, Trivia
- **Credits economy** that connects gameplay to real-world rewards (gift cards, merch, charity donations)
- **"Back It" merchandise** - get your bracket picks printed on premium apparel
- **AI Auto-Pilot** - voice-command bracket creation with intelligent template matching
- **Charity mode** - "Play for Their Charity" turns competition into social good
- **Live content engine** - real sports data populates brackets daily, keeping the board fresh

**Current Version:** 2.1.0
**Package Name:** `com.backmybracket.bmb` (Android)
**App Name:** Back My Bracket

---

## 2. Product Vision & Mission

### Vision
To be the world's most intuitive bracket competition platform, where any person can create a tournament about anything, compete with friends or strangers, and turn their picks into real rewards.

### Mission
Democratize bracket-style competitions by providing a platform that is:
1. **Effortless to use** - Voice commands, AI auto-build, one-tap joining
2. **Rewarding** - Credits convert to gift cards, merchandise, and charity donations
3. **Social** - Per-tournament chat, host reviews, community engagement, referrals
4. **Always fresh** - Daily content engine crawls real sports calendars; bots keep the board active
5. **Fair** - Transparent scoring, leaderboard rankings, tie-breaker systems

### Design Philosophy
- **Dark theme first** - Deep navy gradient aesthetic with gold/blue accents
- **Custom typography** - ClashDisplay font family throughout
- **Mobile-first** - Designed for portrait Android/iOS, with web preview capability
- **Sports DNA** - Every element feels like a premium sports broadcast

---

## 3. Target Audience

### Primary Users
| Persona | Description | Key Needs |
|---------|-------------|-----------|
| **Casual Sports Fan** | Enjoys bracket challenges during March Madness, NFL Playoffs | Easy join, quick picks, social bragging |
| **Competitive Player** | Plays multiple brackets weekly, tracks accuracy | Leaderboard, stats, re-pick ability |
| **Social Host** | Creates brackets for friend groups, offices, fantasy leagues | Builder tools, share links, manage participants |
| **Content Creator** | Creates voting brackets for audience engagement (Best Pizza, GOAT debates) | Voting mode, share to social, custom branding |

### Secondary Users
| Persona | Description | Key Needs |
|---------|-------------|-----------|
| **Business/Brand** | Uses brackets for marketing, promotions, employee engagement | Business Hub, BMB Starter Kit, branded brackets |
| **Charity Organizer** | Runs charity bracket fundraisers | Charity mode, escrow, Tremendous API payouts |
| **Admin** | BMB platform operator | Admin panel, user management, credit oversight |

### Demographics
- **Age:** 18-45 (core), 16-55 (extended)
- **Gender:** All
- **Geography:** United States (primary), English-speaking markets (secondary)
- **Interests:** Sports, pop culture, competition, social gaming

---

## 4. Platform & Technology

### Technology Stack
| Component | Technology | Version |
|-----------|-----------|---------|
| **Framework** | Flutter | 3.35.4 |
| **Language** | Dart | 3.9.2 |
| **Primary Target** | Android | API 35 (Android 15) |
| **Secondary Target** | Web | Chrome, Firefox, Safari, Edge |
| **Backend** | Firebase (Firestore + Auth) | REST API |
| **Payments** | Stripe | via REST |
| **Gift Cards** | Tremendous API | Sandbox/Production |
| **E-Commerce** | Shopify | Storefront API |
| **Hosting** | Render (merch server) | Production |
| **State Management** | Provider + SharedPreferences + Hive | Local persistence |
| **Audio** | audioplayers | 6.1.0 |
| **Speech** | speech_to_text | 7.3.0 |

### Architecture Pattern
- **Feature-based folder structure** - Each feature domain has its own `data/`, `presentation/`, `models/`, `services/` layers
- **Service singletons** - Core services use the singleton pattern (`BracketBoardService.instance`)
- **REST-first Firebase** - Uses direct REST API calls instead of Firebase JS SDK to avoid iframe/sandbox issues
- **Hybrid persistence** - SharedPreferences for user state, Hive for document storage, Firestore for cloud sync

### Project Structure
```
lib/
  app/                          # App root (MaterialApp, routes)
  core/
    config/                     # App configuration, Firebase options
    data/                       # Team logos, shared data
    services/                   # Current user, daily content engine, device fingerprint
    theme/                      # BmbColors, BmbFontWeights, BmbTextStyles, BmbRadius
    widgets/                    # Shared widgets (bracket tree)
  features/
    admin/                      # Admin panel
    apparel/                    # Apparel preview
    auth/                       # Authentication, biometrics, human verification
    auto_host/                  # AI Auto-Pilot wizard, knowledge packs, templates
    bmb_bucks/                  # Credits purchase flow
    bots/                       # Bot service, hype man
    bracket_builder/            # Builder screen, templates, speech input
    bracket_detail/             # Bracket detail screen
    bracket_print/              # "Back It" merch (print rendering, garment mockup)
    bracket_templates/          # SVG bracket generator, template screen
    business/                   # Business hub, starter kit, signup
    charity/                    # Charity service, escrow
    chat/                       # Tournament chat, access control, profanity filter
    community/                  # Community chat, post-to-BMB, trivia
    companion/                  # AI companion personas, audio, floating widget
    credits/                    # Credit accounting service
    dashboard/                  # Main dashboard, bracket board, cards, stats
    favorites/                  # Favorite teams
    gift_cards/                 # Gift card store, Tremendous integration
    giveaway/                   # Giveaway spinner, leaderboard overlay
    guide_preview/              # Hologram guide preview
    hype_man/                   # Hype man overlay, TTS engine
    inbox/                      # In-app inbox
    legal/                      # Terms of Service, Privacy Policy, Community Guidelines
    notifications/              # Push notifications, welcome notifications
    payments/                   # Stripe payment service
    profile/                    # Profile photo screen
    promo/                      # Promo code service
    referral/                   # Referral codes, landing page
    reviews/                    # Host reviews, post-tournament review
    scoring/                    # Bracket picks, leaderboard, host manager, voting
    settings/                   # About, account settings, help & support
    sharing/                    # Deep links, share bracket, social accounts
    shopify/                    # Shopify product browser
    social/                     # Social follow promo, social links
    splash/                     # Splash screen
    squares/                    # Squares game (10x10 grid)
    store/                      # BMB Store, bracket print flow, order history
    subscription/               # BMB+ upgrade, modal
    support/                    # AI support chat
    ticker/                     # Live sports ticker (ESPN)
    tournament/                 # Tournament join screen
    welcome/                    # Welcome flow overlay
```

---

## 5. Information Architecture

### Navigation Structure (Bottom Tab Bar)
```
[Home]    [Explore]    [Create +]    [My Brackets]    [Profile]
```

| Tab | Description |
|-----|-------------|
| **Home** | Bracket Board feed, featured brackets, live brackets, Hype Man banner |
| **Explore** | Search, categories, trending brackets, sport filters |
| **Create (+)** | Opens Bracket Builder wizard |
| **My Brackets** | Hosted / Joined / Completed brackets with filter tabs |
| **Profile** | User stats, avatar, BMB+ status, settings, BMB Bucket balance |

### Screen Hierarchy
```
SplashScreen
  -> AuthScreen (login/register)
    -> CompanionSelectorScreen (onboarding)
      -> DashboardScreen (main hub)
        |-> BracketDetailScreen
        |-> TournamentJoinScreen -> BracketPicksScreen
        |-> BracketBuilderScreen
        |-> BracketPicksScreen (re-pick)
        |-> LeaderboardScreen
        |-> TournamentChatScreen
        |-> BackItFlowScreen (merch)
        |-> GiftCardStoreScreen
        |-> BmbStoreScreen
        |-> SquaresHubScreen -> SquaresGameScreen
        |-> AutoPilotWizardScreen
        |-> HostApprovalScreen
        |-> HostReviewsScreen
        |-> CommunityChatScreen
        |-> InboxScreen
        |-> NotificationsScreen
        |-> ReferralScreen
        |-> BmbPlusUpgradeScreen
        |-> BusinessHubScreen
        |-> AdminPanelScreen
        |-> AccountSettingsScreen
        |-> AiSupportChatScreen
        |-> GiveawaySpinnerScreen
```

---

## 6. Feature Specifications

### 6.1 Authentication & Onboarding

**Purpose:** Secure account creation and first-time user setup.

**Capabilities:**
- Email/password registration and login via Firebase Auth (REST API)
- Biometric authentication (fingerprint/face) for returning users
- Human verification widget (anti-bot CAPTCHA-like challenge)
- Bot account service for platform-generated accounts
- Device fingerprint service for anti-abuse tracking

**Onboarding Flow:**
1. Splash screen with BMB branding
2. Auth screen (sign up / sign in)
3. Companion selector (choose Jake, Marcus, or Alex as your AI hype man)
4. Welcome flow overlay with app tour
5. Dashboard

**Data Collected at Registration:**
- Display name
- Email
- Password
- US state abbreviation (for leaderboard display)
- City (optional)
- Street address / ZIP (optional, for merch shipping)

**Security:**
- Secure token storage via `flutter_secure_storage`
- Device fingerprinting for multi-account detection
- Rate-limited login attempts

---

### 6.2 Dashboard & Navigation

**Purpose:** Central hub for all activity, the "home screen" of BMB.

**Layout:**
- Bottom navigation bar with 5 tabs (Home, Explore, Create, My Brackets, Profile)
- Live Sports Ticker at the top of the Home tab (ESPN integration)
- Hype Man banner with companion-driven engagement prompts
- Bracket Board horizontal card carousel (featured brackets)
- Category-based bracket browsing in Explore tab

**Dashboard Components:**
| Component | Description |
|-----------|-------------|
| **Stats Card** | Displays user rating, total pools, wins, BMB credits balance |
| **Enhanced Bracket Card** | Rich card with sport icon, host badge, entry info, progress bars, dynamic action buttons |
| **Pool Card** | Simpler bracket card for list views |
| **Animated Pool Card** | Card with entrance animations |
| **Live Bracket Tile** | Compact tile for live/in-progress brackets |
| **My Bracket Tile** | Tile for user's hosted/joined brackets |

**Dynamic Action Buttons (per card):**
| User State | Button Label | Action |
|------------|-------------|--------|
| Not joined | "Join Now" | Navigate to TournamentJoinScreen |
| Joined, no picks | "Make My Picks" | Navigate to BracketPicksScreen |
| Joined, picks made | "Re-Pick" | Navigate to BracketPicksScreen (edit mode) |
| In-progress, joined | "View My Picks" | Navigate to BracketPicksScreen (read-only) |
| Done, joined | "View My Picks" | Navigate to results view |
| Done, not joined | "Results" | Navigate to results view |

---

### 6.3 Bracket Board (Live Feed)

**Purpose:** The always-fresh feed of active tournaments that makes BMB feel alive.

**Service:** `BracketBoardService` (singleton)

**Mechanics:**
- Maintains 12-20 active brackets at any time
- Auto-lifecycle progression: `upcoming -> live -> in_progress -> done -> archived`
- Configurable visibility durations per status:
  - Upcoming: 12 hours
  - Live: 24 hours
  - In-progress: 48 hours
  - Done: 6 hours (then archived)
- Background timer checks lifecycle every 3 minutes
- New brackets generated every cycle (2 per cycle)
- Template pool of 30+ bracket templates across all sports and game types

**Content Sources:**
1. **Template Pool** - Pre-built bracket templates (College Football Playoff, March Madness, NBA Playoffs, etc.)
2. **Daily Content Engine** - Crawls real sports calendars (ESPN, NBA.com, NHL.com, MLB.com, etc.) to generate brackets from actual events happening today
3. **User-Created Brackets** - Brackets created by users that are set to "public" appear on the board
4. **Firestore Brackets** - Cloud-synced brackets from other users

**Host Pool:**
- 8 host personas (mix of real bot accounts and platform official)
- Each host has name, profile image, rating, review count, location, verification badge
- Host rotation ensures variety

---

### 6.4 Game Types

BMB supports **seven distinct game types**, each with its own gameplay flow, scoring, and UI:

| Game Type | Icon | Description | Picks Required | Scoring |
|-----------|------|-------------|----------------|---------|
| **Bracket** | Trophy | Traditional single-elimination bracket. Pick winners through each round to crown a champion. | Yes - pick winner of every matchup | Points per correct pick, weighted by round |
| **Pick 'Em** | Edit | Pick the winner of each game in a slate. No elimination tree. | Yes - pick each game winner | Percentage correct + tie-breaker |
| **Voting** | Vote | Community vote bracket. "Best pizza", "GOAT quarterback", etc. | Yes - vote on each matchup | Majority vote advances |
| **Squares** | Grid | 10x10 grid (100 squares). Score-based quarter prizes. | No picks - claim squares | Last digit of score per quarter |
| **Props** | Thumbs Up/Down | Prop bets (over/under style picks) | Yes | Correct prop predictions |
| **Survivor** | Shield | Pick one team per week. If your team loses, you're eliminated. | Yes - one pick per week | Survival |
| **Trivia** | Quiz | Trivia/quiz night competition | Yes - answer questions | Correct answers |

---

### 6.5 Bracket Builder

**Purpose:** The creation wizard for building any type of bracket tournament.

**Screen:** `BracketBuilderScreen`

**Builder Steps:**
1. **Template Selection** - Choose from 16+ official BMB templates or build custom
2. **Sport Selection** - Basketball, Football, Baseball, Soccer, Hockey, Golf, Tennis, MMA, Voting, Custom
3. **Team/Option Entry** - Manual entry, voice input, or auto-fill from templates
4. **Bracket Type** - Standard (elimination), Pick'Em, Voting
5. **Entry Fee** - Free or credits-based (1-1000 credits)
6. **Prize Configuration** - None, Store prize, Custom description, Charity
7. **Go-Live Date** - Schedule when the bracket opens for play
8. **Tie-Breaker** - Championship game total points prediction
9. **Giveaway Settings** - Optional random winner drawing
10. **Visibility** - Public (Bracket Board) or Private (link-only)
11. **Auto-Host** - Enable automatic lifecycle transitions

**Speech Input:**
- Voice-to-text bracket creation via `speech_to_text` package
- `SportsSpeechProcessor` interprets natural language team/player names
- `TeamAutocompleteService` provides real-time suggestions as user types

**Official Templates:**
| Template | Sport | Teams | Special Rules |
|----------|-------|-------|---------------|
| March Madness NCAA | Basketball | 64 (+4 play-in) | First Four play-in games, ESPN data feed |
| NCAA Women's BB | Basketball | 64 (+4 play-in) | First Four play-in |
| NIT Tournament | Basketball | 32 | Post-season |
| NFL Playoffs | Football | 14 | Reseeds after Wild Card, bye for #1 seeds |
| College Football Playoff | Football | 12 | First-round byes for top 4 seeds |
| NBA Playoffs | Basketball | 16 | Standard 16-team format |
| NBA In-Season Tournament | Basketball | 8 | NBA Cup knockout |
| FIFA World Cup | Soccer | 32 | Group stage + knockout |
| Wimbledon | Tennis | 32 | Grand Slam format |
| MLB Playoffs | Baseball | 12 | Wild Card + Division |
| Masters Golf | Golf | 16 | Major championship |
| MMA Championship | MMA | 8 | Fight bracket |
| UFC Fight Night | MMA | 8 | Single event |
| Boxing Match | Boxing | 2 | Head-to-head |
| Head-to-Head | Any | 2 | 1v1 format |
| Stanley Cup Playoffs | Hockey | 16 | NHL format |

---

### 6.6 Tournament Lifecycle

**Status Flow:**
```
SAVED -> UPCOMING -> LIVE -> IN_PROGRESS -> DONE
```

| Status | Description | User Actions Available |
|--------|-------------|----------------------|
| **Saved** | Draft, not visible to anyone but host | Full edit, delete |
| **Upcoming** | Published, accepting joins | Join, edit TBD names, share |
| **Live** | Active for play, picks are open | Make picks, re-pick, join (if still open) |
| **In Progress** | Picks locked, games being played | View picks, view leaderboard |
| **Done** | All games complete, winner determined | View results, leave review, claim prize |

**Auto-Host Features:**
- Automatic `upcoming -> live` transition when conditions met (min players + scheduled date)
- Credits deducted from all participants when bracket goes live
- Minimum player threshold (configurable by host)
- Scheduled go-live date/time

**Host Management (`HostBracketManagerScreen`):**
- View all participants and their picks
- Manually advance bracket status
- Enter game results (for custom/non-template brackets)
- Confirm winner and distribute prizes
- View leaderboard and rankings

---

### 6.7 Scoring & Leaderboard

**Purpose:** Track picks accuracy, rank players, determine winners.

**Services:**
- `ScoringEngine` - Calculates scores by comparing user picks to official results
- `ResultsService` - Manages bracket results (auto-synced or host-manual)
- `OfficialResultsRegistry` - Template-to-live-data mapping for auto-scoring
- `LiveDataFeedService` - Pulls real game results from sports APIs
- `VotingDataService` - Manages community vote tallies
- `TournamentStatusService` - Tracks lifecycle transitions

**Scoring Model:**
```
GameResult:
  - gameId: "r{round}_g{matchIndex}"
  - team1, team2, winner, score
  - isCompleted, completedAt

UserPicks:
  - userId, userName, userState
  - picks: Map<gameId, pickedTeam>
  - tieBreakerPrediction

ScoredEntry:
  - correctPicks, incorrectPicks, pendingPicks
  - score, rank, maxPossibleScore
  - championPick, accuracy percentage
  - tieBreakerDiff
```

**Tie-Breaker System:**
- For standard brackets: user predicts total combined points of the championship game
- Closest prediction wins without going over
- If still tied: user who submitted picks first wins

**Leaderboard Features:**
- Real-time ranking with position changes
- Champion pick status (alive/eliminated indicator)
- Accuracy percentage per player
- State abbreviation displayed next to each player name
- Current user highlighted in the list
- Separate voting leaderboard for voting brackets

---

### 6.8 Squares Game Mode

**Purpose:** Classic "Squares" pool game (Super Bowl Squares, etc.)

**Screen:** `SquaresHubScreen` -> `SquaresGameScreen`

**Rules:**
1. **Upcoming Phase** - Players pick squares on a 10x10 grid (blind - no numbers visible). Credits NOT deducted yet.
2. **In-Progress Phase** - Board locked. Credits deducted. Column/row numbers randomly revealed (0-9 shuffled per team).
3. **Scoring** - Last digit of each team's score at end of each quarter determines the winning square.
4. **Prizes** - Credits awarded per quarter winner + grand prize bonus for final score winner.

**Supported Sports:** Football, Basketball, Hockey, Lacrosse, Soccer

**Model:**
```
SquaresGame:
  - 10x10 grid (100 squares)
  - creditsPerSquare, maxSquaresPerPlayer
  - prizePerQuarter, grandPrizeBonus
  - QuarterScore tracking (Q1-Q4)
  - Auto-score pulling via ESPN event ID
  - Auto-host lifecycle support
```

---

### 6.9 BMB Credits Economy

**Purpose:** The internal currency that powers the entire platform.

**Service:** `CreditAccountingService`

**Economics:**
| Metric | Value |
|--------|-------|
| **Purchase Rate** | 1 credit = $0.12 (what users pay) |
| **Redemption Rate** | 1 credit = $0.10 (store/gift card value) |
| **BMB Margin** | $0.02 per credit |
| **Gift Card Surcharge** | +5 credits ($0.50) per redemption |
| **Platform Fee** | 10% of entry credits go to BMB |
| **Stripe Processing** | 2.9% + $0.30 per transaction |

**Credit Flow:**
```
User buys credits ($) -> Stripe -> Credits added to BMB Bucket
User joins bracket -> Credits deducted at LIVE transition
Winner declared -> Prize credits awarded
User redeems credits -> Gift cards / merch / charity
```

**BMB Bucket (Balance) Features:**
- Purchase screen with credit packages
- Auto-replenish option (auto-add 10 credits when balance <= 10)
- Transaction history
- Balance displayed throughout the app (header, profile, join screens)

**Credit Sources:**
| Source | Credits |
|--------|---------|
| Purchase via Stripe | Variable (packages) |
| Promo codes | 10-200 credits |
| Referral rewards | 10 credits per referral |
| Welcome bonus | 25 credits |
| Tournament winnings | Prize pool distribution |
| Giveaway prizes | Configurable per bracket |

---

### 6.10 BMB Store & Gift Cards

**Purpose:** Let users spend their earned credits on real-world rewards.

**Screens:** `BmbStoreScreen`, `GiftCardStoreScreen`, `ProductDetailScreen`, `OrderHistoryScreen`

**Store Categories:**
| Category | Examples |
|----------|---------|
| **Gift Cards** | Amazon, Visa, Nike, Starbucks, DoorDash, Steam, PlayStation, Xbox |
| **Merch** | BMB Champion Hoodie, Snapback Cap, Pro T-Shirt, Mystery Box |
| **Digital** | Premium avatars, themes, badges |
| **Custom Bracket Print** | Physical printed bracket picks on apparel |

**Gift Card Integration (Tremendous API):**
- 50+ brand partners
- Denominations: $5 - $500
- Instant digital delivery
- Redemption code + URL delivered to in-app inbox
- Credit conversion: `credits = (dollarAmount / 0.10) + 5 surcharge`

**Shopify Integration:**
- Product browser connected to `backmybracket.com` Shopify store
- Product sync for merch items
- Variant support (sizes, colors)

---

### 6.11 Bracket Print / "Back It" Merchandise

**Purpose:** The signature BMB feature - get your bracket picks printed on premium apparel.

**Screens:** `BackItFlowScreen`, `ApparelPreviewScreen`

**Services:**
- `BracketPrintRenderer` - Renders bracket to print-ready format
- `GarmentMockupPainter` - Overlays bracket onto garment photos
- `MerchPreviewService` - Generates preview images
- `PrintProductCatalog` - Available garment types and pricing
- `PrintShopDeliveryService` - Shipping and delivery management
- `BracketPrintOrderService` - Order creation and tracking

**Flow:**
1. User makes their bracket picks
2. Tap "Back It" button
3. Choose garment type (hoodie, t-shirt, long sleeve, etc.)
4. Choose color
5. Preview bracket printed on garment (realistic mockup)
6. Enter shipping address
7. Pay with credits or Stripe
8. Order confirmation -> Inbox notification

**Print Quality:**
- 300 DPI output for DTG (Direct-to-Garment) printing
- UI contamination guard prevents interactive elements (highlights, selection bars) from appearing in print output
- Three render modes: `bracketUI` (interactive), `bracketPrint` (300 DPI), `bracketPreview` (garment mockup)

---

### 6.12 Charity Brackets

**Purpose:** "Play for Their Charity" - competition meets social good.

**Service:** `CharityService`, `CharityEscrowService`

**How It Works:**
1. Host creates a bracket with `prizeType: 'charity'`
2. Host sets charity name, raise goal (in dollars), minimum contribution
3. Players join and contribute credits to the charity pot
4. BMB takes a 10% platform fee from the pot
5. Tournament winner chooses which specific charity receives the donation
6. Net credits converted to dollars via Tremendous API and donated

**Financial Model:**
```
Example: 50 players x 100 credits each = 5,000 credits in pot
BMB fee (10%): 500 credits
Net donation: 4,500 credits = $450.00
Winner picks charity from curated list -> Tremendous sends donation
```

**Charity Contribution Tracking:**
```
CharityContribution:
  - userId, userName
  - credits, contributedAt
  - dollars (credits * 0.10)
```

**UI Elements:**
- Charity badge on bracket cards
- Fundraising progress bar (toward dollar goal)
- Contributor list
- Winner CTA: "Choose Your Charity" with charity selector

---

### 6.13 Chat System

**Purpose:** Private tournament chat rooms for social engagement during competition.

**Screen:** `TournamentChatScreen`

**Access Control (`ChatAccessService`):**
1. User must have JOINED the tournament to access chat
2. User must have accepted Terms of Service
3. User must not be suspended or banned

**Features:**
- Real-time messaging within each tournament
- System messages (e.g., "User joined the bracket")
- Sender location (state abbreviation) displayed
- Message flagging/reporting

**Moderation:**
- `ProfanityFilter` - Automated content filtering
- Violation tracking with progressive enforcement:
  - 1st violation: Warning
  - 2nd: 24-hour suspension
  - 3rd: 7-day suspension
  - 4th: 30-day suspension
  - 5th+: Permanent ban

**Community Chat (`CommunityChatScreen`):**
- Global community chat (not tournament-specific)
- Post-to-BMB service for sharing content
- Trivia integration

---

### 6.14 AI Auto-Host / Auto-Pilot

**Purpose:** Voice-command bracket creation using AI-powered intent detection.

**Screen:** `AutoPilotWizardScreen`

**Services:**
- `AutoBuilderService` - Core AI parsing engine
- `KnowledgePackService` - Curated topic databases
- `LifecycleAutomationService` - Auto-transitions for hosted brackets
- `AutoShareService` - Auto-share brackets to social when published

**How It Works:**
1. User taps mic or types: "Build me an NFL playoff bracket"
2. `AutoBuilderService.parseCommand()` analyzes the query
3. **Intent Detection** distinguishes between:
   - **Tournament Intent** (keywords: "playoff", "tournament", "championship", "bracket") -> Matches official BMB templates first
   - **Voting Intent** (keywords: "best", "favorite", "greatest", "GOAT") -> Matches Knowledge Packs
4. System builds the bracket with smart defaults:
   - Correct template (NFL Playoffs = 14-team bracket with reseeding)
   - TBD teams if event hasn't started
   - Appropriate go-live date (e.g., NFL Playoffs -> January 2026)
   - Default entry fee (10 credits)
5. User reviews, edits, and publishes

**Knowledge Packs:**
Pre-curated databases for instant bracket population:
- NFL Quarterbacks, NBA All-Stars, Best 90s Rock Bands, Top Pizza Chains, etc.
- Each pack has: category, default bracket size, items list, keyword triggers, seasonal hints

**Saved Templates:**
Hosts can save bracket configurations as reusable templates with:
- Recurrence rules (one-time, weekly, monthly, yearly, custom)
- Auto-host settings
- Default teams, entry fees, prizes
- Approval workflow option

**Host Approval Screen:**
When `requiresApproval` is enabled on a saved template, auto-generated brackets queue for host review before going live.

---

### 6.15 Bot Ecosystem

**Purpose:** Keep the platform active and engaging even with low initial user counts.

**Service:** `BotService`

**Bot Roles:**
| Role | Description |
|------|-------------|
| **Host** | Creates and hosts official BMB brackets |
| **Participant** | Joins FREE brackets, makes picks, engages in chat |
| **Host+Participant** | Both creates and joins brackets |

**Bot Accounts (Examples):**
| Username | Role | State | Persona |
|----------|------|-------|---------|
| BackMyBracket | Host | US | Official BMB brackets |
| BMBSports | Host | US | Sports desk official |
| Marc_Buckets | Host+Participant | TX | Houston hooper, stats nerd |
| Queen_of_Upsets | Host+Participant | FL | Upset whisperer, Cinderella believer |
| JamSession81 | Participant | IL | Bracket enthusiast |
| SwishKing | Participant | CA | Nothing but net |
| MarchMadnessMax | Participant | NC | March Madness specialist |

**Bot Behavior:**
- Auto-join free brackets
- Generate realistic picks based on seedings
- Post chat messages for engagement
- Profile images sourced from Pexels
- Verified badges where appropriate

---

### 6.16 Companion System (Hype Man)

**Purpose:** Personalized AI companion that guides, entertains, and hypes the user.

**Screen:** `CompanionSelectorScreen`

**Personas:**
| Companion | Nickname | Personality | Voice Style |
|-----------|----------|-------------|-------------|
| **Jake** | The Hype Man | High-energy, loud, contagious excitement | Young energetic Caucasian male, fast-paced |
| **Marcus** | The Analyst | Cool, confident, data-driven | Deep energetic African American male, swagger |
| **Alex** | [Third companion] | [Distinct personality] | [Distinct voice] |

**Features:**
- Voice intro clips (remote audio URLs)
- Floating companion widget on dashboard
- Context-aware hype triggers:
  - `joinedTournament` - Celebrates when user joins
  - `madePicks` - Reacts to pick submissions
  - `wonBracket` - Victory celebration
  - `streakAchievement` - Win streak acknowledgment
- TTS engine for real-time voice responses (`WebTtsEngine`)
- Hype Man overlay for dramatic moments
- Audio playback via `CompanionAudioPlayer`

---

### 6.17 Host Reviews & Ratings

**Purpose:** Build trust and reputation for tournament hosts.

**Screens:** `HostReviewsScreen`, `PostTournamentReviewScreen`

**Service:** `HostReviewService`

**Model:**
```
HostReview:
  - hostId, hostName
  - playerId, playerName, playerState
  - tournamentId, tournamentName
  - stars (1-5)
  - comment (optional)
  - createdAt
```

**Rules:**
- One review per player per tournament (deduplicated by `playerId + tournamentId`)
- Reviews only available after tournament is marked "done"
- Host rating = average of all stars across all hosted tournaments
- Review count displayed on host profile/badge

---

### 6.18 Community & Social

**Purpose:** Social engagement beyond individual tournaments.

**Features:**
- **Community Chat** (`CommunityChatScreen`) - Global chat room
- **Post to BMB** (`PostToBmbSheet`) - Share content to the BMB feed
- **Trivia** (`TriviaService`) - Community trivia games
- **Social Links** (`SocialLinksScreen`) - Connect Twitter/X, Instagram accounts
- **Social Follow Promos** (`SocialFollowPromoOverlay`) - Incentivize following BMB social accounts
- **Social Promo Admin** (`SocialPromoAdminScreen`) - Admin tools for managing social promos

---

### 6.19 Sharing & Deep Links

**Purpose:** Viral growth through easy bracket sharing.

**Services:**
- `DeepLinkService` - Parse and generate deep links
- `ShareBracketService` - Generate share text and links
- `SocialAccountsService` - Social platform connections

**Deep Link Patterns:**
| Pattern | Destination |
|---------|-------------|
| `/join/{bracketId}` | JoinBracketScreen for specific bracket |
| `/invite?ref=CODE` | ReferralLandingPage with referral code |
| `/invite?ref=CODE&section=videos` | Landing page scrolled to how-to videos |

**Share Options:**
- Text message (SMS)
- X / Twitter
- Instagram
- Copy link to clipboard
- Each generates a formatted message with bracket title, host name, sport, player count

**Bracket Tree Viewer:**
- `BracketTreeViewerScreen` - Visual bracket tree for sharing
- `SVGBracketGenerator` - Generates SVG bracket images for sharing

---

### 6.20 Notifications & Inbox

**Purpose:** Keep users informed and engaged.

**Screens:** `NotificationsScreen`, `InboxScreen`

**Services:**
- `WelcomeNotificationService` - Sends welcome message on first launch
- `ReplyNotificationService` - Notifies when someone replies to your pick

**Notification Types:**
- Tournament going live
- Picks deadline approaching
- Game results posted
- You won a bracket
- Gift card delivered
- New chat message in tournament
- Referral rewards earned
- Promo code available

---

### 6.21 Referral Program

**Purpose:** Organic user growth through existing users.

**Screen:** `ReferralScreen`, `ReferralLandingPage`

**Service:** `ReferralCodeService`

**How It Works:**
1. Each user gets ONE permanent referral code (format: `BMB-XXXXX`)
2. Share link format: `https://backmybracket.com/invite?ref=BMB-K7X9M2&section=videos`
3. Landing page is PUBLIC (no auth required to view):
   - How-to videos
   - BMB+ membership promos
   - Free registration option
4. When new user signs up via referral: both parties earn credits

**Tracking:**
- Referral history per user
- Stats: total referrals, conversion rate, credits earned

---

### 6.22 Promo Codes

**Purpose:** Marketing tool for user acquisition and engagement.

**Service:** `PromoCodeService`

**Code Types:**
| Type | Example | Credits | Restrictions |
|------|---------|---------|-------------|
| Host Free Tournament | `FREEHOST50` | 50 | Max 100 redemptions |
| Host Starter | `HOSTBMB100` | 100 | Max 50 redemptions |
| Boss Pack | `BMBBOSS` | 200 | Max 25 redemptions |
| Welcome Bonus | `WELCOME81` | 25 | 1 per account, within 48h of signup |
| Event Code | Various | Variable | Expiration date |

**Anti-Abuse System (4 Layers):**
1. **Per-User Tracking** - One code per user account
2. **Per-Device Tracking** - One code per physical device (via `DeviceFingerprintService`)
3. **Rate Limiting** - Max 3 failed / 5 total attempts per hour; 24h lockout after 10 failures
4. **Code-Type Restrictions** - Welcome codes: 48h window, 1 per lifetime; Event codes: expiration dates

---

### 6.23 Subscriptions (BMB+ / VIP)

**Purpose:** Premium tier with exclusive features and priority placement.

**Screen:** `BmbPlusUpgradeScreen`, `BmbPlusModal`

**Subscription Pricing (Stripe Payment Links):**

| Plan | Price | Billing | Stripe Config Key |
|------|-------|---------|-------------------|
| **BMB+ Monthly** | $9.99/month | Recurring | `bmbPlusMonthly` |
| **BMB+ Yearly** | $99.99/year | Annual (save ~17%) | `bmbPlusYearly` |
| **BMB+ VIP Add-On** | $2.00/month | Recurring add-on | `bmbPlusVipMonthly` |
| **BMB+biz Monthly** | $99.00/month | Recurring | `bmbBizMonthly` |
| **BMB+biz Yearly** | $899.00/year | Annual (save ~24%) | `bmbBizYearly` |

**Feature Comparison:**
| Feature | Free | BMB+ | BMB+ VIP |
|---------|------|------|----------|
| Join brackets | Yes | Yes | Yes |
| Create brackets | Limited | Unlimited | Unlimited |
| Save bracket templates | No | Yes | Yes |
| VIP bracket placement | No | No | Yes (2 credits/month) |
| Priority support | No | Yes | Yes |
| Exclusive badges | No | Yes | VIP badge |
| Auto-host | No | Yes | Yes |

---

### 6.24 Business Hub

**Purpose:** B2B features for brands, companies, and organizations.

**Screens:** `BusinessHubScreen`, `BusinessSignupScreen`, `BmbStarterKitScreen`

**Features:**
- Business account creation
- BMB Starter Kit (onboarding materials)
- Branded bracket creation
- Employee engagement tournaments
- Marketing campaign brackets
- Analytics dashboard (planned)

---

### 6.25 Giveaway Spinner

**Purpose:** Random prize drawing within brackets to boost engagement.

**Screens:** `GiveawaySpinnerScreen`, `LeaderboardSpinnerOverlay`

**How It Works:**
1. Host enables giveaway when creating bracket
2. Configures: number of winners, credits per winner
3. At bracket completion, all participants are eligible
4. Animated spinner randomly selects winners
5. Credits automatically awarded

---

### 6.26 Admin Panel

**Purpose:** Platform management for BMB administrators.

**Screen:** `AdminPanelScreen`

**Admin Capabilities:**
- User management (view, edit, ban)
- Bracket moderation
- Credit balance adjustments
- Platform statistics
- Bot management
- Promo code creation
- Feature flags (planned)

**Access Control:**
- Only users with `isAdmin: true` can access
- Admin account gets 999,999 credits balance

---

### 6.27 Favorites & Personalization

**Purpose:** Personalize the experience based on user's team preferences.

**Screen:** `FavoriteTeamsScreen`

**Service:** `FavoriteTeamsService`

**Features:**
- Select favorite teams across all sports
- Teams used to personalize bracket suggestions
- Highlight favorite teams in bracket picks
- Sport-specific team databases

---

### 6.28 Live Sports Ticker

**Purpose:** Real-time sports scores running across the top of the app.

**Widget:** `LiveSportsTicker`

**Service:** `EspnSportsService`

**Features:**
- Scrolling ticker with live game scores
- ESPN data integration
- Sport-specific icons
- Tap to expand game details (planned)

---

### 6.29 Settings & Legal

**Screens:** `AccountSettingsScreen`, `AboutScreen`, `HelpSupportScreen`

**Legal Pages:**
- `TermsOfServiceScreen` - Full TOS
- `PrivacyPolicyScreen` - Privacy policy
- `CommunityGuidelinesScreen` - Chat and community rules

**Account Settings:**
- Edit display name, email, state, city, address
- Change password
- Toggle biometric login
- Toggle notifications
- Manage favorite teams
- Delete account

---

### 6.30 AI Support Chat

**Purpose:** 24/7 automated customer support.

**Screen:** `AiSupportChatScreen`

**Service:** `AiSupportService`

**Capabilities:**
- Natural language understanding for common questions
- Credit balance inquiries
- Order status checking
- Tournament rules explanation
- Account troubleshooting
- Escalation to human support (planned)

---

## 7. Data Models

### Core Models Summary

| Model | Location | Purpose |
|-------|----------|---------|
| `BracketItem` | `dashboard/data/models/` | Live bracket on the board |
| `BracketHost` | `dashboard/data/models/` | Host profile (name, rating, image, verified) |
| `UserProfile` | `dashboard/data/models/` | Current user's profile and stats |
| `UserStats` | `dashboard/data/models/` | Extended user statistics |
| `HostRanking` | `dashboard/data/models/` | Host leaderboard ranking |
| `PoolItem` | `dashboard/data/models/` | Simplified bracket pool |
| `CreatedBracket` | `bracket_builder/data/models/` | Full bracket created by user/bot |
| `BracketTemplate` | `bracket_builder/data/models/` | Pre-built tournament template |
| `JoinedPlayer` | `bracket_builder/data/models/` | Player who joined a tournament |
| `CharityContribution` | `bracket_builder/data/models/` | Individual charity pot contribution |
| `BmbStorePrize` | `bracket_builder/data/models/` | Store prize option |
| `GameResult` | `scoring/data/models/` | Single game/matchup result |
| `BracketResults` | `scoring/data/models/` | All results for a bracket |
| `UserPicks` | `scoring/data/models/` | User's submitted picks |
| `ScoredEntry` | `scoring/data/models/` | Scored/ranked leaderboard entry |
| `SquaresGame` | `squares/data/models/` | Squares game (10x10 grid) |
| `ChatMessage` | `chat/data/models/` | Tournament chat message |
| `ChatRoom` | `chat/data/models/` | Chat room metadata |
| `HostReview` | `reviews/data/models/` | Player review of a host |
| `CompanionPersona` | `companion/data/` | AI companion character definition |
| `KnowledgePack` | `auto_host/data/models/` | Curated topic database for auto-build |
| `SavedTemplate` | `auto_host/data/models/` | Reusable bracket template with recurrence |
| `GiftCardBrand` | `gift_cards/data/models/` | Gift card brand (Tremendous integration) |
| `GiftCardOrder` | `gift_cards/data/models/` | Gift card redemption order |
| `StoreProduct` | `store/data/models/` | BMB Store product (Shopify sync) |
| `BmbBucks` | `bmb_bucks/data/models/` | Credit balance and transaction history |
| `PrintProduct` | `bracket_print/data/models/` | Print product specification |

### Key Enums

| Enum | Values | Purpose |
|------|--------|---------|
| `RewardType` | credits, custom, charity, none | What the champion wins |
| `GameType` | bracket, pickem, squares, trivia, props, survivor, voting | Competition format |
| `TournamentStatus` | saved, upcoming, live, inProgress, done | Lifecycle state |
| `SquaresStatus` | upcoming, live, inProgress, done | Squares-specific lifecycle |
| `RecurrenceType` | oneTime, everyMonth, everyWeek, yearly, custom | Template scheduling |
| `PickStatus` | correct, incorrect, pending, notPicked | Pick result display |
| `BracketRenderMode` | bracketUI, bracketPrint, bracketPreview | Rendering pipeline |

---

## 8. Credit Economy & Monetization

### Revenue Streams

| Stream | Description | BMB Revenue |
|--------|-------------|-------------|
| **Credit Sales** | Users purchase credits via Stripe | $0.02/credit margin |
| **Platform Fees** | 10% of entry credits collected per bracket | Variable per tournament |
| **Gift Card Surcharge** | +5 credits per gift card redemption | $0.50/redemption |
| **Merch Sales** | Bracket print "Back It" merchandise | Markup on COGS |
| **BMB+ Subscription** | $9.99/month or $99.99/year | $100-120/year MRR |
| **BMB+biz Subscription** | $99/month or $899/year | $899-1,188/year MRR |
| **VIP Add-On** | $2/month front-of-board bracket placement | $24/year MRR |
| **Shopify Store** | Direct merchandise sales (backmybracket.com) | Product margins |

### Credit Purchase Packages (via Stripe Payment Links)

| Package | Credits | Price | Per Credit | Stripe Config Key |
|---------|---------|-------|-----------|-------------------|
| Starter | 50 | $5.99 | $0.12 | `buxStarter50` |
| Popular | 100 | $11.99 | $0.12 | `buxPopular100` |
| Value | 250 | $29.99 | $0.12 | `buxValue250` |
| Pro | 500 | $59.99 | $0.12 | `buxPro500` |
| Elite | 1000 | $99.99 | $0.10 | `buxElite1000` |
| Whale | 2500 | $199.99 | $0.08 | `buxWhale2500` |

### Unit Economics Example

```
User purchases 100 credits for $11.99:
  Stripe fee (2.9% + $0.30): $0.65
  BMB gross: $11.34
  Credit redemption value (100 x $0.10): $10.00
  BMB net margin: $1.34 (11.2%)

User redeems for $10 Amazon gift card:
  Credit cost: 105 credits (100 face + 5 surcharge)
  BMB nets additional $0.50 from surcharge
  Gift card cost to BMB (via Tremendous): ~$10.00
  BMB total earnings from this user: $1.84
```

### Platform Fee Flow (Bracket Entry)

```
50 players join a bracket at 100 credits each:
  Total collected: 5,000 credits
  BMB Platform Fee (10%): 500 credits ($50 value)
  Host Prize Pool (90%): 4,500 credits ($450 value)
  
  For charity brackets:
    BMB Platform Fee (10%): 500 credits
    Charity Donation (90%): 4,500 credits = $450
    --> Donated via Tremendous API to winner's chosen charity
```

### Transaction Types
```
CREDIT:   purchase, welcome_bonus (25), referral_reward (10),
          promo_code (10-200), tournament_prize, giveaway_win,
          social_follow_bonus (3 per platform, max 15),
          auto_replenish (10 when balance <= 10)
          
DEBIT:    bracket_entry, gift_card_redemption, merch_purchase,
          vip_placement, charity_contribution, squares_entry
          
PLATFORM: platform_fee_collected (10% of entries)
          bmb_admin_bucket (userId: 'bmb_platform')
```

### Auto-Replenish Feature
- When user's credit balance drops to 10 or below
- Automatically adds 10 credits
- Prevents users from being unable to join free brackets
- Configurable by user (opt-in)

---

## 8.5 Third-Party API Integrations

### Payment & Financial
| Service | Purpose | Integration Method | Config Location |
|---------|---------|-------------------|------------------|
| **Stripe** | Credit purchases, subscriptions | Payment Links (URL redirect) | `stripe_config.dart` |
| **Tremendous** | Gift card fulfillment | REST API (sandbox + production) | `tremendous_service.dart` |

### Sports Data
| Service | Purpose | Integration Method | Endpoints |
|---------|---------|-------------------|----------|
| **ESPN Hidden API** | Live scores, game data | REST (unofficial) | `site.api.espn.com/apis/site/v2/sports/...` |
| **NCAA Casablanca API** | Official NCAA bracket data | REST (unofficial) | `data.ncaa.com/casablanca/scoreboard/...` |
| **henrygd NCAA API** | Proxy for NCAA data | REST (free proxy) | `ncaa-api.henrygd.me/scoreboard/...` |

### E-Commerce
| Service | Purpose | Integration Method | Config Location |
|---------|---------|-------------------|------------------|
| **Shopify** | Merch store (backmybracket.com) | Storefront API | `shopify_service.dart` |
| **Render** | Merch server hosting | HTTPS | `app_config.dart` merchServerBaseUrl |

### Authentication & Security
| Service | Purpose | Integration Method |
|---------|---------|-------------------|
| **Firebase Auth** | User authentication | REST API (no JS SDK) |
| **Firebase Firestore** | Cloud data storage | REST API (no JS SDK) |
| **Device Fingerprint** | Anti-abuse tracking | Local device hashing |
| **Biometric Auth** | Fingerprint/Face login | local_auth + flutter_secure_storage |

### Content & Social
| Platform | Handle | URL |
|----------|--------|-----|
| **Instagram** | @backmybracket | instagram.com/backmybracket |
| **X (Twitter)** | @backmybracket | x.com/backmybracket |
| **TikTok** | @backmybracket | tiktok.com/@backmybracket |
| **YouTube** | @backmybracket | youtube.com/@backmybracket |
| **Snapchat** | backmybracket | snapchat.com/add/backmybracket |

### External URLs
| URL | Purpose |
|-----|---------|
| `backmybracket.com` | Main website / Shopify store |
| `backmybracket.com/join/{id}` | Deep link for bracket sharing |
| `backmybracket.com/invite?ref=CODE` | Referral landing page |
| `tech@backmybracket.com` | Primary support email (AI escalation) |
| `backmybracket-mobile-version-2.onrender.com` | Merch server (Render) |

---

## 9. User Flows

### Flow 1: Join and Play a Bracket
```
Dashboard -> Browse Bracket Board -> Tap bracket card
  -> BracketDetailScreen (view details, teams, rules, host)
  -> Tap "Join & Make Picks" (or "Join Now")
    -> TournamentJoinScreen (confirm entry fee)
      -> Credits deducted (if applicable)
      -> ChatAccessService.recordJoin()
    -> BracketPicksScreen (make picks for each matchup)
      -> Submit picks -> ResultsService.submitPicks()
      -> Auto-navigate to "Back It" flow (optional)
  -> Return to Dashboard (card shows "Re-Pick" button)
```

### Flow 2: Create and Host a Bracket
```
Dashboard -> Tap "Create +" tab
  -> BracketBuilderScreen
    -> Select template OR custom
    -> Enter teams (type, voice, or auto-fill)
    -> Set entry fee & prize
    -> Set go-live date
    -> Configure tie-breaker
    -> Save/Publish
      -> IF auto-host: bracket auto-transitions at scheduled time
      -> IF manual: host taps "Go Live" when ready
  -> Bracket appears on Bracket Board (if public)
  -> Players join and make picks
  -> Host manages via HostBracketManagerScreen
  -> Host confirms winner -> Prizes distributed
```

### Flow 3: AI Auto-Pilot Bracket Creation
```
Dashboard -> Tap mic icon
  -> Speak: "Build me an NFL playoff bracket"
  -> AutoBuilderService.parseCommand()
    -> Intent: Tournament (not voting)
    -> Template match: nflPlayoffs (14 teams, reseeds)
    -> Smart defaults: TBD teams, Jan 2026 go-live, 10 credits entry
  -> AutoPilotWizardScreen (review & edit)
    -> Confirm -> Bracket published
```

### Flow 4: Redeem Credits for Gift Card
```
Profile -> Tap BMB Bucket balance
  -> GiftCardStoreScreen
    -> Browse brands (Amazon, Nike, Starbucks, etc.)
    -> Select brand -> Choose denomination ($10, $25, $50)
    -> Confirm: credits deducted (amount/0.10 + 5 surcharge)
    -> TremendousService generates order
    -> Redemption code delivered to Inbox
```

### Flow 5: "Back It" Merchandise
```
BracketPicksScreen -> Submit picks -> "Back It" prompt
  -> BackItFlowScreen
    -> Choose garment (hoodie, tee, long sleeve)
    -> Choose color
    -> Preview (realistic garment mockup with bracket overlay)
    -> Enter shipping address
    -> Pay (credits or Stripe)
    -> Order confirmation
```

### Flow 6: Squares Game
```
Dashboard -> Squares Hub -> Select game
  -> SquaresGameScreen (10x10 grid)
  -> UPCOMING: Pick squares (blind, no numbers, no credits deducted)
  -> Host taps "Go Live":
    -> Credits deducted from all participants
    -> Column/row numbers randomly assigned (0-9 shuffle)
    -> Board locked
  -> IN_PROGRESS: Live score tracking
    -> Score digits determine quarter winners
    -> Q1, Q2, Q3, Q4 prizes awarded automatically
  -> DONE: Grand prize for final score match
```

### Flow 7: Charity Bracket
```
BracketBuilder -> Set prize type to "Charity"
  -> Enter charity name, raise goal ($), minimum contribution
  -> Players join and contribute credits
  -> Tournament plays out normally
  -> Winner declared
  -> Winner selects charity from curated list
  -> BMB deducts 10% platform fee from pot
  -> Net credits converted to dollars (credits x $0.10)
  -> Tremendous API sends donation to chosen charity
  -> Confirmation sent to all participants
```

### Flow 8: Welcome & Onboarding
```
App Launch -> SplashScreen (brand animation)
  -> AuthScreen
    -> Tab 1: Login (email + password, biometric option)
    -> Tab 2: Sign Up
      -> Step -1: Account type chooser (Individual / Business)
      -> Step 0: Account info (display name, email, password)
      -> Step 1: Address (street, city, state, ZIP for merch shipping)
      -> Step 2: Human verification (anti-bot CAPTCHA)
  -> WelcomeFlowOverlay (5 panels):
    -> Panel 0: Thank You / Welcome message
    -> Panel 1: Companion Picker (Jake, Marcus, or Alex)
    -> Panel 2: Promo Code entry (e.g., WELCOME81 for 25 credits)
    -> Panel 3: Social Follow promo (3 credits per platform, 5 platforms)
    -> Panel 4: Profile Stats Summary + total credits earned
  -> "Let's Go!" -> Dashboard
```

### Flow 9: Deep Link Join (Existing User)
```
Tap share link: backmybracket.com/join/{bracketId}
  -> App opens -> /join/{bracketId} route
  -> Fetch bracket from Firestore
  -> JoinBracketScreen (confirm entry fee)
  -> Join -> BracketPicksScreen
```

### Flow 10: Deep Link Join (New User)
```
Tap share link: backmybracket.com/join/{bracketId}
  -> App opens -> /join/{bracketId} route
  -> User not logged in
  -> Redirect to AuthScreen with pendingBracketId stored
  -> User signs up -> completes onboarding
  -> pendingBracketId consumed
  -> Auto-navigate to JoinBracketScreen for the bracket
```

---

## 10. Non-Functional Requirements

### Performance
| Metric | Target |
|--------|--------|
| App startup (cold) | < 3 seconds |
| Screen transition | < 300ms |
| Bracket Board refresh | < 2 seconds |
| Pick submission | < 1 second |
| Gift card delivery | < 30 seconds |

### Reliability
- 99.9% uptime for bracket operations
- Offline bracket viewing (cached via Hive)
- Graceful degradation when Firebase is unavailable
- Global error handler with styled error screens (no blank white pages)

### Security
- Firebase Auth with REST API (no JS SDK dependencies)
- Secure token storage (`flutter_secure_storage`)
- Device fingerprinting for abuse prevention
- 4-layer promo code anti-abuse system
- Chat profanity filter with progressive enforcement
- Admin-only access controls

### Scalability
- Firestore-backed cloud storage for brackets and user data
- SharedPreferences + Hive for fast local reads
- Singleton service architecture for efficient memory use
- Background timers with configurable intervals

### Accessibility
- Dark theme with high contrast text (primary/secondary/tertiary text colors)
- Touch targets minimum 48x48dp
- SafeArea implementation on all screens
- Screen reader compatible widget labels (planned)

---

## 11. Risk & Mitigation

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|------------|
| Low early user count | Board feels empty | High | Bot ecosystem simulates active community; DailyContentEngine generates real-sports brackets |
| Credit abuse (multi-account farming) | Revenue loss | Medium | 4-layer anti-abuse system; device fingerprinting; per-device code limits |
| Incorrect scoring | User trust damage | Medium | Official results registry; host manual override; tie-breaker dispute resolution |
| Chat toxicity | User churn | Medium | Profanity filter; progressive enforcement (warn -> suspend -> ban) |
| Sports data API changes | Stale bracket content | Low | Multiple data source fallbacks; manual host entry option |
| Stripe/Tremendous API downtime | Purchase/redemption failure | Low | Graceful error handling; retry logic; admin credit adjustment capability |
| Gambling regulation concerns | Legal risk | Medium | Credits are not currency; no cash-out option; gift cards only; charity mode |

---

## 12. Glossary

| Term | Definition |
|------|-----------|
| **BMB** | Back My Bracket - the platform |
| **BMB Bucket** | User's credit balance account |
| **BMB Credits** | Internal currency (1 credit = $0.10 redemption value) |
| **BMB+** | Premium subscription tier |
| **BMB+ VIP** | Top-tier subscription with front bracket placement |
| **Bracket Board** | The live feed of active tournaments on the Home tab |
| **Back It** | Feature to print bracket picks on merchandise |
| **Bracket Type** | Standard (elimination), Pick'Em (flat slate), Voting (community vote) |
| **Champion** | Winner of a bracket tournament |
| **Companion** | AI hype man persona (Jake, Marcus, or Alex) |
| **Daily Content Engine** | Service that generates brackets from real sports events |
| **Game Type** | Competition format: bracket, pickem, squares, trivia, props, survivor, voting |
| **Host** | User or bot who creates and manages a bracket |
| **Knowledge Pack** | Curated topic database for AI auto-bracket building |
| **Platform Fee** | 10% of entry credits collected by BMB |
| **Re-Pick** | Edit previously submitted bracket picks |
| **Squares** | 10x10 grid game where score digits determine winners |
| **Tie-Breaker** | Championship game total points prediction to break ranking ties |
| **Top Host** | Host designation based on rating, reviews, and hosting volume |
| **Tournament** | A complete bracket competition from creation to winner declaration |
| **Tremendous** | Third-party API for gift card fulfillment |
| **TBD** | "To Be Determined" - placeholder for teams not yet known |

---

---

## 13. Design System

### Brand Colors
| Token | Hex | Usage |
|-------|-----|-------|
| `deepNavy` | `#0A0E27` | Background gradient top |
| `midNavy` | `#141B3D` | Background gradient middle |
| `lightNavy` | `#1E2651` | Background gradient bottom |
| `gold` | `#FFD700` | Accent, BMB+ badge, highlights |
| `goldLight` | `#FFE44D` | Hover/active gold states |
| `blue` | `#2137FF` | Brand primary blue |
| `darkBlue` | `#0D1454` | Deep brand blue |
| `buttonPrimary` | `#36B37E` | CTA buttons (green) |
| `buttonGlow` | `#2D9A6B` | Active button state |
| `successGreen` | `#4CAF50` | Success states |
| `errorRed` | `#E53935` | Error states, ban indicators |
| `vipPurple` | `#9B59FF` | VIP tier accent |
| `textPrimary` | `#FFFFFF` | Primary text |
| `textSecondary` | `#B0B8D4` | Secondary text |
| `textTertiary` | `#7A82A1` | Tertiary/muted text |
| `borderColor` | `#2A3260` | Card/input borders |
| `cardDark` | `#252949` | Dark card surface |

### Gradients
| Gradient | Colors | Usage |
|----------|--------|-------|
| `backgroundGradient` | deepNavy -> midNavy -> lightNavy (vertical) | Full-screen background |
| `cardGradient` | `#1A2244` -> `#252D5A` (diagonal) | Card backgrounds |

### Typography
| Style | Font | Weight | Usage |
|-------|------|--------|-------|
| Display | ClashDisplay-Variable | Bold (700) | Headers, hero text, brand elements |
| Body | System default | Regular (400) | Body text, descriptions |
| Caption | System default | Medium (500) | Labels, captions, badges |

### Component Patterns
- **Cards**: Rounded corners (14px radius), gradient background, bottom margin 12px, padding 16px
- **Buttons**: Rounded (12px radius), primary green (`#36B37E`), with glow effect on press
- **Badges**: Pill-shaped, sport-colored or status-colored
- **Bottom Nav**: 5 tabs, active = gold, inactive = textTertiary
- **Modals**: Dark overlay, centered card with gradient background
- **Status Colors**: Saved=grey, Upcoming=blue, Live=green, In-progress=gold, Done=cyan

---

## 14. Scoring Engine Deep-Dive

### Round-Based Point Values
| Round | Points per Correct Pick | Example (64-team bracket) |
|-------|------------------------|---------------------------|
| Round 0 (R64) | 1 | First round |
| Round 1 (R32) | 2 | Second round |
| Round 2 (Sweet 16) | 4 | Regional semifinal |
| Round 3 (Elite 8) | 8 | Regional final |
| Round 4 (Final Four) | 16 | National semifinal |
| Round 5 (Championship) | 32 | Championship game |
| Round 6+ | 64+ (doubles each round) | Extended formats |

### Game ID Format
```
"r{round}_g{matchIndex}"  e.g., "r0_g0", "r1_g3", "r5_g0"
```
- `round`: 0-indexed round number
- `matchIndex`: 0-indexed match within the round

### Leaderboard Calculation Algorithm
1. Score all users' picks against `BracketResults`
2. Sort by `score` descending
3. Break ties by:
   a. Tie-breaker prediction (closest without going over)
   b. Submission timestamp (earlier = better)
4. Assign rank (1-indexed)
5. Calculate `maxPossibleScore = score + (pending picks * their round points)`

### Voting Bracket Scoring
- Each matchup gets community votes
- Majority-voted team advances to next round
- `VotingDataService` tracks vote tallies per matchup
- `VotingLeaderboardScreen` shows aggregate results
- No individual scoring -- the community decides the winner

---

## 15. Bracket Template Specifications

### NFL Playoffs (14 teams, reseeds)
```
Team Count: 14
Format: 4 rounds (Wild Card, Divisional, Championship, Super Bowl)
Reseeds: Yes (after Wild Card round)
Reseed Rule: Highest remaining seed faces lowest remaining seed
Bye: #1 seeds in AFC and NFC get first-round bye
Default Teams: "(1) AFC #1" through "(7) AFC #7" + NFC equivalents
```

### March Madness NCAA (68 teams)
```
Team Count: 64 main bracket + 4 play-in games (8 play-in teams)
Format: 6 rounds (R64, R32, Sweet 16, Elite 8, Final Four, Championship)
Regions: East, West, South, Midwest
Play-In: 8 teams compete in 4 First Four games to fill 4 main bracket spots
Data Feed: ESPN NCAA Men's Basketball (espn_ncaam)
```

### College Football Playoff (12 teams)
```
Team Count: 12
Format: 4 rounds (First Round, Quarterfinals, Semifinals, Championship)
Bye: Top 4 seeds get first-round bye
Default Teams: "(1) Seed 1" through "(12) Seed 12"
```

### FIFA World Cup (32 teams)
```
Team Count: 32
Format: Group stage (8 groups of 4) + Knockout (R16, QF, SF, Final)
Default Teams: 32 qualified nations
```

---

## 16. Future Roadmap (Planned Features)

| Priority | Feature | Description | Status |
|----------|---------|-------------|--------|
| P0 | iOS Support | iPhone/iPad native build | Planned |
| P0 | Push Notifications (FCM/APNs) | Server-side push via Firebase Cloud Messaging | Planned |
| P1 | Stripe Webhook Verification | Server-side payment confirmation before granting credits | Planned |
| P1 | Screen Reader Accessibility | Full VoiceOver/TalkBack support | Planned |
| P1 | App Store Deployment | Google Play + Apple App Store publishing | Planned |
| P2 | Real-Time Leaderboard | WebSocket/Firestore listener for live rank updates | Planned |
| P2 | Advanced Analytics Dashboard | Host-facing analytics for bracket performance | Planned |
| P2 | Feature Flags | Admin-controlled feature rollouts | Planned |
| P2 | Human Support Escalation | AI chat escalation to live agents | Planned |
| P3 | Dark/Light Theme Toggle | User-selectable theme preference | Planned |
| P3 | Multi-Language Support | i18n for Spanish, French markets | Planned |
| P3 | Tap-to-Expand Ticker | Live sports ticker with detailed game view | Planned |

---

## 17. Appendix A: Service Inventory

### Core Services
| Service | Pattern | Location | Purpose |
|---------|---------|----------|----------|
| `CurrentUserService` | Singleton | `core/services/` | User identity, auth state, credentials |
| `DailyContentEngine` | Singleton | `core/services/` | Real sports bracket generation |
| `DeviceFingerprintService` | Static | `core/services/` | Hardware fingerprinting for anti-abuse |
| `UserStateNotifier` | ChangeNotifier | `core/services/` | Reactive user state management |
| `FunFactsService` | Static | `core/services/` | Sports fun facts for engagement |

### Firebase Services
| Service | Pattern | Location | Purpose |
|---------|---------|----------|----------|
| `FirebaseAuthService` | Singleton | `core/services/firebase/` | Firebase Auth wrapper |
| `FirestoreService` | Singleton | `core/services/firebase/` | Firestore read/write wrapper |
| `RestFirebaseAuth` | Singleton | `core/services/firebase/` | REST-based Firebase Auth (no JS SDK) |
| `RestFirestoreService` | Singleton | `core/services/firebase/` | REST-based Firestore (no JS SDK) |

### Feature Services
| Service | Pattern | Location | Purpose |
|---------|---------|----------|----------|
| `AutoBuilderService` | Singleton | `auto_host/` | Voice command to bracket parsing |
| `KnowledgePackService` | Singleton | `auto_host/` | Curated topic databases |
| `LifecycleAutomationService` | Singleton | `auto_host/` | Bracket lifecycle transitions |
| `AutoShareService` | Singleton | `auto_host/` | Auto-share published brackets |
| `BracketBoardService` | Singleton | `dashboard/` | Board lifecycle, template pool |
| `BotService` | Singleton | `bots/` | Bot account management |
| `HypeManService` | Singleton | `hype_man/` | AI companion event triggers |
| `ScoringEngine` | Static | `scoring/` | Score calculation, leaderboard building |
| `ResultsService` | Static | `scoring/` | Bracket results management |
| `LiveDataFeedService` | Static | `scoring/` | ESPN/NCAA live data ingestion |
| `VotingDataService` | Singleton | `scoring/` | Community vote tracking |
| `TournamentStatusService` | Singleton | `scoring/` | Lifecycle transition tracking |
| `OfficialResultsRegistry` | Static | `scoring/` | Template-to-live-data mapping |
| `CreditAccountingService` | Singleton | `credits/` | Credit economy calculations |
| `StripePaymentService` | Static | `payments/` | Stripe checkout integration |
| `CharityService` | Singleton | `charity/` | Charity pot management |
| `CharityEscrowService` | Singleton | `charity/` | Escrow for charity funds |
| `ChatAccessService` | Static | `chat/` | Join tracking, TOS, suspensions |
| `ProfanityFilter` | Static | `chat/` | Chat content moderation |
| `CompanionService` | Singleton | `companion/` | Companion selection persistence |
| `CompanionAudioPlayer` | Instance | `companion/` | Companion voice playback |
| `StoreService` | Singleton | `store/` | Product catalog, orders |
| `BracketPrintService` | Singleton | `store/` | Print order management |
| `OrderEmailService` | Singleton | `store/` | Order confirmation emails |
| `ShopifyService` | Singleton | `shopify/` | Shopify storefront integration |
| `TremendousService` | Singleton | `gift_cards/` | Gift card fulfillment |
| `GiftCardRedemptionService` | Singleton | `gift_cards/` | Gift card order processing |
| `DeepLinkService` | Singleton | `sharing/` | Deep link generation/parsing |
| `ShareBracketService` | Static | `sharing/` | Share text generation |
| `SocialAccountsService` | Singleton | `sharing/` | Social platform connections |
| `ReferralCodeService` | Singleton | `referral/` | Referral code management |
| `PromoCodeService` | Singleton | `promo/` | Promo code validation |
| `SocialFollowPromoService` | Singleton | `social/` | Social follow reward tracking |
| `AiSupportService` | Singleton | `support/` | AI knowledge base chat |
| `SquaresService` | Singleton | `squares/` | Squares game operations |
| `LiveScoreService` | Singleton | `squares/` | Squares live score integration |
| `GiveawayService` | Singleton | `giveaway/` | Random prize drawings |
| `FavoriteTeamsService` | Singleton | `favorites/` | User team preferences |
| `EspnSportsService` | Static | `ticker/` | Live sports ticker data |
| `BiometricAuthService` | Singleton | `auth/` | Fingerprint/face login |
| `BotAccountService` | Singleton | `auth/` | Bot account creation |
| `HostReviewService` | Singleton | `reviews/` | Host rating system |
| `SpeechInputService` | Instance | `bracket_builder/` | Voice-to-text input |
| `SportsSpeechProcessor` | Static | `bracket_builder/` | Natural language team parsing |
| `TeamAutocompleteService` | Static | `bracket_builder/` | Team name suggestions |
| `WelcomeNotificationService` | Singleton | `notifications/` | Post-signup notification |
| `ReplyNotificationService` | Singleton | `notifications/` | Chat reply notifications |
| `BracketPrintRenderer` | Instance | `bracket_print/` | Bracket-to-image rendering |
| `GarmentMockupPainter` | Instance | `bracket_print/` | Garment mockup overlay |
| `MerchPreviewService` | Instance | `bracket_print/` | Preview image generation |
| `PrintProductCatalog` | Static | `bracket_print/` | Garment types and pricing |
| `PrintShopDeliveryService` | Singleton | `bracket_print/` | Shipping management |
| `BracketPrintOrderService` | Singleton | `bracket_print/` | Print order creation |
| `SVGBracketGenerator` | Static | `bracket_templates/` | SVG bracket image generation |
| `CommunityPostStore` | Singleton | `community/` | Community feed persistence |
| `PostToBmbService` | Singleton | `community/` | Content sharing to BMB |
| `TriviaService` | Singleton | `community/` | Community trivia games |
| `WebTtsEngine` | Instance | `hype_man/` | Text-to-speech for web |

---

## 18. Appendix B: Screen Inventory (All 56 Screens)

| # | Screen | Module | Purpose |
|---|--------|--------|---------|
| 1 | SplashScreen | `splash/` | App launch branding |
| 2 | AuthScreen | `auth/` | Login + Registration (tabbed) |
| 3 | CompanionSelectorScreen | `companion/` | AI companion onboarding |
| 4 | DashboardScreen | `dashboard/` | Main hub (5 tabs, 5700+ lines) |
| 5 | BracketDetailScreen | `bracket_detail/` | Tournament details + join/re-pick |
| 6 | TournamentJoinScreen | `tournament/` | Entry confirmation + credit deduction |
| 7 | BracketPicksScreen | `scoring/` | Make/view bracket picks |
| 8 | LeaderboardScreen | `scoring/` | Player rankings |
| 9 | VotingLeaderboardScreen | `scoring/` | Voting bracket results |
| 10 | HostBracketManagerScreen | `scoring/` | Host tournament management |
| 11 | PlayerPicksViewerScreen | `scoring/` | View another player's picks |
| 12 | BracketBuilderScreen | `bracket_builder/` | Create/edit bracket wizard |
| 13 | BracketTemplateScreen | `bracket_templates/` | Template gallery |
| 14 | AutoPilotWizardScreen | `auto_host/` | AI auto-build review |
| 15 | HostApprovalScreen | `auto_host/` | Approve auto-generated brackets |
| 16 | MyTemplatesScreen | `auto_host/` | Saved template management |
| 17 | SquaresHubScreen | `squares/` | Squares game lobby |
| 18 | SquaresGameScreen | `squares/` | 10x10 grid gameplay |
| 19 | BmbBucksPurchaseScreen | `bmb_bucks/` | Credit purchase flow |
| 20 | BmbStoreScreen | `store/` | Store product browser |
| 21 | ProductDetailScreen | `store/` | Product detail page |
| 22 | BracketPrintFlowScreen | `store/` | Bracket print ordering |
| 23 | OrderHistoryScreen | `store/` | Past orders |
| 24 | GiftCardStoreScreen | `gift_cards/` | Gift card browser |
| 25 | BackItFlowScreen | `bracket_print/` | Merch creation flow |
| 26 | ApparelPreviewScreen | `apparel/` | Garment mockup preview |
| 27 | TournamentChatScreen | `chat/` | Per-tournament chat room |
| 28 | CommunityChatScreen | `community/` | Global community chat |
| 29 | InboxScreen | `inbox/` | In-app message inbox |
| 30 | NotificationsScreen | `notifications/` | Push notification list |
| 31 | ReferralScreen | `referral/` | Share referral code |
| 32 | ReferralLandingPage | `referral/` | Public referral landing |
| 33 | BmbPlusUpgradeScreen | `subscription/` | Subscription upgrade |
| 34 | BusinessHubScreen | `business/` | Business features |
| 35 | BusinessSignupScreen | `business/` | Business account creation |
| 36 | BmbStarterKitScreen | `business/` | Onboarding kit |
| 37 | GiveawaySpinnerScreen | `giveaway/` | Prize spinner animation |
| 38 | HostReviewsScreen | `reviews/` | View host reviews |
| 39 | PostTournamentReviewScreen | `reviews/` | Leave a host review |
| 40 | HypeManDemoScreen | `hype_man/` | Hype man feature demo |
| 41 | FavoriteTeamsScreen | `favorites/` | Team selection |
| 42 | SocialLinksScreen | `social/` | Social account connections |
| 43 | SocialPromoAdminScreen | `social/` | Admin social promo tools |
| 44 | ProfilePhotoScreen | `profile/` | Avatar/photo selection |
| 45 | AdminPanelScreen | `admin/` | Platform administration |
| 46 | AiSupportChatScreen | `support/` | AI support chatbot |
| 47 | AccountSettingsScreen | `settings/` | User account settings |
| 48 | AboutScreen | `settings/` | App information |
| 49 | HelpSupportScreen | `settings/` | Help & support |
| 50 | TermsOfServiceScreen | `legal/` | TOS document |
| 51 | PrivacyPolicyScreen | `legal/` | Privacy policy |
| 52 | CommunityGuidelinesScreen | `legal/` | Community rules |
| 53 | BracketTreeViewerScreen | `sharing/` | Visual bracket tree |
| 54 | JoinBracketScreen | `sharing/` | Deep link join handler |
| 55 | ShopifyProductBrowserScreen | `shopify/` | Shopify product catalog |
| 56 | HologramGuidePreview | `guide_preview/` | Interactive guide |

### Widgets & Overlays (Non-Screen Components)
| Widget | Module | Purpose |
|--------|--------|---------|
| FloatingCompanion | `companion/` | Persistent AI companion on dashboard |
| WelcomeFlowOverlay | `welcome/` | 5-panel post-signup onboarding |
| HypeManOverlay | `hype_man/` | Full-screen hype celebration |
| BmbPlusModal | `subscription/` | Upgrade prompt modal |
| ShareBracketSheet | `sharing/` | Bottom sheet for sharing |
| PostToBmbSheet | `community/` | Bottom sheet for posting to community |
| ChatAccessGate | `chat/` | Access control wrapper for chat |
| SocialFollowPromoOverlay | `social/` | Social follow promo popup |
| LeaderboardSpinnerOverlay | `giveaway/` | Spinner animation overlay |
| BiometricLoginDialog | `auth/` | Biometric login prompt |
| HumanVerificationWidget | `auth/` | CAPTCHA-like verification |
| AutoPilotDashboardWidget | `auto_host/` | Auto-pilot status on dashboard |
| BracketPrintCanvas | `bracket_print/` | Bracket rendering canvas |
| BracketCompositePreview | `bracket_print/` | Composite garment preview |
| RealisticGarmentMockup | `bracket_print/` | Photorealistic garment overlay |
| ColorMatchedImage | `bracket_print/` | Color-accurate garment image |
| LiveSportsTicker | `ticker/` | Scrolling sports scores |
| EnhancedBracketCard | `dashboard/` | Rich bracket card widget |
| AnimatedPoolCard | `dashboard/` | Card with entrance animation |
| PoolCard | `dashboard/` | Simplified bracket card |
| StatsCard | `dashboard/` | User statistics display |
| BracketTreeWidget | `core/widgets/` | Interactive bracket tree |

---

## 19. Appendix C: Persistence Architecture

### Data Layer Summary
| Layer | Technology | Purpose | Scope |
|-------|-----------|---------|-------|
| **Cloud** | Firebase Firestore (REST) | User accounts, brackets, picks, transactions | All users |
| **Local (structured)** | Hive (document DB) | Cached brackets, offline data | Per device |
| **Local (key-value)** | SharedPreferences | User prefs, join tracking, promo state | Per device |
| **Secure** | flutter_secure_storage | Auth tokens, saved credentials | Per device |
| **In-Memory** | Dart singletons | Active session state, board brackets | Runtime only |

### SharedPreferences Keys (Critical)
| Key Pattern | Service | Purpose |
|-------------|---------|----------|
| `joined_bracket_ids` | ChatAccessService | Track which brackets user has joined |
| `picked_bracket_ids` | Dashboard | Track which brackets user has made picks for |
| `user_bmb_credits_{userId}` | SquaresService | Per-user credit balance |
| `bmb_companion_id` | CompanionService | Selected AI companion |
| `bmb_companion_voice_enabled` | CompanionService | Voice toggle |
| `bmb_companion_visible` | CompanionService | Companion visibility |
| `bmb_has_seen_tutorial` | CompanionService | Tutorial completion |
| `pending_bracket_id` | DeepLinkService | Bracket to auto-join after signup |
| `social_promo_enabled` | SocialFollowPromoService | Global promo toggle |
| `social_promo_visited` | SocialFollowPromoService | Visited platforms |
| `social_promo_claimed` | SocialFollowPromoService | Reward claimed flag |
| `social_promo_schedule_*` | SocialFollowPromoService | Schedule start/end/enabled |
| `social_promo_admin_override` | SocialFollowPromoService | Admin override flag |
| `last_board_refresh` | BracketBoardService | Board freshness timestamp |
| `bmb_welcome_notif_sent` | WelcomeNotificationService | Notification queued flag |
| `bmb_welcome_notif_dismissed` | WelcomeNotificationService | User dismissed flag |
| `bmb_welcome_notif_ts` | WelcomeNotificationService | Notification timestamp |

### Firestore Collections (Cloud)
| Collection | Purpose | Key Fields |
|------------|---------|------------|
| `users` | User profiles | uid, displayName, email, state, credits, membership |
| `brackets` | Tournament brackets | name, sport, teams, entryFee, status, hostId |
| `bracket_picks` | User picks per bracket | userId, bracketId, picks map, submittedAt |
| `bracket_results` | Game results | bracketId, games map, lastUpdated |
| `bracket_reservations` | Early join reservations | bracketId, userId, reservedAt, status |
| `credit_transactions` | Credit history | userId, amount, type, description, timestamp |
| `chat_messages` | Tournament chat | bracketId, senderId, message, timestamp |
| `host_reviews` | Host ratings | hostId, playerId, stars, comment |
| `gift_card_orders` | Gift card redemptions | userId, brand, denomination, status |
| `print_orders` | Merch orders | userId, bracketId, garmentType, status |
| `saved_templates` | Reusable templates | userId, templateData, recurrence |
| `event_log` | Platform events | eventType, data, timestamp |

---

*This document is a living blueprint and will be updated as features evolve. Last updated based on comprehensive codebase analysis of version 2.1.0+2 (150+ Dart source files, 40+ feature modules, 56 screens, 60+ services).*

*Confidential - Back My Bracket, LLC*
