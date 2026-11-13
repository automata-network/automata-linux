# Automata Linux v0.3.8 image bundle

This release contains five provider archives and their signed measurement packs.
Use Atakit CLI 0.7.8 and independently trust the publisher key before verification.
The expected boot values are offline-derived, as recorded in provenance.json.

Run scripts/verify-release.py against all 23 files with the independently trusted
--publisher-key value. Use --scratch-dir inside your private scratch directory.
