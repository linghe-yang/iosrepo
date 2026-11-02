Retired packages — excluded from the active APT indexes.

ShadeBar 0.1.0~beta1:
A device crash report identified ShadeManager initialization -> FBSOrientationObserver
setHandler: -> objc_msgSend. Do not use this version as a rollback.

ShadeBar 0.2.0~beta1:
The user could install and open the desktop app, but the overlay did not appear,
even with the application allowlist disabled. Kept for debugging and comparison.

The current candidate is 0.3.0~beta1 in debs/. It changes window scene association,
hosting, shared settings, rotation and drag-only controls, and adds display diagnostics.
Local checks passed; physical-device behavior has not yet been verified.
