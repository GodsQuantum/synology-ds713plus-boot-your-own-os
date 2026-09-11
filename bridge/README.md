# Appendix — DS713Bridge

**DS713Bridge is the former rear-USB boot method.** It is kept because it was used to understand the DS713+, validate the Etron EJ168 path and develop N3. It is no longer required by the recommended workflow.

The current path is: **F400 + N3 firmware → OS media directly**. See the [quick start](../docs/QUICKSTART.md).

## When the bridge is still useful

- experimenting without installing N3 into firmware;
- keeping a removable recovery/fallback key;
- diagnosing the Etron controller or UEFI driver stack;
- reproducing the project's research history.

## Versions

| Version | Purpose | Status |
|---|---|---|
| v9.1 | first rear-USB boot proof with XhciDxe | historical, validated |
| v9.3 | research iteration | historical |
| v9.4 FULL-STACK R2 | complete xHCI + USB + storage + filesystem stack | validated |
| v9.5 SATA-POWER | v9.4 + GPIO16 → 200 ms → GPIO20 | validated |

To recreate the latest bridge key:

```bash
./scripts/13-create-usb3-bridge-v95.sh
```

Historical docs remain available:

- [USB3 overview](../docs/USB3-BRIDGE.md)
- [v9.4 FULL-STACK](../docs/USB3-BRIDGE-V94.md)
- [v9.5 SATA-POWER](../docs/USB3-BRIDGE-V95.md)
- [Research status](../docs/RESEARCH-STATUS.md)
- [Research handoff](../docs/RESEARCH-HANDOFF.md)
