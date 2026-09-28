const pptxgen = require('pptxgenjs');
const projets = require('./projets.json');

const BLEU = '1B3A6B', BLEU_PALE = 'D9E9FB', FOND = 'F3F6FA', GRIS = '5C7190', BLANC = 'FFFFFF';
const TITRE = 'Cambria', TEXTE = 'Calibri';

const pres = new pptxgen();
pres.layout = 'LAYOUT_WIDE'; // 13.333 x 7.5
pres.title = 'Projets Arduino – L3 ELN';

// ---- Couverture ----
{
  const s = pres.addSlide();
  s.background = { color: BLEU };
  s.addText('TRAVAUX AVANT-PROJET · L3 ELN · 2026/2027', { isTextBox: true, x: 0.7, y: 1.6, w: 6.2, h: 0.4,
    fontFace: TEXTE, fontSize: 14, bold: true, color: BLEU_PALE, charSpacing: 2, margin: 0 });
  s.addText('Projets Arduino', { isTextBox: true, x: 0.7, y: 2.1, w: 6.2, h: 1.3,
    fontFace: TITRE, fontSize: 54, bold: true, color: BLANC, margin: 0 });
  s.addText('30 projets au choix pour les groupes', { isTextBox: true, x: 0.7, y: 3.45, w: 6.2, h: 0.6,
    fontFace: TEXTE, fontSize: 22, color: BLEU_PALE, margin: 0 });
  s.addText('Chaque groupe choisit un seul projet, ou propose le sien.', { isTextBox: true, x: 0.7, y: 4.3, w: 6.0, h: 0.8,
    fontFace: TEXTE, fontSize: 16, color: BLANC, margin: 0 });
  // mosaïque de 6 projets
  const choix = [4, 6, 12, 14, 21, 28];
  const cw = 2.55, ch = 1.6, gx = 0.2, gy = 0.2, x0 = 7.3, y0 = 1.35;
  choix.forEach((k, i) => {
    const p = projets[k];
    const x = x0 + (i % 2) * (cw + gx), y = y0 + Math.floor(i / 2) * (ch + gy);
    s.addShape(pres.shapes.RECTANGLE, { x: x - 0.04, y: y - 0.04, w: cw + 0.08, h: ch + 0.08, fill: { color: BLANC }, line: { color: BLANC } });
    s.addImage({ path: p.img, x, y, w: cw, h: ch, sizing: { type: 'cover', w: cw, h: ch } });
  });
}

// ---- Une diapositive par projet ----
projets.forEach(p => {
  const s = pres.addSlide();
  s.background = { color: FOND };

  s.addShape(pres.shapes.OVAL, { x: 0.55, y: 0.42, w: 0.85, h: 0.85, fill: { color: BLEU }, line: { color: BLEU } });
  s.addText(p.n, { isTextBox: true, x: 0.55, y: 0.42, w: 0.85, h: 0.85, align: 'center', valign: 'middle',
    fontFace: TEXTE, fontSize: 22, bold: true, color: BLANC, margin: 0 });
  s.addText(p.titre, { isTextBox: true, x: 1.65, y: 0.3, w: 11.1, h: 1.1, valign: 'middle',
    fontFace: TITRE, fontSize: 28, bold: true, color: BLEU, margin: 0 });

  // image entière, centrée dans la zone disponible
  const zx = 0.55, zy = 1.65, zw = 12.23, zh = 5.35;
  const r = Math.min(zw / p.w, zh / p.h);
  const w = p.w * r, h = p.h * r, x = zx + (zw - w) / 2, y = zy + (zh - h) / 2;
  s.addShape(pres.shapes.RECTANGLE, { x: x - 0.08, y: y - 0.08, w: w + 0.16, h: h + 0.16,
    fill: { color: BLANC }, line: { color: 'D5DEEA', width: 0.75 },
    shadow: { type: 'outer', color: '1B3A6B', opacity: 0.18, blur: 8, offset: 3, angle: 90 } });
  s.addImage({ path: p.img, x, y, w, h });

  s.addText(p.n + ' / 30', { isTextBox: true, x: 11.5, y: 7.08, w: 1.28, h: 0.3, align: 'right',
    fontFace: TEXTE, fontSize: 11, color: GRIS, margin: 0 });
});

pres.writeFile({ fileName: 'Projets_Arduino_L3_ELN.pptx' }).then(f => console.log('écrit', f));
