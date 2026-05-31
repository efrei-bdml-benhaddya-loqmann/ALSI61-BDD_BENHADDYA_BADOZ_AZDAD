"""Helpers partagés entre les routes.

Regroupe ce qui est réutilisé par plusieurs vues : utilisateur courant
(sélecteur navbar, sans authentification), parsing du formulaire de congé,
calcul du nombre de jours, et la palette de couleurs des statuts.
"""
from flask import g, session

import db

COULEURS_STATUT = {
    "BUR": "#198754", "TT": "#0d6efd", "RTT": "#ffc107",
    "CP": "#fd7e14", "MAL": "#dc3545", "FOR": "#6f42c1",
}


def current_user_id():
    """Id de l'employé courant (mémorisé en session, 1er employé par défaut)."""
    if "current_user_id" not in g:
        uid = session.get("current_user_id")
        if uid is None:
            premier = db.query("SELECT id_employe FROM Employe ORDER BY id_employe LIMIT 1", one=True)
            uid = premier["id_employe"] if premier else None
            session["current_user_id"] = uid
        g.current_user_id = uid
    return g.current_user_id


def types_conge():
    """Types de statut sélectionnables pour une demande (on exclut Bureau/Télétravail)."""
    return db.query(
        "SELECT id_statut, libelle, code FROM StatutJour WHERE code IN ('CP','RTT','MAL','FOR') ORDER BY libelle"
    )


def parse_conge_form(form):
    """Extrait dates + demi-journées selon le mode choisi dans le formulaire."""
    if form.get("mode") == "half":
        d = form["date_half"]
        dj = form["demi_journee"]
        return d, d, dj, dj
    return form["date_debut"], form["date_fin"], "journee", "journee"


def nb_jours(demande):
    """Nombre de jours d'une demande (0.5 pour une demi-journée)."""
    if demande["demi_journee_debut"] in ("matin", "apres-midi"):
        return 0.5
    return (demande["date_fin"] - demande["date_debut"]).days + 1
