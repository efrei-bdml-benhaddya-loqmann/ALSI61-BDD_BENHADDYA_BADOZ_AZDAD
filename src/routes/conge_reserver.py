"""Route 2 — Réserver un congé (INSERT DemandeConge)."""
import db
from flask import current_app, flash, redirect, render_template, request, url_for

from helpers import current_user_id, parse_conge_form, types_conge


def conge_reserver():
    uid = current_user_id()
    if request.method == "POST":
        try:
            date_debut, date_fin, dj_debut, dj_fin = parse_conge_form(request.form)
            db.execute(
                """
                INSERT INTO DemandeConge
                    (date_debut, date_fin, demi_journee_debut, demi_journee_fin,
                     statut_demande, motif, id_employe, id_statut)
                VALUES (%s, %s, %s, %s, 'en_attente', %s, %s, %s)
                """,
                (
                    date_debut, date_fin, dj_debut, dj_fin,
                    request.form.get("motif") or None,
                    uid,
                    request.form["id_statut"],
                ),
            )
            flash("Demande de congé envoyée (en attente de validation).", "success")
            return redirect(url_for("mes_conges"))
        except Exception as exc:
            current_app.logger.error(exc)
            flash("Une erreur est survenue. Veuillez réessayer.", "danger")

    return render_template("conge_form.html", demande=None, types=types_conge())
