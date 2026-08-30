# Custom YouMod automation

This fork keeps the fullscreen engagement-panel fix in the single commit
`906a3e11d5ecf50ceccf86e2e3760de4bdf68419` on
`fix/fullscreen-engagement-panel`. The default branch contains only the
automation around that patch.

## What is automatic

`.github/workflows/custom-release.yml` checks the newest upstream tag daily.
It skips the patch if the regression check proves that upstream already has the
fix; otherwise it cherry-picks the isolated patch. Successful scheduled builds
publish only a compiled `.deb` and `provenance.json`. Failures open one tracking
issue and never publish a release.

The macOS LaunchAgent checks those releases daily. When `Input/base.ipa` exists,
it replaces the one existing `YouMod.dylib` (and its resource bundle when
present), validates the unsigned result, and saves it in `Ready` for manual
SideStore import.

No decrypted or finished IPA and no Apple credentials are uploaded to GitHub.

## One-time Mac setup

1. Ensure `gh auth status` succeeds for the `Noel-0` account.
2. Run `scripts/install-macos-automation.sh` from this checkout.
3. Put the explicitly selected decrypted, already-tweaked IPA at:
   `iCloud Drive/YouMod Builder/Input/base.ipa`.
4. Trigger **Build custom YouMod release** manually once with `publish` enabled.
5. Import the resulting IPA from `Ready` into SideStore without deleting the
   installed app. Always use the same sideloading Apple account and bundle ID.

Run the assembler immediately with:

```sh
"$HOME/Library/Application Support/YouMod Builder/bin/assemble-private-ipa.sh"
```

## SideStore checklist

- Use a separate Apple account dedicated to sideloading.
- Use an official anisette-v3 server.
- Keep SideStore's VPN and iOS Background App Refresh enabled.
- Treat AltStore and Sideloadly as recovery tools; do not let them refresh this
  installation concurrently.
- Open SideStore periodically to confirm the seven-day expiration advanced.

## Rollback and upstream merge

Previous candidates are moved to `Archive` before replacement. Re-import the
last known-good IPA with the same Apple account and bundle ID to roll back.

When the regression check passes on clean upstream, the workflow automatically
stops cherry-picking the patch. After a normal driftywinds build containing the
fix is tested successfully, disable this workflow and return to their source.
