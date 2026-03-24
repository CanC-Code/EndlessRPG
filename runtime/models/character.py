# ── EXPORT LOGIC ────────────────────────────────────────────────
if __name__ == "__main__":
    # Create the Knight
    knight = assemble_knight()
    knight.name = "Knight_Hero"
    
    # Create Environment assets
    tree = build_real_tree(height=5.5, seed=123)
    tree.location = (3, 3, 0)
    
    grass = build_grass_blade()
    grass.location = (1, 1, 0)
    
    print("Character & Environment successfully generated.")
