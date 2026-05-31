"""Route 6 — Valider une demande (manager). Le trigger trg_valider_demande décompte le solde."""
import db
from flask import current_app, flash, redirect, url_for

from helpers import current_user_id, nb_jours


def conge_valider(id_demande):
    uid = current_user_id()
    demande = db.query(
        """
        SELECT dc.*, sj.code
        FROM DemandeConge dc
        JOIN StatutJour sj ON sj.id_statut = dc.id_statut
        WHERE dc.id_demande = %s
        """,
        (id_demande,),
        one=True,
    )
    if not demande:
        flash("Demande introuvable.", "warning")
        return redirect(url_for("mes_conges"))

    n = nb_jours(demande)
    try:
        # Le trigger trg_valider_demande met à jour SoldeConge automatiquement.
        # La contrainte CHECK ck_solde_positif rejette un dépassement de solde.
        db.execute(
            """
            UPDATE DemandeConge
            SET statut_demande = 'validee', id_manager_valideur = %s
            WHERE id_demande = %s
            """,
            (uid, id_demande),
        )
        flash(f"Demande validée ({n} jour(s)).", "success")
    except Exception as exc:
        current_app.logger.error(exc)
        flash("Solde insuffisant ou contrainte violée — validation refusée.", "danger")
    return redirect(url_for("conge_detail", id_demande=id_demande))
