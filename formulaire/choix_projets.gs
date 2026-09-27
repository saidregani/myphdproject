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
  '01 - Système de détection et d\'alerte du niveau d\'eau',
  '02 - Ouverture d\'une serrure électrique par carte RFID',
  '03 - Ouverture d\'une serrure électrique par clavier',
  '04 - Ouverture d\'une serrure électrique par empreinte digitale',
  '05 - Barrière de parking automatique avec capteur à ultrasons',
  '06 - Horloge numérique avec écran LCD et module RTC',
  '07 - Station météo avec capteur DHT11 et affichage LCD',
  '08 - Système automatique de récupération de vêtements basé sur la détection de pluie',
  '09 - Minuteur pour contrôler une lampe avec relais',
  '10 - Détecteur de fuite de gaz avec ventilateur d\'extraction',
  '11 - Système de tri automatique des déchets humides et secs',
  '12 - Tirelire intelligente : compteur de pièces et affichage LCD',
  '13 - Système d\'éclairage automatique à base de capteur LDR',
  '14 - Compteur bidirectionnel de visiteurs avec capteurs IR',
  '15 - Porte automatique avec capteur à ultrasons et servomoteur',
  '16 - Calculatrice de base avec Arduino et clavier matriciel',
  '17 - Jeu de mémoire électronique',
  '18 - Implémentation des portes logiques fondamentales avec Arduino',
  '19 - Contrôleur de feux tricolores avec afficheur 7 segments',
  '20 - Robinet d\'eau automatique à base d\'Arduino Uno',
  '21 - Thermomètre numérique avec capteur LM35 et écran LCD',
  '22 - Radar de recul avec capteur à ultrasons et buzzer',
  '23 - Arrosage automatique des plantes avec capteur d\'humidité du sol',
  '24 - Alarme anti-intrusion avec capteur PIR et buzzer',
  '25 - Dé électronique avec LED et bouton-poussoir',
  '26 - Ventilateur automatique commandé par la température (DHT11 et relais)',
  '27 - Commande de LED et de relais par smartphone via Bluetooth (HC-05)',
  '28 - Réglage de la vitesse d\'un moteur à courant continu par potentiomètre (PWM)',
  '29 - Suiveur de lumière avec deux LDR et un servomoteur',
  '30 - Détecteur de flamme avec alarme sonore',
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
