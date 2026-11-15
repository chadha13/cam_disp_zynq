# Plan d'adressage PicoBlaze (port_id 8 bits)

| Port | Sens | Contenu |
|------|------|---------|
| 0x10-0x13 | W | AXI wdata, octets 0..3 |
| 0x14 / 0x15 / 0x16 | W | Adresse AXI bits 7:0 / 15:8 / 23:16 (0x1_0000 = D-PHY, 0x0_0000 = contrôleur DSI) |
| 0x17 | W | Commande AXI : bit0 écriture, bit1 lecture (impulsion) |
| 0x18-0x1B | R | AXI rdata, octets 0..3 |
| 0x1C | R | bit0 busy, bit1 erreur (SLVERR/DECERR/timeout ≈ 2^20 cycles) |
| 0x20 / 0x21 | W | SCCB adresse registre haut / bas |
| 0x22 | W | SCCB donnée à écrire |
| 0x23 | W | Commande SCCB : bit0 écriture, bit1 lecture (impulsion) |
| 0x24 | R | SCCB donnée lue |
| 0x25 | R | bit0 busy, bit1 nack |
| 0x30 | W | bit0 : effacement des drapeaux collants (niveau) |
| 0x31 | R | bit0 overflow FIFO, bit1 underrun vidéo |
| 0x33 | R | État FSM : 0 IDLE, 1 POWER, 2 RESET, 3 CFG_CAM, 4 CFG_DSI, 5 RUN, 6 FAULT |
| 0x34 | W | bit0 start, bit1 cam_done, bit2 dsi_done, bit3 ack_fault (niveaux) |
| 0x35 | W | Adresse SCCB d'écriture (défaut 0x78) |
| 0x39 | R | Compteur de millisecondes (8 bits) |
| 0x3A | W | Code d'erreur fatale (1 capteur, 2 AXI, 3 D-PHY) |

## Registres matériels utilisés (vérifiés dans la documentation AMD)
- **D-PHY (PG202 v4.3)** : 0x00 CONTROL (bit0 SRST, bit1 DPHY_EN), 0x08 INIT, 0x10 HS_TIMEOUT,
  0x1C DL0_STATUS (bit3 INIT_DONE, bit6 STOP_STATE), 0x30 HS_SETTLE.
- **Contrôleur DSI (PG238 v3.0)** : 0x00 Core Config (bit0 core_en, bit3 command_mode, bit6 ulps_mode),
  0x04 Protocol Config, 0x24 Interrupt Status, 0x2C Status, 0x30 Command Queue, 0x50-0x6C timings vidéo.
- Séquence « mode vidéo » : timings programmés avec core_en=0, puis core_en=1, ulps_mode=0, command_mode=0.
