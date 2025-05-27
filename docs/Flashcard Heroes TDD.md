# Flashcard Heroes: Gachamon - Technical Design Document

*Version: 2.0*  
*Last Updated: 2025-05-27*  
*Development Environment: Godot 4.1.1 with GDScript*

## Table of Contents
1. [Development Approach](#1-development-approach)
2. [Project Structure](#2-project-structure)
3. [Version Control Strategy](#3-version-control-strategy)
4. [Windsurf Integration](#4-windsurf-integration)
5. [Walking Skeleton Implementation](#5-walking-skeleton-implementation)
6. [Documentation](#6-documentation)

## 1. Development Approach

### 1.1 Walking Skeleton Methodology
- **Minimal Viable Product First**: Build the thinnest possible vertical slice that demonstrates core gameplay
- **End-to-End Functionality**: Each iteration results in a shippable (but minimal) product
- **Incremental Development**: Add features in small, testable chunks
- **Continuous Integration**: Regular commits to the main branch with passing tests

### 1.2 Development Phases

#### Phase 0: Project Setup (Week 1)
- [ ] Initialize GitHub repository with proper .gitignore
- [ ] Set up Godot 4.1.1 project structure
- [ ] Configure Godot project settings
- [ ] Create basic README and documentation
- [ ] Set up basic Godot localization (create `translations/en.csv` and add to project settings)

#### Phase 1: Core Loop (Weeks 2-4)
- [ ] Basic scene management
- [ ] Single hero vs single enemy combat
- [ ] Basic flashcard system (hardcoded questions)
- [ ] Simple win/lose conditions

#### Phase 2: Core Features (Weeks 5-8)
- [ ] Gacha system (single machine)
- [ ] Basic unit stats and combat
- [ ] Simple progression system
- [ ] Basic save/load functionality

#### Phase 3: Polish & Content (Weeks 9-12)
- [ ] UI/UX improvements
  - [ ] Ensure all UI elements support text expansion
  - [ ] Test with different languages
- [ ] Visual/audio feedback
- [ ] Additional content
  - [ ] Localize all text content
  - [ ] Ensure all assets support internationalization
- [ ] Performance optimization
  - [ ] Test with different character sets
  - [ ] Optimize font rendering for all supported languages

## 2. Project Structure

```
flashcard-heroes/
├── .github/                  # GitHub workflows and templates
│   ├── workflows/
│   │   ├── test.yml          # CI/CD pipeline
│   │   └── deploy.yml        # Deployment pipeline
│   └── PULL_REQUEST_TEMPLATE.md
│
├── addons/                  # Godot addons (e.g., GUT for testing)
│   └── gut/                 # Godot Unit Test framework
│
├── assets/                  # Game assets (images, fonts, audio, etc.)
│   ├── audio/               # Sound effects and music
│   ├── fonts/                # Font files
│   ├── icons/                # UI icons and sprites
│   ├── models/               # 3D models (if any)
│   └── translations/         # Localization files (*.translation)
│
├── data/                    # Game data and resources
│   ├── units/               # Unit definition resources (.tres)
│   ├── items/               # Item definition resources
│   ├── trinkets/            # Trinket definition resources
│   └── flashcards/          # Flashcard sets and definitions
│
├── scenes/                 # Godot scene files (.tscn)
│   ├── core/                # Core game scenes
│   │   ├── main.tscn        # Main game scene
│   │   ├── battle/          # Battle scene and sub-scenes
│   │   ├── ui/              # UI scenes and components
│   │   └── world/           # World/level scenes
│   └── systems/             # System-specific scenes
│
├── scripts/                # GDScript files (.gd)
│   ├── autoloads/          # Autoload scripts (singletons)
│   │   ├── game_manager.gd  # Core game state
│   │   ├── player_data.gd   # Player progress and resources
│   │   ├── event_bus.gd     # Global event system
│   │   └── save_system.gd   # Save/load functionality
│   ├── core/                # Core game systems
│   ├── entities/            # Entity scripts (units, items, etc.)
│   ├── systems/             # Game systems (battle, gacha, etc.)
│   └── ui/                  # UI scripts
│
├── tests/                  # Test files
│   ├── unit/                # Unit tests
│   └── integration/         # Integration tests
│
├── docs/                   # Documentation
│   └── design/              # Design documents
│
├── .gitignore              # Git ignore rules
├── project.godot            # Godot project settings
├── default_env.tres         # Default environment settings
└── README.md               # Project documentation
```

## 3. Version Control Strategy

### 3.1 Branching Strategy
- `main`: Production-ready code
- `develop`: Integration branch
- `feature/*`: New features
- `bugfix/*`: Bug fixes
- `hotfix/*`: Critical production fixes

### 3.2 Commit Message Convention
```
type(scope): brief description

Detailed description if needed

- Bullet points for details
- More details if necessary

BREAKING CHANGE: if applicable
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code changes that neither fix bugs nor add features
- `test`: Adding tests
- `chore`: Changes to build process or auxiliary tools

## 4. Godot Project Configuration

### 4.1 Project Settings
```ini
# project.godot (excerpt)
[application]
config/name="Flashcard Heroes"
run/main_scene="res://scenes/core/main.tscn"

[rendering]
quality/driver/driver_name="GLES3"

[input]
# Define input actions here
ui_accept={ "deadzone": 0.5, "events": [Object(InputEventKey)] }
ui_cancel={ "deadzone": 0.5, "events": [Object(InputEventKey)] }

[autoload]
GameManager="*res://scripts/autoloads/game_manager.gd"
PlayerData="*res://scripts/autoloads/player_data.gd"
EventBus="*res://scripts/autoloads/event_bus.gd"
SaveSystem="*res://scripts/autoloads/save_system.gd"
```

### 4.2 Development Workflow with Windsurf

1. **Start a new feature**:
   ```bash
   # Using Windsurf's CLI for better context management
   windsurf start feature/feature-name --model gemini-2.5-pro
   ```
   - Automatically creates branch and sets up context
   - Loads relevant files into context window
   - Suggests related files based on feature name

2. **Development Cycle**:
   - Write tests first (Red)
   - Implement minimal code to pass tests (Green)
   - Refactor while maintaining tests (Refactor)
   - Use `windsurf review` for AI code review

3. **Commit with Context**:
   ```bash
   windsurf commit -m "feat(combat): implement basic attack system"
   ```
   - Automatically generates well-formatted commit messages
   - Includes relevant code context
   - Suggests related files to include in commit

2. **Commit changes**:
   ```bash
   git add .
   git commit -m "feat(combat): implement basic attack system"
   ```

3. **Push changes**:
   ```bash
   git push -u origin feature/feature-name
   ```

4. **Create Pull Request**:
   - Open PR from `feature/feature-name` to `develop`
   - Request code review
   - Address review comments
   - Merge when approved

## 5. Battle-Focused Walking Skeleton Implementation

*Version: 1.0*  
*Last Updated: 2025-05-27*  
*Target: Godot 4.1.1 with GDScript*

### 5.0 Development Guidelines
- **Godot Scene/Node Management**: Organize game states and scenes effectively using Godot's scene system
- **GDScript Best Practices**: Follow GDScript guidelines with static typing where beneficial, and use signals for decoupled communication
- **Data-Driven Design**: Leverage Godot's Custom Resources (`.tres` files) for game data (Units, Items, Flashcards, etc.)
- **Signal System**: Utilize Godot's built-in signal system for decoupled communication between nodes and systems
- **UI Construction**: Utilize Godot's Control Nodes for UI construction and scene-based UI components
- **State Management**: Use Godot Autoloads/Singletons for global state management
- **Clear Naming Conventions**: Follow consistent naming conventions for files, classes, functions, and variables (e.g., PascalCase for classes/types, camelCase for functions/variables)
- **Code Comments**: Write clear and concise comments for complex logic or non-obvious code sections
- **Manual Testing**: Core logic and systems will be verified through manual testing
- **Asset Organization**: Keep assets organized within the `public/` or `src/assets/` directory

### 5.1 Milestone WS0: Project & Core Scene Setup

#### Tasks
1. **Project Setup**
   - [ ] Create new Godot 4.1.1 project
   - [ ] Set up basic project structure (see TDD)
   - [ ] Configure input map (ui_accept, ui_cancel, etc.)
   - [ ] Set up basic display settings (window size, stretch mode)

2. **Core Scenes**
   - [ ] `scenes/screens/TitleScreen.tscn`
     - Simple "Start Game" button
     - Quit button
   - [ ] `scenes/screens/PathChoiceScreen.tscn` (stub)
     - Simple "Battle" button

2. **Implement Core Autoload Singletons (in `scripts/autoloads/`):**
   - **GameManager.gd:**
     - High-level game state management and scene transitions.
     - Implement functions for basic scene loading and changing.
     - Include variables for tracking basic battle state.
   - **PlayerData.gd:**
     - Store persistent data for the current run (e.g., Hero HP, Gacha Tokens).
     - Define and initialize variables for hero_hp and gacha_tokens.
   - **EventBus.gd:**
     - Central message broker for decoupled communication using Godot signals.
     - Define initial, essential global signals relevant to battle, UI interaction, and data changes.
   - **InputManager.gd:**
     - Centralize the processing of user input, particularly for UI interactions.
     - Translate raw input into game-specific actions or events.

3. **Create Core Scene Files:**
   - `scenes/core/main.tscn` (set as the project's run/main_scene).
   - `scenes/screens/TitleScreen.tscn` with a "Start Battle Test" button and a "Quit" button.
   - `scenes/screens/GameOverScreen.tscn` with a simple text display and a button to return to the TitleScreen.

4. **Initial BattleScreen Setup:**
   - Create `scenes/core/battle/BattleScreen.tscn` with placeholder UI components.
   - Create `scripts/core/battle/BattleScreen.gd` and attach it to BattleScreen.tscn.
   - Structure the BattleScreen with areas for:
     - Player Unit Lineup
     - Enemy Unit Lineup
     - Player Information Display
     - Gacha Machine Interaction Area
     - Battle Log Display
     - "End Turn" Button
     - Inspection Panel Area (initially hidden)

### Phase 1: Battle Entities, Data Structures, and Foundational Spawning

**Goal:** Define the UnitDefinition resource for unit data, create a reusable Unit scene, and implement the spawning of initial units onto the BattleScreen based on this data structure.

1. **Define Unit Data Structure (UnitDefinition.gd):**
   - Create `scripts/resources/UnitDefinition.gd` extending Resource.
   - Define exported variables for core unit attributes (id, display_name, max_hp, power, icon).
   - Create sample unit definitions in `data/units/`.

2. **Create Reusable Unit Scene:**
   - Create `scenes/entities/Unit.tscn` with visual representation and HP display.
   - Create `scripts/entities/Unit.gd` with methods for initialization, taking damage, and basic attacks.
   - Implement event emission for unit actions and state changes.

3. **Implement Initial Unit Spawning Logic:**
   - Load sample unit definitions in BattleScreen.gd.
   - Instance and initialize units for both player and enemy sides.
   - Position units in their respective lineup areas.
   - Emit relevant events for unit spawning and battle start.
### Phase 2: Foundational Combat Loop & UI Feedback via EventBus

**Goal:** Implement a simplified combat turn initiated by the "End Turn" button, with automated combat resolution and event-driven UI updates.

1. **Implement "End Turn" Button Logic:**
   - Connect the button's pressed signal in BattleScreen.gd.
   - Disable the button during combat resolution.
   - Implement a simple combat sequence (player attacks, then enemies attack).
   - Handle turn transitions and re-enable the button.

2. **Implement Battle Log Updates:**
   - Create a method to handle battle log messages via EventBus.
   - Display combat actions and results in the battle log area.

3. **Implement Unit Death Handling & Basic Win/Loss Conditions:**
   - Handle unit_death events.
   - Check for win/loss conditions after each unit death.
   - Trigger game over or victory states as appropriate.

### Phase 3: Foundational Inspection Window & Gacha Machine Interaction

**Goal:** Implement an initial version of a modal panel for unit inspection and basic Gacha Machine interaction.

1. **Create Inspection Panel:**
   - Create `scenes/ui/InspectionPanel.tscn` with UI elements for unit details.
   - Implement `scripts/ui/InspectionPanel.gd` to display unit information.
   - Handle unit inspection requests via EventBus.

2. **Implement Foundational Flashcard Interaction:**
   - Add a debug button to simulate correct flashcard answers.
   - Update Gacha Token count in PlayerData and UI.

3. **Implement Foundational Gacha Machine Buttons:**
   - Connect Gacha Machine buttons in BattleScreen.gd.
   - Implement token cost validation and spending.
   - Spawn new units based on Gacha tier.
   - Update UI and emit relevant events.

### Phase 4: Foundational Merge System Interaction

**Goal:** Implement an initial version of the unit merging system with basic selection and combination mechanics.

1. **Implement Basic Unit Selection for Merging:**
   - Track selected units in BattleScreen.gd.
   - Provide visual feedback for selected units.
   - Handle unit selection/deselection.

2. **Implement "Merge" Button and Foundational Merge Logic:**
   - Add a debug merge button to BattleScreen.
   - Validate selection (exactly two units).
   - Remove selected units and spawn a merged unit.
   - Provide feedback via battle log and events.

## 6. Documentation

### 6.1 Code Documentation
- [ ] Document all public APIs and complex logic
- [ ] Update README with setup instructions
- [ ] Document event system architecture

### 6.2 EventBus Signals Reference
- **battle_started()**: Emitted when battle begins
- **battle_ended(victory: bool)**: Emitted when battle ends (true if player won)
- **unit_spawned(unit: Node, definition: Resource)**: When a new unit enters the battlefield
- **unit_took_damage(unit: Node, amount: int, new_hp: int)**: When a unit receives damage
- **unit_died(unit: Node)**: When a unit is defeated
- **gacha_tokens_changed(new_amount: int)**: When gacha token count changes
- **request_unit_inspection(unit: Node)**: Request to show unit details
- **request_show_battle_log_message(message: String)**: Add message to battle log
- **player_turn_started()**: When player's turn begins
- **player_turn_ended()**: When player ends their turn

### 6.3 Deployment Guide
- **Build Procedures**:
  - Export settings for HTML5 and desktop platforms
  - Asset optimization settings
- **Platform Considerations**:
  - Web: Browser compatibility and performance
  - Desktop: Minimum system requirements
  - Mobile: Touch controls and performance
- **Performance Guidelines**:
  - Texture and audio optimization
  - Memory management best practices
  - Profiling and optimization targets

### 6.4 Future Enhancements
- **Visual Improvements**:
  - Combat animations and effects
  - Screen shake and hit effects
  - Unit movement and attack animations
- **Gameplay Expansions**:
  - Full flashcard mini-game implementation
  - Additional unit types and abilities
  - Item and progression systems
  - Multiple battle arenas and environments

### 6.5 Development Notes
- **UI/UX**:
  - Focus on functionality over polish initially
  - Use clear visual feedback for player actions
  - Ensure all interactive elements are easily identifiable
- **Art Assets**:
  - Use placeholder art during development
  - Maintain consistent art style guidelines
  - Document asset specifications and requirements
- **Core Focus**:
  - Prioritize battle mechanics implementation
  - Ensure smooth turn-based gameplay flow
  - Maintain clean separation of concerns in code

### 6.6 Onboarding
- **Development Setup**:
  - Godot 4.1.1 installation
  - Project import and setup
  - Required tools and plugins
- **Project Guidelines**:
  - Code style and formatting
  - Branching and version control workflow
  - Commit message conventions
- **Development Process**:
  - Feature implementation workflow
  - Manual testing approach
  - Debugging and issue reporting
