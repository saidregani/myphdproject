const pptxgen = require('pptxgenjs');

const BLEU = '1B3A6B', BLEU2 = '2C5596', PALE = 'D9E9FB', FOND = 'F3F6FA', GRIS = '5C7190', BLANC = 'FFFFFF', ENCRE = '1C2533';
const TITRE = 'Cambria', TEXTE = 'Calibri';

const pres = new pptxgen();
pres.layout = 'LAYOUT_WIDE'; // 13.333 x 7.5
pres.title = 'Travaux Avant-Projet – Organisation du module';

const ETAPES = [
  ['Analyser le besoin', 'Quel problème ?'],
  ['Écrire le cahier des charges', 'Fonctions + contraintes'],
  ['Découper en blocs', 'Un rôle par bloc'],
  ['Choisir les composants', 'Et le justifier'],
  ['Réaliser et tester', 'Étape par étape'],
];

function titre(s, texte, couleur) {
  s.addText(texte, { isTextBox: true, x: 0.7, y: 0.45, w: 11.9, h: 0.9, fontFace: TITRE, fontSize: 36, bold: true,
    color: couleur || BLEU, margin: 0, valign: 'middle' });
}
function pastille(s, x, y, d, texte, fond, coul) {
  s.addShape(pres.shapes.OVAL, { x, y, w: d, h: d, fill: { color: fond }, line: { color: fond } });
  s.addText(texte, { isTextBox: true, x, y, w: d, h: d, align: 'center', valign: 'middle', fontFace: TEXTE,
    fontSize: Math.round(d * 26), bold: true, color: coul, margin: 0 });
}
function carte(s, x, y, w, h, fond) {
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y, w, h, rectRadius: 0.12, fill: { color: fond || BLANC },
    line: { color: 'D5DEEA', width: 0.75 },
    shadow: { type: 'outer', color: BLEU, opacity: 0.12, blur: 8, offset: 2, angle: 90 } });
}

// ---- 1. Rappel de la séance précédente ----
{
  const s = pres.addSlide(); s.background = { color: FOND };
  titre(s, 'Rappel de la séance précédente');
  s.addText('Nous avons vu les cinq étapes de la conception d\'un projet, dans un ordre à respecter : chaque étape prépare la suivante. Exemple : la lampe automatique.',
    { isTextBox: true, x: 0.7, y: 1.45, w: 11.9, h: 0.8, fontFace: TEXTE, fontSize: 18, color: ENCRE, margin: 0 });
  const w = 2.25, g = 0.16, x0 = 0.7, y0 = 2.85;
  ETAPES.forEach(([t, d], i) => {
    const x = x0 + i * (w + g);
    carte(s, x, y0, w, 3.2);
    pastille(s, x + (w - 0.9) / 2, y0 + 0.35, 0.9, String(i + 1), BLEU, BLANC);
    s.addText(t, { isTextBox: true, x: x + 0.15, y: y0 + 1.45, w: w - 0.3, h: 0.9, align: 'center', valign: 'top',
      fontFace: TITRE, fontSize: 17, bold: true, color: BLEU, margin: 0 });
    s.addText(d, { isTextBox: true, x: x + 0.15, y: y0 + 2.35, w: w - 0.3, h: 1.1, align: 'center', valign: 'top',
      fontFace: TEXTE, fontSize: 14, color: GRIS, margin: 0 });
     if (i < ETAPES.length - 1) s.addShape(pres.shapes.RIGHT_ARROW, { x: x + w + 0.01, y: y0 + 1.7, w: 0.14, h: 0.2,
      fill: { color: BLEU2 }, line: { color: BLEU2 } });
  });
}

// ---- 2. Objectif : préparer le PFE ----
{
  const s = pres.addSlide(); s.background = { color: BLEU };
  s.addText('Pourquoi ce module ?', { isTextBox: true, x: 0.8, y: 1.0, w: 11.7, h: 0.6, fontFace: TEXTE, fontSize: 18,
    bold: true, color: PALE, charSpacing: 2, margin: 0 });
  s.addText('Ce module vous prépare à votre projet de fin d\'études (PFE) du Master 2.', { isTextBox: true, x: 0.8, y: 1.6,
    w: 11.7, h: 1.5, fontFace: TITRE, fontSize: 36, bold: true, color: BLANC, margin: 0 });
  const cases = [['Aujourd\'hui', 'Travaux Avant-Projet', 'Licence 3'], ['Demain', 'Projet de fin d\'études', 'Master 2 – semestre 2']];
  cases.forEach(([a, b, c], i) => {
    const x = i === 0 ? 0.8 : 7.3;
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y: 3.7, w: 5.2, h: 2.4, rectRadius: 0.12, fill: { color: BLANC }, line: { color: BLANC } });
    s.addText(a, { isTextBox: true, x: x + 0.4, y: 3.95, w: 4.4, h: 0.4, fontFace: TEXTE, fontSize: 15, bold: true, color: GRIS, margin: 0 });
    s.addText(b, { isTextBox: true, x: x + 0.4, y: 4.4, w: 4.4, h: 0.9, fontFace: TITRE, fontSize: 26, bold: true, color: BLEU, margin: 0 });
    s.addText(c, { isTextBox: true, x: x + 0.4, y: 5.35, w: 4.4, h: 0.5, fontFace: TEXTE, fontSize: 17, color: ENCRE, margin: 0 });
  });
  s.addShape(pres.shapes.RIGHT_ARROW, { x: 6.2, y: 4.55, w: 0.9, h: 0.7, fill: { color: PALE }, line: { color: PALE } });
}

