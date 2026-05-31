"""Route 1 — Accueil : mes demandes (filtre statut + recherche) + soldes + à valider."""
import db
from flask import render_template, request

from helpers import current_user_id


def mes_conges():
    uid = current_user_id()
    statut = request.args.get("statut", "")
    q = request.args.get("q", "").strip()

    sql = """
        SELECT dc.id_demande, dc.date_debut, dc.date_fin, dc.statut_demande,
               dc.date_soumission, dc.motif, sj.libelle AS type_conge, sj.code
        FROM DemandeConge dc
        JOIN StatutJour sj ON sj.id_statut = dc.id_statut
        WHERE dc.id_employe = %s
    """
    params = [uid]
    if statut in ("en_attente", "validee", "refusee"):
        sql += " AND dc.statut_demande = %s"
        params.append(statut)
    if q:
        # Recherche par mot-clé : motif de la demande, libellé ou code du type de congé
        sql += " AND (dc.motif LIKE %s OR sj.libelle LIKE %s OR sj.code LIKE %s)"
        like = f"%{q}%"
        params.extend([like, like, like])
    sql += " ORDER BY dc.date_soumission DESC"
    demandes = db.query(sql, params)

    soldes = db.query(
        """
        SELECT sj.libelle AS type_conge, sc.annee,
               sc.jours_acquis, sc.jours_pris,
               (sc.jours_acquis - sc.jours_pris) AS restant
        FROM SoldeConge sc
        JOIN StatutJour sj ON sj.id_statut = sc.id_statut
        WHERE sc.id_employe = %s
        ORDER BY sc.annee DESC, sj.libelle
        """,
        (uid,),
    )

    # Demandes des subordonnés en attente (validation manager, inline)
    a_valider = db.query(
        """
        SELECT dc.id_demande, dc.date_debut, dc.date_fin, dc.motif,
               sj.libelle AS type_conge,
               CONCAT_WS(' ', e.prenom, e.nom) AS demandeur
        FROM DemandeConge dc
        JOIN Employe e    ON e.id_employe = dc.id_employe
        JOIN StatutJour sj ON sj.id_statut = dc.id_statut
        WHERE e.id_manager = %s AND dc.statut_demande = 'en_attente'
        ORDER BY dc.date_debut
        """,
        (uid,),
    )

    return render_template(
        "mes_conges.html", demandes=demandes, soldes=soldes,
        a_valider=a_valider, statut=statut, q=q,
    )
