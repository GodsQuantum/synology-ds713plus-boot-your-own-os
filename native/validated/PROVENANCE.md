# Validated N3 payload provenance

The files in this directory are the exact payloads used by the hardware-validated DS713NativeBoot N3 build. They are included so the default firmware workflow can verify and use the known-good bytes rather than silently substituting a different local rebuild.

- DS713NativeBoot N3 SHA-256: `63037d646791ddfc133840ecd5b4c80151213c61e8ce34862b7483799734d6a3`
- EDK2 tag: `edk2-stable202605`
- EDK2 commit: `b03a21a63e3bd001f52c527e5a57feddb53a690b`
- EDK2 driver hashes are enforced by `scripts/native/00-prepare-loader.sh`.

`DS713NativeBoot-N3.efi` is built from the source in `native/`. The embedded driver binaries under `drivers/` originate from TianoCore EDK2 at the pinned commit above and remain subject to the upstream EDK2 licensing terms. The repository-level MIT license does not override third-party file licenses.
