# TestFlight da GitHub Actions

Questo progetto puo' inviare una build iOS a TestFlight direttamente da GitHub.
Il workflow e' nella root del repository, in
`../.github/workflows/testflight.yml`, e usa la lane Fastlane `ios ci_beta`,
che costruisce e carica l'IPA senza modificare `pubspec.yaml`, senza creare
commit e senza creare tag locali.

## Trigger

Il trigger consigliato e' un tag Git nel formato:

```sh
git tag testflight-v1.0.3+4
git push origin testflight-v1.0.3+4
```

Nel tag:

- `1.0.3` diventa `CFBundleShortVersionString`.
- `4` diventa `CFBundleVersion`.
- Il build number deve essere maggiore dei build gia' caricati in App Store
  Connect per la stessa versione marketing.

Il workflow si puo' lanciare anche manualmente da GitHub Actions, inserendo
`version` e `build_number`.

Il job usa il runner `macos-26` e Flutter `3.41.7`, allineato alla toolchain
locale usata per le build iOS del progetto.

## GitHub Secrets richiesti

Configura questi secret nel repository o nell'organizzazione GitHub:

| Secret | Contenuto |
| --- | --- |
| `ASC_KEY_ID` | Key ID della chiave App Store Connect API. |
| `ASC_ISSUER_ID` | Issuer ID della chiave App Store Connect API. |
| `APPSTORE_CONNECT_API_KEY_BASE64` | File `.p8` della chiave ASC codificato base64. |
| `APPLE_CERTIFICATE_P12_BASE64` | Certificato Apple Distribution `.p12` codificato base64. |
| `APPLE_CERTIFICATE_PASSWORD` | Password usata esportando il `.p12`. |
| `APPLE_PROVISIONING_PROFILE_BASE64` | Profilo App Store `.mobileprovision` codificato base64. |
| `APPLE_PROVISIONING_PROFILE_NAME` | Nome del profilo App Store contenuto nel `.mobileprovision`. |
| `SUPABASE_URL` | URL Supabase usato per generare `.env` in CI. |
| `SUPABASE_ANON_KEY` | Anon key Supabase usata per generare `.env` in CI. |
| `GOOGLE_WEB_CLIENT_ID` | Client ID Web Google usato come `serverClientId` per Supabase Auth. |
| `GOOGLE_IOS_CLIENT_ID` | Client ID iOS Google usato da Google Sign-In su iOS. |

Su macOS puoi copiare un file in base64 cosi':

```sh
base64 -i AuthKey_XXXXXXXXXX.p8 | tr -d '\n' | pbcopy
base64 -i apple_distribution.p12 | tr -d '\n' | pbcopy
base64 -i appstore.mobileprovision | tr -d '\n' | pbcopy
```

## App Store Connect

La lane distribuisce il build al gruppo TestFlight esterno `External Testers`.
Quel gruppo deve esistere in App Store Connect. Se usi un altro nome gruppo,
aggiorna `groups: ["External Testers"]` in `ios/fastlane/Fastfile`.

Per TestFlight pubblico, abilita il public link su quel gruppo in App Store
Connect. Il workflow carica il build e lo assegna al gruppo; la configurazione
del link pubblico resta in App Store Connect.

## Prima di taggare

Aggiorna le note in:

```text
ios/fastlane/metadata/en-US/release_notes.txt
```

La lane ha una guardrail che blocca il rilascio se le release notes non sono
state aggiornate dall'ultimo tag.

Verifica anche che `ios/ExportOptions.plist` punti al profilo corretto:

```text
4athletes App Store
```
