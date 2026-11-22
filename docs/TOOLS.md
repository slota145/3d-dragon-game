# Darmowe narzędzia dla agenta AI — research (listopad 2026)

Status: ✅ używamy · 🟡 warto rozważyć · ⚪ opcjonalne / później

## 1. Generowanie modeli 3D

| Narzędzie | Status | Co daje | Uwagi |
|---|---|---|---|
| **Blender jako moduł Pythona (`bpy`, pip)** | ✅ | Pełny Blender 5.3 bez GUI: modelowanie kodem, modyfikatory, riggi, animacje, eksport `.glb`, rendery podglądowe | Podstawa naszego pipeline'u. `tools/setup.sh` instaluje go do `.venv-tools`. |
| **Blender MCP** (np. [ahujasid/blender-mcp](https://enterprisedna.co/directories/mcp/ahujasid-blender-mcp), MIT) | ⚪ | Agent steruje Blenderem z GUI przez add-on + serwer MCP | Ma sens, gdy Blender działa na Twoim komputerze i chcesz patrzeć na żywo. W chmurze headless `bpy` robi to samo bez pośrednika. Inne: [blend-ai](https://lobehub.com/mcp/jabberwock-blend-ai), [blender-ai-mcp](https://mcpservers.org/ru/servers/patrykiti/blender-ai-mcp). |
| **Hunyuan3D 2.1** ([GitHub](https://github.com/Tencent/Hunyuan3D-2), [paper](https://arxiv.org/html/2506.15442v1)) | 🟡 | Obraz → model 3D z teksturami PBR, open source | **Wymaga GPU** (ten kontener go nie ma). Do uruchomienia lokalnie na mocnej karcie. Wyniki zwykle wymagają retopologii. |
| **TRELLIS / TRELLIS.2** (Microsoft) i **Pixal3D** ([HF](https://huggingface.co/TencentARC/Pixal3D)) | 🟡 | Obraz → 3D, bardzo czyste siatki | Jak wyżej: GPU, a wynik trzeba czyścić. |
| **TripoSR** | ⚪ | Szybkie obraz → 3D | Słabsza jakość ([porównanie](https://www.pixazo.ai/blog/best-open-source-3d-model-generation-apis)). |

**Wniosek:** proceduralne modele w `bpy` to główna ścieżka. Generatory AI
(Hunyuan3D/TRELLIS) bardziej pasują do stylu realistycznego lub kreskówkowego,
a do tego potrzebują GPU.

## 2. Godot ↔ agent

| Narzędzie | Status | Uwagi |
|---|---|---|
| **Godot CLI headless** (`--headless`, `--import`, `--quit-after`, `--script`) | ✅ | Wystarcza do weryfikacji: `tools/check.sh`, `tools/screenshot.sh`. |
| **Xvfb + Mesa lavapipe** | ✅ | Programowy Vulkan, więc zrzuty ekranu Forward+ działają bez GPU. |
| **[Coding-Solo/godot-mcp](https://mcpservers.org/servers/Coding-Solo/godot-mcp)** | 🟡 | `claude mcp add godot -- npx @coding-solo/godot-mcp`: uruchamianie projektu, łapanie debug outputu, tworzenie scen i węzłów. Wygodne lokalnie z edytorem. |
| **[hybridindie/godot-mcp](https://github.com/hybridindie/godot-mcp)** | ⚪ | Most do **żywego edytora** Godota (addon + serwer Pythona). Dobre, gdy pracujesz w edytorze na swoim komputerze. |
| [beckett-godot-mcp](https://enterprisedna.co/directories/mcp/beckettlab-beckett-godot-mcp), [IvanMurzak/Godot-MCP](https://mcpservers.org/pt-BR/servers/ivanmurzak/godot-mcp), [godot-mcp-enhanced](https://cdn.jsdelivr.net/npm/godot-mcp-enhanced@0.33.1/README.en.md) | ⚪ | Alternatywy, nie zweryfikowane. |

## 3. Voxel (gdyby wybrać ten styl)

- **MagicaVoxel**: darmowy edytor; format `.vox` łatwo zapisać kodem.
- Importery do Godota 4: [MagicaVoxel Importer with Extensions](https://store.godotengine.org/asset/bakacandy/magicavoxel-importer-with-extensions/)
  (MIT, testowany z 4.7.1), [wersja ++ z klatkami animacji](https://godotengine.org/asset-library/asset/1580).

## 4. Gotowe darmowe assety (CC0)

- **Kenney.nl**: tysiące assetów low-poly, UI, dźwięków (CC0).
- **Quaternius**: low-poly postacie, potwory, natura, często z animacjami (CC0).
- **Poly Haven**: HDRI, tekstury PBR, modele (CC0).
- **ambientCG**: tekstury PBR (CC0).

## 5. 2D, dźwięk, muzyka

- **PixelLab (MCP, już podłączony do sesji)**: pixel-art, ikony UI, sprite'y, tekstury,
  efekty, **muzyka i efekty dźwiękowe**. Wymaga subskrypcji lub kredytów PixelLab.
  Przyda się do HUD-u, ikon przedmiotów, dźwięków ryku i ognia.
