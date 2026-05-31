"""MyEfrei Congés — Réservation de congés (Projet BDD ALSI61).


8 fonctionnalités sur la demande de congé :
  1. Lister mes demandes (avec filtre par statut)      -> routes/mes_conges.py
  2. Réserver un congé (créer)                          -> routes/conge_reserver.py
  3. Voir le détail d'une demande                       -> routes/conge_detail.py
  4. Modifier une demande (tant qu'elle est en attente) -> routes/conge_modifier.py
  5. Annuler une demande (supprimer)                    -> routes/conge_annuler.py
  6. Valider une demande (manager) — décompte le solde  -> routes/conge_valider.py
  7. Refuser une demande (manager)                      -> routes/conge_refuser.py
  8. Grille calendrier de l'équipe + solde             -> routes/calendrier.py
"""
import os

from flask import Flask

import db
from helpers import current_user_id
from routes.calendrier import calendrier
from routes.changer_utilisateur import changer_utilisateur
from routes.conge_annuler import conge_annuler
from routes.conge_detail import conge_detail
from routes.conge_modifier import conge_modifier
from routes.conge_refuser import conge_refuser
from routes.conge_reserver import conge_reserver
from routes.conge_valider import conge_valider
from routes.mes_conges import mes_conges
from routes.stats import stats

app = Flask(__name__)
app.secret_key = os.getenv("FLASK_SECRET_KEY", "dev-secret-change-me")


@app.context_processor
def inject_user():
    """Rend l'utilisateur courant et la liste des employés dispo dans tous les templates."""
    uid = current_user_id()
    current = None
    if uid is not None:
        current = db.query(
            "SELECT id_employe, nom, prenom FROM Employe WHERE id_employe = %s", (uid,), one=True
        )
    tous = db.query("SELECT id_employe, nom, prenom FROM Employe ORDER BY nom, prenom")
    return {"current_user": current, "tous_employes": tous}


# Branchement des routes : URL -> endpoint -> vue (une vue = un fichier)
app.add_url_rule("/", "mes_conges", mes_conges)
app.add_url_rule("/reserver", "conge_reserver", conge_reserver, methods=["GET", "POST"])
app.add_url_rule("/conges/<int:id_demande>", "conge_detail", conge_detail)
app.add_url_rule("/conges/<int:id_demande>/modifier", "conge_modifier", conge_modifier, methods=["GET", "POST"])
app.add_url_rule("/conges/<int:id_demande>/annuler", "conge_annuler", conge_annuler, methods=["POST"])
app.add_url_rule("/conges/<int:id_demande>/valider", "conge_valider", conge_valider, methods=["POST"])
app.add_url_rule("/conges/<int:id_demande>/refuser", "conge_refuser", conge_refuser, methods=["POST"])
app.add_url_rule("/calendrier", "calendrier", calendrier)
app.add_url_rule("/stats", "stats", stats)
app.add_url_rule("/utilisateur", "changer_utilisateur", changer_utilisateur, methods=["POST"])


if __name__ == "__main__":
    app.run(debug=os.getenv("FLASK_DEBUG", "0") == "1", port=5000)
