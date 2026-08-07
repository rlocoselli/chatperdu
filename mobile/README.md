# Application Flutter Chat Perdu

Les identifiants AdMob fournis sont exclusivement les identifiants de test officiels. Créez les applications et blocs réels dans AdMob, configurez un message RGPD dans « Confidentialité et messages », puis compilez avec `--dart-define`.

```bash
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:5000/api
```

Pour Android natif, vous pouvez injecter l'identifiant AdMob applicatif sans le hardcoder dans le dépôt :

```bash
export ORG_GRADLE_PROJECT_ADMOB_APPLICATION_ID=ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy
flutter build apk --dart-define=API_URL=https://api.example.com/api
```

L'application peut téléverser une image vers `/api/uploads`, puis créer le signalement correspondant en base via `/api/reports`.

L'interstitiel est limité à une transition naturelle, après publication d'une alerte. Les publicités ne sont chargées qu'après la vérification UMP du consentement.
