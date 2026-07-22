# Inventory container art provenance

These six 512×512 plates preserve the approved high-detail pixel-art container
concepts. They are intentionally more tactile than the flat environment boards:
leather grain, velvet, stitching, wood, brass hardware, wear, and authored
recesses are part of the inventory identity and must not be quantized away.

The integration pass aligns them with the shipped game without flattening them:

- ink/navy shadows share the environment and UI foundation;
- existing rim light is graded toward the canonical cyan, pink, and amber;
- a restrained four-pixel scan rhythm echoes the environment boards;
- the authored 3/5/7/10 Bag/Backpack/Suitcase/Trunk spaces remain intact;
- loose carry and home storage retain open surfaces for generated layouts;
- no items, labels, focus boxes, or other UI state are baked into the plates.

`InventoryContainerSurface` renders transparent 32×32 object models over these
plates, seats each model toward the bottom of its physical space, and uses only
a short underline plus diamond marker for focus. The full slot remains an
invisible accessible hit target, so mouse/touch/keyboard behavior does not add a
large highlight card around the art.

The runtime owner is `data/ui/inventory_containers.json`; the art manifest is
not the loader for these files. Run `tools/audit_rendered_art.py` when adding or
moving art so previews stay limited to assets with a real rendering owner.
