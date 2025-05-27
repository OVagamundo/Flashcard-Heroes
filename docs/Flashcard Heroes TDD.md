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
- **Testing**: Write unit and integration tests for core logic and systems
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
     - "Return to Title" button
   - [ ] `scenes/core/battle/BattleScreen.tscn`
     - Basic layout (player side, enemy side)
     - Placeholder UI elements
   - [ ] `scenes/screens/GameOverScreen.tscn`
     - Simple "Game Over" text
     - "Return to Title" button

3. **Autoloads**
   - [ ] `scripts/autoloads/GameManager.gd`
     - Scene management
     - Basic game state
   - [ ] `scripts/autoloads/PlayerData.gd`
     - hero_hp: int
     - gold: int
     - gacha_tokens: int
   - [ ] `scripts/autoloads/EventBus.gd`
     - Basic signal definitions

### 5.2 Milestone WS1: Basic Battle Participants & Data

#### Tasks
1. **Unit System**
   - [ ] Create `scripts/resources/UnitDefinition.gd`
     ```gdscript
     class_name UnitDefinition extends Resource
     @export var id: String
     @export var display_name: String
     @export var max_hp: int
     @export var power: int
     @export var icon: Texture2D
     ```
   - [ ] Create sample unit definitions:
     - `data/units/hero_definition.tres`
     - `data/units/enemy_definition.tres`

2. **Unit Scene**
   - [ ] Create `scenes/units/Unit.tscn`
     - Node2D (root)
       - Sprite2D (visual)
       - Label (HP display)
   - [ ] Create `scripts/units/Unit.gd`
     - Handles unit state and visuals
     - Basic methods: take_damage(), attack()

3. **Battle Setup**
   - [ ] Update BattleScreen to spawn test units
   - [ ] Display basic unit information
   - [ ] Show current turn indicator

### 5.3 Milestone WS2: Rudimentary Combat Interaction

#### Tasks
1. **Battle UI**
   - [ ] Add "Attack" button to BattleScreen
   - [ ] Add basic battle log
   - [ ] Show HP bars for units

2. **Combat Logic**
   - [ ] Implement basic attack flow
     - Player selects "Attack"
     - Hero attacks enemy
     - Enemy counterattacks
     - Update HP displays
   - [ ] Check win/lose conditions
     - If enemy HP <= 0: player wins
     - If hero HP <= 0: game over

3. **Turn Management**
   - [ ] Simple turn state machine
   - [ ] Visual feedback for active turn
   - [ ] Basic battle end handling

### 5.4 Milestone WS3: Minimal Flashcard & Gacha Integration

#### Tasks
1. **Flashcard Stub**
   - [ ] Add "Solve Flashcard" button
   - [ ] Award 1 Gacha Token on click (no actual flashcard yet)
   - [ ] Update token display

2. **Gacha Stub**
   - [ ] Add "Draw Unit" button (costs 1 token)
   - [ ] Spawn friendly unit when clicked (if tokens > 0)
   - [ ] Update token count

3. **Unit Management**
   - [ ] Allow selecting active unit
   - [ ] Only selected unit can attack
   - [ ] Basic unit targeting

### 5.5 Milestone WS4: Basic Battle Loop & Win/Loss Flow

#### Tasks
1. **Battle Flow**
   - [ ] Implement proper turn order
   - [ ] Add basic AI for enemy turns
   - [ ] Handle unit death and cleanup

2. **Progression**
   - [ ] Award gold on battle win
   - [ ] Update path choice screen with gold display
   - [ ] Implement basic run progression

3. **Game Over**
   - [ ] Proper game over handling
   - [ ] Reset player data on new run
   - [ ] Return to title screen

### 5.6 Testing Plan

#### Unit Tests
- [ ] Unit damage calculation
- [ ] Turn management
- [ ] Win/lose conditions

#### Integration Tests
- [ ] Full battle flow
- [ ] Scene transitions
- [ ] Resource management

### 5.7 Future Considerations
- Add animations and sound effects
- Implement proper flashcard mini-game
- Add more unit types and abilities
- Implement item system
- Add visual polish and feedback

### 5.8 Notes
- Keep UI minimal but functional
- Use placeholder art where needed
- Focus on core battle mechanics first
- Document any assumptions or limitations

## 6. Documentation

### 6.1 Living Documentation
- Code documentation
- Architecture decisions
- API references
- Tutorials and guides

### 6.2 Onboarding
- Development environment setup
- Contribution guidelines
- Code style guide
- Testing guidelines
