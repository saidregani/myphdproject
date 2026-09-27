/**
 * Choix des projets (Google Forms + Apps Script)
 * - les projets déjà choisis restent visibles, marqués « déjà choisi » ;
 * - un groupe qui en choisit un est envoyé vers une section qui le renvoie
 *   au début du formulaire : il ne peut pas l'envoyer ;
 * - un groupe qui a choisi un projet pris juste avant lui est prévenu par e-mail ;
 * - le formulaire se ferme quand tous les projets sont choisis.
 *
 * Structure du formulaire (titres EXACTS) :
 *   Section 1 : question « Projet choisi » (liste déroulante)
 *   Section 2 : « Projet déjà choisi » (message, sans question)
 *   Section 3 : « Informations du groupe » (membres + e-mail du responsable)
 */

const QUESTION_PROJET = 'Projet choisi';
const QUESTION_EMAIL  = 'E-mail du responsable du groupe';
const SECTION_PRIS    = 'Projet déjà choisi';
const SECTION_GROUPE  = 'Informations du groupe';
const MARQUE_PRIS     = '⛔ ';
const SUFFIXE_PRIS    = ' (déjà choisi)';

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

// Met à jour la liste : projets libres -> section groupe ; projets pris -> section « déjà choisi »
function majListe_() {
  const form = FormApp.getActiveForm();
  const item = trouver_(form, QUESTION_PROJET);
  const sectionPris = trouver_(form, SECTION_PRIS).asPageBreakItem();
  const sectionGroupe = trouver_(form, SECTION_GROUPE).asPageBreakItem();

  // la section « déjà choisi » renvoie toujours au début du formulaire
  sectionPris.setGoToPage(FormApp.PageNavigationType.RESTART);

  const pris = new Set(form.getResponses().map(r => reponse_(r, QUESTION_PROJET)));
  const liste = item.getType() === FormApp.ItemType.LIST
    ? item.asListItem() : item.asMultipleChoiceItem();

  liste.setChoices(PROJETS.map(p => pris.has(p)
    ? liste.createChoice(MARQUE_PRIS + p + SUFFIXE_PRIS, sectionPris)
    : liste.createChoice(p, sectionGroupe)));

  if (PROJETS.every(p => pris.has(p))) {
    form.setAcceptingResponses(false);
    form.setCustomClosedFormMessage('Tous les projets ont déjà été choisis.');
  } else {
    form.setAcceptingResponses(true);
  }
}

function trouver_(form, titre) {
  const item = form.getItems().find(i => i.getTitle() === titre);
  if (!item) throw new Error('Élément introuvable dans le formulaire : ' + titre);
  return item;
}

// Réponse d'une question donnée dans une réponse du formulaire
function reponse_(formResponse, titre) {
  const ir = formResponse.getItemResponses().find(x => x.getItem().getTitle() === titre);
  return ir ? ir.getResponse() : null;
}
