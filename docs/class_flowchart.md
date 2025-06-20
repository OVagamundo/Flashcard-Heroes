# Class Relationships Flowchart

This diagram shows the relationships between classes in the game's architecture.

```mermaid
graph TD
    %% Core Managers
    A[Game Manager] -->|Uses| B[Event Bus]
    C[Battle Manager] -->|Uses| B
    D[Interaction Manager] -->|Uses| B
    B -->|Calls| A
    B -->|Calls| C
    B -->|Calls| E[Scene Manager]
    
    %% Data Flow
    A -->|Manages| F[Gacha Ball Instance]
    C -->|Manages| F
    C -->|Updates| G[Gacha Ball View]
    D -->|Interacts with| G
    
    %% Inheritance
    G -->|Inherits| H[Item View]
    G -->|Inherits| I[Unit View]
    
    %% Database
    A -->|Reads| J[Database]
    C -->|Reads| J

    %% Styling
    style A fill:#9cf,stroke:#333
    style C fill:#9cf,stroke:#333
    style D fill:#9cf,stroke:#333
    style E fill:#9cf,stroke:#333
    style J fill:#9cf,stroke:#333
    
    style F fill:#f9f,stroke:#333
    style G fill:#f9f,stroke:#333
    style H fill:#f9f,stroke:#333
    style I fill:#f9f,stroke:#333
```

## Class Methods

### Manager Classes (Blue)
- **Game Manager**: handle_start_run(), handle_battle_start(), handle_merge()
- **Battle Manager**: handle_draw_gacha(), handle_reshuffle(), handle_interaction()
- **Interaction Manager**: handle_view_interaction(), clear_selection()
- **Scene Manager**: change_scene(), load_scene()
- **Event Bus**: emit_signal(), connect()

### Data/View Classes (Pink)
- **Gacha Ball Instance**: create_battle_copy(), initialize()
- **Gacha Ball View**: display(), handle_gui_input()
- **Unit View**: update_equipped_items()
- **Database**: get_gachaball_def(), get_merge_recipe()
