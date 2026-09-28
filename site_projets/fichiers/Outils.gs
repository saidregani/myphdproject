// Propositions des groupes et fonctions utilitaires

// Appelé par la page : un groupe propose son propre projet
function proposerProjet(titre, description, membres, email) {
  titre       = String(titre || '').trim();
  description = String(description || '').trim();
  membres     = String(membres || '').trim();
  email       = String(email || '').trim();

  if (titre.length < 5) throw new Error('Indiquez le titre du projet proposé.');
  if (membres.length < 3) throw new Error('Indiquez le nom et le prénom des membres du groupe.');
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new Error("L'adresse e-mail du responsable n'est pas valide.");

  const projet = 'Proposition : ' + titre;
  const lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    feuille_().appendRow([new Date(), texte_(projet), texte_(membres), texte_(email), texte_(description)]);
    SpreadsheetApp.flush();
  } finally {
    lock.releaseLock();
  }

  if (NOTIFIER) {
    try {
      const corps = 'Projet proposé : ' + titre + (description ? '\nDescription : ' + description : '') +
        '\nMembres du groupe :\n' + membres + '\nResponsable : ' + email;
      MailApp.sendEmail(Session.getEffectiveUser().getEmail(), 'Nouvelle proposition : ' + titre, corps);
      MailApp.sendEmail(email, 'Proposition de projet reçue',
        'Votre proposition a bien été enregistrée. Elle sera étudiée par l\'enseignant.\n\n' + corps);
    } catch (err) {
      console.warn('E-mail non envoyé : ' + err.message);
    }
  }
  return getProjets();
}

// Onglet des choix (créé au besoin avec sa ligne d'en-tête)
function feuille_() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sh = ss.getSheetByName(FEUILLE);
  if (!sh) {
    sh = ss.insertSheet(FEUILLE);
    sh.appendRow(['Date', 'Projet', 'Membres du groupe', 'E-mail du responsable']);
    sh.setFrozenRows(1);
  }
  if (sh.getRange(1, 5).getValue() === '') sh.getRange(1, 5).setValue('Description (projet proposé)');
  return sh;
}

function projetsPris_() {
  const sh = feuille_();
  const n = sh.getLastRow();
  if (n < 2) return [];
  return sh.getRange(2, 2, n - 1, 1).getValues().map(r => String(r[0]));
}

// Empêche qu'un texte commençant par = + - @ soit lu comme une formule
function texte_(s) {
  return /^[=+\-@]/.test(s) ? "'" + s : s;
}
