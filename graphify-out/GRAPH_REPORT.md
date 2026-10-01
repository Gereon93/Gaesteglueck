# Graph Report - Gaesteglueck  (2026-10-01)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 3062 nodes · 6873 edges · 181 communities (168 shown, 13 thin omitted)
- Extraction: 89% EXTRACTED · 11% INFERRED · 0% AMBIGUOUS · INFERRED: 772 edges (avg confidence: 0.84)
- Token cost: 172,530 input · 2,247 output

## Graph Freshness
- Built from commit: `be576cef`
- Run `git diff be576cef --stat -- ':!graphify-out' ':!.graphify*' ':!AGENTS.md' ':!CLAUDE.md'` to check if indexed source files have changed since the build.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Canvas Table UI Components
- PDF Export Drawing
- Guest Table Model
- Screen Toolbar & Wave
- Table Card Exporter
- Guest Model Logic
- Caterer Summary Export
- Seating Co-Pilot
- App Lifecycle & Backup
- Custom Table Section
- Contacts Service
- Prompt Evaluation Scripts
- Guest List Actions
- LLM Guest Parser
- Speech Guest Exporter
- LM Studio Client
- Room Input Stage
- Tag Model & Rows
- Enrichment Wizard
- SwiftData Schema Versions
- Tag Proposal Application
- Import Row Application
- Google Sheets Import Flow
- Partner Assignment & Form
- Dashboard Recommendations
- KI Wizard Chat
- Backup & Data Settings
- Gender & RSVP Enums
- CSV Parser
- Seat Chip View
- Import Row Cards
- Platform Export Views
- Avatar & Tag Chip
- Table Canvas Item
- OpenRouter HTTP Client
- Guest Constraints
- Room Canvas Content
- AI Settings Card
- KI Chat View
- CSV Export Tests
- Family Roles
- Happiness Scorer
- AI Suggestion Sheet
- Phone Verification Preview
- Bridal Table Policy
- Guest Import Matching
- Seating Graph Optimizer
- Name Style Rendering
- LLM Seating Planner
- Google Sheets Importer
- Apple Foundation Models Client
- Layout Version Store
- Seating Legend Model
- Table Inventory & Shape
- Fun Fact Normalizer
- Seating Legend View
- Excel Parser
- Violations & Room Inspector
- OpenRouter Models API
- Room Setup View
- Guest List Filtering Tests
- Table Geometry Layout
- Seating Plan Render
- Guest Inspector View
- Room Plan Setup
- Fun Fact Reminders
- Google Sheets URL
- Local Tag Deriver
- Visual Plan Header Drawing
- Visual Plan Text Drawing
- Static Seat View
- Seat Layout
- Conflict Banner
- Seat Name Offset
- Group Analyzer
- Tag Suggestion Service
- Seating Optimizer Tests
- App Sidebar
- Wizard Phases
- Seating Rules Capacity
- Layout Version Snapshots
- Seat Name Side
- Fun Fact Worklist
- LLM Client Factory
- Guest List Filtering
- Settings Cards
- Tag Category
- Fun Fact Game Cards
- Fun Fact Normalizer Tests
- Fun Fact Validator
- Saal Konfigurator
- App Sections
- Canvas Labels Layer
- Design Tokens
- Import Guest Edit Sheet
- Age Category
- Event & Layout Versions
- AI Feature Routing
- Guest List Operations
- Tafel Layout
- Seating Planner LLM Tests
- Warm Button Style
- Canvas Environment Keys
- Constraint Type Model
- Seat Chip Content
- Seat Info Display
- Phone vCard Export
- Hall Inventory Capacity
- Table Placement Logic
- Table Shape View
- Stat Card
- Guest Status Filters
- Onboarding Wizard
- Guest Inbox Assignment
- Typography Fonts
- Poster PDF Export
- Hall Configurator Parsing
- Google Sheets Import
- Guest Filter Rail
- Hall Table Placement
- Hall Configurator View
- LLM Cost Estimator
- Visual Plan Exporter
- Empty State Card
- Card Components
- Chip Flow Layout
- Seating Rules Editor
- Fun Fact Worklist Export
- Scale Calibration Overlay
- Dashboard Meters
- Tag Kind Colors
- Table Form
- Fun Fact Validator Tests
- LLM Provider Factory
- Import Export Views
- Tag Kind Dots
- Size Metrics
- Warm Button Sizes
- Event Setup View
- Check and Radio Rows
- Chip Flow Layout Alt
- Canvas Grid Dots
- Table List View
- Seating Rules Tests
- Schema Migration Plan
- Combination Role
- Canvas Image Export
- Family Grouper
- LM Studio Errors
- AI Run Indicator
- Column Resize Handle
- Reset Target Options
- Event Card View
- Statistics View
- LLM Factory Tests
- Keychain Store
- Canvas Label
- Sheet Backup Store
- Dashboard Hero Card
- AI Suggestion Card
- Guest Tags Section
- Fun Fact Review Sheet
- Import Row State
- Custom Message Input
- Layout Version Store Tests
- Button Configuration
- LLM Response Decoding
- Welcome Fields
- Fun Fact Game Cards Tests
- Render Context Metrics
- Connection State
- Scoring Constants
- KI Connection State
- Resolved Center Content
- Proposed Plan Panel
- Guest Tag Selection Tests
- Must Sit Together Tests
- Violation Banner
- Package Manifest
- macOS App Build Script
- Module Exports

## God Nodes (most connected - your core abstractions)
1. `Guest` - 303 edges
2. `GuestTable` - 196 edges
3. `SwiftData` - 115 edges
4. `Image` - 98 edges
5. `Tag` - 94 edges
6. `Event` - 82 edges
7. `GuestListView` - 53 edges
8. `TableCanvasItemView` - 52 edges
9. `PartnerAssignment` - 48 edges
10. `Gaesteglueck` - 46 edges