// ---- 3. Organisation : cours + TP ----
{
  const s = pres.addSlide(); s.background = { color: FOND };
  titre(s, 'Le module comprend deux parties');
  [['Cours', 'Les notions de conception et les logiciels de simulation', 'C'], ['TP', 'Un projet réalisé en groupe', 'TP']].forEach(([t, d, m], i) => {
    const x = 0.7 + i * 6.1;
    carte(s, x, 1.9, 5.85, 4.6);
    pastille(s, x + 0.5, 2.35, 1.3, m, i === 0 ? BLEU : BLEU2, BLANC);
    s.addText(t, { isTextBox: true, x: x + 0.5, y: 3.95, w: 5.0, h: 0.9, fontFace: TITRE, fontSize: 40, bold: true, color: BLEU, margin: 0 });
    s.addText(d, { isTextBox: true, x: x + 0.5, y: 4.9, w: 5.0, h: 1.2, fontFace: TEXTE, fontSize: 20, color: ENCRE, margin: 0 });
  });
}

// ---- 4. Le cours ----
{
  const s = pres.addSlide(); s.background = { color: FOND };
  titre(s, 'Le cours');
  const lignes = [
    ['Examen', 'Un examen écrit avec des questions sur ce que nous étudions en cours.'],
    ['Support', 'Le cours complet vous sera envoyé en PDF.'],
  ];
  lignes.forEach(([t, d], i) => {
    const y = 1.9 + i * 2.3;
    carte(s, 0.7, y, 11.9, 1.95);
    pastille(s, 1.1, y + 0.45, 1.05, String(i + 1), BLEU, BLANC);
    s.addText(t, { isTextBox: true, x: 2.55, y: y + 0.3, w: 9.6, h: 0.6, fontFace: TITRE, fontSize: 26, bold: true, color: BLEU, margin: 0 });
    s.addText(d, { isTextBox: true, x: 2.55, y: y + 0.95, w: 9.6, h: 0.75, fontFace: TEXTE, fontSize: 20, color: ENCRE, margin: 0 });
  });
}

// ---- 5. Le TP : un projet ----
{
  const s = pres.addSlide(); s.background = { color: FOND };
  titre(s, 'Le TP : un projet à réaliser');
  s.addText('Chaque groupe réalise un projet complet, de l\'idée au prototype.', { isTextBox: true, x: 0.7, y: 1.45,
    w: 11.9, h: 0.6, fontFace: TEXTE, fontSize: 20, color: ENCRE, margin: 0 });
  // frise
  const pts = [['Aujourd\'hui', 'Choix du projet'], ['Pendant le semestre', 'Conception et réalisation'], ['Dernière semaine du semestre', 'Remise et présentation']];
  s.addShape(pres.shapes.LINE, { x: 1.6, y: 3.55, w: 10.1, h: 0, line: { color: BLEU, width: 3 } });
  pts.forEach(([a, b], i) => {
    const cx = 1.6 + i * 5.05;
    pastille(s, cx - 0.4, 3.15, 0.8, String(i + 1), i === 2 ? BLEU : BLEU2, BLANC);
    s.addText(a, { isTextBox: true, x: cx - 1.9, y: 4.2, w: 3.8, h: 0.5, align: 'center', fontFace: TEXTE, fontSize: 16, bold: true, color: GRIS, margin: 0 });
    s.addText(b, { isTextBox: true, x: cx - 1.9, y: 4.7, w: 3.8, h: 0.8, align: 'center', fontFace: TITRE, fontSize: 20, bold: true, color: BLEU, margin: 0 });
  });
  carte(s, 0.7, 5.9, 11.9, 0.95, PALE);
  s.addText('Délai : jusqu\'à la dernière semaine du semestre, avant les vacances d\'hiver.', { isTextBox: true, x: 1.0, y: 5.9,
    w: 11.3, h: 0.95, valign: 'middle', fontFace: TEXTE, fontSize: 20, bold: true, color: BLEU, margin: 0 });
}

