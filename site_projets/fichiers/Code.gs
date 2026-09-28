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
  '25 - Distributeur automatique d\'objets avec servomoteur',
  '26 - Ventilateur automatique commandé par la température (DHT11 et relais)',
  '27 - Commande de LED et de relais par smartphone via Bluetooth (HC-05)',
  '28 - Réglage de la vitesse d\'un moteur à courant continu par potentiomètre (PWM)',
  '29 - Suiveur de lumière avec deux LDR et un servomoteur',
  '30 - Détecteur de flamme avec alarme sonore',
];
