"""Application Flask — Réservation de congés (Projet BDD ALSI61).

Entité principale (CRUD) : DemandeConge.
Pas d'authentification (cf. plan §10) : l'utilisateur courant est choisi
via un sélecteur dans la navbar et mémorisé en session.

8 fonctionnalités sur la demande de congé :
  1. Lister mes demandes (avec filtre par statut)
  2. Réserver un congé (créer)
  3. Voir le détail d'une demande
  4. Modifier une demande (tant qu'elle est en attente)
  5. Annuler une demande (supprimer)
  6. Valider une demande (action manager) — décompte le solde
  7. Refuser une demande (action manager)
  8. Consulter la grille calendrier de l'équipe + le solde de congés
"""
import os
from datetime import date, timedelta

from flask import (Flask, abort, flash, g, redirect, render_template, request,
                   session, url_for)

import db

app = Flask(__name__)
app.secret_key = os.getenv("FLASK_SECRET_KEY", "dev-secret-change-me")

COULEURS_STATUT = {
    "BUR": "#198754", "TT": "#0d6efd", "RTT": "#ffc107",
    "CP": "#fd7e14", "MAL": "#dc3545", "FOR": "#6f42c1",
}


# ---------------------------------------------------------------------------
# Utilisateur courant (sélecteur navbar, sans authentification)
# ---------------------------------------------------------------------------
def _current_user_id():
    if "current_user_id" not in g:
        uid = session.get("current_user_id")
        if uid is None:
            premier = db.query("SELECT id_employe FROM Employe ORDER BY id_employe LIMIT 1", one=True)
            uid = premier["id_employe"] if premier else None
            session["current_user_id"] = uid
        g.current_user_id = uid
    return g.current_user_id


@app.context_processor
def inject_user():
    """Rend l'utilisateur courant et la liste des employés dispo dans tous les templates."""
    uid = _current_user_id()
    current = None
    if uid is not None:
        current = db.query(
            "SELECT id_employe, nom, prenom FROM Employe WHERE id_employe = %s", (uid,), one=True
        )
    tous = db.query("SELECT id_employe, nom, prenom FROM Employe ORDER BY nom, prenom")
    return {"current_user": current, "tous_employes": tous}


@app.route("/utilisateur", methods=["POST"])
def changer_utilisateur():
    session["current_user_id"] = int(request.form["id_employe"])
    return redirect(request.referrer or url_for("mes_conges"))


def _types_conge():
    """Types de statut sélectionnables pour une demande (on exclut Bureau/Télétravail)."""
    return db.query(
        "SELECT id_statut, libelle, code FROM StatutJour WHERE code IN ('CP','RTT','MAL','FOR') ORDER BY libelle"
    )


def _parse_conge_form(form):
    """Extrait dates + demi-journées selon le mode choisi dans le formulaire."""
    if form.get("mode") == "half":
        d = form["date_half"]
        dj = form["demi_journee"]
        return d, d, dj, dj
    return form["date_debut"], form["date_fin"], "journee", "journee"


def _nb_jours(demande):
    if demande["demi_journee_debut"] in ("matin", "apres-midi"):
        return 0.5
    return (demande["date_fin"] - demande["date_debut"]).days + 1


# ---------------------------------------------------------------------------
# 1. Accueil — mes demandes de congé (entité principale) + filtre + solde
# ---------------------------------------------------------------------------
@app.route("/")
def mes_conges():
    uid = _current_user_id()
    statut = request.args.get("statut", "")

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
        a_valider=a_valider, statut=statut,
    )


# ---------------------------------------------------------------------------
# 2. Réserver un congé
# ---------------------------------------------------------------------------
@app.route("/reserver", methods=["GET", "POST"])
def conge_reserver():
    uid = _current_user_id()
    if request.method == "POST":
        try:
            date_debut, date_fin, dj_debut, dj_fin = _parse_conge_form(request.form)
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
            app.logger.error(exc)
            flash("Une erreur est survenue. Veuillez réessayer.", "danger")

    return render_template("conge_form.html", demande=None, types=_types_conge())


# ---------------------------------------------------------------------------
# 3. Détail d'une demande
# ---------------------------------------------------------------------------
@app.route("/conges/<int:id_demande>")
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

    nb_jours = _nb_jours(demande)
    peut_valider = demande["id_manager"] == _current_user_id()
    return render_template(
        "conge_detail.html", demande=demande, nb_jours=nb_jours, peut_valider=peut_valider
    )


# ---------------------------------------------------------------------------
# 4. Modifier une demande (uniquement si en attente)
# ---------------------------------------------------------------------------
@app.route("/conges/<int:id_demande>/modifier", methods=["GET", "POST"])
def conge_modifier(id_demande):
    demande = db.query("SELECT * FROM DemandeConge WHERE id_demande = %s", (id_demande,), one=True)
    if not demande:
        flash("Demande introuvable.", "warning")
        return redirect(url_for("mes_conges"))
    if demande["id_employe"] != _current_user_id():
        abort(403)
    if demande["statut_demande"] != "en_attente":
        flash("Seules les demandes en attente peuvent être modifiées.", "warning")
        return redirect(url_for("conge_detail", id_demande=id_demande))

    if request.method == "POST":
        try:
            date_debut, date_fin, dj_debut, dj_fin = _parse_conge_form(request.form)
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
            app.logger.error(exc)
            flash("Une erreur est survenue. Veuillez réessayer.", "danger")

    return render_template("conge_form.html", demande=demande, types=_types_conge())


