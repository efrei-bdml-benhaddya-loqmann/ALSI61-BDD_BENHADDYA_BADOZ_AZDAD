-- ====================================================
-- 09_vues.sql — Vues de consolidation
-- ====================================================
-- Objectif : factoriser les jointures récurrentes (demande → demandeur →
-- service → type → valideur) et le calcul du nombre de jours, utilisés à la
-- fois par les requêtes d'interrogation (R1, R4, R6, R10) et par l'application
-- Flask (routes / et /conges/<id>). Une seule définition, réutilisée partout.
-- ====================================================
USE planning_entreprise;

-- ----------------------------------------------------
-- v_demandes_completes — une demande de congé « à plat »
-- avec son demandeur, son service, son type, son valideur
-- et le nombre de jours décomptés (0.5 si demi-journée).
-- ----------------------------------------------------
CREATE OR REPLACE VIEW v_demandes_completes AS
SELECT  dc.id_demande,
        dc.date_debut,
        dc.date_fin,
        dc.demi_journee_debut,
        dc.statut_demande,
        dc.date_soumission,
        dc.motif,
        CONCAT_WS(' ', e.prenom, e.nom)  AS demandeur,
        s.libelle                        AS service,
        sj.code                          AS code_type,
        sj.libelle                       AS type_conge,
        CONCAT_WS(' ', v.prenom, v.nom)  AS valideur,
        CASE
            WHEN dc.demi_journee_debut IN ('matin', 'apres-midi') THEN 0.5
            ELSE DATEDIFF(dc.date_fin, dc.date_debut) + 1
        END                              AS nb_jours
FROM    DemandeConge dc
JOIN    Employe e     ON e.id_employe = dc.id_employe
JOIN    Service s     ON s.id_service = e.id_service
JOIN    StatutJour sj ON sj.id_statut = dc.id_statut
LEFT JOIN Employe v   ON v.id_employe = dc.id_manager_valideur;