// ---- 6. Évaluation du TP et projets ----
{
  const s = pres.addSlide(); s.background = { color: FOND };
  titre(s, 'Le TP : évaluation et organisation');
  s.addText('La note du TP est divisée en quatre parties :', { isTextBox: true, x: 0.7, y: 1.4, w: 11.9, h: 0.5,
    fontFace: TEXTE, fontSize: 18, color: ENCRE, margin: 0 });
  ['Présence', 'Rapport', 'Projet', 'Présentation'].forEach((t, i) => {
    const x = 0.7 + i * 3.02;
    carte(s, x, 2.05, 2.8, 1.6);
    pastille(s, x + 0.2, 2.5, 0.7, String(i + 1), BLEU, BLANC);
    s.addText(t, { isTextBox: true, x: x + 1.05, y: 2.05, w: 1.7, h: 1.6, valign: 'middle', fontFace: TITRE, fontSize: 18, bold: true, color: BLEU, margin: 0 });
  });
  [['30', 'projets proposés, entre faciles et moyens'], ['4', 'étudiants au maximum par groupe']].forEach(([n, t], i) => {
    const x = 0.7 + i * 6.1;
    carte(s, x, 4.1, 5.85, 2.6, i === 0 ? BLANC : BLANC);
    s.addText(n, { isTextBox: true, x: x + 0.4, y: 4.3, w: 2.2, h: 2.2, valign: 'middle', fontFace: TITRE, fontSize: 80, bold: true, color: BLEU, margin: 0 });
    s.addText(t, { isTextBox: true, x: x + 2.6, y: 4.3, w: 3.0, h: 2.2, valign: 'middle', fontFace: TEXTE, fontSize: 20, color: ENCRE, margin: 0 });
  });
}

// ---- 7. Absence d'un mois ----
{
  const s = pres.addSlide(); s.background = { color: BLEU };
  s.addText('Organisation du mois prochain', { isTextBox: true, x: 0.8, y: 0.8, w: 11.7, h: 0.9, fontFace: TITRE, fontSize: 36, bold: true, color: BLANC, margin: 0 });
  s.addText('Après cette séance, je serai absent pendant un mois.', { isTextBox: true, x: 0.8, y: 1.75, w: 11.7, h: 0.6,
    fontFace: TEXTE, fontSize: 22, color: PALE, margin: 0 });
  const blocs = [['2', 'cours en ligne'], ['2', 'TP en ligne'], ['Ensuite', 'retour normal des séances']];
  blocs.forEach(([n, t], i) => {
    const x = 0.8 + i * 4.0;
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y: 3.0, w: 3.7, h: 3.2, rectRadius: 0.12, fill: { color: BLANC }, line: { color: BLANC } });
    s.addText(n, { isTextBox: true, x: x + 0.3, y: 3.3, w: 3.1, h: 1.5, align: 'center', valign: 'middle', fontFace: TITRE,
      fontSize: n.length > 2 ? 40 : 80, bold: true, color: BLEU, margin: 0 });
    s.addText(t, { isTextBox: true, x: x + 0.3, y: 4.9, w: 3.1, h: 1.0, align: 'center', valign: 'middle', fontFace: TEXTE,
      fontSize: 22, color: ENCRE, margin: 0 });
  });
}

// ---- 8. Plan du chapitre 1 ----
{
  const s = pres.addSlide(); s.background = { color: FOND };
  titre(s, 'Chapitre 1 : les 5 étapes de la conception');
  ETAPES.forEach(([t, d], i) => {
    const y = 1.6 + i * 1.1;
    carte(s, 0.7, y, 11.9, 0.9);
    pastille(s, 0.95, y + 0.12, 0.66, String(i + 1), BLEU, BLANC);
    s.addText(t, { isTextBox: true, x: 1.95, y, w: 4.3, h: 0.9, valign: 'middle', fontFace: TITRE, fontSize: 21, bold: true, color: BLEU, margin: 0 });
    s.addText(d, { isTextBox: true, x: 6.3, y, w: 6.1, h: 0.9, valign: 'middle', fontFace: TEXTE, fontSize: 17, color: GRIS, margin: 0 });
  });
}

pres.writeFile({ fileName: 'Organisation_Module_L3_ELN.pptx' }).then(f => console.log('écrit', f));