# ---------------------------------------------------------------------------
# 5. Annuler (supprimer) une demande
# ---------------------------------------------------------------------------
@app.route("/conges/<int:id_demande>/annuler", methods=["POST"])
def conge_annuler(id_demande):
    demande = db.query("SELECT * FROM DemandeConge WHERE id_demande = %s", (id_demande,), one=True)
    if not demande:
        flash("Demande introuvable.", "warning")
        return redirect(url_for("mes_conges"))
    if demande["id_employe"] != _current_user_id():
        abort(403)
    try:
        db.execute("DELETE FROM DemandeConge WHERE id_demande = %s", (id_demande,))
        flash("Demande annulée.", "success")
    except Exception as exc:
        app.logger.error(exc)
        flash("Une erreur est survenue. Veuillez réessayer.", "danger")
    return redirect(url_for("mes_conges"))


# ---------------------------------------------------------------------------
# 6. Valider une demande (action manager) — décompte le solde si applicable
# ---------------------------------------------------------------------------
@app.route("/conges/<int:id_demande>/valider", methods=["POST"])
def conge_valider(id_demande):
    uid = _current_user_id()
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

    nb_jours = _nb_jours(demande)
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
        flash(f"Demande validée ({nb_jours} jour(s)).", "success")
    except Exception as exc:
        app.logger.error(exc)
        flash("Solde insuffisant ou contrainte violée — validation refusée.", "danger")
    return redirect(url_for("conge_detail", id_demande=id_demande))


# ---------------------------------------------------------------------------
# 7. Refuser une demande (action manager)
# ---------------------------------------------------------------------------
@app.route("/conges/<int:id_demande>/refuser", methods=["POST"])
def conge_refuser(id_demande):
    uid = _current_user_id()
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
        app.logger.error(exc)
        flash("Une erreur est survenue. Veuillez réessayer.", "danger")
    return redirect(url_for("conge_detail", id_demande=id_demande))


# ---------------------------------------------------------------------------
# 8a. Grille calendrier de l'équipe
# ---------------------------------------------------------------------------
@app.route("/calendrier")
def calendrier():
    try:
        offset = int(request.args.get("s", 0))
    except ValueError:
        offset = 0

    today = date.today()
    lundi = today - timedelta(days=today.weekday()) + timedelta(weeks=offset)
    jours = [lundi + timedelta(days=i) for i in range(5)]
    debut, fin = jours[0], jours[-1]

    employes = db.query(
        """
        SELECT e.id_employe, e.nom, e.prenom, s.libelle AS service
        FROM Employe e JOIN Service s ON s.id_service = e.id_service
        ORDER BY e.nom, e.prenom
        """
    )
    entrees = db.query(
        """
        SELECT ep.id_employe, ep.date, ep.demi_journee, sj.code, sj.libelle
        FROM EntreePlanning ep
        JOIN StatutJour sj ON sj.id_statut = ep.id_statut
        WHERE ep.date BETWEEN %s AND %s
        """,
        (debut, fin),
    )
    planning = {}
    for ent in entrees:
        planning.setdefault(ent["id_employe"], {}).setdefault(ent["date"].isoformat(), []).append(ent)

    return render_template(
        "calendrier.html", employes=employes, jours=jours, planning=planning,
        couleurs=COULEURS_STATUT, offset=offset, debut=debut, fin=fin,
    )


# ---------------------------------------------------------------------------
# 8b. Statistiques (bonus)
# ---------------------------------------------------------------------------
@app.route("/stats")
def stats():
    demandes_par_statut = db.query(
        """
        SELECT statut_demande, COUNT(*) AS nb
        FROM DemandeConge
        GROUP BY statut_demande
        ORDER BY nb DESC
        """
    )
    top_demandeurs = db.query(
        """
        SELECT CONCAT_WS(' ', e.prenom, e.nom) AS employe, COUNT(dc.id_demande) AS nb
        FROM Employe e
        JOIN DemandeConge dc ON dc.id_employe = e.id_employe
        GROUP BY e.id_employe, employe
        ORDER BY nb DESC
        LIMIT 5
        """
    )
    repartition_types = db.query(
        """
        SELECT sj.libelle, sj.code, COUNT(dc.id_demande) AS nb
        FROM StatutJour sj
        LEFT JOIN DemandeConge dc ON dc.id_statut = sj.id_statut
        WHERE sj.code IN ('CP','RTT','MAL','FOR')
        GROUP BY sj.id_statut, sj.libelle, sj.code
        ORDER BY nb DESC
        """
    )
    return render_template(
        "stats.html", demandes_par_statut=demandes_par_statut,
        top_demandeurs=top_demandeurs, repartition_types=repartition_types,
        couleurs=COULEURS_STATUT,
    )


if __name__ == "__main__":
    app.run(debug=os.getenv("FLASK_DEBUG", "0") == "1", port=5000)
