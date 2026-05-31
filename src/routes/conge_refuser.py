"""Route 7 — Refuser une demande (manager)."""
import db
from flask import current_app, flash, redirect, url_for

from helpers import current_user_id


def conge_refuser(id_demande):
    uid = current_user_id()
    try:
        db.execute(
            """
            UPDATE DemandeConge
            SET statut_demande = 'refusee', id_manager_valideur = %s
            WHERE id_demande = %s
            """,
            (uid, id_demande),
        )
        flash("Demande refusée.", "info")
    except Exception as exc:
        current_app.logger.error(exc)
        flash("Une erreur est survenue. Veuillez réessayer.", "danger")
    return redirect(url_for("conge_detail", id_demande=id_demande))
