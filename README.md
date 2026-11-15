# cam_disp_zynq — Caméra DVP → MIPI DSI TX, contrôlé par un PicoBlaze

Pipeline : **capteur (DVP 8 bits + SCCB)** → `dvp_capture` → `async_fifo` → `vid_out` (AXI4-Stream RGB888) → **MIPI DSI TX Subsystem (PG238)**.
Un **PicoBlaze (KCPSM6)** configure le capteur (SCCB) et le DSI/D-PHY (AXI4-Lite) ; une **FSM de Mealy** séquence l'ensemble.

```
rtl/   sync_bit, cam_disp_fsm (Mealy), sccb_master, axil_ctrl, async_fifo, dvp_capture, vid_out, pb_ctrl, cam_disp_core, cam_disp_top
fw/    cam_disp.psm  (firmware KCPSM6)
sim/   testbenches + stubs + run_all.sh (GHDL)      docs/  PORTS.md, FSM.md      tcl/  build.tcl
```

## État de vérification (ce qui a réellement été exécuté)
| Élément | État |
|---|---|
| FSM de Mealy | Simulée sous GHDL : 15 vérifications (séquence complète, sorties Mealy, défaut, reprise, abandon) |
| Chemin de données | Simulé : trame 6×3 px, SOF/EOL, RGB565→RGB888 exact, underrun, effacement, overflow |
| SCCB | Simulé avec esclave modélisé : écriture (0x78 / 0x300A / 0x82) et lecture d'ID (0x56) |
| Cœur complet | Compile et s'élabore (stubs pour KCPSM6 et la ROM) |
| Firmware `.psm` | **Non assemblé ni exécuté** : contrôle de syntaxe/étiquettes uniquement (244/1024 instructions). À assembler avec `kcpsm6.exe` officiel |
| Pont AXI4-Lite, intégration PicoBlaze + DSI réel | **Non simulés** (pas de modèle KCPSM6 ni du sous-système DSI ici) |
| `tcl/build.tcl` | **Non testé** (pas de Vivado) ; noms `CONFIG.*` de l'IP à vérifier |

## Mise en œuvre
1. `kcpsm6.exe fw/cam_disp.psm` → produit `cam_disp.vhd` (ROM) ; copier avec `kcpsm6.vhd` (AMD) dans `rtl_extra/`.
2. `sim/run_all.sh` pour rejouer la régression (nécessite GHDL).
3. Compléter les paramètres marqués dans `cam_disp.psm` (voir ci-dessous), puis `vivado -mode batch -source tcl/build.tcl -tclargs <puce>`.

## Ce qui reste à fournir / décider (dépend de votre matériel)
1. **Capteur** (OV5640 supposé : adresse 0x78, registres 16 bits, ID 0x56/0x40) : modèle exact + table d'initialisation (PLL, résolution, polarités DVP). Le firmware ne contient que reset, format RGB565 et streaming.
2. **Dalle** : résolution, timings (HSA/HBP/HFP, VSA/VBP/VFP), nombre de lignes DSI, débit par ligne, éventuelle séquence DCS d'initialisation → pour calculer les registres 0x04 et 0x50–0x6C (actuellement à 0).
3. **Carte / puce Zynq**, horloges disponibles (AXI-Lite, `clk_vid`, D-PHY 200 MHz), brochage.
4. **Polarité VSYNC** du capteur : générique `FS_RISING` (défaut : début de trame sur front descendant).

## Limite d'architecture à connaître
Le flux est **direct** (sans mémoire d'image). Le DSI consomme les pixels à son propre rythme : sa cadence de trame doit donc **être égale** à celle de la caméra (mêmes durées de ligne et de trame), sinon underrun. La FIFO (1024 mots) + le seuil `PREFILL` n'absorbent que la phase, pas une différence de cadence. Si les cadences diffèrent (ex. capteur 30 i/s, dalle 60 Hz), il faut un tampon d'image en DDR (VDMA sur Zynq).
