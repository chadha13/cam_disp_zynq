# FSM de supervision (machine de Mealy)

```mermaid
stateDiagram-v2
    [*] --> IDLE
    IDLE --> POWER: start=1 / cam_pwdn=0
    POWER --> RESET: PWR_MS écoulées / rst_n capteur relâché
    RESET --> CFG_CAM: RST_MS écoulées
    CFG_CAM --> CFG_DSI: cam_done=1
    CFG_DSI --> RUN: dsi_done=1
    RUN --> FAULT: fault=1 / stream_en=0, cap_en=0 (même cycle)
    FAULT --> CFG_CAM: ack_fault=1
    POWER --> IDLE: start=0
    RESET --> IDLE: start=0
    CFG_CAM --> IDLE: start=0
    CFG_DSI --> IDLE: start=0
    RUN --> IDLE: start=0 / flux coupé
    FAULT --> IDLE: start=0
```

Sorties de Mealy (dépendent de l'état **et** des entrées) :

| Sortie | Équation |
|--------|----------|
| cam_pwdn | `1` si IDLE et start=0 |
| cam_rst_n | `0` si IDLE, POWER ou start=0 ; sinon `1` |
| cap_en = stream_en | `1` si RUN et fault=0 et start=1 (retombent dans le cycle où fault monte) |
| led_err | `1` si FAULT, ou RUN avec fault=1 |
