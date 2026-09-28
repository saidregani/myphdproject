// Choix et propositions des groupes, enregistrés dans le Google Sheet

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
