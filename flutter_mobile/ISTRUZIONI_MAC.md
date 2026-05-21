# Istruzioni Finali per il Rilascio iOS (Mac)

Questo file contiene i passaggi finali che **devono** essere eseguiti da un Mac prima di sottoporre l'app alla revisione Apple per TestFlight, per evitare che venga rifiutata.

## 1. Risolvere il crash del Google Sign-In su iOS
Attualmente l'app passa solo il `GOOGLE_WEB_CLIENT_ID` da `.env`. Su iOS questo non basta e l'app crasherà al momento del login. Per risolvere:
1. Vai su Firebase / Google Cloud Console.
2. Scarica il file `GoogleService-Info.plist` relativo all'app iOS.
3. Posizionalo fisicamente nella cartella `ios/Runner` tramite Xcode (importante assicurarsi che sia collegato al target "Runner").
4. Copia il `REVERSED_CLIENT_ID` contenuto in quel file.
5. Apri `ios/Runner/Info.plist` e aggiungi il blocco URL Types:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>INCOLLA_QUI_IL_REVERSED_CLIENT_ID</string>
    </array>
  </dict>
</array>
```

## 2. Rimuovere i permessi non autorizzati (Podfile)
Dato che nel progetto è installato il pacchetto `permission_handler`, Apple rileverà moltissimi permessi (es. Bluetooth, Posizione, Contatti) che in realtà l'app non usa. Questo causa un rifiuto automatico.
Per evitarlo, devi dire al compilatore di scartare i permessi che non servono.

1. Sul Mac, esegui `flutter build ios` (o `pod install` nella cartella `ios`) per generare il `Podfile`.
2. Apri il file `ios/Podfile`.
3. Vai in fondo al file nel blocco `post_install` e modificalo affinché risulti così, mantenendo abilitati solo i permessi per cui abbiamo fornito le descrizioni:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    
    target.build_configurations.each do |config|
      # Rimuove permessi inutilizzati da permission_handler
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_CAMERA=1',
        'PERMISSION_PHOTOS=1',
        'PERMISSION_MICROPHONE=1',
      ]
    end
  end
end
```
