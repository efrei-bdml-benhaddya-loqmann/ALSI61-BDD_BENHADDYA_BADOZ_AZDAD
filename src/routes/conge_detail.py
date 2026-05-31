"""Route 3 — Détail d'une demande."""
import db
from flask import flash, redirect, render_template, url_for

from helpers import current_user_id, nb_jours


def conge_detail(id_demande):
    demande = db.query(
        """
        SELECT dc.*, sj.libelle AS type_conge, sj.code,
               CONCAT_WS(' ', e.prenom, e.nom) AS demandeur, e.id_manager,
               CONCAT_WS(' ', v.prenom, v.nom) AS valideur
        FROM DemandeConge dc
        JOIN Employe e    ON e.id_employe = dc.id_employe
        JOIN StatutJour sj ON sj.id_statut = dc.id_statut
        LEFT JOIN Employe v ON v.id_employe = dc.id_manager_valideur
        WHERE dc.id_demande = %s
        """,
        (id_demande,),
        one=True,
    )
    if not demande:
        flash("Demande introuvable.", "warning")
        return redirect(url_for("mes_conges"))

    peut_valider = demande["id_manager"] == current_user_id()
    return render_template(
        "conge_detail.html", demande=demande, nb_jours=nb_jours(demande), peut_valider=peut_valider
    )