## Surprising Connections (you probably didn't know these)
- `SitzplanCoPilotTests` --calls--> `LMStudioClient`  [INFERRED]
  Tests/GaesteglueckTests/Services/SitzplanCoPilotTests.swift → Sources/Gaesteglueck/Services/LMStudioClient.swift
- `.body` --calls--> `OnboardingWizardView`  [INFERRED]
  Sources/Gaesteglueck/ContentView.swift → Sources/Gaesteglueck/Views/OnboardingWizardView.swift
- `.totalGuests` --references--> `RegistrationRow`  [INFERRED]
  Sources/Gaesteglueck/Views/ImportPreviewView.swift → Sources/Gaesteglueck/Services/CSVParser.swift
- `.combinedTagDisplay` --references--> `Tag`  [INFERRED]
  Sources/Gaesteglueck/Views/Import/ImportGuestEditSheet.swift → Sources/Gaesteglueck/Models/Tag.swift
- `.currentInboxFilterLabel` --references--> `Tag`  [INFERRED]
  Sources/Gaesteglueck/Views/Room/RoomGuestInbox.swift → Sources/Gaesteglueck/Models/Tag.swift

## Import Cycles
- None detected.

## Communities (181 total, 13 thin omitted)

### Community 1 - "PDF Export Drawing"
Cohesion: 0.07
Nodes (14): CoreGraphics, CoreText, Foundation, Gaesteglueck, PDFDrawing, PDFPageSize, Synchronization, Testing (+6 more)

### Community 2 - "Guest Table Model"
Cohesion: 0.06
Nodes (33): GuestTable, .activeRules, .attendingGuests, .disabledSeatIndices, .ghostGuests, .isFull, .remainingSeats, .seatNameSide (+25 more)

### Community 3 - "Screen Toolbar & Wave"
Cohesion: 0.06
Nodes (37): GraphicsContext, ContentView, .body, .mainSplit, .header, .backgroundLayer, ScreenToolbar, .body (+29 more)

### Community 4 - "Table Card Exporter"
Cohesion: 0.07
Nodes (28): Bool, CGContext, CGFloat, CGPoint, CGRect, CGSize, Int, String (+20 more)

### Community 5 - "Guest Model Logic"
Cohesion: 0.08
Nodes (16): Guest, .awaitsSeating, .countsForSeating, .dietarySummary, .fullName, .funFactDisplay, .funFactNeedsReview, .hasIncompleteFunFact (+8 more)

### Community 6 - "Caterer Summary Export"
Cohesion: 0.08
Nodes (25): Equatable, AgeCount, CatererSummary, Change, DietCount, Int, String, Options (+17 more)

### Community 7 - "Seating Co-Pilot"
Cohesion: 0.09
Nodes (22): CoPilotAction, info, moveGuest, swapGuests, unassignGuest, CoPilotResponse, SitzplanCoPilot, SitzplanCoPilotApplier (+14 more)

### Community 8 - "App Lifecycle & Backup"
Cohesion: 0.10
Nodes (22): App, OSLog, Scene, GaesteglueckApp, .body, Int, ModelContainer, String (+14 more)

### Community 9 - "Custom Table Section"
Cohesion: 0.09
Nodes (28): CustomTableSection, .body, .customComputedCapacity, .customTableValid, Binding, Bool, Int, String (+20 more)

### Community 10 - "Contacts Service"
Cohesion: 0.09
Nodes (22): CNContact, Contacts, LocalizedError, ContactMatch, .displayName, ContactsService, ContactsServiceError, accessDenied (+14 more)

