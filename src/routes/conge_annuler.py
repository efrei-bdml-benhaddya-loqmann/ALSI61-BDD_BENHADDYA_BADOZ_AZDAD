"""Route 5 — Annuler (DELETE) une demande, par son auteur."""
import db
from flask import abort, current_app, flash, redirect, url_for

from helpers import current_user_id


def conge_annuler(id_demande):
    demande = db.query("SELECT * FROM DemandeConge WHERE id_demande = %s", (id_demande,), one=True)
    if not demande:
        flash("Demande introuvable.", "warning")
        return redirect(url_for("mes_conges"))
    if demande["id_employe"] != current_user_id():
        abort(403)
    try:
        db.execute("DELETE FROM DemandeConge WHERE id_demande = %s", (id_demande,))
        flash("Demande annulée.", "success")
    except Exception as exc:
        current_app.logger.error(exc)
        flash("Une erreur est survenue. Veuillez réessayer.", "danger")
    return redirect(url_for("mes_conges"))
