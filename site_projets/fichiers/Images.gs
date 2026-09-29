// Page Web et images des projets (voir Code.gs pour les réglages)

// Point d'entrée de l'application Web
function doGet() {
  return HtmlService.createHtmlOutputFromFile('Index')
    .setTitle('Choix des projets Arduino')
    .addMetaTag('viewport', 'width=device-width, initial-scale=1');
}

// À exécuter une fois, puis après chaque changement d'images dans le dossier :
// rend les images lisibles par le site et mémorise leurs identifiants.
// Les fichiers dans la corbeille sont ignorés ; si un numéro a plusieurs
// fichiers (« 21.jpg », « 21 (1).jpg »...), le plus récent est gardé.
function preparerImages() {
  const dossiers = DriveApp.getFoldersByName(DOSSIER_IMAGES);
  const ids = {}, dates = {};
  let trouve = false;
  while (dossiers.hasNext()) {
    const dossier = dossiers.next();
    if (dossier.isTrashed()) continue;
    trouve = true;
    const it = dossier.getFiles();
    while (it.hasNext()) {
      const f = it.next();
      if (f.isTrashed()) continue;
      const m = f.getName().match(/^(\d{2})/);   // « 21.jpg » -> '21'
      if (!m) continue;
      const d = f.getDateCreated().getTime();
      if (dates[m[1]] && dates[m[1]] > d) continue;
      f.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
      ids[m[1]] = f.getId();
      dates[m[1]] = d;
    }
  }
  if (!trouve) throw new Error('Dossier Drive introuvable : ' + DOSSIER_IMAGES);
  PropertiesService.getScriptProperties().setProperty('IMAGES', JSON.stringify(ids));
  feuille_();
  const manquants = PROJETS.map(p => p.slice(0, 2)).filter(n => !ids[n]);
  console.log(Object.keys(ids).length + ' image(s) prête(s).' +
    (manquants.length ? ' Sans image : ' + manquants.join(', ') : ' Toutes les images sont présentes.'));
}
