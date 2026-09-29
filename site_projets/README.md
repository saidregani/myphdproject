# Site de choix des projets Arduino

Application Web Google Apps Script liée à un Google Sheet.

- `Code.gs` : serveur (liste des projets, enregistrement des choix, e-mails).
- `Index.html` : page affichée aux étudiants.
- Images : dossier Google Drive `Images_Projets` (01.jpg, 02.jpg, ...),
  voir `../formulaire/Images_Projets.zip`.

Mise en place : Google Sheet → Extensions → Apps Script → coller `Code.gs`,
ajouter un fichier HTML nommé `Index` → exécuter `preparerImages` →
Déployer → Nouveau déploiement → Application Web
(Exécuter en tant que : Moi ; Accès : Tout le monde).

Les choix sont enregistrés dans l'onglet « Choix » du Google Sheet.
Pour libérer un projet, supprimer sa ligne.
