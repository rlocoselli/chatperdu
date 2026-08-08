# Application Flutter Chat Perdu

Les identifiants AdMob fournis sont exclusivement les identifiants de test officiels. Créez les applications et blocs réels dans AdMob, configurez un message RGPD dans « Confidentialité et messages », puis compilez avec `--dart-define`.

```bash
flutter pub get
flutter run \
	--dart-define=API_URL=https://audeladedonnees.fr/api \
	--dart-define=AUTH_URL=https://audeladedonnees.fr
```

Google OAuth via Audela (ouverture dans le navigateur) utilise :

```bash
flutter run \
	--dart-define=API_URL=https://audeladedonnees.fr/api \
	--dart-define=AUTH_URL=https://audeladedonnees.fr \
	--dart-define=AUDELA_GOOGLE_APP=tenant \
	--dart-define=AUDELA_TENANT_SLUG=<slug-optionnel>
```

Pour Android natif, vous pouvez injecter l'identifiant AdMob applicatif sans le hardcoder dans le dépôt :

```bash
export ORG_GRADLE_PROJECT_ADMOB_APPLICATION_ID=ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy
flutter build apk --dart-define=API_URL=https://api.example.com/api
```

L'application peut téléverser une image vers `/api/uploads`, puis créer le signalement correspondant en base via `/api/reports`.

L'interstitiel est limité à une transition naturelle, après publication d'une alerte. Les publicités ne sont chargées qu'après la vérification UMP du consentement.