### Community 11 - "Prompt Evaluation Scripts"
Cohesion: 0.08
Nodes (30): deepeval, deepeval_metrics, deepeval_models, deepeval_test_case, DeepEvalBaseLLM, main(), normalize(), r"""Zieht die System-Prompts aus den Swift-Quellen — Single Source of Truth.… (+22 more)

### Community 12 - "Guest List Actions"
Cohesion: 0.08
Nodes (26): String, FunFactExportFormat, csv, pdf, reminderCSV, Int, GuestListView, .body (+18 more)

### Community 13 - "LLM Guest Parser"
Cohesion: 0.16
Nodes (9): RegistrationRow, BatchEntry, LLMGuestParser, ParsedGuest, Bool, Int, String, Wrapper (+1 more)

### Community 14 - "Speech Guest Exporter"
Cohesion: 0.10
Nodes (18): CategoryBucket, custom, family, friends, .heading, none, role, work (+10 more)

### Community 15 - "LM Studio Client"
Cohesion: 0.16
Nodes (29): Codable, Message, Sendable, LLMPlan, TablePlan, ChatRequest, ChatResponse, Choice (+21 more)

### Community 16 - "Room Input Stage"
Cohesion: 0.09
Nodes (30): ClosedRange, SaalInputStageView, .actionRow, .body, .capacityHeader, .capacitySurplusAccent, .capacitySurplusLabel, .capacitySurplusValue (+22 more)

### Community 17 - "Tag Model & Rows"
Cohesion: 0.09
Nodes (19): Bool, Int, Set, String, UUID, Tag, .guestCount, GuestRowView (+11 more)

### Community 18 - "Enrichment Wizard"
Cohesion: 0.09
Nodes (22): Array, EnrichmentWizardView, .bottomBar, .contentArea, .currentEvent, .currentGroup, .registrationGroups, .stepIndicator (+14 more)

### Community 19 - "SwiftData Schema Versions"
Cohesion: 0.06
Nodes (26): SchemaV1, .models, .versionIdentifier, PersistentModel, Schema, SchemaV2, .models, .versionIdentifier (+18 more)

### Community 20 - "Tag Proposal Application"
Cohesion: 0.11
Nodes (19): ProposedTag, UUID, Binding, String, View, .applyBar, .familySkipBanner, .inputContextHint (+11 more)

### Community 21 - "Import Row Application"
Cohesion: 0.11
Nodes (20): Int, String, .pendingRows, Bool, Int, String, ImportPreviewView, .body (+12 more)

### Community 22 - "Google Sheets Import Flow"
Cohesion: 0.12
Nodes (13): escaping, GoogleSheetsImportFlow, State, error, idle, loading, preview, Sendable (+5 more)

### Community 23 - "Partner Assignment & Form"
Cohesion: 0.09
Nodes (21): PartnerAssignment, both, .id, partner1, partner2, unassigned, GuestFormView, .body (+13 more)

### Community 24 - "Dashboard Recommendations"
Cohesion: 0.08
Nodes (27): .allergyHint, .bottomCards, .guestBreakdown, .menuMeters, .nextStepBody, .nextStepCard, .nextStepCTA, .nextStepTarget (+19 more)

### Community 25 - "KI Wizard Chat"
Cohesion: 0.10
Nodes (19): ChatBubble, .body, .isUser, ChatMessage, Bool, String, UUID, String (+11 more)

### Community 26 - "Backup & Data Settings"
Cohesion: 0.14
Nodes (14): Alert, BackupSet, .id, DataCardView, .body, .dataCard, Bool, Duration (+6 more)

### Community 27 - "Gender & RSVP Enums"
Cohesion: 0.08
Nodes (27): CaseIterable, Gender, .displayName, diverse, female, .id, male, unspecified (+19 more)

### Community 28 - "CSV Parser"
Cohesion: 0.13
Nodes (7): CSVField, CSVParser, Character, Int, String, CSVParserTests, GuestImporterTests

### Community 29 - "Seat Chip View"
Cohesion: 0.07
Nodes (26): SeatChipView, .body, .centerContentView, .coupleGlyph, .dietBadgeColor, .effectiveCenter, .fillColor, .hasIntolerance (+18 more)

### Community 30 - "Import Row Cards"
Cohesion: 0.12
Nodes (19): Array, EditingTarget, .id, ImportRowCard, .body, .rawText, .statusBadge, Bool (+11 more)

### Community 31 - "Platform Export Views"
Cohesion: 0.07
Nodes (3): AppKit, PDFColors, UIKit

### Community 32 - "Avatar & Tag Chip"
Cohesion: 0.13
Nodes (15): Image, PlatformImage, Avatar, .body, .initials, Bool, CGFloat, String (+7 more)

### Community 33 - "Table Canvas Item"
Cohesion: 0.10
Nodes (21): CGFloat, CGPoint, CGSize, Double, String, Void, TableCanvasItemView, .body (+13 more)

### Community 34 - "OpenRouter HTTP Client"
Cohesion: 0.12
Nodes (20): FoundationNetworking, HTTPSession, OpenRouterClient, OpenRouterError, apiError, emptyResponse, .errorDescription, http (+12 more)

### Community 35 - "Guest Constraints"
Cohesion: 0.11
Nodes (19): Constraint, Bool, Set, String, UUID, GuestConflictsSection, .body, .conflictsForThisGuest (+11 more)

### Community 36 - "Room Canvas Content"
Cohesion: 0.10
Nodes (21): CanvasGridBackground, .body, RoomCanvasContent, .body, .canvasContents, .canvasDisplayNames, .canvasInfoMode, .canvasSeatingLegend (+13 more)

### Community 37 - "AI Settings Card"
Cohesion: 0.12
Nodes (19): AISettingsCardView, .aiCard, .aiCardSubtitle, .body, .connectionDotColor, .connectionLabel, .featureRoutingCard, .llmProvider (+11 more)

### Community 38 - "KI Chat View"
Cohesion: 0.10
Nodes (23): ConnectionState, checking, connected, unknown, unreachable, KIChatView, .body, .canSubmit (+15 more)

### Community 39 - "CSV Export Tests"
Cohesion: 0.14
Nodes (13): HTTPURLResponse, Data, FunFactWorklistCSVExporter, String, makeResponse(), OpenRouterClientTests, OpenRouterModelsAPITests, StubSession (+5 more)

### Community 40 - "Family Roles"
Cohesion: 0.08
Nodes (23): FamilyRole, aunt, brother, brotherInLaw, child, cousin, cousine, father (+15 more)

### Community 41 - "Happiness Scorer"
Cohesion: 0.17
Nodes (8): HappinessScorer, Double, .happinessScore, .violations, .happinessScore, .violations, HappinessScorerTests, String

### Community 42 - "AI Suggestion Sheet"
Cohesion: 0.14
Nodes (17): AISuggestionSheet, .body, .footer, .headlineText, .loadingOrError, .loadingState, .metaText, PlanState (+9 more)

### Community 43 - "Phone Verification Preview"
Cohesion: 0.16
Nodes (15): ExportPhonePreview, .body, .pendingMismatchBinding, PendingMismatch, PhoneCoverage, PhoneVerifyStatus, failed, nameMismatch (+7 more)

### Community 44 - "Bridal Table Policy"
Cohesion: 0.09
Nodes (20): Identifiable, BridalTablePolicy, allInner, both, brautpaarOnly, eltern, .explanation, .id (+12 more)

### Community 45 - "Guest Import Matching"
Cohesion: 0.19
Nodes (11): ImportedFamily, ImportedGuest, UUID, ImportDiffField, ImportMatcher, MatchType, nameMatchOnly, new (+3 more)

### Community 46 - "Seating Graph Optimizer"
Cohesion: 0.21
Nodes (11): Edge, SeatingGraph, Bool, Double, Set, UUID, SeatingOptimizer, Bool (+3 more)

### Community 47 - "Name Style Rendering"
Cohesion: 0.16
Nodes (15): NameStyle, firstOnly, firstWithInitial, full, .id, smartDeduped, CGContext, CGFloat (+7 more)

### Community 48 - "LLM Seating Planner"
Cohesion: 0.23
Nodes (12): Error, LLMSeatingPlanner, PlannerContext, PlannerError, .errorDescription, invalidJSON, ProposedAssignment, Int (+4 more)

### Community 49 - "Google Sheets Importer"
Cohesion: 0.16
Nodes (11): Fetch, GoogleSheetsImporter, GoogleSheetsImportError, .errorDescription, invalidEncoding, invalidURL, String, GoogleSheetsImporterTests (+3 more)

### Community 50 - "Apple Foundation Models Client"
Cohesion: 0.15
Nodes (15): FoundationModels, LLMClient, AppleOnDeviceModel, .isSupported, FoundationModelsClient, Bool, Double, Int (+7 more)

### Community 51 - "Layout Version Store"
Cohesion: 0.16
Nodes (8): LayoutVersionStore, String, ModelContext, .body, StaticString, AppLogTests, ModelContainer, UInt

### Community 52 - "Seating Legend Model"
Cohesion: 0.19
Nodes (9): Entry, .id, SeatingLegend, .hasAgeMarkers, .isEmpty, Bool, Int, String (+1 more)

### Community 53 - "Table Inventory & Shape"
Cohesion: 0.14
Nodes (15): Double, Int, String, UUID, TableInventoryItem, TableShape, .icon, .id (+7 more)

### Community 54 - "Fun Fact Normalizer"
Cohesion: 0.13
Nodes (12): Error, .errorDescription, unparseable, FunFactNormalizer, .systemPromptForTesting, Result, .id, .isRewrite (+4 more)

### Community 55 - "Seating Legend View"
Cohesion: 0.13
Nodes (16): SeatingLegendView, .body, .coupleLegendRow, .divider, .heartLegendRow, .legendAgeGrid, .legendNumberGrid, .shouldShow (+8 more)

### Community 56 - "Excel Parser"
Cohesion: 0.11
Nodes (16): CoreXLSX, Result, ExcelParser, ImportError, emptyFile, .errorDescription, invalidFormat, missingNameColumn (+8 more)

### Community 57 - "Violations & Room Inspector"
Cohesion: 0.12
Nodes (18): String, UUID, Violation, ViolationType, constraintViolated, tableOverCapacity, RoomInspectorPanel, RoomCanvasView (+10 more)

### Community 58 - "OpenRouter Models API"
Cohesion: 0.16
Nodes (17): Entry, Envelope, Error, .errorDescription, http, invalidJSON, invalidURL, rateLimited (+9 more)

### Community 59 - "Room Setup View"
Cohesion: 0.13
Nodes (17): CapacityState, neutral, ok, short, RoomSetupView, .capacityIndicator, .capacityState, .centerColumn (+9 more)

### Community 60 - "Guest List Filtering Tests"
Cohesion: 0.21
Nodes (4): GuestListFilteringTests, Bool, String, UUID

### Community 61 - "Table Geometry Layout"
Cohesion: 0.18
Nodes (11): Seat, CGFloat, CGPoint, Double, Int, UUID, TafelGeometry, .tafelGeometry (+3 more)

### Community 62 - "Seating Plan Render"
Cohesion: 0.16
Nodes (13): SeatingPlanRenderView, .body, .bounds, .hasBridalTable, .legendReserve, .legendVisible, Bool, CGFloat (+5 more)

### Community 63 - "Guest Inspector View"
Cohesion: 0.16
Nodes (12): GuestInspectorView, .bulkTagControls, .multiSelectInspector, .primarySelectedGuest, .selectedGuests, .selectionBreakdown, SelectionBreakdown, Bool (+4 more)

### Community 64 - "Room Plan Setup"
Cohesion: 0.13
Nodes (12): RoomPlan, .pixelsToCM, Double, UUID, RoomPlanFactory, FloorPlanSetupView, .body, SetupPhase (+4 more)

### Community 65 - "Fun Fact Reminders"
Cohesion: 0.18
Nodes (5): FunFactReminderCSVExporter, String, FunFactReminderGenerator, String, FunFactReminderGeneratorTests

### Community 66 - "Google Sheets URL"
Cohesion: 0.20
Nodes (4): GoogleSheetsURL, String, URL, GoogleSheetsURLTests

### Community 67 - "Local Tag Deriver"
Cohesion: 0.32
Nodes (5): LocalTagDeriver, Result, Bool, Set, String

### Community 68 - "Visual Plan Header Drawing"
Cohesion: 0.13
Nodes (13): CGColor, CGContext, CGPoint, CGRect, NSColor, NSFont, String, CGContext (+5 more)

### Community 69 - "Visual Plan Text Drawing"
Cohesion: 0.23
Nodes (11): Bool, CGContext, CGFloat, CGPoint, CGRect, CGSize, Double, NSColor (+3 more)

### Community 70 - "Static Seat View"
Cohesion: 0.12
Nodes (17): ResolvedCenter, age, initials, intolerance, StaticSeatView, .centerContentView, .coupleGlyph, .dietBadgeColor (+9 more)

### Community 71 - "Seat Layout"
Cohesion: 0.22
Nodes (6): SeatLayout, CGFloat, CGPoint, Int, .seatPositions, SeatLayoutTests

### Community 72 - "Conflict Banner"
Cohesion: 0.16
Nodes (15): ConflictBanner, .bannerBody, .body, Action, String, Tone, .background, .border (+7 more)

### Community 73 - "Seat Name Offset"
Cohesion: 0.17
Nodes (10): PreferenceKey, NameSizeKey, .nameOffset, CGFloat, CGSize, Double, .body, SeatNameOffsetTests (+2 more)

### Community 74 - "Group Analyzer"
Cohesion: 0.23
Nodes (9): BridgePerson, Cluster, GroupAnalyzer, Int, String, UUID, TagOverlap, .systemContext (+1 more)

### Community 75 - "Tag Suggestion Service"
Cohesion: 0.29
Nodes (7): GuestSnapshot, GenerationResult, LLMClient, Set, String, UUID, TagSuggestionService

### Community 77 - "App Sidebar"
Cohesion: 0.17
Nodes (10): AppSidebar, .body, .event, .kiDotColor, .kiStatusFooter, .kiTitle, .liquidGlassBackground, Date (+2 more)

### Community 78 - "Wizard Phases"
Cohesion: 0.15
Nodes (14): Int, String, WizardPhase, childTable, clusters, done, harmony, .icon (+6 more)

### Community 79 - "Seating Rules Capacity"
Cohesion: 0.17
Nodes (10): Int, SeatingRules, .isValid, Bool, Double, .capacityLabel, .currentCapacity, Bool (+2 more)

### Community 80 - "Layout Version Snapshots"
Cohesion: 0.33
Nodes (10): LayoutLabelSnapshot, LayoutSeatSnapshot, LayoutTableSnapshot, LayoutVersion, Bool, Date, Double, Int (+2 more)

### Community 81 - "Seat Name Side"
Cohesion: 0.13
Nodes (12): SeatNameSide, auto, bottom, .icon, .id, left, .localUnitVector, right (+4 more)

### Community 82 - "Fun Fact Worklist"
Cohesion: 0.19
Nodes (6): FunFactWorklist, Int, .funFactWorklistCount, FunFactWorklistTests, Bool, String

### Community 83 - "LLM Client Factory"
Cohesion: 0.37
Nodes (5): LLMClientFactory, Double, LLMClient, UserDefaults, String

### Community 84 - "Guest List Filtering"
Cohesion: 0.24
Nodes (8): GuestListFiltering, .filteredGuests, .hasActiveFilter, .isFunFactFilterActive, .registrationSections, RegistrationSection, Bool, String

### Community 85 - "Settings Cards"
Cohesion: 0.15
Nodes (15): AccentCardView, .body, String, ListColumnsCardView, .body, Bool, SeatingCardView, .body (+7 more)

### Community 86 - "Tag Category"
Cohesion: 0.14
Nodes (10): TagCategory, activity, custom, .defaultColor, family, friendGroup, .id, role (+2 more)

### Community 87 - "Fun Fact Game Cards"
Cohesion: 0.29
Nodes (8): FunFactGameCardsExporter, .cardSize, CGContext, CGFloat, CGPoint, CGSize, Int, String

### Community 88 - "Fun Fact Normalizer Tests"
Cohesion: 0.22
Nodes (8): LLMClient, MainActor, FunFactNormalizerTests, StubLLM, Bool, Double, Int, String

### Community 89 - "Fun Fact Validator"
Cohesion: 0.27
Nodes (9): FunFactValidator, .systemPromptForTesting, Result, String, UUID, Verdict, empty, generic (+1 more)

### Community 90 - "Saal Konfigurator"
Cohesion: 0.19
Nodes (13): ProposedTable, SaalProposal, .totalCapacity, Bool, UUID, ProposedTableCard, .body, .shapeBadge (+5 more)

### Community 91 - "App Sections"
Cohesion: 0.14
Nodes (13): AppSection, assistant, dashboard, export, .group, guests, .icon, .id (+5 more)

### Community 92 - "Canvas Labels Layer"
Cohesion: 0.18
Nodes (12): Group, app, overview, planning, CanvasLabelsLayer, .body, CanvasLabelView, .body (+4 more)

### Community 93 - "Design Tokens"
Cohesion: 0.15
Nodes (10): Colors, Radius, Shadow, Spacing, CGFloat, Tokens, View, .doneState (+2 more)

### Community 94 - "Import Guest Edit Sheet"
Cohesion: 0.23
Nodes (9): ImportGuestEditSheet, .body, .canAddNewTag, .combinedTagDisplay, Bool, Content, Set, String (+1 more)

### Community 95 - "Age Category"
Cohesion: 0.15
Nodes (12): AgeCategory, adult, baby, child, .iconName, .id, .isMarkedAge, .needsSeat (+4 more)

### Community 96 - "Event & Layout Versions"
Cohesion: 0.19
Nodes (11): Event, .partnerDisplayName1, .partnerDisplayName2, Date, Double, String, UUID, LayoutVersionsSheet (+3 more)

### Community 97 - "AI Feature Routing"
Cohesion: 0.15
Nodes (12): AIFeature, chat, .displayName, funfact, .hint, .id, importParse, .modelKey (+4 more)

### Community 98 - "Guest List Operations"
Cohesion: 0.22
Nodes (6): GuestTagSelection, MustSitTogetherLink, Bool, Set, String, UUID

### Community 99 - "Tafel Layout"
Cohesion: 0.28
Nodes (5): TafelLayout, Bool, Int, UUID, .seatChipsLayer

### Community 100 - "Seating Planner LLM Tests"
Cohesion: 0.26
Nodes (3): LLMSeatingPlannerTests, String, UUID

### Community 101 - "Warm Button Style"
Cohesion: 0.21
Nodes (10): ButtonStyle, View, WarmButtonKind, ghost, primary, sage, secondary, soft (+2 more)

### Community 102 - "Canvas Environment Keys"
Cohesion: 0.24
Nodes (11): EnvironmentKey, CanvasScaleKey, EnvironmentValues, .canvasScale, .seatDisplayNames, .seatingLegend, SeatDisplayNamesKey, SeatingLegendKey (+3 more)

### Community 103 - "Constraint Type Model"
Cohesion: 0.20
Nodes (8): ConstraintType, .id, mustNotSitTogether, mustSitTogether, Color, .color, .icon, String

### Community 104 - "Seat Chip Content"
Cohesion: 0.17
Nodes (11): SeatChipContent, age, ageAndIntolerance, .icon, .id, initials, intolerance, .label (+3 more)

### Community 105 - "Seat Info Display"
Cohesion: 0.17
Nodes (11): SeatInfoDisplay, all, dietOnly, .icon, .id, intoleranceOnly, .label, none (+3 more)

### Community 106 - "Phone vCard Export"
Cohesion: 0.27
Nodes (3): PhoneVCardExporter, String, PhoneVCardExporterTests

### Community 107 - "Hall Inventory Capacity"
Cohesion: 0.30
Nodes (8): SaalInventar, .bridalCapacity, .childCapacity, .maxTotalCapacity, .rectCapacityEach, .roundCapacityEach, Double, Int

### Community 108 - "Table Placement Logic"
Cohesion: 0.32
Nodes (5): Double, UUID, TablePlacement, TablePlacer, TablePlacerTests

### Community 109 - "Table Shape View"
Cohesion: 0.17
Nodes (12): .tableShape, Bool, CGFloat, TableCanvasTableShapeView, .body, .borderColor, .borderWidth, .fillColor (+4 more)

### Community 110 - "Stat Card"
Cohesion: 0.18
Nodes (11): .statGrid, GGStatCard, .body, String, Tint, .background, .foreground, rose (+3 more)

### Community 111 - "Guest Status Filters"
Cohesion: 0.17
Nodes (10): StatusFilter, allergies, assigned, funfactEmpty, funfactGood, funfactPending, phoneMissing, phoneSet (+2 more)

### Community 112 - "Onboarding Wizard"
Cohesion: 0.18
Nodes (11): OnboardingWizardView, .backgroundLayer, .body, .canDismissWithoutSaving, .canSubmit, .eventDisplayName, .welcomeCard, Bool (+3 more)

### Community 113 - "Guest Inbox Assignment"
Cohesion: 0.21
Nodes (8): RoomGuestInbox, .currentInboxFilterLabel, .unassignedGuests, .unassignedSorted, Bool, String, UUID, .canvasLayout

### Community 114 - "Typography Fonts"
Cohesion: 0.20
Nodes (10): Font, DisplayWeight, .fontName, .italicFontName, medium, regular, semibold, Bool (+2 more)

### Community 115 - "Poster PDF Export"
Cohesion: 0.24
Nodes (4): PosterExporter, Date, String, PosterExporterTests

### Community 116 - "Hall Configurator Parsing"
Cohesion: 0.38
Nodes (4): SaalKonfigurator, Any, LLMClient, String

### Community 117 - "Google Sheets Import"
Cohesion: 0.27
Nodes (8): GoogleSheetsImportButton, .body, .event, .savedURL, .urlInputDialog, GoogleSheetsRowsWrapper, Int, String

### Community 118 - "Guest Filter Rail"
Cohesion: 0.25
Nodes (7): GuestFilterRailView, .body, Bool, Content, Int, String, Void

### Community 119 - "Hall Table Placement"
Cohesion: 0.25
Nodes (5): SaalTablePlacement, Double, Int, UUID, .applyBar

### Community 120 - "Hall Configurator View"
Cohesion: 0.20
Nodes (10): SaalKonfiguratorView, .applyButtonTitle, .body, .seatingNeed, Duration, Int, Never, String (+2 more)

### Community 121 - "LLM Cost Estimator"
Cohesion: 0.36
Nodes (5): LLMCostEstimator, Double, Int, String, .costLine

### Community 122 - "Visual Plan Exporter"
Cohesion: 0.47
Nodes (5): CGContext, CGFloat, CGPoint, CGRect, VisualSeatingPlanExporter

### Community 123 - "Empty State Card"
Cohesion: 0.27
Nodes (8): .emptyState, EmptyStateCard, .body, Action, String, Variant, `default`, warm

### Community 124 - "Card Components"
Cohesion: 0.29
Nodes (8): GGCard, .body, InspectorSection, .body, Action, CGFloat, Content, String

### Community 125 - "Chip Flow Layout"
Cohesion: 0.31
Nodes (7): Layout, ChipFlow, CGFloat, CGRect, CGSize, ProposedViewSize, Subviews

### Community 126 - "Seating Rules Editor"
Cohesion: 0.33
Nodes (7): .seatingRules, SeatingRulesEditor, .body, Binding, Double, String, WritableKeyPath

### Community 127 - "Fun Fact Worklist Export"
Cohesion: 0.28
Nodes (4): FunFactWorklistExporter, String, PDFSmokeTests, String

### Community 128 - "Scale Calibration Overlay"
Cohesion: 0.25
Nodes (8): ScaleCalibrationOverlay, .body, .hasCalibration, Bool, CGPoint, CGSize, String, Void

### Community 129 - "Dashboard Meters"
Cohesion: 0.22
Nodes (9): DashboardMeter, .body, .percent, RecommendationRow, .body, Double, Int, String (+1 more)

### Community 130 - "Tag Kind Colors"
Cohesion: 0.22
Nodes (9): TagKind, activity, .background, custom, family, .foreground, friends, role (+1 more)

### Community 131 - "Table Form"
Cohesion: 0.25
Nodes (8): Bool, Double, Int, String, TableFormView, .body, .isValid, .previewCapacity

### Community 132 - "Fun Fact Validator Tests"
Cohesion: 0.29
Nodes (3): LLMClient, MainActor, FunFactValidatorTests

### Community 133 - "LLM Provider Factory"
Cohesion: 0.25
Nodes (7): LLMProvider, appleOnDevice, .displayName, .id, lmStudio, openRouter, .selectableCases

### Community 135 - "Tag Kind Dots"
Cohesion: 0.25
Nodes (8): Kind, activity, custom, .dotColor, family, friends, role, work

### Community 136 - "Size Metrics"
Cohesion: 0.25
Nodes (8): Size, .dotSize, .fontSize, .horizontalPadding, md, sm, .verticalPadding, CGFloat

### Community 137 - "Warm Button Sizes"
Cohesion: 0.25
Nodes (8): CGFloat, WarmButtonSize, .fontSize, .horizontalPadding, lg, md, sm, .verticalPadding

### Community 138 - "Event Setup View"
Cohesion: 0.32
Nodes (6): EventSetupView, .body, .existingEvent, Bool, Date, String

### Community 139 - "Check and Radio Rows"
Cohesion: 0.32
Nodes (8): CheckRow, .body, RadioRow, .body, Bool, String, Void, .optionsPane

### Community 140 - "Chip Flow Layout Alt"
Cohesion: 0.36
Nodes (6): ChipFlowLayout, CGFloat, CGRect, CGSize, ProposedViewSize, Subviews

### Community 141 - "Canvas Grid Dots"
Cohesion: 0.25
Nodes (6): CanvasGridDots, .body, SetupTableShape, .body, .shape, .roomVisualization

### Community 142 - "Table List View"
Cohesion: 0.25
Nodes (7): Int, TableListView, .body, .totalAssigned, .totalCapacity, TableRowView, .body

### Community 144 - "Schema Migration Plan"
Cohesion: 0.29
Nodes (6): MigrationStage, SchemaMigrationPlan, AppMigrationPlan, .schemas, .stages, VersionedSchema

### Community 145 - "Combination Role"
Cohesion: 0.29
Nodes (6): CombinationRole, corner, end, head, .id, middle

### Community 146 - "Canvas Image Export"
Cohesion: 0.29
Nodes (6): CanvasImageExporter, Bool, CGFloat, NSImage, String, UUID

### Community 148 - "LM Studio Errors"
Cohesion: 0.29
Nodes (7): LMStudioError, connectionFailed, emptyResponse, .errorDescription, invalidJSON, invalidURL, noModelsLoaded

### Community 149 - "AI Run Indicator"
Cohesion: 0.29
Nodes (6): AIRunIndicator, .body, Int, String, Void, .body

### Community 150 - "Column Resize Handle"
Cohesion: 0.29
Nodes (6): ColumnResizeHandle, .body, Double, .guestTableHeader, CGFloat, String

### Community 151 - "Reset Target Options"
Cohesion: 0.29
Nodes (7): ResetTarget, everything, guests, guestsAndTags, .id, tables, tags

### Community 152 - "Event Card View"
Cohesion: 0.43
Nodes (5): EventCardView, .body, .event, Date, String

### Community 153 - "Statistics View"
Cohesion: 0.29
Nodes (7): StatisticsView, .assignedGuests, .confirmedGuests, .event, .totalCapacity, Double, Int

### Community 154 - "LLM Factory Tests"
Cohesion: 0.43
Nodes (3): LLMClientFactoryTests, String, UserDefaults

### Community 155 - "Keychain Store"
Cohesion: 0.47
Nodes (3): Security, KeychainStore, String

### Community 156 - "Canvas Label"
Cohesion: 0.47
Nodes (4): CanvasLabel, Double, String, UUID

### Community 157 - "Sheet Backup Store"
Cohesion: 0.47
Nodes (3): SheetBackupStore, String, URL

### Community 158 - "Dashboard Hero Card"
Cohesion: 0.40
Nodes (3): Int, String, View

### Community 159 - "AI Suggestion Card"
Cohesion: 0.47
Nodes (4): AISuggestionCard, .body, Actions, Content

### Community 160 - "Guest Tags Section"
Cohesion: 0.40
Nodes (5): GuestTagsSection, .body, .tagsByCategory, Set, UUID

### Community 161 - "Fun Fact Review Sheet"
Cohesion: 0.33
Nodes (6): FunFactReviewSheet, .body, Set, String, UUID, Void

### Community 162 - "Import Row State"
Cohesion: 0.33
Nodes (6): RowState, fallback, .guests, parsed, parsing, String

### Community 163 - "Custom Message Input"
Cohesion: 0.40
Nodes (5): CustomMessageInput, .body, Bool, String, Void

### Community 165 - "Button Configuration"
Cohesion: 0.40
Nodes (3): Configuration, Bool, View

### Community 166 - "LLM Response Decoding"
Cohesion: 0.60
Nodes (5): Decodable, Entry, LLMResponse, Entry, LLMResponse

### Community 167 - "Welcome Fields"
Cohesion: 0.40
Nodes (5): Hashable, WelcomeField, partner1, partner2, venue

### Community 169 - "Render Context Metrics"
Cohesion: 0.40
Nodes (5): RenderContext, .dietDotDiameter, .nameFontSize, .nameOffset, .seatDotDiameter

### Community 170 - "Connection State"
Cohesion: 0.40
Nodes (5): ConnectionState, checking, connected, offline, unknown

### Community 171 - "Scoring Constants"
Cohesion: 0.50
Nodes (3): ScoringConstants, SimulatedAnnealing, Double

### Community 172 - "KI Connection State"
Cohesion: 0.50
Nodes (4): KIConnectionState, connected, offline, unknown

### Community 173 - "Resolved Center Content"
Cohesion: 0.50
Nodes (4): ResolvedCenter, age, initials, intolerance

### Community 174 - "Proposed Plan Panel"
Cohesion: 0.50
Nodes (4): ProposedPlanPanel, .body, Bool, Void

## Knowledge Gaps
- **582 isolated node(s):** `PDFPageSize`, `SimulatedAnnealing`, `GaesteglueckModule`, `PDFColors`, `Colors` (+577 more)
  These have ≤1 connection - possible missing edges. (Counts symbols only; 1035 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **13 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Guest` connect `Guest Model Logic` to `Guest Table Model`, `Screen Toolbar & Wave`, `Table Card Exporter`, `Caterer Summary Export`, `Seating Co-Pilot`, `Custom Table Section`, `Contacts Service`, `Guest List Actions`, `Speech Guest Exporter`, `Tag Model & Rows`, `Enrichment Wizard`, `Tag Proposal Application`, `Import Row Application`, `Google Sheets Import Flow`, `Partner Assignment & Form`, `Dashboard Recommendations`, `KI Wizard Chat`, `Backup & Data Settings`, `Gender & RSVP Enums`, `Seat Chip View`, `Import Row Cards`, `Avatar & Tag Chip`, `Table Canvas Item`, `Guest Constraints`, `Room Canvas Content`, `KI Chat View`, `CSV Export Tests`, `Family Roles`, `Happiness Scorer`, `AI Suggestion Sheet`, `Phone Verification Preview`, `Guest Import Matching`, `Seating Graph Optimizer`, `Name Style Rendering`, `LLM Seating Planner`, `Layout Version Store`, `Seating Legend Model`, `Violations & Room Inspector`, `Room Setup View`, `Guest List Filtering Tests`, `Seating Plan Render`, `Guest Inspector View`, `Fun Fact Reminders`, `Visual Plan Text Drawing`, `Static Seat View`, `Group Analyzer`, `Seating Optimizer Tests`, `App Sidebar`, `Seating Rules Capacity`, `Fun Fact Worklist`, `LLM Client Factory`, `Guest List Filtering`, `Tag Category`, `Fun Fact Game Cards`, `Fun Fact Normalizer Tests`, `Fun Fact Validator`, `Age Category`, `Event & Layout Versions`, `Guest List Operations`, `Tafel Layout`, `Seating Planner LLM Tests`, `Phone vCard Export`, `Guest Status Filters`, `Onboarding Wizard`, `Guest Inbox Assignment`, `Poster PDF Export`, `Guest Filter Rail`, `Hall Table Placement`, `Hall Configurator View`, `Fun Fact Worklist Export`, `Fun Fact Validator Tests`, `Family Grouper`, `Statistics View`, `Layout Version Store Tests`, `Fun Fact Game Cards Tests`, `Proposed Plan Panel`, `Violation Banner`?**
  _High betweenness centrality (0.285) - this node is a cross-community bridge._
- **Why does `GuestTable` connect `Guest Table Model` to `PDF Export Drawing`, `Screen Toolbar & Wave`, `Table Card Exporter`, `Guest Model Logic`, `Caterer Summary Export`, `Seating Co-Pilot`, `Table Form`, `Custom Table Section`, `Guest List Actions`, `Canvas Grid Dots`, `Table List View`, `Combination Role`, `Canvas Image Export`, `Google Sheets Import Flow`, `Dashboard Recommendations`, `KI Wizard Chat`, `Backup & Data Settings`, `Statistics View`, `Import Row Cards`, `Avatar & Tag Chip`, `Table Canvas Item`, `Room Canvas Content`, `Layout Version Store Tests`, `KI Chat View`, `CSV Export Tests`, `Happiness Scorer`, `AI Suggestion Sheet`, `Seating Graph Optimizer`, `Name Style Rendering`, `LLM Seating Planner`, `Proposed Plan Panel`, `Layout Version Store`, `Table Inventory & Shape`, `Violations & Room Inspector`, `Room Setup View`, `Guest List Filtering Tests`, `Table Geometry Layout`, `Seating Plan Render`, `Group Analyzer`, `Seating Optimizer Tests`, `Seating Rules Capacity`, `Seat Name Side`, `Event & Layout Versions`, `Tafel Layout`, `Seating Planner LLM Tests`, `Table Placement Logic`, `Table Shape View`, `Guest Inbox Assignment`, `Poster PDF Export`, `Hall Table Placement`, `Hall Configurator View`, `Visual Plan Exporter`, `Fun Fact Worklist Export`?**
  _High betweenness centrality (0.137) - this node is a cross-community bridge._
- **Why does `Foundation` connect `PDF Export Drawing` to `Guest Table Model`, `Table Card Exporter`, `LLM Provider Factory`, `Caterer Summary Export`, `Seating Co-Pilot`, `App Lifecycle & Backup`, `Fun Fact Validator Tests`, `Contacts Service`, `LLM Guest Parser`, `Speech Guest Exporter`, `Seating Rules Tests`, `Combination Role`, `Tag Model & Rows`, `SwiftData Schema Versions`, `Family Grouper`, `Tag Proposal Application`, `Partner Assignment & Form`, `Gender & RSVP Enums`, `Canvas Label`, `CSV Parser`, `Keychain Store`, `Sheet Backup Store`, `OpenRouter HTTP Client`, `Guest Constraints`, `CSV Export Tests`, `Family Roles`, `Fun Fact Game Cards Tests`, `Scoring Constants`, `Bridal Table Policy`, `Guest Import Matching`, `Seating Graph Optimizer`, `Guest Tag Selection Tests`, `LLM Seating Planner`, `Google Sheets Importer`, `Apple Foundation Models Client`, `Layout Version Store`, `Seating Legend Model`, `Table Inventory & Shape`, `Fun Fact Normalizer`, `Excel Parser`, `Violations & Room Inspector`, `OpenRouter Models API`, `Table Geometry Layout`, `Room Plan Setup`, `Fun Fact Reminders`, `Google Sheets URL`, `Seat Layout`, `Group Analyzer`, `Tag Suggestion Service`, `Seating Rules Capacity`, `Layout Version Snapshots`, `Seat Name Side`, `Tag Category`, `Fun Fact Validator`, `Saal Konfigurator`, `Age Category`, `Event & Layout Versions`, `AI Feature Routing`, `Guest List Operations`, `Tafel Layout`, `Seating Planner LLM Tests`, `Constraint Type Model`, `Seat Chip Content`, `Seat Info Display`, `Phone vCard Export`, `Table Placement Logic`, `Poster PDF Export`, `Hall Table Placement`, `LLM Cost Estimator`, `Fun Fact Worklist Export`?**
  _High betweenness centrality (0.072) - this node is a cross-community bridge._
- **Are the 117 inferred relationships involving `Guest` (e.g. with `.attendingGuests` and `.ghostGuests`) actually correct?**
  _`Guest` has 117 INFERRED edges - model-reasoned connections that need verification._
- **Are the 86 inferred relationships involving `GuestTable` (e.g. with `.applyPlan()` and `.planList()`) actually correct?**
  _`GuestTable` has 86 INFERRED edges - model-reasoned connections that need verification._
- **What connects `PDFPageSize`, `SimulatedAnnealing`, `GaesteglueckModule` to the rest of the system?**
  _582 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Canvas Table UI Components` be split into smaller, more focused modules?**
  _Cohesion score 0.06057692307692308 - nodes in this community are weakly interconnected._