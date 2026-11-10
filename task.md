# Bounty Hunter ability revision

- [x] **Core Logic (Scripts)**
  - [x] Add a dedicated `on_bounty_rewarded` trigger and resolve its marked-enemy targets deterministically.
  - [x] Change the Tier 2 Food/Toy Mercenary from Gold-scaled PWR to Bounty-reward Burn.
  - [x] Change the five Tier 3 Mercenary spend effects to costs of 1 / 2 / 3 Gold by unit level.
  - [x] Change the Tier 3 Support/Specialist Mercenary to heal its adjacent allies.
- [x] **Resources (Data)**
  - [x] Update each changed ability resource and its level requirements.
  - [x] Verify resource parameters match their effect script exports.
- [x] **Registration**
  - [x] Keep all Mercenary units, items, and trinkets player-exclusive in enemy encounter pools.
- [x] **Localization**
  - [x] Update English and Brazilian Portuguese summaries and level descriptions.
- [x] **Documentation**
  - [x] Regenerate `docs/GameContentDocument.md` and its localized copy.
