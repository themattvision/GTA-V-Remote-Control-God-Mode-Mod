fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios localize_beta

```sh
[bundle exec] fastlane ios localize_beta
```

Aggiorna le informazioni TestFlight in italiano e inglese senza distribuire build / Updates Italian and English TestFlight information without distributing builds

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Archivia GTARemote Release e carica l'IPA su TestFlight / Archives GTARemote Release and uploads the IPA to TestFlight

### ios public_beta

```sh
[bundle exec] fastlane ios public_beta
```

Distribuisce il build gia caricato al gruppo esterno Beta pubblica / Distributes the uploaded build to the external Beta pubblica group

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
