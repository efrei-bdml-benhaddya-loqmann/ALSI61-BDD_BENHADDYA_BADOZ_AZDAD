"""Sélecteur d'utilisateur courant (navbar, sans authentification)."""
from flask import redirect, request, session, url_for


def changer_utilisateur():
    session["current_user_id"] = int(request.form["id_employe"])
    return redirect(request.referrer or url_for("mes_conges"))
