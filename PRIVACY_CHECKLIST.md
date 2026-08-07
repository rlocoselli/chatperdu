# Checklist avant production

- Remplacer les champs entre crochets des pages légales.
- Désigner le responsable de traitement et le contact vie privée.
- Tenir le registre et réaliser une AIPD si l'analyse de risque le requiert.
- Signer les accords de sous-traitance et documenter les transferts hors EEE.
- Configurer HTTPS, secrets robustes, sauvegardes chiffrées et supervision.
- Supprimer les métadonnées EXIF et ajouter antivirus/modération des uploads.
- Programmer quotidiennement `POST /api/admin/purge` avec `X-Purge-Key`.
- Configurer UMP dans AdMob et garder les identifiants de test jusqu'à validation.
- Remplir Data Safety et App Privacy sur les stores.
- Tester export, suppression, retrait du consentement et gestion des violations.
- Faire valider documents et durées par un juriste ou DPO avant lancement.
