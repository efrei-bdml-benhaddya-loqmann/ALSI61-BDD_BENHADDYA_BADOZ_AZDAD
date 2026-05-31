"""Route 8b — Statistiques (bonus)."""
import db
from flask import render_template

from helpers import COULEURS_STATUT


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
