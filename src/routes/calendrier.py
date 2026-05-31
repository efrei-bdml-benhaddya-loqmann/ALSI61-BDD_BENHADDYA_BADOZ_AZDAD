"""Route 8a — Grille calendrier de l'équipe (semaine, pagination des employés)."""
from datetime import date, timedelta

import db
from flask import render_template, request

from helpers import COULEURS_STATUT

PAGE_SIZE = 5


def calendrier():
    try:
        offset = int(request.args.get("s", 0))
    except ValueError:
        offset = 0
    try:
        page = max(0, int(request.args.get("p", 0)))
    except ValueError:
        page = 0

    today = date.today()
    lundi = today - timedelta(days=today.weekday()) + timedelta(weeks=offset)
    jours = [lundi + timedelta(days=i) for i in range(5)]
    debut, fin = jours[0], jours[-1]

    total_employes = db.query("SELECT COUNT(*) AS n FROM Employe", one=True)["n"]

    employes = db.query(
        """
        SELECT e.id_employe, e.nom, e.prenom, s.libelle AS service
        FROM Employe e JOIN Service s ON s.id_service = e.id_service
        ORDER BY e.nom, e.prenom
        LIMIT %s OFFSET %s
        """,
        (PAGE_SIZE, page * PAGE_SIZE),
    )
    ids = [e["id_employe"] for e in employes]
    if ids:
        placeholders = ",".join(["%s"] * len(ids))
        entrees = db.query(
            f"""
            SELECT ep.id_employe, ep.date, ep.demi_journee, sj.code, sj.libelle
            FROM EntreePlanning ep
            JOIN StatutJour sj ON sj.id_statut = ep.id_statut
            WHERE ep.date BETWEEN %s AND %s
              AND ep.id_employe IN ({placeholders})
            """,
            (debut, fin, *ids),
        )
    else:
        entrees = []

    planning = {}
    for ent in entrees:
        planning.setdefault(ent["id_employe"], {}).setdefault(ent["date"].isoformat(), []).append(ent)

    nb_pages = max(1, -(-total_employes // PAGE_SIZE))

    return render_template(
        "calendrier.html", employes=employes, jours=jours, planning=planning,
        couleurs=COULEURS_STATUT, offset=offset, debut=debut, fin=fin,
        page=page, nb_pages=nb_pages,
    )
