# DS713+ — quick start

The recommended path turns a **retail DS713+ that still boots DSM** into a machine that can boot a normal x86-64 UEFI OS without keeping a bridge key plugged in.

The final firmware does two things in one SPI write:

- removes Synology's `F400:F400` USB restriction;
- replaces the legacy Internal Shell with the hardware-validated **DS713NativeBoot N3** loader.

N3 powers both SATA bays, tries front USB first, initializes the rear Etron USB 3.0 controller next, then tries internal SATA. The portable OS fallback is `\EFI\BOOT\BOOTX64.EFI`.

> ⚠️ Firmware flashing carries real risk. Read [SAFETY.md](SAFETY.md) and [RECOVERY.md](RECOVERY.md) before `arm`.

## 1. Prerequisites

- DS713+ still booting DSM;
- SSH enabled in DSM;
- DSM administrator account;
- Linux PC on the same network;
- stable power.

```bash
git clone https://github.com/GodsQuantum/synology-ds713plus-boot-your-own-os.git
cd synology-ds713plus-boot-your-own-os

export NAS_HOST='192.168.1.x'
export NAS_USER='your-dsm-admin'
```

## 2. Audit and double dump — no SPI write

```bash
./scripts/open-ds713plus.sh audit
```

This builds/installs the project flashrom, verifies the DS713+ SPI profile, performs two independent reads and refuses to continue if they differ.

## 3. Build one F400 + N3 candidate — still no SPI write

```bash
./scripts/open-ds713plus.sh build
```

The default payload is the exact N3 binary validated on real hardware:

```text
SHA-256  63037d646791ddfc133840ecd5b4c80151213c61e8ce34862b7483799734d6a3
Size     315392 bytes
```

Sources live in `native/`; the validated payload and embedded EDK2 drivers live in `native/validated/`.

## 4. Live preflight + prepare — still no SPI write

```bash
./scripts/open-ds713plus.sh prepare
```

Do not continue unless status reaches:

```text
STATUS=WAITING_FOR_ARM
```

## 5. Explicitly arm the write

```bash
./scripts/open-ds713plus.sh status
./scripts/open-ds713plus.sh arm
./scripts/open-ds713plus.sh status
```

The NAS-side worker writes only the computed erase-aligned patch range, verifies the candidate twice and attempts an automatic rollback if verification fails.

Expected success:

```text
FINAL_STATUS=SUCCESS_CANDIDATE_VERIFIED_TWICE
```

## 6. Full BIOS verification before reboot

```bash
./scripts/open-ds713plus.sh verify
```

Reboot only when it ends with:

```text
READY_FOR_REBOOT=YES
```

## 7. OS media

For the most portable setup, provide:

```text
\EFI\BOOT\BOOTX64.EFI
```

N3 physical order:

```text
1. front USB 2.0
2. rear USB 3.0 / Etron EJ168
3. internal SATA
```

SATA power is asserted before boot discovery: GPIO16 HIGH, wait 200 ms, GPIO20 HIGH.

## 8. Validation status

The validated N3 cold-booted without a bridge key into Ubuntu 26.04.1 from the rear USB SSD and reached network + SSH. The observed N3 breadcrumb was `0x277` (GPIO, rear stack, rear filesystem and chainload all reached).

A repeat boot reached Linux `graphical.target` in **46.16 s** after firmware handoff.

## What about DS713Bridge?

It is no longer required by the primary workflow. It remains preserved as a removable fallback, diagnostic tool and research path. See **[bridge/README.md](../bridge/README.md)**.
