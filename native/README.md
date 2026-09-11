# DS713NativeBoot N3

N3 is the UEFI loader used by the project's primary workflow.

It replaces the legacy DS713+ **Internal Shell** while preserving its FFS GUID `C57AD6B7-0515-40A8-9D21-551652854E37`. This is deliberately not a whole-firmware replacement: it reuses an existing BDS target and keeps the modified surface small.

Boot policy:

```text
GPIO16 HIGH → wait 200 ms → GPIO20 HIGH
front USB → rear Etron USB + embedded EDK2 stack → internal SATA
```

For each controller N3 tries matching `Boot####` entries first, then the portable `\EFI\BOOT\BOOTX64.EFI` fallback. It contains no hard-coded OS name, disk UUID, serial number or rear-port number.

Validated payload:

```text
native/validated/DS713NativeBoot-N3.efi
SHA-256 63037d646791ddfc133840ecd5b4c80151213c61e8ce34862b7483799734d6a3
Size    315392 bytes
```

This exact payload cold-booted the validation DS713+ without a bridge key from its rear USB SSD into Ubuntu 26.04.1, network and SSH.

Sources are provided next to the validated payload. `scripts/native/00-prepare-loader.sh --rebuild` can check whether a development environment reproduces the hardware-tested binary byte-for-byte; a mismatch is rejected rather than silently replacing the validated payload.
