/**
 * Choix des projets (Google Forms + Apps Script)
 * - retire de la liste chaque projet déjà choisi ;
 * - prévient par e-mail un groupe qui a choisi un projet pris juste avant lui ;
 * - ferme le formulaire quand tous les projets sont choisis.
 */

// Titres EXACTS des questions du formulaire
const QUESTION_PROJET = 'Projet choisi';
const QUESTION_EMAIL  = 'E-mail du responsable du groupe';

// Liste complète des projets (un par ligne)
const PROJETS = [
  'Projet 01 - Lampe automatique',
  'Projet 02 - ...',
  'Projet 03 - ...',
  // ... jusqu'au projet 30
];

// À exécuter une fois à la main (et après chaque modification de PROJETS)
function initialiser() {
  majListe_();
}

// Déclencheur « Lors de l'envoi du formulaire »
function surEnvoi(e) {
  const lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    const form = FormApp.getActiveForm();
    const projet = reponse_(e.response, QUESTION_PROJET);
    const t = e.response.getTimestamp().getTime();
    const dejaPris = form.getResponses().some(r =>
      r.getTimestamp().getTime() < t && reponse_(r, QUESTION_PROJET) === projet);
    if (dejaPris) {
      const email = reponse_(e.response, QUESTION_EMAIL);
      if (email) {
        MailApp.sendEmail(email, 'Projet déjà choisi',
          'Le projet « ' + projet + ' » a été choisi par un autre groupe juste avant vous.\n' +
          'Merci de remplir à nouveau le formulaire en choisissant un autre projet.');
      }
    }
    majListe_();
  } finally {
    lock.releaseLock();
  }
}

// Met la liste à jour avec les projets encore libres
function majListe_() {
  const form = FormApp.getActiveForm();
  const item = form.getItems().find(i => i.getTitle() === QUESTION_PROJET);
  if (!item) throw new Error('Question introuvable : ' + QUESTION_PROJET);

  const pris = new Set(form.getResponses().map(r => reponse_(r, QUESTION_PROJET)));
  const libres = PROJETS.filter(p => !pris.has(p));

  if (libres.length === 0) {
    form.setAcceptingResponses(false);
    form.setCustomClosedFormMessage('Tous les projets ont déjà été choisis.');
    return;
  }
  form.setAcceptingResponses(true);
  const liste = item.getType() === FormApp.ItemType.LIST
    ? item.asListItem() : item.asMultipleChoiceItem();
  liste.setChoiceValues(libres);
}

// Réponse d'une question donnée dans une réponse du formulaire
function reponse_(formResponse, titre) {
  const ir = formResponse.getItemResponses().find(x => x.getItem().getTitle() === titre);
  return ir ? ir.getResponse() : null;
}
