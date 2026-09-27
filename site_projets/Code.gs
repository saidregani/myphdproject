/**
 * Site de choix des projets Arduino (Google Apps Script, application Web)
 *
 * - La page (Index.html) affiche les 30 projets avec leur image.
 * - Un projet déjà choisi reste visible mais ne peut plus être sélectionné.
 * - Chaque choix est enregistré dans l'onglet « Choix » du Google Sheet
 *   auquel ce script est lié ; l'enseignant et le responsable du groupe
 *   reçoivent un e-mail de confirmation.
 * - Pour libérer un projet : supprimer sa ligne dans l'onglet « Choix ».
 */

const FEUILLE         = 'Choix';           // onglet où les choix sont enregistrés
const DOSSIER_IMAGES  = 'Images_Projets';  // dossier Google Drive : 01.jpg, 02.jpg, ...
const NOTIFIER        = true;              // e-mails de confirmation

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

// Point d'entrée de l'application Web
function doGet() {
  return HtmlService.createHtmlOutputFromFile('Index')
    .setTitle('Choix des projets Arduino')
    .addMetaTag('viewport', 'width=device-width, initial-scale=1');
}

// À exécuter une fois (et après avoir ajouté des images dans le dossier) :
// rend les images lisibles par le site et mémorise leurs identifiants.
function preparerImages() {
  const dossiers = DriveApp.getFoldersByName(DOSSIER_IMAGES);
  if (!dossiers.hasNext()) throw new Error('Dossier Drive introuvable : ' + DOSSIER_IMAGES);
  const ids = {};
  const it = dossiers.next().getFiles();
  while (it.hasNext()) {
    const f = it.next();
    f.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
    ids[f.getName().split('.')[0]] = f.getId();   // « 01.jpg » -> '01'
  }
  PropertiesService.getScriptProperties().setProperty('IMAGES', JSON.stringify(ids));
  feuille_();
  return Object.keys(ids).length + ' image(s) prête(s).';
}

// Appelé par la page : liste des projets et leur état
function getProjets() {
  const pris = new Set(projetsPris_());
  const ids = JSON.parse(PropertiesService.getScriptProperties().getProperty('IMAGES') || '{}');
  return PROJETS.map(p => {
    const id = ids[p.slice(0, 2)];
    return {
      titre: p,
      pris: pris.has(p),
      image: id ? 'https://drive.google.com/thumbnail?id=' + id + '&sz=w600' : ''
    };
  });
}

// Appelé par la page : enregistre le choix d'un groupe
function choisirProjet(projet, membres, email) {
  projet  = String(projet || '');
  membres = String(membres || '').trim();
  email   = String(email || '').trim();

  if (PROJETS.indexOf(projet) === -1) throw new Error('Projet inconnu. Rechargez la page.');
  if (membres.length < 3) throw new Error('Indiquez le nom et le prénom des membres du groupe.');
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new Error("L'adresse e-mail du responsable n'est pas valide.");

  const lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    if (projetsPris_().indexOf(projet) !== -1) {
      throw new Error('Ce projet vient d’être choisi par un autre groupe. Choisissez-en un autre.');
    }
    feuille_().appendRow([new Date(), projet, texte_(membres), texte_(email)]);
    SpreadsheetApp.flush();
  } finally {
    lock.releaseLock();
  }

  // Le choix est déjà enregistré : un e-mail qui échoue (quota atteint...) ne doit pas l'annuler
  if (NOTIFIER) {
    try {
      const corps = 'Projet : ' + projet + '\nMembres du groupe :\n' + membres + '\nResponsable : ' + email;
      MailApp.sendEmail(Session.getEffectiveUser().getEmail(), 'Nouveau choix : ' + projet, corps);
      MailApp.sendEmail(email, 'Confirmation du choix de projet',
        'Votre choix a bien été enregistré.\n\n' + corps);
    } catch (err) {
      console.warn('E-mail non envoyé : ' + err.message);
    }
  }
  return getProjets();
}

// À exécuter à la main : nombre d'e-mails encore autorisés aujourd'hui
function quotaEmails() {
  const n = MailApp.getRemainingDailyQuota();
  console.log('E-mails restants aujourd\'hui : ' + n);
  return n;
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
