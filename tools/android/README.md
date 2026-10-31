# Stable development APK signature

The committed keystore is a PUBLIC TEST KEY for development APKs only, using
the standard Android debug alias/password. It is deliberately non-secret and
is not a store/release signing identity. Pinning it makes successive development
builds install as updates instead of generating a different key on each runner.
The old 1.31/1.32 builds used unrelated ephemeral keys; the first installation
of 1.33 requires removing that old test APK. Preserve this file for later debug
updates. Never use this public key for a production store release.
