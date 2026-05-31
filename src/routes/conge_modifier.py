"""Route 4 — Modifier une demande (uniquement si en attente, par son auteur)."""
import db
from flask import abort, current_app, flash, redirect, render_template, request, url_for

from helpers import current_user_id, parse_conge_form, types_conge


def conge_modifier(id_demande):
    demande = db.query("SELECT * FROM DemandeConge WHERE id_demande = %s", (id_demande,), one=True)
    if not demande:
        flash("Demande introuvable.", "warning")
        return redirect(url_for("mes_conges"))
    if demande["id_employe"] != current_user_id():
        abort(403)
    if demande["statut_demande"] != "en_attente":
        flash("Seules les demandes en attente peuvent être modifiées.", "warning")
        return redirect(url_for("conge_detail", id_demande=id_demande))

    if request.method == "POST":
        try:
            date_debut, date_fin, dj_debut, dj_fin = parse_conge_form(request.form)
            db.execute(
                """
                UPDATE DemandeConge
                SET date_debut = %s, date_fin = %s,
                    demi_journee_debut = %s, demi_journee_fin = %s,
                    motif = %s, id_statut = %s
                WHERE id_demande = %s
                """,
                (
                    date_debut, date_fin, dj_debut, dj_fin,
                    request.form.get("motif") or None,
                    request.form["id_statut"],
                    id_demande,
                ),
            )
            flash("Demande modifiée.", "success")
            return redirect(url_for("conge_detail", id_demande=id_demande))
        except Exception as exc:
            current_app.logger.error(exc)
            flash("Une erreur est survenue. Veuillez réessayer.", "danger")

    return render_template("conge_form.html", demande=demande, types=types_conge())
